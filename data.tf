data "aws_secretsmanager_secret" "odoo_admin_passwd" {
  name = "odoo/admin/password"
}
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}
