terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region"  { default = "us-east-1" }
variable "db_password" { sensitive = true }
variable "db_username" { default = "payment_app" }

# -----------------------------------------------------------
# RDS — Payment Primary Database
# -----------------------------------------------------------

resource "aws_db_subnet_group" "payment" {
  name       = "payment-prod-subnet-group"
  subnet_ids = ["subnet-0a1b2c3d", "subnet-0e4f5a6b"]
}

resource "aws_security_group" "rds" {
  name   = "payment-rds-sg"
  vpc_id = "vpc-0123456789abcdef0"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = ["sg-app-tier"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "payment_primary" {
  identifier        = "payment-prod"
  engine            = "postgres"
  engine_version    = "15.4"
  instance_class    = "db.r6g.large"
  allocated_storage = 100
  storage_type      = "gp3"

  # ❌ storage_encrypted is false — violates Security Policy §2.1
  storage_encrypted = false

  db_name  = "payments"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.payment.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = true
  skip_final_snapshot = false
  deletion_protection = true

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:05:00-sun:06:00"

  tags = {
    Environment = "production"
    Service     = "payment"
    Team        = "platform"
  }
}
