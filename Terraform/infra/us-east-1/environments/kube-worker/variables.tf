variable "instance-type" { default = "t2.micro" }
variable "worker-count" { default = "3" }
variable "volume-type" { default = "gp2" }
variable "volume-size" { default = "20" }
variable "private-key-path" { default = "~/Keys/vradan-kp.pem" }
variable "certs-dir" { default = "~/certs" }
