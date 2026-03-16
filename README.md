# Odoo on AWS (ECS & Terraform)

This project provides a production-ready infrastructure for deploying **Odoo 19** on AWS using Terraform. It leverages AWS ECS (Elastic Container Service) with EC2 capacity providers, Amazon RDS for PostgreSQL, and Amazon EFS for persistent storage.

## Architecture

- **Global Delivery**: AWS CloudFront provides HTTPS termination and edge caching for static assets.
- **Load Balancing**: An Application Load Balancer (ALB) distributes traffic to ECS tasks.
- **Compute**: Odoo and Nginx run as sidecar containers in ECS Tasks on EC2 instances (m7i-flex.large).
- **Database**: Amazon RDS for PostgreSQL (Multi-AZ) handles application data.
- **Storage**: Amazon EFS provides a shared file system for Odoo's `filestore` and sessions.
- **Networking**: A VPC with both public and private subnets, secured with specialized Security Groups.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) (>= 1.1)
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate permissions.
- Docker (for building and pushing custom images to ECR).

## Getting Started

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/jenisrowan/odoo-aws-cloud.git
    cd odoo-aws-cloud
    ```

2.  **Initialize Terraform**:
    ```bash
    terraform init
    ```

3.  **Configure Variables**:
    Create a `terraform.tfvars` file or set environment variables for the following:
    - `db_password`: RDS PostgreSQL admin password.
    - `admin_passwd`: Odoo Master Password (passed securely via environment variables).
    - `odoo_image_url`: Your custom Odoo image in ECR.
    - `nginx_image_url`: Your custom Nginx image in ECR.

4.  **Deploy**:
    ```bash
    terraform apply
    ```

## Performance & Tuning

## Cost Optimization & Networking

### Regional NAT Gateway
To reduce configuration complexity and minimize costs, this project utilizes a **Regional NAT Gateway** pattern:
- **Cost Savings**: By using a single Regional NAT Gateway shared across private subnets, we avoid the fixed hourly charges of multiple NAT Gateways in different Availability Zones.
- **Data Transfer**: This design is especially cost-effective if certain AZs have no active resources, as it eliminates NAT-related idle costs while maintaining outbound internet access for private workloads.
- **Smarter Traffic**: zero multi-AZ transfer charges for regional NAT gateways, as AWS will pick the NAT in the current AZ for oubound traffic.

## Security

- **Database**: RDS is situated in private subnets and only accepts traffic from ECS tasks on port 5432.
- **Secrets Management**: Sensitive data like `db_password` and `admin_passwd` are handled as sensitive Terraform variables and passed to containers via ECS environment variables, avoiding plain-text configuration files.
- **Encryption**: EFS is encrypted at rest, and CloudFront enforces HTTPS.

## Outputs

After deployment, Terraform will output:
- `cloudfront_url`: The primary public URL for your Odoo instance.
- `alb_url`: Internal load balancer URL (for testing).
- `odoo_ecr_url` / `nginx_ecr_url`: Target repositories for your Docker images.
