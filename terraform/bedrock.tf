resource "aws_bedrockagent_knowledge_base" "research_kb" {
  name     = "research-kb"
  role_arn = aws_iam_role.bedrock_kb_role.arn
  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/amazon.titan-embed-text-v2:0"
    }
  }
  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.bedrock_kb.arn
      vector_index_name = "bedrock-knowledge-base-default-index"
      field_mapping {
        vector_field   = "bedrock-knowledge-base-default-vector"
        text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
        metadata_field = "AMAZON_BEDROCK_METADATA"
      }
    }
  }
  depends_on = [
    aws_opensearchserverless_collection.bedrock_kb,
    aws_iam_role_policy_attachment.bedrock_kb_opensearch
  ]
}

resource "aws_bedrockagent_data_source" "research_s3" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.research_kb.id
  name              = "s3-document-vault"
  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.company_research_vault.arn
    }
  }
}

resource "aws_bedrockagent_agent" "supervisor" {
  agent_name                  = "CustomerResearchSupervisor"
  agent_resource_role_arn     = aws_iam_role.bedrock_agent_role.arn
  foundation_model            = "anthropic.claude-3-5-sonnet-20240620-v1:0"
  instruction                 = "You are a customer research supervisor. Your job is to compile a complete briefing by searching the web and the internal document vault to find all relevant information on a company. Once compiled, use the OdooIntegrator to push the final report back directly to Odoo."
  idle_session_ttl_in_seconds = 1800
}

resource "aws_bedrockagent_agent_action_group" "web_search" {
  agent_id           = aws_bedrockagent_agent.supervisor.id
  agent_version      = "DRAFT"
  action_group_name  = "WebSearch"
  action_group_state = "ENABLED"
  description        = "Use this action to search the public web via Tavily to find recent news and context."
  action_group_executor {
    lambda = aws_lambda_function.librarian.arn
  }

  api_schema {
    payload = jsonencode({
      "openapi" = "3.0.0",
      "info" = {
        "title"   = "WebSearch API",
        "version" = "1.0.0"
      },
      "paths" = {
        "/search" = {
          "post" = {
            "summary"     = "Search the web for news or topics",
            "operationId" = "SearchWeb",
            "requestBody" = {
              "required" = true,
              "content" = {
                "application/json" = {
                  "schema" = {
                    "type" = "object",
                    "properties" = {
                      "query" = {
                        "type"        = "string",
                        "description" = "The search query to search via Tavily."
                      }
                    },
                    "required" = ["query"]
                  }
                }
              }
            },
            "responses" = {
              "200" = {
                "description" = "Successful search",
                "content" = {
                  "application/json" = {
                    "schema" = {
                      "type" = "object",
                      "properties" = {
                        "search_result" = { "type" = "string" }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    })
  }
}

resource "aws_bedrockagent_agent_action_group" "odoo_integrator" {
  agent_id           = aws_bedrockagent_agent.supervisor.id
  agent_version      = "DRAFT"
  action_group_name  = "OdooIntegrator"
  action_group_state = "ENABLED"
  description        = "Use this action to submit the completed research briefing back to the Odoo ERP system."
  action_group_executor {
    lambda = aws_lambda_function.odoo_integrator.arn
  }

  api_schema {
    payload = jsonencode({
      "openapi" = "3.0.0",
      "info" = {
        "title"   = "Odoo Integrator",
        "version" = "1.0.0"
      },
      "paths" = {
        "/submit" = {
          "post" = {
            "summary"     = "Submit final report to Odoo Partner record.",
            "operationId" = "SubmitReport",
            "requestBody" = {
              "required" = true,
              "content" = {
                "application/json" = {
                  "schema" = {
                    "type" = "object",
                    "properties" = {
                      "partner_id" = {
                        "type"        = "integer",
                        "description" = "The ID of the Partner/Lead in Odoo."
                      },
                      "report" = {
                        "type"        = "string",
                        "description" = "The markdown or HTML report content."
                      }
                    },
                    "required" = ["partner_id", "report"]
                  }
                }
              }
            },
            "responses" = {
              "200" = {
                "description" = "Successful submission",
                "content" = {
                  "application/json" = {
                    "schema" = {
                      "type" = "object",
                      "properties" = {
                        "status" = { "type" = "string" }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    })
  }
}

resource "aws_bedrockagent_agent_knowledge_base_association" "analyst" {
  agent_id             = aws_bedrockagent_agent.supervisor.id
  agent_version        = "DRAFT"
  knowledge_base_id    = aws_bedrockagent_knowledge_base.research_kb.id
  description          = "Use this to search internal PDF documents and 10-K filings."
  knowledge_base_state = "ENABLED"
}

resource "aws_bedrockagent_agent_alias" "prod" {
  agent_alias_name = "ProductionAlias"
  agent_id         = aws_bedrockagent_agent.supervisor.id
  description      = "Production alias for Odoo ECS integration"
}
