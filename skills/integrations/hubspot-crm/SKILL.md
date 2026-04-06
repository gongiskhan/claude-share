---
name: hubspot-crm
description: Use this integration to interact with HubSpot CRM - retrieve contact information, create new contacts, and manage customer relationships.
---

# HubSpot CRM

This integration connects to HubSpot CRM to manage contacts and customer data. Use it when users need to look up contact information, create new contacts, or manage their CRM data.

## Security Model

All actions are executed through the Maestric Integration Proxy. API credentials are stored encrypted on the company server and are never exposed to agents or LLMs. The proxy handles authentication and executes requests securely.

## Available Actions

### get_contact

Retrieves a contact from HubSpot by their email address. Returns contact details including name, email, and associated properties.

**Arguments:**
- `email` (string, required): The email address of the contact to retrieve

**Example:**