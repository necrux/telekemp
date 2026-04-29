#--------------------------------------------------------------
# Backend
#--------------------------------------------------------------

variable "state_bucket" {default = "telekemp-terraform-state" }

#--------------------------------------------------------------
# Global
#--------------------------------------------------------------

variable "region"   { default = "us-east-2" }
variable "vpc_id"   { default = "vpc-0e9df176a53cb00cd" }
variable "key_name" { default = "telekemp-admin" }

variable "base_security_group" { default = "" }
variable "lockdown"            { default = true } 

variable "subnets" {
  default = [
      "subnet-0262335772dbc8ad4",
      "subnet-009c5ed853efa03bb",
      "subnet-08d0062cfa3a8990e"
  ]
}

#--------------------------------------------------------------
# k8s
#--------------------------------------------------------------

variable "ami_id" { default = "ami-0fe18bc3cfa53a248" }

variable "control_plane_name" { default = "telekemp-control-plane" }
variable "control_plane_type" { default = "t3.micro" }

variable "worker_name"  { default = "telekemp-worker" }
variable "worker_type"  { default = "t3.micro" }
variable "worker_count" { default = 2 }

#--------------------------------------------------------------
# Products
#--------------------------------------------------------------
