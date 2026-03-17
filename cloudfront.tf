resource "random_password" "cf_secret" {
  length  = 32
  special = false
}

resource "aws_cloudfront_distribution" "odoo" {
  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "alb-origin"

    # By default cloudfront expects S3 but we want our ALB behind the cloudfront
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = 60
    }

    # Add a custom header with a secret value
    # This header will be sent to the ALB
    # The ALB will check this header and only forward traffic only if it matches
    custom_header {
      name  = "X-Odoo-Origin-Verify"
      value = random_password.cf_secret.result
    }
  }

  enabled = true

  # Default caching behaviour for Odoo
  default_cache_behavior {
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    forwarded_values {
      query_string = true
      headers      = ["Host"]
      cookies {
        forward = "all"
      }
    }
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # Caching behavior for dynamically generated Odoo assets (CSS/JS bundles)
  ordered_cache_behavior {
    path_pattern           = "/web/assets/*"
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    forwarded_values {
      query_string = true
      headers      = ["Host"]
      cookies {
        forward = "none"
      }
    }
    # These change whenever the DB content changes, but should be cached for speed
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # Caching behaviour for core odoo static assets
  ordered_cache_behavior {
    path_pattern           = "/web/static/*"
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    forwarded_values {
      query_string = false
      headers      = ["Host"]
      cookies {
        forward = "none"
      }
    }
    # Base odoo core static files will not change often
    min_ttl     = 3600
    default_ttl = 86400
    max_ttl     = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
