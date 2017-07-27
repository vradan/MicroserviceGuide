resource "aws_instance" "kubernetes-master" {

  ami = "${module.global-vars.coreos-stable-ami}"
  instance_type = "${var.instance-type}"

  vpc_security_group_ids = ["${aws_security_group.master-sg.id}"]
  subnet_id = "${element(data.terraform_remote_state.vpc.subnets, 0)}"

  key_name = "${module.global-vars.keypair}"

  user_data = "${data.template_file.cloud-config.rendered}"

  iam_instance_profile = "${data.terraform_remote_state.iam.flannel-profile}"

  source_dest_check = false

  tags {
    Name = "kube-master"
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
      "sudo mkdir -p /etc/docker/certs.d/registry.vradan.com/",
      "sudo mv /tmp/certs/registry.crt /etc/docker/certs.d/registry.vradan.com/ca.crt",
      "sudo mv /tmp/certs/ca.crt /etc/kubernetes/ssl/ca.crt",
      "sudo mv /tmp/certs/apiserver.crt /etc/kubernetes/ssl/apiserver.crt",
      "sudo mv /tmp/certs/apiserver.key /etc/kubernetes/ssl/apiserver.key",
      "sudo chmod 644 /etc/kubernetes/ssl/*",
      "sudo chown root:root /etc/kubernetes/ssl/*",
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
      "/opt/kubernetes/bin/kubectl config set-cluster main-cluster --certificate-authority=/etc/kubernetes/ssl/ca.crt --embed-certs=true --server=https://kubemaster.vradan.com",
      "/opt/kubernetes/bin/kubectl config set-credentials apiserver --client-certificate=/etc/kubernetes/ssl/apiserver.crt --client-key=/etc/kubernetes/ssl/apiserver.key --embed-certs=true",
      "/opt/kubernetes/bin/kubectl config set-context main-context --cluster=main-cluster --user=apiserver",
      "/opt/kubernetes/bin/kubectl config use-context main-context",
      "sudo mkdir -p /var/lib/kube-proxy/",
      "sudo cp ~/.kube/config /var/lib/kube-proxy/kubeconfig",
      "sudo mkdir -p /var/lib/kubelet/",
      "sudo cp ~/.kube/config /var/lib/kubelet/kubeconfig"
    ]
  }

}
