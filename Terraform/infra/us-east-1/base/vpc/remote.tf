terraform {
  backend "s3" {
    bucket = "vradan.com"
    key = "MicroserviceGuide/Terraform/us-east-1/base/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}
