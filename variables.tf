variable "region" {
  default = "ap-south-1"
}

variable "db_password" {
  description = "The database admin password"
  sensitive   = true
}

variable "ecs_ami" {}
