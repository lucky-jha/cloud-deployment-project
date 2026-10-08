# ============================================================================
# Security Groups — Phase 2A
# ============================================================================
# Three-tier traffic flow:
#
#   Internet ──80/443──▶ sg-alb ──5000──▶ sg-app ──5432──▶ sg-db
#
# Key security principle: each tier only accepts traffic from the tier
# directly in front of it, referenced via security_groups (not CIDR blocks).
# This creates a real, provable security boundary — the app tier is not
# reachable from anywhere except the ALB.
# ============================================================================

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-sg-alb"
  description = "Allow HTTP and HTTPS inbound traffic to the ALB"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-sg-alb"
    Tier = "ALB"
  }
}

# HTTP from anywhere
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from Internet anywhere"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

# HTTPS from anywhere
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS from Internet anywhere"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}
# this is for egrees the above one was made for inngress
resource "aws_vpc_security_group_egress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "forward traffic to app tier on container port 5000"

  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

# ----------------------------------------------------------------------------
# sg-app — Attached to EC2 instances running the Docker container
# ----------------------------------------------------------------------------

resource "aws_security_group" "app" {
  name        = "${var.project_name}-sg-app"
  description = "Allow traffic from ALB only ; egress to db and AWS services"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-sg-app"
    Tier = "App"
  }
}


# Only the ALB can reach the container port
# Note: NO inbound rule for port 22 — access is via SSM Session Manager
# which uses outbound HTTPS only. This is more secure than a bastion host

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id = aws_security_group.app.id
  description       = "contaioner port from alb only"

  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

# outbount traffic to db

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id = aws_security_group.app.id
  description       = "allow outbound traffic to db"

  referenced_security_group_id = aws_security_group.db.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
}


# Outbound: HTTPS for ECR image pulls, SSM agent, patching, CloudWatch Logs
resource "aws_vpc_security_group_egress_rule" "app_https_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS outbound for ECR, SSM, CloudWatch, patching"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

# Outbound: HTTP for some package managers (dnf/yum still hit HTTP mirrors)
resource "aws_vpc_security_group_egress_rule" "app_http_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP outbound for package mirrors"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}


# ----------------------------------------------------------------------------
# sg-db — Attached to the RDS instance (created in Phase 3)
# ----------------------------------------------------------------------------

resource "aws_security_group" "db" {
  name        = "${var.project_name}-sg-db"
  description = "Allow POSTGRES FORM APP TIER ONLY"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-sg-db"
    Tier = "private-DB"
  }

}
resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id = aws_security_group.db.id
  description       = "allow postgres from app tier"

  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
}


# no outbound rule bcz db will not initiate outbount connection