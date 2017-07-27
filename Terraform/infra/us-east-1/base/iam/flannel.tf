resource "aws_iam_role" "flannel-role" {
  name = "Flannel"
  path = "/terraform/"

  description = "Role used by Flannel to manage VPC"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_instance_profile" "flannel-profile" {
  name  = "Flannel"
  role = "${aws_iam_role.flannel-role.name}"
}

resource "aws_iam_role_policy" "route-table-policy" {
  name = "route-table-policy"
  role = "${aws_iam_role.flannel-role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
          "Effect": "Allow",
          "Action": [
                "ec2:AttachVolume",
                "ec2:CreateRoute",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:DeleteRoute",
                "ec2:DeleteVolume",
                "ec2:DescribeInstances",
                "ec2:DescribeRouteTables",
                "ec2:DescribeVolumes",
                "ec2:DetachVolume",
                "ec2:ReplaceRoute",
                "elasticloadbalancing:DescribeLoadBalancers"
          ],
          "Resource": "*"
    }
  ]
}
EOF
}
