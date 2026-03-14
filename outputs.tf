output "cloudfront_url" {
  value = aws_cloudfront_distribution.odoo.domain_name
}

output "alb_url" {
  value = aws_lb.main.dns_name
}

output "odoo_ecr_url" {
  value = aws_ecr_repository.odoo.repository_url
}

output "nginx_ecr_url" {
  value = aws_ecr_repository.nginx.repository_url
}
