# =============================================================================
# Bootstrap — creates the S3 bucket + DynamoDB table used for Terraform
# remote state in the MAIN project.
#
# This is a ONE-TIME setup. Run it once, then never again (unless you want to
# tear down the whole project).
#
# Uses LOCAL state (chicken-and-egg: you can't use remote state to create
# the remote state backend itself).
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# S3 bucket for Terraform state
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name
  tags = {
    Name    = var.state_bucket_name
    Purpose = "Terraform remote state"
  }
}

# Enable versioning so we can recover from accidental state overwrites
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest (state files can contain secrets like DB passwords)
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access — state files must never be public
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# DynamoDB table for state locking
# Prevents two `terraform apply` runs from stepping on each other
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "tf_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name    = var.lock_table_name
    Purpose = "Terraform state locking"
  }
}