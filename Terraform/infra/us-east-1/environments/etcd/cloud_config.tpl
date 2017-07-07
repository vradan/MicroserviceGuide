#cloud-config

hostname: ${hostname}
coreos:
  update:
    reboot-strategy: off
  etcd2:
    name: ${hostname}
    discovery: ${token}
    initial-advertise-peer-urls: http://$private_ipv4:2380
    listen-peer-urls: http://$private_ipv4:2380
    advertise-client-urls: http://$public_ipv4:2379
    listen-client-urls: http://0.0.0.0:2379
  units:
    - name: etcd2.service
      command: start
