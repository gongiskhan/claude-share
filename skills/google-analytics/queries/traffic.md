# Traffic Query

Get session counts, users, page views, and engagement metrics for a date range.

## Description

Returns core traffic metrics:
- **Sessions** - Total visits
- **Users** - Unique visitors  
- **Page Views** - Total pages viewed
- **Avg. Session Duration** - Time spent on site
- **Bounce Rate** - Single-page sessions
- **New Users** - First-time visitors

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `startDate` | string | `7daysAgo` | Start date (YYYY-MM-DD or relative) |
| `endDate` | string | `today` | End date (YYYY-MM-DD or relative) |
| `dimensions` | array | `[]` | Optional: `date`, `country`, `deviceCategory` |

### Relative Date Values
- `today`, `yesterday`
- `NdaysAgo` (e.g., `7daysAgo`, `30daysAgo`)
- `YYYY-MM-DD` (e.g., `2026-01-01`)

## GA4 API Request

```json
{
  "dateRanges": [
    {
      "startDate": "{{startDate}}",
      "endDate": "{{endDate}}"
    }
  ],
  "metrics": [
    {"name": "sessions"},
    {"name": "totalUsers"},
    {"name": "screenPageViews"},
    {"name": "averageSessionDuration"},
    {"name": "bounceRate"},
    {"name": "newUsers"}
  ]
}
```

### With Daily Breakdown

```json
{
  "dateRanges": [
    {
      "startDate": "{{startDate}}",
      "endDate": "{{endDate}}"
    }
  ],
  "dimensions": [
    {"name": "date"}
  ],
  "metrics": [
    {"name": "sessions"},
    {"name": "totalUsers"},
    {"name": "screenPageViews"}
  ],
  "orderBys": [
    {"dimension": {"dimensionName": "date"}}
  ]
}
```

## Python Implementation

```python
import json
import os
from google.oauth2 import service_account
from google.analytics.data_v1beta import BetaAnalyticsDataClient
from google.analytics.data_v1beta.types import (
    RunReportRequest, DateRange, Metric, Dimension, OrderBy
)

def get_traffic(start_date="7daysAgo", end_date="today", by_day=False):
    """Get traffic metrics for date range."""
    
    # Load config
    config_path = os.path.expanduser("~/.ekoa/integrations/google-analytics.json")
    with open(config_path) as f:
        config = json.load(f)
    
    # Authenticate
    creds = service_account.Credentials.from_service_account_info(
        config['credentials']['serviceAccountKey'],
        scopes=['https://www.googleapis.com/auth/analytics.readonly']
    )
    
    client = BetaAnalyticsDataClient(credentials=creds)
    
    # Build request
    request = RunReportRequest(
        property=f"properties/{config['propertyId']}",
        date_ranges=[DateRange(start_date=start_date, end_date=end_date)],
        metrics=[
            Metric(name="sessions"),
            Metric(name="totalUsers"),
            Metric(name="screenPageViews"),
            Metric(name="averageSessionDuration"),
            Metric(name="bounceRate"),
            Metric(name="newUsers"),
        ]
    )
    
    if by_day:
        request.dimensions = [Dimension(name="date")]
        request.order_bys = [OrderBy(dimension=OrderBy.DimensionOrderBy(dimension_name="date"))]
    
    # Execute
    response = client.run_report(request)
    
    return response

def format_traffic_response(response, by_day=False):
    """Format response for human display."""
    
    if not response.rows:
        return "No data available for this period."
    
    if by_day:
        lines = ["📊 **Daily Traffic**\n"]
        lines.append("| Date | Sessions | Users | Page Views |")
        lines.append("|------|----------|-------|------------|")
        for row in response.rows:
            date = row.dimension_values[0].value
            formatted_date = f"{date[:4]}-{date[4:6]}-{date[6:]}"
            sessions = row.metric_values[0].value
            users = row.metric_values[1].value
            pageviews = row.metric_values[2].value
            lines.append(f"| {formatted_date} | {sessions} | {users} | {pageviews} |")
        return "\n".join(lines)
    else:
        row = response.rows[0]
        sessions = int(row.metric_values[0].value)
        users = int(row.metric_values[1].value)
        pageviews = int(row.metric_values[2].value)
        avg_duration = float(row.metric_values[3].value)
        bounce_rate = float(row.metric_values[4].value) * 100
        new_users = int(row.metric_values[5].value)
        
        minutes = int(avg_duration // 60)
        seconds = int(avg_duration % 60)
        
        return f"""📊 **Traffic Summary**

- **Sessions:** {sessions:,}
- **Users:** {users:,} ({new_users:,} new)
- **Page Views:** {pageviews:,}
- **Avg. Session Duration:** {minutes}m {seconds}s
- **Bounce Rate:** {bounce_rate:.1f}%
"""

# Usage
if __name__ == "__main__":
    response = get_traffic("yesterday", "yesterday")
    print(format_traffic_response(response))
```

## curl Implementation

```bash
#!/bin/bash
# Get traffic metrics via curl

CONFIG_FILE="$HOME/.ekoa/integrations/google-analytics.json"
START_DATE="${1:-7daysAgo}"
END_DATE="${2:-today}"

# Get property ID
PROPERTY_ID=$(jq -r '.propertyId' "$CONFIG_FILE")

# Get access token (requires google-auth Python package)
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

# Make API request
curl -s "https://analyticsdata.googleapis.com/v1beta/properties/${PROPERTY_ID}:runReport" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"dateRanges\": [{\"startDate\": \"$START_DATE\", \"endDate\": \"$END_DATE\"}],
    \"metrics\": [
      {\"name\": \"sessions\"},
      {\"name\": \"totalUsers\"},
      {\"name\": \"screenPageViews\"},
      {\"name\": \"averageSessionDuration\"},
      {\"name\": \"bounceRate\"}
    ]
  }" | jq '.rows[0].metricValues | {
    sessions: .[0].value,
    users: .[1].value,
    pageViews: .[2].value,
    avgDuration: .[3].value,
    bounceRate: .[4].value
  }'
```

## Response Parsing

### Raw API Response
```json
{
  "dimensionHeaders": [],
  "metricHeaders": [
    {"name": "sessions", "type": "TYPE_INTEGER"},
    {"name": "totalUsers", "type": "TYPE_INTEGER"},
    {"name": "screenPageViews", "type": "TYPE_INTEGER"},
    {"name": "averageSessionDuration", "type": "TYPE_SECONDS"},
    {"name": "bounceRate", "type": "TYPE_FLOAT"},
    {"name": "newUsers", "type": "TYPE_INTEGER"}
  ],
  "rows": [{
    "dimensionValues": [],
    "metricValues": [
      {"value": "1234"},
      {"value": "987"},
      {"value": "3456"},
      {"value": "154.5"},
      {"value": "0.423"},
      {"value": "456"}
    ]
  }],
  "rowCount": 1
}
```

## Human-Friendly Output

**For chat/messaging:**
```
📊 Yesterday's Traffic (Feb 3, 2026)

• Sessions: 1,234
• Users: 987 (456 new)
• Page Views: 3,456
• Avg. Session Duration: 2m 34s
• Bounce Rate: 42.3%
```

**For voice/TTS:**
> Yesterday you had twelve hundred thirty four sessions from nine hundred eighty seven users. That's four hundred fifty six new visitors. People viewed thirty four hundred fifty six pages and spent about two and a half minutes on average. Your bounce rate was forty two percent.

## Common Date Ranges

| Request | startDate | endDate |
|---------|-----------|---------|
| Yesterday | `yesterday` | `yesterday` |
| Last 7 days | `7daysAgo` | `today` |
| Last 30 days | `30daysAgo` | `today` |
| This month | `2026-02-01` | `today` |
| Last month | `2026-01-01` | `2026-01-31` |
