# 1. Base Cluster
resource "aws_ecs_cluster" "odoo" {
  name = "odoo-cluster"
}

data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

# 2. EC2 Infrastructure
resource "aws_launch_template" "ecs" {
  name_prefix   = "odoo-ecs-template-"
  image_id      = data.aws_ssm_parameter.ecs_optimized_ami.value
  instance_type = "m7i-flex.large"

  update_default_version = true

  # We give the EC2 no ingress (inbound) rules
  vpc_security_group_ids = [aws_security_group.ecs_node_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.odoo.name} >> /etc/ecs/ecs.config
echo ECS_RESERVED_CPU=256 >> /etc/ecs/ecs.config
echo ECS_RESERVED_MEMORY=512 >> /etc/ecs/ecs.config
EOF
  )
# We reserve some memory and CPU for the OS and Docker daemon
}

# Autoscale physical EC2 servers
resource "aws_autoscaling_group" "ecs_asg" {
  vpc_zone_identifier  = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  min_size             = 1
  max_size             = 4
  desired_capacity     = 1
  protect_from_scale_in = true

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }
}

# 3. ECS Capacity Providers (Linking ASG to Cluster)
resource "aws_ecs_capacity_provider" "odoo" {
  name = "odoo-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_asg.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 80
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "odoo" {
  cluster_name       = aws_ecs_cluster.odoo.name
  capacity_providers = [aws_ecs_capacity_provider.odoo.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.odoo.name
  }
}

# 4. Task Definition
resource "aws_ecs_task_definition" "odoo" {
  family                   = "odoo"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  # We are opting for 1 task per EC2 instance because Odoo is a powerful
  # ERP solution with heavy manufacturing, procurement, accounting logic.
  # Using a "light-weight" edition by having 2 tasks per EC2 instance
  # significantly impacts the performance.
  
  cpu    = "1664" # 2048 - 256 (reserved for OS) - 128 (Buffer)
  memory = "7296" # 8192 - 512 (reserved for OS) - 384 (Buffer)

  container_definitions = templatefile("${path.module}/templates/odoo-task.json", {
    db_host            = aws_db_instance.postgres.address
    
    # We pass the ARN
    admin_password_arn = data.aws_secretsmanager_secret.odoo_admin_passwd.arn
    
    # Grab the ARN of the auto-generated secret directly from RDS
    db_password_arn    = aws_db_instance.postgres.master_user_secret[0].secret_arn

    nginx_image_url    = var.nginx_image_url
    odoo_image_url     = var.odoo_image_url
    aws_region         = var.region
  })

  volume {
    name = "odoo-efs"

    efs_volume_configuration {
      file_system_id = aws_efs_file_system.odoo.id
    }
  }
}

# 4.5 Orchestrator (or the manager)
resource "aws_ecs_service" "odoo" {
  name            = "odoo-service"
  cluster         = aws_ecs_cluster.odoo.id
  task_definition = aws_ecs_task_definition.odoo.arn
  desired_count   = 1

  health_check_grace_period_seconds = 90

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.odoo.name
    weight            = 100
  }

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    # Opens access to Nginx
    security_groups = [aws_security_group.ecs_task_sg.id] 
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.odoo.arn
    container_name   = "nginx"
    container_port   = 80
  }
}

# 5. Service Auto-Scaling (Task Count)
resource "aws_appautoscaling_target" "ecs_target" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.odoo.name}/${aws_ecs_service.odoo.name}"
  scalable_dimension = "ecs:service:DesiredCount"

  min_capacity = 1
  max_capacity = 4
}

resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "cpu-scale"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 75
  }
}

resource "aws_cloudwatch_log_group" "odoo_logs" {
  name              = "/ecs/odoo"
  retention_in_days = 7
}
