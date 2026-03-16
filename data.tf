data "aws_secretsmanager_secret" "odoo_admin_passwd" {
  name = "odoo/admin/password"
}
