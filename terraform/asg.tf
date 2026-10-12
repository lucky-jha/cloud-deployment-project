# ============================================================================
# Phase 2D — Auto Scaling Group
# ============================================================================
# Maintains 2 instances (min 2, max 4) across both private app subnets.
# Registers instances with the ALB target group from Phase 2C.
# Replaces unhealthy/terminated instances automatically (self-healing).
# ============================================================================

resource "aws_autoscaling_group" "app" {
  name_prefix = "${var.project_name}-asg-app-"
  vpc_zone_identifier = [
    aws_subnet.private-app-1.id,
    aws_subnet.private-app-2.id
  ]

  desired_capacity = 2
  min_size         = 2
  max_size         = 4

  #register new instances with the ALB target group
  target_group_arns = [aws_lb_target_group.app.arn]

  # ALB health checks + EC2 status checks
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Instances are spread across AZs (default: balanced across AZs)
  # (No explicit setting needed — AWS balances by default.)

  # Rolling updates: when the launch template changes, replace instances

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 60
    }
    triggers = [
      "launch_template"
    ]
  }

  # Enable metrics collection at 1-minute granularity (Phase 4 needs this)
  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app-instance"
    propagate_at_launch = true
  }
  tag {
    key                 = "Role"
    value               = "App"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
