# ============================================================================
# Phase 6 — S3 Bucket for ALB Access Logs + Lifecycle Policy
# ============================================================================
# Stores ALB access logs with automated tiering:
#   Standard (0-30d) → Standard-IA (31-90d) → Glacier (91-365d) → Delete
# Demonstrates cost optimization using S3 lifecycle rules.
# ============================================================================

# ----------------------------------------------------------------------------
# Bucket
# ----------------------------------------------------------------------------
resource "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-alb-logs-${data.aws_caller_identity.current.account_id}"
  tags = {
    Name    = "${var.project_name}-alb-logs"
    Purpose = "ALB access logs"
  }
}

# Encrypt at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning (harmless, good practice)
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ----------------------------------------------------------------------------
# Lifecycle policy — the cost optimization
# ----------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  # Transition current versions through storage classes
  rule {
    id     = "log-tiering"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    expiration {
      days = 365
    }
  }

  # Clean up old versions of objects
  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ----------------------------------------------------------------------------
# Bucket policy — allow the ALB service to write logs
# ----------------------------------------------------------------------------
data "aws_elb_service_account" "current" {}

data "aws_caller_identity" "current" {}

# ----------------------------------------------------------------------------
# Bucket policy — modern ALB log delivery principal
# ----------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowALBLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      },
      {
        Sid    = "AllowALBLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.logs.arn
      }
    ]
  })
}

# Remove the old aws_elb_service_account data source (no longer needed)
# data "aws_elb_service_account" "current" {}   

# ----------------------------------------------------------------------------
# Enable ALB access logs
# ----------------------------------------------------------------------------
# resource "aws_lb" "ap" {
#   # ... existing config stays, but here's the addition:
#   # Add access_logs block — see integration step below
#   # (We'll edit the existing aws_lb resource instead)
# }