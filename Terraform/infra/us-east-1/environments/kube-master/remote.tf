terraform {
  backend "s3" {
    bucket = "vradan.com"
    key = "MicroserviceGuide/Terraform/us-east-1/environments/kube-master/terraform.tfstate"
    region = "us-east-1"
  }
}
