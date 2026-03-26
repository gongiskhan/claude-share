# Google Analytics Setup Wizard

This guide walks you through connecting Google Analytics 4 to Ekoa OS.

## Prerequisites

Before starting, you'll need:
- [ ] A Google Analytics 4 property (GA4, not Universal Analytics)
- [ ] Access to Google Cloud Console
- [ ] Admin or Editor access to the GA4 property

## Step 1: Identify Your GA4 Property

1. Go to [Google Analytics](https://analytics.google.com/)
2. Select your account and property
3. Click **Admin** (gear icon, bottom left)
4. Under **Property**, click **Property Settings**
5. Copy your **Property ID** (numeric, e.g., `123456789`)

> 💡 If you see "UA-XXXXXX", that's Universal Analytics. You need GA4!

**Format:** Your property ID should be just numbers. When using the API, it becomes `properties/123456789`.

---

## Step 2: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click the project dropdown (top bar)
3. Click **New Project** (or select existing)
4. Name it something like "Ekoa Analytics"
5. Click **Create**

---

## Step 3: Enable the Analytics Data API

1. In Google Cloud Console, go to **APIs & Services** > **Library**
2. Search for "Google Analytics Data API"
3. Click on **Google Analytics Data API** (NOT "Analytics Reporting API")
4. Click **Enable**

> ⚠️ Make sure you enable the **Data API**, not the older Reporting API!

---

## Step 4: Create Service Account

Service accounts are simpler for automation (no user interaction needed).

1. Go to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **Service Account**
3. Fill in:
   - **Name:** `ekoa-analytics-reader`
   - **Description:** "Read-only access to GA4 for Ekoa OS"
4. Click **Create and Continue**
5. For role, select: **No role** (we'll grant access in GA4)
6. Click **Done**

### Download the Key

1. Click on your new service account
2. Go to **Keys** tab
3. Click **Add Key** > **Create new key**
4. Select **JSON**
5. Save the file (e.g., `ekoa-ga-service-account.json`)

> 🔐 Keep this file secure! It grants API access.

---

## Step 5: Grant GA4 Access to Service Account

1. Go back to [Google Analytics](https://analytics.google.com/)
2. Click **Admin** > **Property Access Management**
3. Click **+** > **Add users**
4. Enter the service account email (from the JSON file, looks like `xxx@project.iam.gserviceaccount.com`)
5. Select role: **Viewer** (read-only is sufficient)
6. Click **Add**

---

## Step 6: Configure Ekoa OS

Now let's store your credentials:

### Option A: Interactive Setup

Tell me:
1. Your GA4 Property ID (just the numbers)
2. Paste the contents of your service account JSON file

I'll create the config file for you.

### Option B: Manual Setup

Create `~/.ekoa/integrations/google-analytics.json`:

```json
{
  "propertyId": "YOUR_PROPERTY_ID",
  "authType": "service_account",
  "credentials": {
    "serviceAccountKey": {
      "type": "service_account",
      "project_id": "your-project-id",
      "private_key_id": "...",
      "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
      "client_email": "ekoa-analytics-reader@your-project.iam.gserviceaccount.com",
      "client_id": "...",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token"
    }
  },
  "configured": true,
  "configuredAt": "2026-02-04T19:42:00Z"
}
```

---

## Step 7: Verify Setup

Run a test query:

```bash
# Quick test - should return property info
python3 << 'EOF'
import json
from google.oauth2 import service_account
from google.analytics.data_v1beta import BetaAnalyticsDataClient
from google.analytics.data_v1beta.types import RunReportRequest, DateRange, Metric

with open('~/.ekoa/integrations/google-analytics.json'.replace('~', __import__('os').path.expanduser('~'))) as f:
    config = json.load(f)

creds = service_account.Credentials.from_service_account_info(
    config['credentials']['serviceAccountKey'],
    scopes=['https://www.googleapis.com/auth/analytics.readonly']
)

client = BetaAnalyticsDataClient(credentials=creds)
response = client.run_report(RunReportRequest(
    property=f"properties/{config['propertyId']}",
    date_ranges=[DateRange(start_date="yesterday", end_date="yesterday")],
    metrics=[Metric(name="sessions")]
))

print(f"✅ Connected! Yesterday's sessions: {response.rows[0].metric_values[0].value}")
EOF
```

---

## Troubleshooting

### "Permission denied" Error
- Verify the service account email was added to GA4 Property Access Management
- Wait 5-10 minutes after adding (propagation delay)
- Ensure you're using the correct Property ID

### "API not enabled" Error
- Go back to Google Cloud Console
- Ensure "Google Analytics Data API" is enabled (not just "Analytics API")

### "Invalid property" Error
- Property ID should be just numbers (e.g., `123456789`)
- Don't include "GA4-" or "properties/" prefix in config

### Dependencies Not Installed
```bash
pip install google-analytics-data google-auth
```

---

## Quick Reference

| Item | Value |
|------|-------|
| Config Location | `~/.ekoa/integrations/google-analytics.json` |
| API | Google Analytics Data API v1beta |
| Auth Method | Service Account (recommended) |
| Required Scope | `analytics.readonly` |
| GA4 Property Format | Just the number (e.g., `123456789`) |

---

## Alternative: OAuth Setup

If you prefer OAuth (requires browser auth):

1. Create **OAuth 2.0 Client ID** instead of Service Account
2. Download the client secrets JSON
3. First run will open browser for consent
4. Refresh token stored for subsequent requests

OAuth is better for:
- Personal use with your own Google account
- Apps that need user-specific data
- Situations where you can't add service accounts to GA4

Service Account is better for:
- Automation / server-side scripts
- Multiple properties under your control
- No browser interaction needed
