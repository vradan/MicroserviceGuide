resource "aws_route53_record" "etcd" {
  zone_id = "${data.terraform_remote_state.hosted-zone.vradan-zone-id}"
  name    = "registry.vradan.com"
  type    = "A"
  ttl     = "5"

  records = ["${aws_instance.registry.public_ip}"]
}
