data "aws_route_table" "selected" {
  vpc_id   = "${aws_vpc.vpc.id}"
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

resource "aws_route" "route" {
  route_table_id         = "${data.aws_route_table.selected.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.igw.id}"
}
