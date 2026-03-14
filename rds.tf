resource "aws_db_subnet_group" "rds" {
  name       = "odoo-db-subnet-group"
  subnet_ids = [aws_subnet.private.id, aws_subnet.private2.id]
}

resource "aws_db_instance" "postgres" {
  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t4g.micro"

  multi_az = true

  allocated_storage = 20

  username = "odoo"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  skip_final_snapshot = true
}
