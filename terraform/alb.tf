# ============================================================================
# Phase 2C — Application Load Balancer + Target Group + Listener
# ============================================================================
# The ALB sits in the public subnets, receives internet traffic, and forwards
# it to app instances (registered in the target group) on the container port.
#
# Flow:
#   Internet → ALB (port 80) → Target Group → EC2 container (port 5000)
# ============================================================================

# ----------------------------------------------------------------------------
# Target Group — logical grouping of app instances
# ----------------------------------------------------------------------------

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg-app"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"


  # Deregistration delay: time to wait before removing a target
  # 30s for faster dev cycles; production often uses 300s
  deregistration_delay = 30
  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
  tags = {
    Name = "${var.project_name}-tg-app"
  }
}
# ----------------------------------------------------------------------------
# Application Load Balancer — public facing load balancer , it lives in both public subnets
# ----------------------------------------------------------------------------
resource "aws_lb" "app" {
  name               = "${var.project_name}-alb"
  internal           = false # internal facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public-1.id, aws_subnet.public-2.id]

  # Send access logs to an S3 bucket (we'll add this in Phase 6)
  # enable_deletion_protection = false         # set true in production
  idle_timeout = 60
  tags = {
    Name = "${var.project_name}-alb"
  }
}
#------------------------------------------------------------------------------
# Listener — port 80 (HTTP) -> forward to target group
#------------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = {
    Name = "${var.project_name}-http-listener"
  }
}

