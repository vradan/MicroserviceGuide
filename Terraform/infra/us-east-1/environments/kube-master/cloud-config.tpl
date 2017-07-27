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
        Requires=docker.service
        After=docker.service
        [Service]
        ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests
        ExecStartPre=/usr/bin/mkdir -p /var/log/containers
        ExecStart=/opt/kubernetes/bin/kubelet \
          --require-kubeconfig \
          --container-runtime=docker \
          --pod-manifest-path /etc/kubernetes/manifests/ \
          --allow-privileged=true \
          --network-plugin=cni \
          --cni-bin-dir=/etc/cni/bin \
          --node-labels="nodeRole=master" \
          --hostname-override=${hostname} \
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
          --kubeconfig=/var/lib/kube-proxy/kubeconfig \
          --master=http://127.0.0.1:8080 \
          --hostname-override=${hostname}
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
  - path: "/etc/kubernetes/manifests/apiserver.json"
    permission: "0644"
    owner: "root"
    content: |
      {
        "kind": "Pod",
        "apiVersion": "v1",
        "metadata": {
          "name": "kube-apiserver"
        },
        "spec": {
          "hostNetwork": true,
          "containers": [
            {
              "name": "kube-apiserver",
              "image": "quay.io/coreos/hyperkube:v1.7.0_coreos.0",
              "command": [
                "/hyperkube",
                "apiserver",
                "--service-cluster-ip-range=10.3.0.0/16",
                "--etcd-servers=http://etcdnode1.vradan.com:2379,http://etcdnode2.vradan.com:2379,http://etcdnode3.vradan.com:2379",
                "--storage-backend=etcd2",
                "--storage-media-type=application/json",
                "--bind-address=0.0.0.0",
                "--advertise-address=$private_ipv4",
                "--secure-port=443",
                "--tls-cert-file=/etc/kubernetes/ssl/apiserver.crt",
                "--tls-private-key-file=/etc/kubernetes/ssl/apiserver.key",
                "--client-ca-file=/etc/kubernetes/ssl/ca.crt",
                "--anonymous-auth=false",
                "--allow-privileged=true"
              ],
              "ports": [
                {
                  "name": "https",
                  "hostPort": 443,
                  "containerPort": 443
                },
                {
                  "name": "local",
                  "hostPort": 8080,
                  "containerPort": 8080
                }
              ],
              "volumeMounts": [
                {
                  "name": "kubernetes-ssl",
                  "mountPath": "/etc/kubernetes/ssl",
                  "readOnly": true
                }
              ],
              "livenessProbe": {
                "httpGet": {
                  "scheme": "HTTP",
                  "host": "127.0.0.1",
                  "port": 8080,
                  "path": "/healthz"
                },
                "initialDelaySeconds": 90,
                "timeoutSeconds": 15
              }
            }
          ],
          "volumes": [
            {
              "name": "kubernetes-ssl",
              "hostPath": {
                "path": "/etc/kubernetes/ssl"
              }
            }
          ]
        }
      }
  - path: "/etc/kubernetes/manifests/kube-scheduler.json"
    permission: "0644"
    owner: "root"
    content: |
      {
        "kind": "Pod",
        "apiVersion": "v1",
        "metadata": {
          "name": "kube-scheduler"
        },
        "spec": {
          "hostNetwork": true,
          "containers": [
            {
              "name": "kube-scheduler",
              "image": "quay.io/coreos/hyperkube:v1.7.0_coreos.0",
              "command": [
                "/hyperkube",
                "scheduler",
                "--master=http://127.0.0.1:8080"
              ],
              "livenessProbe": {
                "httpGet": {
                  "scheme": "HTTP",
                  "host": "127.0.0.1",
                  "port": 10251,
                  "path": "/healthz"
                },
                "initialDelaySeconds": 30,
                "timeoutSeconds": 15
              }
            }
          ]
        }
      }
  - path: "/etc/kubernetes/manifests/kube-controller-manager.json"
    permission: "0644"
    owner: "root"
    content: |
      {
        "kind": "Pod",
        "apiVersion": "v1",
        "metadata": {
          "name": "kube-controller-manager"
        },
        "spec": {
          "hostNetwork": true,
          "containers": [
            {
              "name": "kube-controller-manager",
              "image": "quay.io/coreos/hyperkube:v1.7.0_coreos.0",
              "command": [
                "/hyperkube",
                "controller-manager",
                "--master=http://127.0.0.1:8080",
                "--service-account-private-key-file=/etc/kubernetes/ssl/apiserver.key",
                "--root-ca-file=/etc/kubernetes/ssl/ca.crt",
                "--cloud-provider=aws"
              ],
              "volumeMounts": [
                {
                  "name": "certs",
                  "mountPath": "/etc/kubernetes/ssl",
                  "readOnly": true
                }
              ],
              "livenessProbe": {
                "httpGet": {
                  "scheme": "HTTP",
                  "host": "127.0.0.1",
                  "port": 10252,
                  "path": "/healthz"
                },
                "initialDelaySeconds": 30,
                "timeoutSeconds": 15
              }
            }
          ],
          "volumes": [
            {
              "name": "certs",
              "hostPath": {
                "path": "/etc/kubernetes/ssl/"
              }
            }
          ]
        }
      }
  - path: "/etc/kubernetes/cni/docker_opts_cni.env"
    content: |
      DOCKER_OPT_BIP=""
      DOCKER_OPT_IPMASQ=""
