resource "aws_launch_configuration" "worker-conf" {

  name = "worker-conf"

  instance_type = "${var.instance-type}"
  image_id = "${module.global-vars.coreos-stable-ami}"

  key_name = "${module.global-vars.keypair}"
  iam_instance_profile = "${data.terraform_remote_state.iam.flannel-profile}"

  security_groups = ["${aws_security_group.worker-sg.id}"]

  user_data = "${data.template_file.cloud-config.rendered}"

  root_block_device {
    volume_type = "${var.volume-type}"
    volume_size = "${var.volume-size}"
    delete_on_termination = true
  }

}

resource "aws_autoscaling_group" "workers" {

  name = "kube-workers"

  min_size = 0
  max_size = 10
  desired_capacity = 1

  health_check_type = "EC2"

  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.subnets}"]

  launch_configuration = "${aws_launch_configuration.worker-conf.name}"

  termination_policies = ["OldestInstance"]

  tags = [
    {
      key                 = "Name"
      value               = "kube-worker"
      propagate_at_launch = true
    }
  ]

}
