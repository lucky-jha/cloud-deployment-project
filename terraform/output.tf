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