#cloud-config

hostname: ${hostname}
coreos:
  update:
    reboot-strategy: off
  etcd2:
    discovery: ${token}
    listen-client-urls: http://0.0.0.0:2379
  units:
    - name: etcd2.service
      command: start
    - name: mnt-registry.mount
      command: start
      content: |
        [Mount]
        What=/dev/xvdf
        Where=/mnt/registry
        Type=ext4
    - name: docker.service
      command: start
    - name: registry.service
      command: start
      content: |
        [Unit]
        Description = Registry unit service
        [Service]
        ExecStartPre=-/usr/bin/docker stop registry
        ExecStartPre=-/usr/bin/docker rm -v registry
        ExecStart=/usr/bin/docker run \
          -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
          -e REGISTRY_HTTP_TLS_CERTIFICATE=/etc/registry/ssl/registry.crt \
          -e REGISTRY_HTTP_TLS_KEY=/etc/registry/ssl/registry.key \
          -v /mnt/registry:/var/lib/registry \
          -v /etc/registry/ssl/:/etc/registry/ssl/ \
          -p 443:443 \
          --restart=always \
          --name registry \
          registry:2
        ExecStop=/usr/bin/docker stop registry
        Restart=always
        RestartSec=10
        [Install]
        WantedBy=multi-user.target
