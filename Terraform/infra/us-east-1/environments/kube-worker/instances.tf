resource "aws_instance" "kubernetes-worker" {

  count = "${var.worker-count}"

  ami = "${module.global-vars.coreos-stable-ami}"
  instance_type = "${var.instance-type}"

  vpc_security_group_ids = ["${aws_security_group.worker-sg.id}"]
  subnet_id = "${element(data.terraform_remote_state.vpc.subnets, 0)}"

  key_name = "${module.global-vars.keypair}"

  user_data = "${element(data.template_file.cloud-config.*.rendered, count.index)}"

  iam_instance_profile = "${data.terraform_remote_state.iam.flannel-profile}"

  source_dest_check = false

  tags {
    Name = "kube-worker-${count.index + 1}"
  }

  root_block_device {
    volume_type = "${var.volume-type}"
    volume_size = "${var.volume-size}"
    delete_on_termination = true
  }

  connection {
    type = "ssh"
    user = "core"
    private_key = "${file("~/Keys/vradan-kp.pem")}"
  }

  provisioner "file" {
    source = "/home/ubuntu/certs"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/kubernetes/ssl",
      "sudo mkdir -p /etc/cni/bin",
      "wget -P /tmp/cni https://github.com/containernetworking/cni/releases/download/v0.5.2/cni-amd64-v0.5.2.tgz",
      "tar xvzf /tmp/cni/cni-amd64-v0.5.2.tgz -C /tmp/cni/",
      "sudo mv /tmp/cni/flannel /etc/cni/bin/",
      "sudo mv /tmp/cni/loopback /etc/cni/bin/",
      "sudo mv /tmp/cni/bridge /etc/cni/bin/",
      "sudo mv /tmp/cni/host-local /etc/cni/bin/",
      "sudo mkdir -p /opt/kubernetes/",
      "wget -P /tmp/ https://dl.k8s.io/v1.7.1/kubernetes-node-linux-amd64.tar.gz",
      "tar xvzf /tmp/kubernetes-node-linux-amd64.tar.gz -C /tmp/",
      "sudo mv /tmp/kubernetes/node/bin/ /opt/kubernetes/",
      "sudo chmod -R 755 /opt/kubernetes/",
      "sudo rm -dR /tmp/kubernetes/"
    ]
  }

}
