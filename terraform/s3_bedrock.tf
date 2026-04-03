resource "aws_s3_bucket" "company_research_vault" {
  bucket        = "company-research-vault-64"
  force_destroy = true

  tags = {
    Name        = "Company Research Vault"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_versioning" "company_research_vault_versioning" {
  bucket = aws_s3_bucket.company_research_vault.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "company_research_vault_sse" {
  bucket = aws_s3_bucket.company_research_vault.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
