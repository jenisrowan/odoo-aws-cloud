data "archive_file" "tavily_search_zip" {
  type        = "zip"
  source_file = "${path.module}/functions/tavily_search.py"
  output_path = "${path.module}/functions/tavily_search.zip"
}

data "archive_file" "odoo_integrator_zip" {
  type        = "zip"
  source_file = "${path.module}/functions/odoo_integrator.py"
  output_path = "${path.module}/functions/odoo_integrator.zip"
}

# 1. Librarian Lambda
resource "aws_lambda_function" "librarian" {
  filename         = data.archive_file.tavily_search_zip.output_path
  function_name    = "bedrock_agent_librarian"
  role             = aws_iam_role.librarian_lambda_role.arn
  handler          = "tavily_search.lambda_handler"
  runtime          = "python3.12"
  timeout          = 90
  source_code_hash = data.archive_file.tavily_search_zip.output_base64sha256

  environment {
    variables = {
      TAVILY_SECRET_ARN = data.aws_secretsmanager_secret.tavily_api_key.arn
    }
  }
}

resource "aws_lambda_permission" "bedrock_invoke_librarian" {
  statement_id  = "AllowBedrockInvokeLibrarian"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.librarian.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = aws_bedrockagent_agent.supervisor.agent_arn
}

# 2. Odoo Integrator Lambda
resource "aws_lambda_function" "odoo_integrator" {
  filename         = data.archive_file.odoo_integrator_zip.output_path
  function_name    = "bedrock_agent_odoo_integrator"
  role             = aws_iam_role.odoo_integrator_lambda_role.arn
  handler          = "odoo_integrator.lambda_handler"
  runtime          = "python3.12"
  timeout          = 90
  source_code_hash = data.archive_file.odoo_integrator_zip.output_base64sha256

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda_odoo_integrator_sg.id]
  }

  environment {
    variables = {
      ODOO_URL                    = "http://odoo.odoo.local:8069"
      ODOO_CREDENTIALS_SECRET_ARN = data.aws_secretsmanager_secret.odoo_integration_credentials.arn
    }
  }
}

resource "aws_lambda_permission" "bedrock_invoke_odoo_integrator" {
  statement_id  = "AllowBedrockInvokeOdooIntegrator"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.odoo_integrator.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = aws_bedrockagent_agent.supervisor.agent_arn
}
