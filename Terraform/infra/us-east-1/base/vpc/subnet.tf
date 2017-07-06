resource "aws_subnet" "subnets" {
  count = "${var.subnet-count}"
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "192.168.${count.index}.0/24"
  availability_zone = "${element(var.availability-zones, count.index)}"
  map_public_ip_on_launch = true

  tags {
    Name = "subnet-${count.index + 1}"
  }
}
