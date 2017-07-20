resource "aws_route53_record" "kubernetes-master" {
  zone_id = "${data.terraform_remote_state.hosted-zone.vradan-zone-id}"
  name    = "kubemaster.vradan.com"
  type    = "A"
  ttl     = "5"

  records = ["${aws_instance.kubernetes-master.public_ip}"]
}
