resource "aws_efs_file_system" "odoo" {
  creation_token   = "odoo-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"
  # Elastic is more expensive but most users will not touch 95% of the
  # Files after 90 days, archive storage is much cheaper in the long run.
  # Bursting doesn't give much saving unless we access files frequently and have a period of dormancy for the odoo usage.

  # Intelligent Tiering: move to IA after 30 days
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  # Archive storage: move to Archive if not accessed for 90 days
  # We can use Archive storage class because we are using regional EFS
  lifecycle_policy {
    transition_to_archive = "AFTER_90_DAYS"
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
