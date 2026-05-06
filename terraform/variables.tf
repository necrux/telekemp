#--------------------------------------------------------------
# Backend
#--------------------------------------------------------------

variable "state_bucket" {default = "telekemp-terraform-state" }

#--------------------------------------------------------------
# Global
#--------------------------------------------------------------

#variable "account_id" { default = "109389764247" } #NewAcct: Switching for NLB deployment.
#variable "vpc_id"     { default = "vpc-0e9df176a53cb00cd" } #NewAcct: Switching for NLB deployment.
variable "account_id" { default = "264405255203" }
variable "region"     { default = "us-east-2" }
variable "vpc_id"     { default = "vpc-e67eaa8f" }
variable "zone_id"    { default = "Z05408313TYWO9EM9XWQL" }
variable "key_name"   { default = "telekemp-admin" }

variable "base_security_group" { default = "" }
variable "lockdown"            { default = true } 

#--------------------------------------------------------------
# k8s - Build
#--------------------------------------------------------------

variable "ami_id" { default = "ami-0fe18bc3cfa53a248" }

variable "control_plane_name"      { default = "telekemp-control-plane" }
variable "control_plane_type"      { default = "m7i-flex.large" }
variable "control_plane_secrets"   { default = "control-plane-secrets" }
variable "pod_cidr"                { default = "192.168.0.0/16" }
variable "control_plane_disk_size" { default = 10 }
variable "control_plane_disk_type" { default = "gp3" }

variable "worker_name"      { default = "telekemp-worker" }
variable "worker_type"      { default = "c7i-flex.large" }
variable "worker_count"     { default = 2 }
variable "worker_disk_size" { default = 20 }
variable "worker_disk_type" { default = "gp3" }

variable "kube_version"   { default = "1.33.11-1.1" }
variable "calico_version" { default = "3.31.5" }

variable "base_packages" { 
  default = [
    "containerd",
    "apt-transport-https",
    "ca-certificates",
    "curl",
    "gpg",
    "apache2-utils"
  ]
}

variable "kube_packages" {
  default = [
    "kubelet",
    "kubeadm",
    "kubectl"
  ]
}

#--------------------------------------------------------------
# k8s - Configuration
#--------------------------------------------------------------

variable "namespace" { default = "telekemp" }
variable "ro_role"   { default = "telekemp-qa" }
variable "rw_role"   { default = "telekemp-devs" }

#--------------------------------------------------------------
# k8s - Additional Deployment Options
#--------------------------------------------------------------

variable "deploy_istio"         { default = true }
variable "deploy_nginx_ingress" { default = true }
variable "istio_version"        { default = "1.29.2" }
variable "deploy_lb_controller" { default = true }
variable "deploy_cert_manager"  { default = true }
variable "cert_manager_version" { default = "1.20.2" }
variable "deploy_argocd"        { default = true }
variable "deploy_flux"          { default = false }
variable "deploy_teleport"      { default = true }
variable "teleport_version"     { default = "18.7.6" }
