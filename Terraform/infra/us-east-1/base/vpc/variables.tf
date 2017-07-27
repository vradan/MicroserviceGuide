variable "subnet-count" { default = 2 }

variable "availability-zones" {
  type = "list"
  default = ["us-east-1a", "us-east-1b"]
}
