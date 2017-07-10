resource "aws_instance" "etcd" {
  count = "${var.count}"

  ami = "${module.global-vars.coreos-stable-ami}"
  instance_type = "${var.instance-type}"

  vpc_security_group_ids = ["${data.terraform_remote_state.sg.etcd-sg-id}"]
  subnet_id = "${element(data.terraform_remote_state.vpc.subnets, count.index)}"

  key_name = "${module.global-vars.keypair}"

  user_data = "${element(data.template_file.cloud-config.*.rendered, count.index)}"

  iam_instance_profile = "${data.terraform_remote_state.iam.flannel-profile}"

  source_dest_check = false

  tags {
    Name = "etcd-node-${count.index + 1}"
  }

  root_block_device {
    volume_type = "${var.volume-type}"
    volume_size = "${var.volume-size}"
    delete_on_termination = true
  }
}
