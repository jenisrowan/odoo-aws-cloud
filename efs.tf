resource "aws_efs_file_system" "odoo" {
  creation_token   = "odoo-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  # Intelligent Tiering: move to IA after 60 days (~2 months) of no access
  lifecycle_policy {
    transition_to_ia = "AFTER_60_DAYS"
  }

  # Archive storage: move to Archive if not accessed for 6 months
  # We can use Archive storage class because we are using regional EFS
  lifecycle_policy {
    transition_to_archive = "AFTER_180_DAYS"
  }

  # Move back to Standard storage immediately on first access
  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }
}

resource "aws_efs_mount_target" "efs_mount" {
  file_system_id  = aws_efs_file_system.odoo.id
  subnet_id       = aws_subnet.private_a.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "efs_mount2" {
  file_system_id  = aws_efs_file_system.odoo.id
  subnet_id       = aws_subnet.private_b.id
  security_groups = [aws_security_group.efs_sg.id]
}
