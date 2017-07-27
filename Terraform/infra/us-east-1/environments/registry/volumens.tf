resource "aws_ebs_volume" "registry" {
  availability_zone = "us-east-1a"
  size = 40
  type = "gp2"
  tags {
    Name = "Registry"
  }
}
