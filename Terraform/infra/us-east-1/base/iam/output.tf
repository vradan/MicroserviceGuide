output "flannel-profile" { value = "${aws_iam_instance_profile.flannel-profile.name}" }
output "registry-profile" { value = "${aws_iam_instance_profile.registry-profile.name}" }
