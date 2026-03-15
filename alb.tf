# We want an application load balancer that are in 2 public subnets
resource "aws_lb" "main" {
  name = "odoo-alb"

  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  subnets = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "odoo" {
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  
  # Odoo's root path (/) redirects to /web/login (302), which ALB would treat
  # as unhealthy. /web/health is Odoo's built-in endpoint that always returns 200.
  health_check {
    path                = "/web/health"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.odoo.arn
  }
}
