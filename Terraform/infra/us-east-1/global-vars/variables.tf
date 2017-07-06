variable "default-region" { default = "us-east-1" }
variable "s3-bucket" { default = "vradan.com" }
variable "s3-bucket-path" { default = "MicroserviceGuide/Terraform/us-east-1"}
variable "coreos-stable-ami" { default = "ami-a2577cb4" }
variable "keypair" { default = "vradan-kp" }
variable "etcd-token" { default = "https://discovery.etcd.io/7129bed2c17b6f6e4596f19522fb1c21" }
