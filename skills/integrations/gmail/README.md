# Gmail

Read and search emails from Gmail accounts. Supports fetching emails, searching by query, retrieving specific messages, and accessing attachment metadata.

## Provider

**Provider:** Google
**Auth Type:** oauth2
**Category:** communication

## Available Actions

### read_emails

Fetch recent emails from the inbox or a specific label. Returns a list of email summaries.

**Arguments:**
```json
{
  "type": "object",
  "properties": {
    "label": {
      "type": "string",
      "description": "Label/folder to read from (e.g., 'INBOX', 'SENT', 'STARRED'). Defaults to INBOX."
    },
    "max_results": {
      "type": "number",
      "description": "Maximum number of emails to return. Defaults to 10, max 100."
    },
    "include_body": {
      "type": "boolean",
      "description": "Whether to include email body content. Defaults to false for performance."
    }
  },
  "required": []
}
```

**Returns:**
```json
{
  "type": "object",
  "properties": {
    "emails": {
      "type": "array",
      "description": "List of email objects",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string",
            "description": "Unique email ID"
          },
          "thread_id": {
            "type": "string",
            "description": "Thread ID this email belongs to"
          },
          "subject": {
            "type": "string",
            "description": "Email subject line"
          },
          "from": {
            "type": "string",
            "description": "Sender email address"
          },
          "to": {
            "type": "string",
            "description": "Recipient email addresses"
          },
          "date": {
            "type": "string",
            "description": "ISO 8601 timestamp when email was received"
          },
          "snippet": {
            "type": "string",
            "description": "Short preview of email content"
          },
          "body": {
            "type": "string",
            "description": "Full email body (if include_body was true)"
          },
          "has_attachments": {
            "type": "boolean",
            "description": "Whether email has attachments"
          }
        }
      }
    },
    "result_count": {
      "type": "number",
      "description": "Number of emails returned"
    }
  }
}
```

### search_emails

Search emails using Gmail search query syntax (same as Gmail search bar).

**Arguments:**
```json
{
  "type": "object",
  "properties": {
    "query": {
      "type": "string",
      "description": "Gmail search query (e.g., 'from:john@example.com', 'subject:invoice', 'is:unread', 'after:2024/01/01')"
    },
    "max_results": {
      "type": "number",
      "description": "Maximum number of emails to return. Defaults to 10, max 100."
    },
    "include_body": {
      "type": "boolean",
      "description": "Whether to include email body content. Defaults to false."
    }
  },
  "required": [
    "query"
  ]
}
```

**Returns:**
```json
{
  "type": "object",
  "properties": {
    "emails": {
      "type": "array",
      "description": "List of matching email objects",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string",
            "description": "Unique email ID"
          },
          "thread_id": {
            "type": "string",
            "description": "Thread ID"
          },
          "subject": {
            "type": "string",
            "description": "Email subject line"
          },
          "from": {
            "type": "string",
            "description": "Sender email address"
          },
          "to": {
            "type": "string",
            "description": "Recipient email addresses"
          },
          "date": {
            "type": "string",
            "description": "ISO 8601 timestamp"
          },
          "snippet": {
            "type": "string",
            "description": "Short preview of content"
          },
          "body": {
            "type": "string",
            "description": "Full body if requested"
          },
          "has_attachments": {
            "type": "boolean",
            "description": "Whether email has attachments"
          }
        }
      }
    },
    "result_count": {
      "type": "number",
      "description": "Number of matching emails"
    }
  }
}
```

### get_email

Retrieve a specific email by its ID with full details including body content.

**Arguments:**
```json
{
  "type": "object",
  "properties": {
    "email_id": {
      "type": "string",
      "description": "The unique ID of the email to retrieve"
    },
    "format": {
      "type": "string",
      "description": "Response format: 'full' (default), 'minimal', or 'raw'"
    }
  },
  "required": [
    "email_id"
  ]
}
```

**Returns:**
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "description": "Unique email ID"
    },
    "thread_id": {
      "type": "string",
      "description": "Thread ID"
    },
    "subject": {
      "type": "string",
      "description": "Email subject line"
    },
    "from": {
      "type": "string",
      "description": "Sender email address and name"
    },
    "to": {
      "type": "string",
      "description": "Recipient email addresses"
    },
    "cc": {
      "type": "string",
      "description": "CC recipients"
    },
    "bcc": {
      "type": "string",
      "description": "BCC recipients"
    },
    "date": {
      "type": "string",
      "description": "ISO 8601 timestamp"
    },
    "body_text": {
      "type": "string",
      "description": "Plain text body content"
    },
    "body_html": {
      "type": "string",
      "description": "HTML body content"
    },
    "labels": {
      "type": "array",
      "description": "Labels applied to this email",
      "items": {
        "type": "string"
      }
    },
    "attachments": {
      "type": "array",
      "description": "List of attachment metadata",
      "items": {
        "type": "object",
        "properties": {
          "attachment_id": {
            "type": "string",
            "description": "Attachment ID for retrieval"
          },
          "filename": {
            "type": "string",
            "description": "Original filename"
          },
          "mime_type": {
            "type": "string",
            "description": "MIME type of attachment"
          },
          "size": {
            "type": "number",
            "description": "Size in bytes"
          }
        }
      }
    }
  }
}
```

### get_email_attachments

Get attachment metadata and secure download URLs for a specific email.

**Arguments:**
```json
{
  "type": "object",
  "properties": {
    "email_id": {
      "type": "string",
      "description": "The unique ID of the email containing attachments"
    },
    "attachment_id": {
      "type": "string",
      "description": "Optional: specific attachment ID to retrieve. If omitted, returns all attachments."
    }
  },
  "required": [
    "email_id"
  ]
}
```

**Returns:**
```json
{
  "type": "object",
  "properties": {
    "attachments": {
      "type": "array",
      "description": "List of attachment objects with download URLs",
      "items": {
        "type": "object",
        "properties": {
          "attachment_id": {
            "type": "string",
            "description": "Unique attachment identifier"
          },
          "filename": {
            "type": "string",
            "description": "Original filename"
          },
          "mime_type": {
            "type": "string",
            "description": "MIME type (e.g., 'application/pdf', 'image/png')"
          },
          "size": {
            "type": "number",
            "description": "File size in bytes"
          },
          "download_url": {
            "type": "string",
            "description": "Secure, time-limited URL to download the attachment"
          }
        }
      }
    },
    "total_count": {
      "type": "number",
      "description": "Total number of attachments"
    },
    "total_size": {
      "type": "number",
      "description": "Combined size of all attachments in bytes"
    }
  }
}
```

## Admin Configuration

Admins must configure the following fields:

| Field | Label | Type | Required | Secret |
|-------|-------|------|----------|--------|
| oauth2_client_id | OAuth2 Client ID | string | Yes | No |
| oauth2_client_secret | OAuth2 Client Secret | string | Yes | Yes |

## Usage

This integration is used automatically by the coding agent when it detects a request that requires this data source.

**Example request from coding agent:**
```json
{
  "integrationKey": "gmail",
  "actionName": "read_emails",
  "args": {}
}
```

**IMPORTANT:** Secrets/tokens are never exposed to the LLM. All credentials are stored securely on the company server and used only by the Integration Proxy at execution time.