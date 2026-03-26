# Top Pages Query

Get the most viewed pages on your website.

## Description

Returns pages ranked by views with:
- **Page Path** - URL path (e.g., `/blog/my-post`)
- **Page Title** - HTML title
- **Views** - Total page views
- **Users** - Unique viewers
- **Avg. Time on Page** - Engagement duration

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `startDate` | string | `7daysAgo` | Start date |
| `endDate` | string | `today` | End date |
| `limit` | integer | `10` | Number of pages to return |
| `orderBy` | string | `screenPageViews` | Sort metric |

## GA4 API Request

```json
{
  "dateRanges": [
    {
      "startDate": "{{startDate}}",
      "endDate": "{{endDate}}"
    }
  ],
  "dimensions": [
    {"name": "pagePath"},
    {"name": "pageTitle"}
  ],
  "metrics": [
    {"name": "screenPageViews"},
    {"name": "totalUsers"},
    {"name": "averageSessionDuration"},
    {"name": "bounceRate"}
  ],
  "orderBys": [
    {
      "metric": {"metricName": "screenPageViews"},
      "desc": true
    }
  ],
  "limit": {{limit}}
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

def get_top_pages(start_date="7daysAgo", end_date="today", limit=10):
    """Get top pages by views."""
    
    config_path = os.path.expanduser("~/.ekoa/integrations/google-analytics.json")
    with open(config_path) as f:
        config = json.load(f)
    
    creds = service_account.Credentials.from_service_account_info(
        config['credentials']['serviceAccountKey'],
        scopes=['https://www.googleapis.com/auth/analytics.readonly']
    )
    
    client = BetaAnalyticsDataClient(credentials=creds)
    
    request = RunReportRequest(
        property=f"properties/{config['propertyId']}",
        date_ranges=[DateRange(start_date=start_date, end_date=end_date)],
        dimensions=[
            Dimension(name="pagePath"),
            Dimension(name="pageTitle"),
        ],
        metrics=[
            Metric(name="screenPageViews"),
            Metric(name="totalUsers"),
            Metric(name="averageSessionDuration"),
            Metric(name="bounceRate"),
        ],
        order_bys=[
            OrderBy(
                metric=OrderBy.MetricOrderBy(metric_name="screenPageViews"),
                desc=True
            )
        ],
        limit=limit
    )
    
    return client.run_report(request)

def format_top_pages(response, limit=10):
    """Format as human-readable list."""
    
    if not response.rows:
        return "No page data available for this period."
    
    lines = [f"📄 **Top {min(len(response.rows), limit)} Pages**\n"]
    
    for i, row in enumerate(response.rows[:limit], 1):
        path = row.dimension_values[0].value
        title = row.dimension_values[1].value or path
        views = int(row.metric_values[0].value)
        users = int(row.metric_values[1].value)
        
        # Truncate title if too long
        if len(title) > 50:
            title = title[:47] + "..."
        
        lines.append(f"{i}. **{title}**")
        lines.append(f"   `{path}` — {views:,} views, {users:,} users")
    
    return "\n".join(lines)

# Usage
if __name__ == "__main__":
    response = get_top_pages("30daysAgo", "today", 10)
    print(format_top_pages(response))
```

## curl Implementation

```bash
#!/bin/bash

CONFIG_FILE="$HOME/.ekoa/integrations/google-analytics.json"
START_DATE="${1:-7daysAgo}"
END_DATE="${2:-today}"
LIMIT="${3:-10}"

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

curl -s "https://analyticsdata.googleapis.com/v1beta/properties/${PROPERTY_ID}:runReport" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"dateRanges\": [{\"startDate\": \"$START_DATE\", \"endDate\": \"$END_DATE\"}],
    \"dimensions\": [
      {\"name\": \"pagePath\"},
      {\"name\": \"pageTitle\"}
    ],
    \"metrics\": [
      {\"name\": \"screenPageViews\"},
      {\"name\": \"totalUsers\"}
    ],
    \"orderBys\": [{\"metric\": {\"metricName\": \"screenPageViews\"}, \"desc\": true}],
    \"limit\": $LIMIT
  }" | jq -r '.rows[] | "\(.dimensionValues[0].value) | \(.metricValues[0].value) views"'
```

## Response Parsing

### Raw API Response
```json
{
  "dimensionHeaders": [
    {"name": "pagePath"},
    {"name": "pageTitle"}
  ],
  "metricHeaders": [
    {"name": "screenPageViews", "type": "TYPE_INTEGER"},
    {"name": "totalUsers", "type": "TYPE_INTEGER"}
  ],
  "rows": [
    {
      "dimensionValues": [
        {"value": "/"},
        {"value": "Home - My Website"}
      ],
      "metricValues": [
        {"value": "5432"},
        {"value": "3210"}
      ]
    },
    {
      "dimensionValues": [
        {"value": "/blog/popular-post"},
        {"value": "My Popular Blog Post"}
      ],
      "metricValues": [
        {"value": "2345"},
        {"value": "1890"}
      ]
    }
  ]
}
```

## Human-Friendly Output

**For chat (no markdown tables for WhatsApp):**
```
📄 Top 5 Pages (Last 7 Days)

1. Home - My Website
   / — 5,432 views, 3,210 users

2. My Popular Blog Post
   /blog/popular-post — 2,345 views, 1,890 users

3. About Us
   /about — 1,234 views, 987 users

4. Contact
   /contact — 876 views, 654 users

5. Products
   /products — 765 views, 543 users
```

**For voice/TTS:**
> Your top page is your homepage with over five thousand views. Second is your blog post "My Popular Blog Post" with about twenty three hundred views. Third is your About page with twelve hundred views.

## Variations

### Top Landing Pages (entry pages)
```json
{
  "dimensions": [{"name": "landingPage"}],
  "metrics": [{"name": "sessions"}, {"name": "bounceRate"}]
}
```

### Top Exit Pages
```json
{
  "dimensions": [{"name": "pagePath"}],
  "metrics": [{"name": "exits"}, {"name": "screenPageViews"}]
}
```

### Pages by Engagement
```json
{
  "dimensions": [{"name": "pagePath"}],
  "metrics": [{"name": "engagementRate"}, {"name": "screenPageViews"}],
  "orderBys": [{"metric": {"metricName": "engagementRate"}, "desc": true}],
  "metricFilter": {
    "filter": {
      "fieldName": "screenPageViews",
      "numericFilter": {"operation": "GREATER_THAN", "value": {"int64Value": "100"}}
    }
  }
}
```
