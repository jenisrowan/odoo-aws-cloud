# Odoo on AWS (ECS & Terraform)

This project provides a production-ready infrastructure for deploying **Odoo 19** on AWS using Terraform. It leverages AWS ECS (Elastic Container Service) with EC2 capacity providers, Amazon RDS for PostgreSQL, and Amazon EFS for persistent storage.

## Architecture

- **Global Delivery**: AWS CloudFront provides HTTPS termination and edge caching for static assets.
- **Load Balancing**: An Application Load Balancer (ALB) distributes traffic to Odoo tasks.
- **Compute (Odoo)**: Odoo and Nginx run as sidecar containers on dedicated `m7i-flex.large` instances.
- **PgBouncer Pooling**: A High-Availability PgBouncer layer (2 tasks) runs on dedicated `t3.micro` instances to manage database connection pooling efficiently.
- **Service Discovery**: ECS Service Connect (`odoo.local`) provides seamless internal communication between Odoo and PgBouncer using `pgbouncer.odoo.local`.
- **Database**: Amazon RDS for PostgreSQL (Multi-AZ) handles application data.
- **Storage**: Amazon EFS provides a shared file system for Odoo's `filestore` and sessions.
- **Networking**: A VPC with both public and private subnets, secured with specialized Security Groups for ALB, Tasks, PgBouncer, and RDS.

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

3.  **Setup AWS Secrets**:
    Before deploying, you must manually create a secret in AWS Secrets Manager to store the Odoo Admin password. *(Note: The PostgreSQL database password is automatically generated and managed by AWS RDS).*
    - Go to AWS Secrets Manager -> Store a new secret.
    - Choose **Other type of secret**.
    - Add a Key/Value pair: Key = `password`, Value = `[Your_Secure_Password]`.
    - Name the secret: `odoo/admin/password`.

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
- **Smarter Traffic**: Zero multi-AZ transfer charges for regional NAT gateways, as AWS will pick the NAT in the current AZ for outbound traffic.

### EFS Storage Tiering
To further optimize long-term storage costs for Odoo's filestore, a triple-tier lifecycle policy is implemented:
- **Infrequent Access (IA)**: Files not accessed for **30 days** automatically move to the IA tier (significantly cheaper storage).
- **Archive Tier**: Files not accessed for **90 days** move to EFS Archive storage for maximum cost savings.
- **Intelligent Recovery**: Any access to a file in IA or Archive immediately transitions it back to **Primary Storage** (AFTER_1_ACCESS) to ensure low-latency performance and cut down on access cost for active data.

## Security

- **Web Application Firewall (WAF)**: A global AWS WAF protects the CloudFront distribution with rules for IP reputation, bot control, and rate limiting against malicious traffic.
- **Database**: RDS is situated in private subnets and **only accepts traffic from PgBouncer tasks** on port 5432.
- **PgBouncer**: Only accepts traffic from Odoo tasks on port 6432.
- **Zero-Knowledge Secrets Management**: 
  - **RDS Managed Passwords**: The master database password is automatically generated, encrypted, and managed natively by AWS. Plain-text credentials are **never** exposed or stored in the Terraform `tfstate` file. 
  - **Direct Secret Injection**: ECS tasks use IAM Task Execution Roles to fetch credentials directly from AWS Secrets Manager at runtime. Passwords are never passed as plain-text environment variables, protecting them from exposure in the AWS Console or logs. 
- **Encryption**: EFS is encrypted at rest, and CloudFront enforces HTTPS.

## Outputs

After deployment, Terraform will output:
- `cloudfront_url`: The primary public URL for your Odoo instance.
- `alb_url`: Internal load balancer URL (for testing).
- `odoo_ecr_url` / `nginx_ecr_url`: Target repositories for your Docker images.
