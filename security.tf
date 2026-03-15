# Security group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "odoo-alb-sg"
  description = "Allow HTTP/HTTPS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Allow nginx from ALB and expose odoo's 8069 and 8072 ports
resource "aws_security_group" "ecs_sg" {
  name        = "odoo-ecs-sg"
  description = "Allow traffic from ALB to ECS instances. Also, expose odoo specific ports."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow Nginx HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description = "Allow Odoo xmlrpc from ALB/within VPC"
    from_port   = 8069
    to_port     = 8069
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  ingress {
    description = "Allow Odoo gevent/longpolling"
    from_port   = 8072
    to_port     = 8072
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Expose the default postgres port to ECS instances
resource "aws_security_group" "rds_sg" {
  name        = "odoo-rds-sg"
  description = "Allow Postgres traffic from ECS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Allow NFS from ECS instances
resource "aws_security_group" "efs_sg" {
  name        = "odoo-efs-sg"
  description = "Allow NFS traffic from ECS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS from ECS instances"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
