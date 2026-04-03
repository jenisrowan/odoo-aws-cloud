import os
import json
import logging
import threading
import base64
from odoo import models, fields, api
import odoo
import redis
import boto3

logger = logging.getLogger(__name__)

def invoke_bedrock_agent(db_name, record_id, company_name):
    """
    Background thread to push status to Redis and invoke Bedrock Agent asynchronous processing.
    """
    registry = odoo.registry(db_name)
    with registry.cursor() as cr:
        env = api.Environment(cr, odoo.SUPERUSER_ID, {})
        record = env['customer.reporting'].browse(record_id)
        
        try:
            redis_host = os.environ.get('REDIS_HOST', 'redis')
            redis_port = int(os.environ.get('REDIS_PORT', 6379))
            redis_client = redis.Redis(host=redis_host, port=redis_port, db=0)
            redis_client.set(f"report_status_{record_id}", "Analysis in process")
            logger.info(f"Pushed status to ElastiCache for {record_id}")
            
            region = os.environ.get('AWS_REGION', 'ap-south-1')
            client = boto3.client('bedrock-agent-runtime', region_name=region)
            agent_id = os.environ.get('BEDROCK_AGENT_ID', 'DUMMY')
            agent_alias_id = os.environ.get('BEDROCK_AGENT_ALIAS_ID', 'DUMMY')
            
            logger.info(f"Triggering Bedrock AI for {company_name}")
            response = client.invoke_agent(
                agentId=agent_id,
                agentAliasId=agent_alias_id,
                sessionId=f"session-{record_id}",
                inputText=f"Please compile a full report on {company_name} and submit it to Odoo for partner id {record_id}. Make sure to invoke OdooIntegrator.",
                enableTrace=True
            )
            
            report_text = ""
            action_group_payload = None
            
            for event in response.get('completion'):
                if 'chunk' in event:
                    chunk_data = event['chunk']['bytes'].decode('utf-8')
                    report_text += chunk_data
                elif 'trace' in event:
                    try:
                        trace_obj = event['trace'].get('trace', {})
                        orch = trace_obj.get('orchestrationTrace', {})
                        obs = orch.get('observation', {})
                        ag_out = obs.get('actionGroupInvocationOutput', {})
                        text_payload = ag_out.get('text')
                        if text_payload:
                            parsed_payload = json.loads(text_payload)
                            if "report_file_b64" in parsed_payload:
                                action_group_payload = parsed_payload
                    except Exception as e:
                        logger.warning("Failed to parse trace: %s", str(e))
                        
            # Extract response and write to report_file
            if action_group_payload and "report_file_b64" in action_group_payload:
                record.report_file = action_group_payload["report_file_b64"]
                record.report_filename = action_group_payload.get("filename", f"{company_name}_report.txt")
            else:
                # Fallback if the agent didn't invoke the action group
                record.report_file = base64.b64encode(report_text.encode('utf-8'))
                record.report_filename = f"{company_name}_report.txt"
                
        except Exception as e:
            logger.error("Bedrock background task failed: %s", str(e))


class CustomerReporting(models.Model):
    _name = "customer.reporting"
    _description = "Customer Reporting"
    _inherit = ['mail.thread', 'mail.activity.mixin']

    name = fields.Char(string="Company Name", required=True, tracking=True)
    report_file = fields.Binary(string="End Result", attachment=True, tracking=True)
    report_filename = fields.Char(string="File Name")

    def action_get_report(self):
        for record in self:
            thread = threading.Thread(target=invoke_bedrock_agent, args=(self.env.cr.dbname, record.id, record.name))
            thread.start()
            
        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': 'Analysis in process',
                'message': 'Analysis in process, it will be available within 5 minutes.',
                'sticky': False,
                'type': 'info',
            }
        }
