resource "aws_instance" "registry" {

  ami = "${module.global-vars.coreos-stable-ami}"
  instance_type = "${var.instance-type}"

  vpc_security_group_ids = ["${aws_security_group.registry-sg.id}"]
  subnet_id = "${element(data.terraform_remote_state.vpc.subnets, 0)}"

  key_name = "${module.global-vars.keypair}"

  user_data = "${data.template_file.cloud-config.rendered}"

  iam_instance_profile = "${data.terraform_remote_state.iam.registry-profile}"

  source_dest_check = false

  tags {
    Name = "registry"
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
      "sudo mkdir -p /etc/registry/ssl",
      "sudo mkdir -p /etc/docker/certs.d/registry.vradan.com/",
      "sudo cp /tmp/certs/registry.crt /etc/docker/certs.d/registry.vradan.com/ca.crt",
      "sudo cp /tmp/certs/registry.crt /etc/registry/ssl/registry.crt",
      "sudo cp /tmp/certs/registry.key /etc/registry/ssl/registry.key",
      "sudo rm -dR /tmp/certs/",
      "sudo chmod 644 /etc/registry/ssl/*"
    ]
  }

}

resource "aws_volume_attachment" "registry-attach" {
  device_name = "/dev/sdf"
  volume_id = "${aws_ebs_volume.registry.id}"
  instance_id = "${aws_instance.registry.id}"
}
