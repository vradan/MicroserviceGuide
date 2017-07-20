variable "default-region" { default = "us-east-1" }
variable "s3-bucket" { default = "vradan.com" }
variable "s3-bucket-path" { default = "MicroserviceGuide/Terraform/us-east-1"}
variable "coreos-stable-ami" { default = "ami-a2577cb4" }
variable "keypair" { default = "vradan-kp" }
variable "etcd_token" { default = "https://discovery.etcd.io/e40275c6bbccb689333d2e422c203c18"  }
