# ============================================================================
# Phase 3 — RDS PostgreSQL Multi-AZ
# ============================================================================
# The database tier. Lives in the two private DB subnets.
# Only sg-app can reach it (from Phase 2A).
# Master password is auto-generated and stored in SSM Parameter Store.
# ============================================================================

resource "random_password" "db_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.project_name}/${var.environment}/db/password"
  description = "RDS PostgreSQL master password"
  type        = "SecureString"
  value       = random_password.db_master.result

  tags = {
    Name = "${var.project_name}-db-password"
  }
}

resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Subnet group for RDS PostgreSQL(private DB tier)"
  subnet_ids = [
    aws_subnet.private-db-1.id,
    aws_subnet.private-db-2.id,
  ]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_parameter_group" "postgres" {
  name        = "${var.project_name}-pg-parameter-group"
  family      = "postgres16"
  description = "Custom PostgreSQL 16 parameters"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = {
    Name = "${var.project_name}-pg-params"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-postgres"

  # Engine
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  # Storage
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_master.result
  port     = var.db_port

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  # High Availability
  multi_az = true

  # Backups
  backup_retention_period = 1
  backup_window           = "03:00-04:00" # UTC
  maintenance_window      = "sun:04:30-sun:05:30"

  # Parameter group
  parameter_group_name = aws_db_parameter_group.postgres.name

  # Deletion protection — set false for dev so we can destroy easily
  deletion_protection = false

  # Take a final snapshot when destroying? No for dev (faster cleanup)
  skip_final_snapshot = true

  # Apply changes during maintenance window (important for Multi-AZ)
  apply_immediately = false

  tags = {
    Name = "${var.project_name}-postgres"
  }
}
