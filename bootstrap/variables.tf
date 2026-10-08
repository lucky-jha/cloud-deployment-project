variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string
  # NOTE: S3 bucket names must be globally unique across ALL AWS accounts
  # worldwide. Change the number to something unique to you.
  default = "threetier-tfstate-lucky-542035163411"
}

variable "lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "threetier-tf-lock"
}