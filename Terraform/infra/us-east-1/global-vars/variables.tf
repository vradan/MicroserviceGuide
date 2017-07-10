variable "default-region" { default = "us-east-1" }
variable "s3-bucket" { default = "vradan.com" }
variable "s3-bucket-path" { default = "MicroserviceGuide/Terraform/us-east-1"}
variable "coreos-stable-ami" { default = "ami-a2577cb4" }
variable "keypair" { default = "vradan-kp" }
variable "etcd_token" { default = "https://discovery.etcd.io/cacfcee5f6dc9f932a4c10f7d0ea446b"  }
