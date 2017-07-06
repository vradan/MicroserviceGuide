module "global-vars" {
  source = "../../global-vars"
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config {
    bucket = "${module.global-vars.s3-bucket}"
    key = "${module.global-vars.s3-bucket-path}/base/vpc/terraform.tfstate"
    region = "${module.global-vars.default-region}"
  }
}

data "terraform_remote_state" "sg" {
  backend = "s3"
  config {
    bucket = "${module.global-vars.s3-bucket}"
    key = "${module.global-vars.s3-bucket-path}/base/security-groups/terraform.tfstate"
    region = "${module.global-vars.default-region}"
  }
}

data "template_file" "cloud-config" {
  count = "${var.count}"
  template = "${file("./cloud_config.tpl")}"
  vars {
    hostname = "etcd-node-${count.index + 1}"
    token = "${module.global-vars.etcd-token}"
  }
}
