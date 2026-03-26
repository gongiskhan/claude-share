# Realtime Query

Get current active users on your website.

## Description

Returns live visitor data:
- **Active Users** - People on site right now
- **Active Pages** - What they're viewing
- **Traffic Sources** - Where they came from
- **Locations** - Geographic distribution

> ⚠️ Realtime data may have 1-2 minute delay

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `minutesAgo` | integer | `30` | Lookback window (max 30) |

## GA4 API Request - Active Users

```json
{
  "metrics": [
    {"name": "activeUsers"}
  ]
}
```

### Active Users by Page

```json
{
  "dimensions": [
    {"name": "unifiedScreenName"}
  ],
  "metrics": [
    {"name": "activeUsers"}
  ],
  "orderBys": [
    {
      "metric": {"metricName": "activeUsers"},
      "desc": true
    }
  ],
  "limit": 10
}
```

### Active Users by Source

```json
{
  "dimensions": [
    {"name": "sessionSource"}
  ],
  "metrics": [
    {"name": "activeUsers"}
  ],
  "orderBys": [
    {
      "metric": {"metricName": "activeUsers"},
      "desc": true
    }
  ],
  "limit": 10
}
```

### Active Users by Country

```json
{
  "dimensions": [
    {"name": "country"}
  ],
  "metrics": [
    {"name": "activeUsers"}
  ],
  "orderBys": [
    {
      "metric": {"metricName": "activeUsers"},
      "desc": true
    }
  ],
  "limit": 10
}
```

## Python Implementation

```python
import json
import os
from google.oauth2 import service_account
from google.analytics.data_v1beta import BetaAnalyticsDataClient
from google.analytics.data_v1beta.types import (
    RunRealtimeReportRequest, Metric, Dimension, OrderBy
)

def get_realtime_users():
    """Get current active users."""
    
    config_path = os.path.expanduser("~/.ekoa/integrations/google-analytics.json")
    with open(config_path) as f:
        config = json.load(f)
    
    creds = service_account.Credentials.from_service_account_info(
        config['credentials']['serviceAccountKey'],
        scopes=['https://www.googleapis.com/auth/analytics.readonly']
    )
    
    client = BetaAnalyticsDataClient(credentials=creds)
    
    # Total active users
    total_request = RunRealtimeReportRequest(
        property=f"properties/{config['propertyId']}",
        metrics=[Metric(name="activeUsers")]
    )
    total_response = client.run_realtime_report(total_request)
    
    # By page
    pages_request = RunRealtimeReportRequest(
        property=f"properties/{config['propertyId']}",
        dimensions=[Dimension(name="unifiedScreenName")],
        metrics=[Metric(name="activeUsers")],
        order_bys=[OrderBy(metric=OrderBy.MetricOrderBy(metric_name="activeUsers"), desc=True)],
        limit=5
    )
    pages_response = client.run_realtime_report(pages_request)
    
    # By country
    country_request = RunRealtimeReportRequest(
        property=f"properties/{config['propertyId']}",
        dimensions=[Dimension(name="country")],
        metrics=[Metric(name="activeUsers")],
        order_bys=[OrderBy(metric=OrderBy.MetricOrderBy(metric_name="activeUsers"), desc=True)],
        limit=5
    )
    country_response = client.run_realtime_report(country_request)
    
    return {
        'total': total_response,
        'pages': pages_response,
        'countries': country_response
    }

def format_realtime(data):
    """Format realtime data for display."""
    
    # Total
    total = 0
    if data['total'].rows:
        total = int(data['total'].rows[0].metric_values[0].value)
    
    lines = [f"🔴 **{total} Active Users Right Now**\n"]
    
    # Top pages
    if data['pages'].rows:
        lines.append("**Currently Viewing:**")
        for row in data['pages'].rows[:5]:
            page = row.dimension_values[0].value
            users = row.metric_values[0].value
            lines.append(f"• {page}: {users}")
        lines.append("")
    
    # Countries
    if data['countries'].rows:
        lines.append("**From:**")
        countries = [f"{row.dimension_values[0].value} ({row.metric_values[0].value})" 
                    for row in data['countries'].rows[:5]]
        lines.append(", ".join(countries))
    
    return "\n".join(lines)

# Usage
if __name__ == "__main__":
    data = get_realtime_users()
    print(format_realtime(data))
```

## curl Implementation

```bash
#!/bin/bash

CONFIG_FILE="$HOME/.ekoa/integrations/google-analytics.json"
PROPERTY_ID=$(jq -r '.propertyId' "$CONFIG_FILE")

ACCESS_TOKEN=$(python3 << EOF
import json
from google.oauth2 import service_account
from google.auth.transport.requests import Request

with open('$CONFIG_FILE') as f:
    config = json.load(f)

creds = service_account.Credentials.from_service_account_info(
    config['credentials']['serviceAccountKey'],
    scopes=['https://www.googleapis.com/auth/analytics.readonly']
)
creds.refresh(Request())
print(creds.token)
EOF
)

# Realtime endpoint is different!
curl -s "https://analyticsdata.googleapis.com/v1beta/properties/${PROPERTY_ID}:runRealtimeReport" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "dimensions": [{"name": "country"}],
    "metrics": [{"name": "activeUsers"}]
  }' | jq '{
    totalUsers: .rows | map(.metricValues[0].value | tonumber) | add,
    byCountry: [.rows[] | {country: .dimensionValues[0].value, users: .metricValues[0].value}]
  }'
```

## Response Parsing

### Raw API Response
```json
{
  "dimensionHeaders": [
    {"name": "country"}
  ],
  "metricHeaders": [
    {"name": "activeUsers", "type": "TYPE_INTEGER"}
  ],
  "rows": [
    {
      "dimensionValues": [{"value": "United States"}],
      "metricValues": [{"value": "42"}]
    },
    {
      "dimensionValues": [{"value": "Portugal"}],
      "metricValues": [{"value": "15"}]
    },
    {
      "dimensionValues": [{"value": "United Kingdom"}],
      "metricValues": [{"value": "8"}]
    }
  ],
  "rowCount": 3
}
```

## Human-Friendly Output

**For chat:**
```
🔴 65 Active Users Right Now

Currently Viewing:
• Home: 23
• Blog Post: How to Use GA4: 12
• Products: 8
• Contact: 5
• Pricing: 4

From: United States (42), Portugal (15), United Kingdom (8)
```

**For voice/TTS:**
> You have sixty five people on your site right now! Most are viewing your homepage. Forty two visitors are from the United States, fifteen from Portugal, and eight from the UK.

## Available Realtime Dimensions

| Dimension | Description |
|-----------|-------------|
| `country` | Visitor's country |
| `city` | Visitor's city |
| `deviceCategory` | desktop, mobile, tablet |
| `platform` | web, iOS, Android |
| `unifiedScreenName` | Page/screen being viewed |
| `audienceName` | Audience membership |
| `sessionSource` | Traffic source |
| `sessionMedium` | Traffic medium |

## Available Realtime Metrics

| Metric | Description |
|--------|-------------|
| `activeUsers` | Users active in last 30 min |
| `screenPageViews` | Views in last 30 min |
| `eventCount` | Events in last 30 min |
| `conversions` | Conversions in last 30 min |

## Notes

- Realtime API has a **separate endpoint**: `:runRealtimeReport`
- Data covers the **last 30 minutes** (not configurable)
- May have **1-2 minute delay** from actual activity
- Lower rate limits than standard reporting API
- Use sparingly for dashboards (cache for 1-2 minutes)
