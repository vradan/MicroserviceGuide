#cloud-config

hostname: ${hostname}
coreos:
  update:
    reboot-strategy: off
  etcd2:
    discovery: ${token}
    listen-client-urls: http://0.0.0.0:2379
  flannel:
    interface: $private_ipv4
    etcd_endpoints: http://etcdnode1.vradan.com:2379,http://etcdnode2.vradan.com:2379,http://etcdnode3.vradan.com:2379
  units:
    - name: etcd2.service
      command: start
    - name: tls.service
      command: start
      content: |
        [Unit]
        Description=Generate TLS asset
        [Service]
        Environment="WORKER_IP=$private_ipv4"
        User=root
        Group=root
        RemainAfterExit=yes
        ExecStartPre=/bin/sleep 20
        ExecStartPre=-/usr/bin/openssl genrsa \
          -out /etc/kubernetes/ssl/${hostname}.key 2048
        ExecStartPre=-/usr/bin/openssl req -new \
          -key /etc/kubernetes/ssl/${hostname}.key \
          -out /tmp/certs/${hostname}.csr \
          -subj "/CN=${hostname}" \
          -config /tmp/certs/worker-openssl.cnf
        ExecStartPre=-/usr/bin/openssl x509 -req \
          -in /tmp/certs/${hostname}.csr \
          -CA /tmp/certs/ca.crt \
          -CAkey /tmp/certs/ca.key \
          -CAcreateserial \
          -out /etc/kubernetes/ssl/${hostname}.crt \
          -days 365 -extensions v3_req \
          -extfile /tmp/certs/worker-openssl.cnf
        ExecStartPre=-/usr/bin/mv /tmp/certs/ca.crt /etc/kubernetes/ssl/
        ExecStartPre=-/usr/bin/chmod -R 600 /etc/kubernetes/ssl/
        ExecStartPre=-/usr/bin/chown -R root /etc/kubernetes/ssl/
        ExecStart=/usr/bin/cat /etc/kubernetes/ssl/${hostname}.crt
        ExecStartPost=-/usr/bin/rm -dR /tmp/certs/
        Restart=always
        RestartSec=10
        [Install]
        WantedBy=multi-user.target
    - name: flanneld.service
      command: start
      drop-ins:
        - name: 50-network-config.conf
          content: |
            [Unit]
            Requires=etcd2.service
            [Service]
            ExecStartPre=/usr/bin/etcdctl set /coreos.com/network/config \
               '{                            \
                  "Network": "10.1.0.0/16",  \
                  "Backend": {               \
                    "Type": "vxlan"          \
                  }                          \
               '}
    - name: rkt.service
      command: start
      content: |
        [Unit]
        Description=Rkt Unit
        [Service]
        ExecStart=/usr/bin/rkt api-service
        [Install]
        WantedBy=multi-user.target
    - name: docker.service
      command: start
      drop-ins:
        - name: 40-flannel.conf
          content: |
            [Unit]
            Requires=flanneld.service
            After=flanneld.service
            [Service]
            EnvironmentFile=/etc/kubernetes/cni/docker_opts_cni.env
    - name: kubelet.service
      command: start
      content: |
        [Unit]
        Requires=docker.service tls.service
        After=docker.service tls.service
        [Service]
        ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests
        ExecStartPre=/usr/bin/mkdir -p /var/log/containers
        ExecStart=/opt/kubernetes/bin/kubelet \
          --require-kubeconfig \
          --kubeconfig=/var/lib/worker-kubeconfig \
          --container-runtime=docker \
          --pod-manifest-path /etc/kubernetes/manifests/ \
          --allow-privileged=true \
          --network-plugin=cni \
          --cni-bin-dir=/etc/cni/bin \
          --node-labels="nodeRole=worker" \
          --cloud-provider=aws
        Restart=always
        RestartSec=10
        [Install]
        WantedBy=multi-user.target
    - name: kube-proxy.service
      command: start
      content: |
        [Unit]
        Description=Kube Proxy Unit
        Requires=kubelet.service
        After=kubelet.service
        [Service]
        ExecStart=/opt/kubernetes/bin/kube-proxy \
          --kubeconfig=/var/lib/worker-kubeconfig \
          --master=https://k8smaster.vradan.com
        Restart=always
        RestartSec=10
        [Install]
        WantedBy=multi-user.target
write_files:
  - path: "/etc/cni/net.d/10-flannel.conf" 
    permissions: "0644"
    owner: "root"
    content: |
      {
        "cniVersion": "0.3.1",
        "name": "podnet",
        "type": "flannel",
        "delegate": {
          "isDefaultGateway": true
        }
      }
  - path: "/var/lib/worker-kubeconfig"
    content: |
      apiVersion: v1
      kind: Config
      clusters:
      - name: main-cluster
        cluster:
          certificate-authority: /etc/kubernetes/ssl/ca.crt
          server: https://k8smaster.vradan.com
      users:
      - name: apiserver
        user:
          client-certificate: /etc/kubernetes/ssl/${hostname}.crt
          client-key: /etc/kubernetes/ssl/${hostname}.key
      contexts:
      - context:
          cluster: main-cluster
          user: apiserver
        name: main-context
      current-context: main-context
  - path: "/etc/kubernetes/cni/docker_opts_cni.env"
    content: |
      DOCKER_OPT_BIP=""
      DOCKER_OPT_IPMASQ=""

