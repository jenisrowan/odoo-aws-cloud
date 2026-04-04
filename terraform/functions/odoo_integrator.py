import json
import base64
import logging
import boto3
import xmlrpc.client
import os

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Global clients and cache for production reuse (optimized for AWS Lambda)
secrets_client = boto3.client('secretsmanager')
CACHED_ODOO_CREDENTIALS = None

def get_odoo_credentials():
    """
    Fetches the Odoo integration credentials (API Key) from Secrets Manager.
    Uses global caching to reduce AWS API calls and latency.
    """
    global CACHED_ODOO_CREDENTIALS
    if CACHED_ODOO_CREDENTIALS:
        return CACHED_ODOO_CREDENTIALS
    
    secret_arn = os.environ.get("ODOO_CREDENTIALS_SECRET_ARN")
    if not secret_arn:
        logger.error("ODOO_CREDENTIALS_SECRET_ARN environment variable is not set.")
        return None
        
    try:
        logger.info(f"Retrieving Odoo credentials from: {secret_arn}")
        response = secrets_client.get_secret_value(SecretId=secret_arn)
        secret_json = json.loads(response['SecretString'])
        
        api_key = secret_json.get('api_key')
        login = secret_json.get('login')
        
        if not api_key:
            logger.error("No 'api_key' found in the secret payload.")
            return None
            
        CACHED_ODOO_CREDENTIALS = {
            'login': login,
            'api_key': api_key
        }
        return CACHED_ODOO_CREDENTIALS
    except Exception as e:
        logger.error(f"Failed to fetch Odoo credentials from Secrets Manager: {e}")
        return None

def lambda_handler(event, context):
    logger.info(f"Odoo Integrator invoked for action: {event.get('apiPath')}")
    
    # Extract parameters passed by the Bedrock Agent
    request_body = event.get('requestBody', {}).get('content', {}).get('application/json', {}).get('properties', [])
    params = {p.get('name'): p.get('value') for p in request_body}
    
    record_id = params.get('partner_id')      # The record ID in customer.reporting
    database_name = params.get('database_name')
    company_name = params.get('company_name', 'Unknown')
    report_content = params.get('report', 'No content generated.')
    
    if not record_id or not database_name:
        logger.error(f"Incomplete parameters. record_id: {record_id}, db: {database_name}")
        return error_response(event, "Integration failed: Missing record_id or database_name.")
        
    creds = get_odoo_credentials()
    if not creds:
        return error_response(event, "Integration failed: Could not load Odoo credentials.")
        
    odoo_url = os.environ.get("ODOO_URL", "http://odoo.odoo.local:8069")
    
    try:
        logger.info(f"Connecting to Odoo at {odoo_url} (DB: {database_name}, User: {creds['login']})")
        
        # 1. Authenticate with Odoo (Using API Key)
        common = xmlrpc.client.ServerProxy(f"{odoo_url}/xmlrpc/2/common")
        uid = common.authenticate(database_name, creds['login'], creds['api_key'], {})
        
        if not uid:
            logger.error(f"Odoo authentication failed for {creds['login']}")
            return error_response(event, f"Authentication failed for user {creds['login']} on database {database_name}.")
            
        # 2. Perform the Update (Write the file back to the record)
        models = xmlrpc.client.ServerProxy(f"{odoo_url}/xmlrpc/2/object")
        filename = f"{company_name.replace(' ', '_').lower()}_report.txt"
        
        update_data = {
            'report_file': base64.b64encode(report_content.encode('utf-8')).decode('utf-8'),
            'report_filename': filename
        }
        
        logger.info(f"Writing report to Odoo record #{record_id}...")
        models.execute_kw(database_name, uid, creds['api_key'], 'customer.reporting', 'write', [[int(record_id)], update_data])
        
        success_msg = f"Successfully updated Odoo record #{record_id} with the research briefing."
        logger.info(success_msg)
        
        return success_response(event, success_msg)
        
    except Exception as e:
        logger.error(f"Odoo Integration Error: {str(e)}")
        return error_response(event, f"Odoo Integration Error: {str(e)}")

def success_response(event, message):
    return format_response(event, 200, {"status": "success", "message": message})

def error_response(event, message):
    return format_response(event, 400, {"status": "error", "message": message})

def format_response(event, status_code, body):
    """
    Formats the response in the standard Amazon Bedrock Agent Action Group format.
    """
    return {
        "messageVersion": "1.0",
        "response": {
            "actionGroup": event.get("actionGroup"),
            "apiPath": event.get("apiPath"),
            "httpMethod": event.get("httpMethod"),
            "httpStatusCode": status_code,
            "responseBody": {
                "application/json": {
                    "body": json.dumps(body)
                }
            }
        }
    }
