resource "aws_opensearchserverless_collection" "bedrock_kb" {
  name             = "bedrock-kb-collection"
  type             = "VECTORSEARCH"
  standby_replicas = "DISABLED"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption_policy,
    aws_opensearchserverless_security_policy.network_policy,
    aws_opensearchserverless_access_policy.data_access
  ]
}

resource "aws_opensearchserverless_security_policy" "encryption_policy" {
  name = "bedrock-encryption-policy"
  type = "encryption"
  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/bedrock-kb-collection"]
      }
    ]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network_policy" {
  name = "bedrock-network-policy"
  type = "network"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/bedrock-kb-collection"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/bedrock-kb-collection"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

resource "aws_opensearchserverless_access_policy" "data_access" {
  name        = "bedrock-kb-access"
  type        = "data"
  description = "Allows data access to bedrock kb"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/bedrock-kb-collection"]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
        },
        {
          ResourceType = "index"
          Resource     = ["index/bedrock-kb-collection/*"]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument"
          ]
        }
      ]
      Principal = [
        aws_iam_role.bedrock_kb_role.arn,
        aws_iam_role.bedrock_agent_role.arn,
        data.aws_caller_identity.current.arn
      ]
    }
  ])
}

resource "opensearch_index" "bedrock_index" {
  name                           = "bedrock-knowledge-base-default-index"
  index_knn                      = true
  index_knn_algo_param_ef_search = "512"

  mappings = jsonencode({
    properties = {
      "bedrock-knowledge-base-default-vector" = {
        type      = "knn_vector"
        dimension = 1024
        method = {
          name       = "hnsw"        # Hierarchical Navigable Small World
          engine     = "faiss"       # Facebook AI Similarity Search
          space_type = "cosinesimil" # Cosine Similarity
          parameters = {
            m               = 16
            ef_construction = 512
          }
        }
      }
      "AMAZON_BEDROCK_TEXT_CHUNK" = {
        type = "text"
      }
      "AMAZON_BEDROCK_METADATA" = {
        type = "text"
      }
    }
  })

  depends_on = [
    aws_opensearchserverless_collection.bedrock_kb,
    aws_opensearchserverless_access_policy.data_access
  ]
}
