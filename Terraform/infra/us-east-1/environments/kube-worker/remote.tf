terraform {
  backend "s3" {
    bucket = "vradan.com"
    key = "MicroserviceGuide/Terraform/us-east-1/environments/kube-worker/terraform.tfstate"
    region = "us-east-1"
  }
}
