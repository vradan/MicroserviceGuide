resource "aws_route53_record" "etcd" {
  count = "${var.count}"
  zone_id = "${data.terraform_remote_state.hosted-zone.vradan-zone-id}"
  name    = "etcdnode${count.index + 1}.vradan.com"
  type    = "A"
  ttl     = "5"

  records = ["${element(aws_instance.etcd.*.public_ip, count.index)}"]
}
