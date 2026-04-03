import json
import base64
import logging

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(f"Received Bedrock event for actionGroup: {event.get('actionGroup')}")
    # This Lambda receives the finished research brief from the Supervisor Agent
    # and returns it in the response payload. The caller (Odoo) will capture
    # this result and save it into the customer.reporting report_file field.
    
    request_body = event.get('requestBody', {}).get('content', {}).get('application/json', {}).get('properties', [])
    partner_id = None
    company_name = "Unknown"
    report_content = "No report generated."
    
    for prop in request_body:
        if prop.get('name') == 'partner_id':
            partner_id = prop.get('value')
        if prop.get('name') == 'company_name':
            company_name = prop.get('value')
        if prop.get('name') == 'report':
            report_content = prop.get('value')
            
    logger.info(f"Formatting report for company: {company_name}")
    
    # Formulate the response that will be sent back to the chat client
    # The client can parse 'report_file_b64' to save into the binary field
    result = {
        "status": "success", 
        "message": f"Report generated for {company_name}",
        "report_text": report_content,
        "report_file_b64": base64.b64encode(report_content.encode('utf-8')).decode('utf-8'),
        "filename": f"{company_name.replace(' ', '_').lower()}_report.txt"
    }
    
    response_body = {
        "application/json": {
            "body": json.dumps(result)
        }
    }
    
    return {
        "messageVersion": "1.0",
        "response": {
            "actionGroup": event.get("actionGroup"),
            "apiPath": event.get("apiPath"),
            "httpMethod": event.get("httpMethod"),
            "httpStatusCode": 200,
            "responseBody": response_body
        }
    }
