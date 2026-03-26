# Period Comparison Query

Compare metrics between two time periods (week-over-week, month-over-month, etc.)

## Description

Compares key metrics across two date ranges:
- Current vs Previous period
- % change for each metric
- Trend indicators (📈 up, 📉 down, ➡️ stable)

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `currentStart` | string | `7daysAgo` | Current period start |
| `currentEnd` | string | `yesterday` | Current period end |
| `previousStart` | string | `14daysAgo` | Previous period start |
| `previousEnd` | string | `8daysAgo` | Previous period end |

### Common Comparison Patterns

| Comparison | Current | Previous |
|------------|---------|----------|
| Week-over-week | `7daysAgo` → `yesterday` | `14daysAgo` → `8daysAgo` |
| Month-over-month | `30daysAgo` → `yesterday` | `60daysAgo` → `31daysAgo` |
| This week vs last week | `monday` → `today` | Use specific dates |

## GA4 API Request

```json
{
  "dateRanges": [
    {
      "startDate": "{{currentStart}}",
      "endDate": "{{currentEnd}}",
      "name": "current"
    },
    {
      "startDate": "{{previousStart}}",
      "endDate": "{{previousEnd}}",
      "name": "previous"
    }
  ],
  "metrics": [
    {"name": "sessions"},
    {"name": "totalUsers"},
    {"name": "screenPageViews"},
    {"name": "averageSessionDuration"},
    {"name": "bounceRate"},
    {"name": "conversions"}
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
    RunReportRequest, DateRange, Metric
)

def compare_periods(
    current_start="7daysAgo", current_end="yesterday",
    previous_start="14daysAgo", previous_end="8daysAgo"
):
    """Compare two time periods."""
    
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
        date_ranges=[
            DateRange(start_date=current_start, end_date=current_end, name="current"),
            DateRange(start_date=previous_start, end_date=previous_end, name="previous"),
        ],
        metrics=[
            Metric(name="sessions"),
            Metric(name="totalUsers"),
            Metric(name="screenPageViews"),
            Metric(name="averageSessionDuration"),
            Metric(name="bounceRate"),
        ]
    )
    
    return client.run_report(request)

def calculate_change(current, previous):
    """Calculate percentage change."""
    if previous == 0:
        return float('inf') if current > 0 else 0
    return ((current - previous) / previous) * 100

def trend_indicator(pct_change, inverse=False):
    """Get trend emoji. inverse=True for metrics where down is good (bounce rate)."""
    if abs(pct_change) < 2:
        return "➡️"
    if inverse:
        return "📈" if pct_change < 0 else "📉"
    return "📈" if pct_change > 0 else "📉"

def format_comparison(response):
    """Format comparison for display."""
    
    if len(response.rows) < 2:
        return "Insufficient data for comparison."
    
    # GA4 returns one row per date range
    current = response.rows[0].metric_values
    previous = response.rows[1].metric_values if len(response.rows) > 1 else None
    
    if not previous:
        return "No previous period data available."
    
    metrics = [
        ("Sessions", 0, False),
        ("Users", 1, False),
        ("Page Views", 2, False),
        ("Avg. Duration", 3, False),
        ("Bounce Rate", 4, True),  # inverse - lower is better
    ]
    
    lines = ["📊 **Week-over-Week Comparison**\n"]
    lines.append("| Metric | This Week | Last Week | Change |")
    lines.append("|--------|-----------|-----------|--------|")
    
    for name, idx, inverse in metrics:
        curr_val = float(current[idx].value)
        prev_val = float(previous[idx].value)
        pct = calculate_change(curr_val, prev_val)
        trend = trend_indicator(pct, inverse)
        
        # Format based on metric type
        if idx == 3:  # duration in seconds
            curr_str = f"{int(curr_val//60)}m {int(curr_val%60)}s"
            prev_str = f"{int(prev_val//60)}m {int(prev_val%60)}s"
        elif idx == 4:  # bounce rate
            curr_str = f"{curr_val*100:.1f}%"
            prev_str = f"{prev_val*100:.1f}%"
        else:
            curr_str = f"{int(curr_val):,}"
            prev_str = f"{int(prev_val):,}"
        
        pct_str = f"+{pct:.1f}%" if pct > 0 else f"{pct:.1f}%"
        lines.append(f"| {name} | {curr_str} | {prev_str} | {trend} {pct_str} |")
    
    return "\n".join(lines)

def format_comparison_chat(response):
    """Format for chat (no tables)."""
    
    if len(response.rows) < 2:
        return "Insufficient data for comparison."
    
    current = response.rows[0].metric_values
    previous = response.rows[1].metric_values
    
    def calc(idx):
        c, p = float(current[idx].value), float(previous[idx].value)
        return c, p, calculate_change(c, p)
    
    sessions_c, sessions_p, sessions_pct = calc(0)
    users_c, users_p, users_pct = calc(1)
    views_c, views_p, views_pct = calc(2)
    
    def arrow(pct, inverse=False):
        if abs(pct) < 2: return "→"
        if inverse: return "↑" if pct < 0 else "↓"
        return "↑" if pct > 0 else "↓"
    
    lines = ["📊 **Week-over-Week**\n"]
    lines.append(f"• Sessions: {int(sessions_c):,} {arrow(sessions_pct)} {sessions_pct:+.1f}%")
    lines.append(f"• Users: {int(users_c):,} {arrow(users_pct)} {users_pct:+.1f}%")
    lines.append(f"• Page Views: {int(views_c):,} {arrow(views_pct)} {views_pct:+.1f}%")
    
    return "\n".join(lines)

# Usage
if __name__ == "__main__":
    response = compare_periods()
    print(format_comparison_chat(response))
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

curl -s "https://analyticsdata.googleapis.com/v1beta/properties/${PROPERTY_ID}:runReport" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "dateRanges": [
      {"startDate": "7daysAgo", "endDate": "yesterday", "name": "current"},
      {"startDate": "14daysAgo", "endDate": "8daysAgo", "name": "previous"}
    ],
    "metrics": [
      {"name": "sessions"},
      {"name": "totalUsers"},
      {"name": "screenPageViews"}
    ]
  }' | jq '{
    current: {
      sessions: .rows[0].metricValues[0].value,
      users: .rows[0].metricValues[1].value,
      pageViews: .rows[0].metricValues[2].value
    },
    previous: {
      sessions: .rows[1].metricValues[0].value,
      users: .rows[1].metricValues[1].value,
      pageViews: .rows[1].metricValues[2].value
    }
  }'
```

## Response Parsing

### Raw API Response
```json
{
  "metricHeaders": [
    {"name": "sessions", "type": "TYPE_INTEGER"},
    {"name": "totalUsers", "type": "TYPE_INTEGER"},
    {"name": "screenPageViews", "type": "TYPE_INTEGER"}
  ],
  "rows": [
    {
      "metricValues": [
        {"value": "1234"},
        {"value": "987"},
        {"value": "3456"}
      ]
    },
    {
      "metricValues": [
        {"value": "1100"},
        {"value": "890"},
        {"value": "3200"}
      ]
    }
  ],
  "rowCount": 2
}
```

## Human-Friendly Output

**For chat (no tables for WhatsApp):**
```
📊 Week-over-Week Comparison

• Sessions: 1,234 ↑ +12.2%
• Users: 987 ↑ +10.9%
• Page Views: 3,456 ↑ +8.0%
• Bounce Rate: 42.3% ↓ -3.5% (good!)
```

**For voice/TTS:**
> Compared to last week, you're doing great! Sessions are up twelve percent to twelve thirty four. Users increased eleven percent. Page views grew eight percent. And your bounce rate dropped three and a half percent, which is good!

## Advanced: Segment Comparison

Compare specific user segments:

```json
{
  "dateRanges": [{"startDate": "7daysAgo", "endDate": "yesterday"}],
  "dimensions": [{"name": "deviceCategory"}],
  "metrics": [
    {"name": "sessions"},
    {"name": "totalUsers"}
  ]
}
```

## Notes

- GA4 supports up to 4 date ranges per request
- Order of rows matches order of date ranges in request
- For month-over-month, account for different month lengths
- Consider comparing same days (e.g., Mon-Sun vs Mon-Sun)
