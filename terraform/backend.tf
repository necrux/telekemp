terraform {
  required_version = "~> 1.15.0"

  backend "s3" {
    bucket         = "telekemp-terraform-state-main-account"
    key            = "terraform.tfstate"
    region         = "us-east-2"
    
    encrypt        = true
  }
}
