terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket         = "threetier-tfstate-lucky-542035163411"
    key            = "terraform/dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "threetier-tf-lock"
    encrypt        = true
    use_lockfile   = true
  }
}
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
