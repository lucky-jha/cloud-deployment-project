output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = [aws_subnet.public-1.id, aws_subnet.public-2.id]
}

output "private_subnets" {
  value = [aws_subnet.private-app-1.id, aws_subnet.private-app-2.id, aws_subnet.private-db-1.id, aws_subnet.private-db-2.id]
}

output "sg_alb_id" {
  value = aws_security_group.alb.id
}

output "sg_app_id" {
  value = aws_security_group.app.id
}

output "sg_db_id" {
  value = aws_security_group.db.id
}
output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  value = aws_ecr_repository.app.name
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "alb_zone_id" {
  value = aws_lb.app.zone_id
}

output "target_group_arn" {
  value = aws_lb_target_group.app.arn
}

output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  value = aws_launch_template.app.id
}

output "ec2_app_role_arn" {
  value = aws_iam_role.ec2_app.arn
}
  