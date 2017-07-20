resource "aws_route53_record" "kubernetes-worker" {
  count   = "${var.worker-count}"
  zone_id = "${data.terraform_remote_state.hosted-zone.vradan-zone-id}"
  name    = "kubeworker${count.index + 1}.vradan.com"
  type    = "A"
  ttl     = "5"

  records = ["${element(aws_instance.kubernetes-worker.*.public_ip, count.index)}"]
}
