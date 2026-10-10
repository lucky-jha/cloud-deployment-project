variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "threetier"
}

variable "environment" {
  description = "Environment of the project"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for the VPC"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "container_port" {
  description = "Container port for the ALB"
  type        = number
  default     = 5000
}
variable "db_port" {
  description = "Container port for the DB"
  type        = number
  default     = 5432
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root volume size (GB)"
  type        = number
  default     = 8
}