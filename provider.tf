terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
  backend "s3" {
    bucket         = "odoo-aws-cloud-s3"
    key            = "odoo-prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "odoo-terraform-state-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}
