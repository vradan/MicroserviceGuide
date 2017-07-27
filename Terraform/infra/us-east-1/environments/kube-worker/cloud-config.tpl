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
    - name: k8sreq.service
      command: start
      content: |
        [Unit]
        Description=Install Kubernetes requirements
        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStartPre=/usr/bin/mkdir -p /etc/cni/bin
        ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/ssl/
        ExecStartPre=/usr/bin/mkdir -p /opt/kubernetes/
        ExecStart=/usr/bin/wget -P /tmp/cni https://github.com/containernetworking/cni/releases/download/v0.5.2/cni-amd64-v0.5.2.tgz
        ExecStart=/usr/bin/tar xvzf /tmp/cni/cni-amd64-v0.5.2.tgz -C /etc/cni/bin/
        ExecStart=/usr/bin/wget -P /tmp/ https://dl.k8s.io/v1.7.1/kubernetes-node-linux-amd64.tar.gz
        ExecStart=/usr/bin/tar xvzf /tmp/kubernetes-node-linux-amd64.tar.gz -C /tmp/
        ExecStart=/usr/bin/mv /tmp/kubernetes/node/bin/ /opt/kubernetes/
        ExecStartPost=/usr/bin/chmod -R 755 /opt/kubernetes/
        ExecStartPost=-/usr/bin/rm /tmp/kubernetes-node-linux-amd64.tar.gz
        ExecStartPost=-/usr/bin/rm -dR /tmp/kubernetes
    - name: tls.service
      command: start
      content: |
        [Unit]
        Description=Generate TLS asset
        ConditionPathExists=!/etc/kubernetes/ssl/${hostname}.crt
        [Service]
        User=root
        Group=root
        Type=oneshot
        RemainAfterExit=yes
        ExecStartPre=/bin/sleep 20
        ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/ssl/
        ExecStartPre=/usr/bin/openssl genrsa \
          -out /tmp/certs/${hostname}.key 2048
        ExecStartPre=/usr/bin/openssl req -new \
          -key /tmp/certs/${hostname}.key \
          -out /tmp/certs/${hostname}.csr \
          -subj "/CN=${hostname}" \
          -config /tmp/certs/worker-openssl.cnf
        ExecStartPre=/usr/bin/openssl x509 -req \
          -in /tmp/certs/${hostname}.csr \
          -CA /tmp/certs/ca.crt \
          -CAkey /tmp/certs/ca.key \
          -CAcreateserial \
          -out /tmp/certs/${hostname}.crt \
          -days 365 -extensions v3_req \
          -extfile /tmp/certs/worker-openssl.cnf
        ExecStart=/usr/bin/mv /tmp/certs/ca.crt /etc/kubernetes/ssl/
        ExecStart=/usr/bin/mv /tmp/certs/${hostname}.key /etc/kubernetes/ssl/
        ExecStart=/usr/bin/mv /tmp/certs/${hostname}.crt /etc/kubernetes/ssl/
        ExecStartPost=-/usr/bin/chmod -R 600 /etc/kubernetes/ssl/
        ExecStartPost=-/usr/bin/chown -R root /etc/kubernetes/ssl/
        ExecStartPost=-/usr/bin/rm -dR /tmp/certs/
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
        Requires=docker.service tls.service k8sreq.service
        After=docker.service tls.service k8sreq.service
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
          --kubeconfig=/var/lib/worker-kubeconfig \
          --master=https://kubemaster.vradan.com \
          --hostname-override=${hostname}
        Restart=always
        RestartSec=10
        [Install]
        WantedBy=multi-user.target
    - name: cloudwatch.service
      content: |
        [Unit]
        Description=CloudWatch Unit
        Requires=kubelet.service
        After=kubelet.service
        [Service]
        User=root
        PermissionsStartOnly=true
        ExecStartPre=-/usr/bin/docker pull registry.vradan.com/cloudwatch
        ExecStartPre=-/usr/bin/docker rm -f cloudwatch
        ExecStart=/usr/bin/docker run \
          -e PRIVATE_IPV4=$private_ipv4 \
          -e AWS_DEFAULT_REGION=us-east-1 \
          --name cloudwatch \
          registry.vradan.com/cloudwatch
    - name: cloudwatch.timer
      command: start
      content: |
        [Unit]
        Description=Run cloudwatch.service every minute
        [Timer]
        OnCalendar=*:0/1
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
          server: https://kubemaster.vradan.com
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
  - path: "/tmp/certs/worker-openssl.cnf"
    content: |
      [req]
      req_extensions = v3_req
      distinguished_name = req_distinguished_name
      [req_distinguished_name]
      [ v3_req ]
      basicConstraints = CA:FALSE
      keyUsage = nonRepudiation, digitalSignature, keyEncipherment
      subjectAltName = @alt_names
      [alt_names]
      IP.1 = $private_ipv4
  - path: "/tmp/certs/ca.crt"
    content: |
      -----BEGIN CERTIFICATE-----
      MIIDuzCCAqOgAwIBAgIJAMM9/LITI7TvMA0GCSqGSIb3DQEBCwUAMHQxCzAJBgNV
      BAYTAkJSMRIwEAYDVQQIDAlTYW8gUGF1bG8xEjAQBgNVBAcMCVNhbyBQYXVsbzET
      MBEGA1UECgwKdnJhZGFuLmNvbTETMBEGA1UECwwKa3ViZXJuZXRlczETMBEGA1UE
      AwwKa3ViZXJuZXRlczAeFw0xNzA3MjAyMTU4NTNaFw00NDEyMDUyMTU4NTNaMHQx
      CzAJBgNVBAYTAkJSMRIwEAYDVQQIDAlTYW8gUGF1bG8xEjAQBgNVBAcMCVNhbyBQ
      YXVsbzETMBEGA1UECgwKdnJhZGFuLmNvbTETMBEGA1UECwwKa3ViZXJuZXRlczET
      MBEGA1UEAwwKa3ViZXJuZXRlczCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
      ggEBAM6AWL7TN3iq7PrBVpkOkuKbs+jd7WM5lC1Kf3BGHdpc/ub2lB9XrROcuM9D
      vwCdImvpcsAy8JV+/wfhUS2c/OI1ekeN12EyjRU7IB0KWCNYwi8b76YKCVlH74HX
      J2sk24VmtkE+ddU4CRodIYOYfkvS6hbgJZ6GCwZvqvsPYjPT9Eb7IMw/8JtAuNBE
      bl9zkQ1luMSjQeM/z5kDzcbadWeXZWj/rDz82wFXjX00KQ8qCp6L/GdVKKcnsLhD
      0LvDhX3M6MXAHpDGvPDpK+D/rsxtm5Sfq9QzGWUW0vKCurEztZ8e4AtKxcFLh+tZ
      zuolHhTAOdPXFhceXH/nq2Js5ucCAwEAAaNQME4wHQYDVR0OBBYEFBOUg+PLEOeo
      tDXzpNJ8pA5ATk4AMB8GA1UdIwQYMBaAFBOUg+PLEOeotDXzpNJ8pA5ATk4AMAwG
      A1UdEwQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBAMr4n5hGrNorwxeVgKDmJQly
      JXwUOKnJhMvgX45ASyeOQf1Hru8g73W9QNJ9bVN42wdqSk8XOhHThhQJjR8hqnH7
      OjSlPIyzjEIX8U/Zd2b/6HBJp2J0r5PTBxdDVpgvx8S2WcKBm7tgZzzjMgp9UDdR
      BrAYXLcDKj7aLJD5Xm+E93vRg4RtlCPiY/Dm/EePTtGo4wFTDJ2KWiOrdMI1X0zm
      QEWBYuKb1rYGe5I1RhVADF6IYn66VEvKLk8bkpp9ggJ7LDUYyOcIgxR4vfKKNSPO
      AQswNM9uFrqevqmxDztijTNwqlmla85C+LT5/f6pzKyw0G/uMquWU3UX6pCCn+w=
      -----END CERTIFICATE-----
  - path: "/tmp/certs/ca.key"
    content: |
      -----BEGIN RSA PRIVATE KEY-----
      MIIEogIBAAKCAQEAzoBYvtM3eKrs+sFWmQ6S4puz6N3tYzmULUp/cEYd2lz+5vaU
      H1etE5y4z0O/AJ0ia+lywDLwlX7/B+FRLZz84jV6R43XYTKNFTsgHQpYI1jCLxvv
      pgoJWUfvgdcnayTbhWa2QT511TgJGh0hg5h+S9LqFuAlnoYLBm+q+w9iM9P0Rvsg
      zD/wm0C40ERuX3ORDWW4xKNB4z/PmQPNxtp1Z5dlaP+sPPzbAVeNfTQpDyoKnov8
      Z1UopyewuEPQu8OFfczoxcAekMa88Okr4P+uzG2blJ+r1DMZZRbS8oK6sTO1nx7g
      C0rFwUuH61nO6iUeFMA509cWFx5cf+erYmzm5wIDAQABAoIBACYSjcopARozUVvu
      F3xCrpwvHt15RVI9BG/RQ2u80bY33RtSLP8WWCe8hmpYUDfZwMXqlaiP+8FkV7rp
      NOFXB1zhhTj6EtKt0ksuyn3wMU3bCHpNCUMwqIaYd7UVqQPdGMggpsuiq3DzUuJI
      qqwrimWKbnRnQShYCGJYZkrBjFaHkUsNrNXAOd1c1ltK2Hn6zdVk+6SzurQIufuP
      9px/SjF7vgyhYN8ipUR3YD8fgbORo1wbLjKcqUBraeOw9o4vsk4+JTJ5aZv9BWEt
      ufDMUfPkFAD7nbQ6F/B5WD6AW88Y00VlUegzp0OB/DS76sC99kBEURu8eu/E1hW5
      X9aF1ukCgYEA/2CGY0YFvbEovx60Ik4e4xOxpbZPLGVD0eLNCgQqpccYoOW1TPE9
      HaSYpZZuE8AybTgsj28Oww90Ippm3aKQWfRHiD03gEeqzBpuNGOm2XaquDFA6CDj
      mwvnf6RLzeBCC5XOJ27Bnh2xTT0cHcMRybVBp41G5sJ4YjG2wc9NuN0CgYEAzwFM
      4+1Mvtc4+BoS5b08BanP2XoZBxx+q7vkpBkA+/RalypMA6GF+dkkFDFFkWBwbGZ3
      nVKODa/XGZu3O10I3u1SimgQBXTuZw5OJ3dzmPgoSlrMLf91y7XkajYyeCGBAZjC
      MPD+4UY6HF5HiJZP7IgeYBqsQ6opvdOSyJFewJMCgYB1Kl/94/52TXWYWgnjQ1xA
      aqSylrY0dDFtdlUEJ205qeLOzxUjO/sCQqYWMrJGNYPtQDyRgi6Pp+NsjNJtFUyN
      ONoo041HOZpPEkFFoALI+vzQjShuV8iVNhz8HvD4f89NaWmwBcynMpBKE6N2tCzR
      EmwQ52yEKuz4gD6NJQNPsQKBgGAZsXGLI/rg/dCogidnz6qtaBIFjgLwJpphk0bf
      WMafbUMKXtm8re8M8KPzL+HKzMZ2V4eQ4OPXw1tfIBSOH2Um9g/NOcreuyLa0Eug
      N+lHI6VJO8sK8svMuKraWFnO7A4qtdR0vU8mBCpRVpJBff9IPhnNqDWNlO1MgLNe
      UYfDAoGAZoryLMbQ/Y/+MBXutXRsjv7JX5TVvXXIbFEF5q3YmVXsPS701bw90CAQ
      9FtQFuEvsQGP0YpRoMJcvwD7bPKHOMPQ3aWO+SHaqgXJRc2C5Nth/iQLu7F1RyK7
      LFlnbxl/BJhrMBnM8SWUBq/HeUHUvZGlRvSXi2awc0uX1srdnso=
      -----END RSA PRIVATE KEY-----
  - path: "/etc/docker/certs.d/registry.vradan.com/ca.crt"
    content: |
      -----BEGIN CERTIFICATE-----
      MIIFyTCCA7GgAwIBAgIJAKgGh4X/f7hOMA0GCSqGSIb3DQEBCwUAMHsxCzAJBgNV
      BAYTAkJSMRIwEAYDVQQIDAlTYW8gUGF1bG8xEjAQBgNVBAcMCVNhbyBQYXVsbzET
      MBEGA1UECgwKdnJhZGFuLmNvbTERMA8GA1UECwwIcmVnaXN0cnkxHDAaBgNVBAMM
      E3JlZ2lzdHJ5LnZyYWRhbi5jb20wHhcNMTcwNzI0MTYwNzU4WhcNMTgwNzI0MTYw
      NzU4WjB7MQswCQYDVQQGEwJCUjESMBAGA1UECAwJU2FvIFBhdWxvMRIwEAYDVQQH
      DAlTYW8gUGF1bG8xEzARBgNVBAoMCnZyYWRhbi5jb20xETAPBgNVBAsMCHJlZ2lz
      dHJ5MRwwGgYDVQQDDBNyZWdpc3RyeS52cmFkYW4uY29tMIICIjANBgkqhkiG9w0B
      AQEFAAOCAg8AMIICCgKCAgEA3o6s3MghVz0/glgFLi6jjvkpi3vOIYvOkX0tANo2
      7zHR60ZH6csCzVrViS9M4FEkoQPZ95w0ZkGoyg07Undwu9IEy8I3tBI84pIbzYHt
      gA57hbISrDddZ/U6zaZppERh9/mzOkrtYHspT1JVLTLZ4+idkwz2Nv+IEs+y3q4Z
      LJcCHw9hA6MXIqTFHhqOER+NJXAKtKWTIe6Jhzzk3qQnI5fl5Re4JYJTCP+nYqm7
      KCLGjrHVLjfvSQXXHPSyp5uxgSqkYdY2FuVViXMszKStyma9xYLBxEvEWLU+tm9s
      uU6klLKPpisXPUdPbZJVe7iMxkUgTc/ruvNOdz97ldZPfQig2UePUmisHPpstAve
      fnFXKtAy9kw4CLIv6AgwigQ20oFGKSnRt1Ag3EDHUX+DokNfuhL1NAI229F2rlxR
      SIFRvFkJCA0efHgH6PgyikytzUUQhEyxk40zUAgBv+H6kKGFTTD0572JhKxmZvPO
      J8YABze2MpUEeDD6Q/t6OSTkHULIRD/9Jd0QZzMd20k6BxTIiQEg8yiHYrLu4Sti
      1LaB08clH/5o4P8EzQvtQ6Vn6ydj61fJxVxPq9o8RK67OofowcG/+LHz9ua+tv0U
      k9L8lALXIDauKr5TgfAQ8etfz47JuyfA+mAsjRFEXIqDcPunVkdXo3sdfRZxeX1Z
      Zt8CAwEAAaNQME4wHQYDVR0OBBYEFATpMrCccYtmN9UYN+7gF5SSuVIaMB8GA1Ud
      IwQYMBaAFATpMrCccYtmN9UYN+7gF5SSuVIaMAwGA1UdEwQFMAMBAf8wDQYJKoZI
      hvcNAQELBQADggIBALIl8JfRl2nFqX3IHOknVWg4H4CRS6UDl8d9PlgUcsaBPdGL
      UpsuiZ8XjgA2qHWLgDP1bFATGHntcnQUmVyGBZosWT5WqCTTExFaZQ83OwXSEAGX
      ene6P6TzD6E8VgXG7MROU2nZcld8L3ZTPjiocX/YpnfEkeidoosQtixyvGqsvjEB
      F5dyDesQlxV+XXiFQ5NQqE6cOJadXCF2r3GbidkY+GqNugvfvlOXAuX5LzUefLQP
      KMP9ne6KAKXSB+BW/Dhhl123DkiJ9x7zo68PYou2u7LtM+7uJ7XbD8Zz8Y/MeuUf
      QsZH/Yp9qGtR+YpzpJXHSNCALQv4L5OwT0pnYRxoa9aNfVRJDbQsOddAK/nQ+hkZ
      zLRyD6UlO5Up+vczH+SwHIT6mDN4MnnL2cA1OSXLbZFBYa7rFz48CUgfZYLEKxDI
      MmdCGsQ9N0qEmgwu9z3kHHECA0ldsjk4wgcDnIIEhi7NV5DMDgjZDFLm8Kg5FepH
      LYjZreg2lpq0L8HTRoqEOHn8GWPdraCvSH7JEE3JC4WlSuWtyKK4QZp8UyPl8jfi
      XEeJF2fmduXvf989L3gfngJv3gsW8vA1TvAhqjNla0XaB7XEtpIxr9XWyiVB0WZO
      riRz/O4jFxyZz8p57ShDqYY2YUmLM5YYRbLhK24sNF73MUbVkdCdb/I+VsYa
      -----END CERTIFICATE-----
