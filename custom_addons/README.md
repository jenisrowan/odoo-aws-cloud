# Custom Odoo Addons

This directory contains the custom Odoo modules developed for the `odoo-aws-cloud` project. 

## Modules

### customer_reporting
*   **Purpose**: Integrates with Amazon Bedrock to generate and store AI-driven customer research reports.
*   **Key Features**:
    *   Adds a "Reporting" menu to CRM.
    *   Connects to AWS Lambda via Bedrock Action Groups.
    *   Stores final reports in Odoo Partner chatter and custom fields.

## Deployment
These modules are automatically copied to `/mnt/extra-addons` inside the Odoo Docker container during the build process defined in `templates/Dockerfile.odoo`.
