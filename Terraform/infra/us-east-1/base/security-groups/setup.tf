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
