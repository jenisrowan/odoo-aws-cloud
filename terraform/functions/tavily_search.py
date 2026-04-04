import json
import os
import urllib.request
import logging
import boto3

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Global clients and cache (outside handler for reuse)
secrets_client = boto3.client('secretsmanager')
CACHED_TAVILY_KEY = None

def get_tavily_key():
    """
    Fetches the Tavily API key from Secrets Manager and caches it globally.
    NOTE: Global caching is SECURE in AWS Lambda because the execution environment 
    is private to the function and is never shared between different AWS accounts or users.
    """
    global CACHED_TAVILY_KEY
    if CACHED_TAVILY_KEY:
        return CACHED_TAVILY_KEY

    tavily_secret_arn = os.environ.get("TAVILY_SECRET_ARN")
    if not tavily_secret_arn:
        logger.error("TAVILY_SECRET_ARN environment variable is not set.")
        return None

    try:
        logger.info(f"Fetching secret from Secrets Manager: {tavily_secret_arn}")
        secret_val = secrets_client.get_secret_value(SecretId=tavily_secret_arn)
        secret_string = secret_val.get('SecretString')
        
        if not secret_string:
            return None

        # Standard AWS Secret format is a JSON Key/Value pair
        try:
            secret_json = json.loads(secret_string)
            CACHED_TAVILY_KEY = secret_json.get('api_key')
            if not CACHED_TAVILY_KEY:
                logger.error("Secret JSON was found but 'api_key' key is missing.")
        except json.JSONDecodeError:
            logger.error("Failed to parse SecretString as JSON. Plaintext secrets are not supported for security reasons.")
            return None

        return CACHED_TAVILY_KEY
    except Exception as e:
        logger.error(f"Failed to retrieve Tavily secret: {e}")
        return None

def lambda_handler(event, context):
    logger.info(f"Tavily search initiated for path: {event.get('apiPath')}")
    
    tavily_api_key = get_tavily_key()
    search_query = "Unknown"
    
    # Extract query from Bedrock Agent parameters
    request_body = event.get('requestBody', {}).get('content', {}).get('application/json', {}).get('properties', [])
    for prop in request_body:
        if prop.get('name') == 'query':
            search_query = prop.get('value')

    logger.info(f"Searching Tavily for query: {search_query}")
    
    if not tavily_api_key:
        search_result = "TAVILY_API_KEY is not set or failed to load from Secrets Manager."
        logger.warning("Search aborted: API key missing.")
    else:
        req_body = json.dumps({
            "api_key": tavily_api_key,
            "query": search_query,
            "search_depth": "advanced", # deeper research
            "include_answer": True,
            "max_results": 20
        }).encode('utf-8')
        
        req = urllib.request.Request(
            "https://api.tavily.com/search",
            data=req_body,
            headers={"Content-Type": "application/json"}
        )
        
        try:
            with urllib.request.urlopen(req) as response:
                result_data = json.loads(response.read().decode('utf-8'))
                
                # Combine the Answer with the Detailed Results for max LLM context
                answer = result_data.get("answer")
                results = result_data.get("results", [])
                
                detail_str = "\n".join([f"- {r.get('title')}: {r.get('content')}" for r in results[:20]])
                
                if answer:
                    search_result = f"SUMMARY:\n{answer}\n\nDETAILED SOURCES:\n{detail_str}"
                else:
                    search_result = f"DETAILED SOURCES:\n{detail_str}"
        except Exception as e:
            logger.error(f"Error calling Tavily API: {str(e)}")
            search_result = f"Failed to search Tavily: {e}"
    
    # Bedrock format response
    response_body = {
        "application/json": {
            "body": json.dumps({"search_result": search_result})
        }
    }
    
    action_response = {
        "actionGroup": event.get("actionGroup"),
        "apiPath": event.get("apiPath"),
        "httpMethod": event.get("httpMethod"),
        "httpStatusCode": 200,
        "responseBody": response_body
    }
    
    return {"messageVersion": "1.0", "response": action_response}
