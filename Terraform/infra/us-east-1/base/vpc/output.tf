output "vpc-id" { value = "${aws_vpc.vpc.id}" }
output "vpc-cidr-block" { value = "${aws_vpc.vpc.cidr_block}" }
output "subnets" { value = "${aws_subnet.subnets.*.id}" }
