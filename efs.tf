resource "aws_efs_file_system" "odoo" {
  creation_token   = "odoo-efs"
  performance_mode = "generalPurpose"

  throughput_mode = "bursting"
}

resource "aws_efs_mount_target" "efs_mount" {
  file_system_id  = aws_efs_file_system.odoo.id
  subnet_id       = aws_subnet.private.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "efs_mount2" {
  file_system_id  = aws_efs_file_system.odoo.id
  subnet_id       = aws_subnet.private2.id
  security_groups = [aws_security_group.efs_sg.id]
}
