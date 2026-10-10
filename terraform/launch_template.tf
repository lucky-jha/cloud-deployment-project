# ============================================================================
# Phase 2D — Launch Template for App Instances
# ============================================================================
# Blueprint for EC2 instances in the ASG:
#   - Amazon Linux 2023 AMI
#   - t3.micro (free tier eligible)
#   - sg-app (chained security group from Phase 2A)
#   - IAM instance profile (SSM + ECR + CloudWatch)
#   - user_data script that installs Docker, pulls the ECR image, runs it
# ============================================================================

# ----------------------------------------------------------------------------
# Look up the latest Amazon Linux 2023 AMI dynamically
# (Hardcoding AMI IDs is fragile — they change per region per release.)
# ----------------------------------------------------------------------------

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}


# ----------------------------------------------------------------------------
# Launch Template
# ----------------------------------------------------------------------------
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  # Attaching the security group which help to limit the inbound to sg-alb only

  vpc_security_group_ids = [aws_security_group.app.id]

  #attaching IAM instance profile to the instance
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_app.name
  }

  # user_data runs on first boot: installs Docker, pulls and runs the container
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    aws_region     = var.aws_region
    ecr_repository_url       = aws_ecr_repository.app.repository_url
    container_port = var.container_port
    app_version    = "v1"
  }))

  # Require IMDSv2 (more secure than IMDSv1)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  # Encrypting root volume
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-app-instance"
      Role = "App"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.project_name}-app-volume"
    }
  }
  tags = {
    Name = "${var.project_name}-lt-app"
  }
}
