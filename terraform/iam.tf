# ============================================================================
# Phase 2D — IAM for EC2 Instances
# ============================================================================
# App instances need an instance profile with:
#   1. SSM Session Manager access (no SSH keys, no open ports)
#   2. ECR image pull permission (read-only)
#   3. CloudWatch Logs write permission (for container logs in Phase 4)
# ============================================================================

# ----------------------------------------------------------------------------
# IAM Role — assumed by EC2 instances
# ----------------------------------------------------------------------------

resource "aws_iam_role" "ec2_app" {
  name = "${var.project_name}-ec2-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Name = "${var.project_name}-ec2-app-role"
  }
}

# ----------------------------------------------------------------------------
# Managed policy — SSM Session Manager
# Allows the SSM agent on the instance to communicate with SSM service.
# This is what makes "no SSH, no bastion" possible.
# ----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ----------------------------------------------------------------------------
# Managed policy — ECR read-only pull
# Allows `docker pull` from ECR without needing credentials on disk.
# ----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ----------------------------------------------------------------------------
# Managed policy — CloudWatch Logs write (for container logs)
# ----------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.ec2_app.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ----------------------------------------------------------------------------
# Instance profile — attached to the ASG
# ----------------------------------------------------------------------------

resource "aws_iam_instance_profile" "ec2_app" {
  name = "${var.project_name}-ec2-app-profile"
  role = aws_iam_role.ec2_app.name

  tags = {
    Name = "${var.project_name}-ec2-app-profile"
  }
}