# Google Analytics Integration

Query your website traffic, top pages, and visitor data directly from GA4.

## Purpose

This integration connects to Google Analytics 4 (GA4) to answer questions about your website's performance. It handles setup, authentication, and provides natural language queries for common analytics tasks.

## Invocation

Triggered when users ask about website traffic, page views, visitor counts, or explicitly mention Google Analytics.

### Trigger Patterns
- "Google Analytics setup" / "configure GA" / "connect analytics"
- "How many visits did I get [timeframe]?"
- "Top pages [timeframe]"
- "GA traffic report"
- "Current visitors on my site"
- "Website traffic [yesterday/this week/last month]"
- "Most viewed pages"
- "How is my website doing?"

## Configuration Detection

**Config file location:** `~/.ekoa/integrations/google-analytics.json`

### Pre-flight Check
```bash
# Check if configured
if [ -f ~/.ekoa/integrations/google-analytics.json ]; then
  jq -r '.configured // false' ~/.ekoa/integrations/google-analytics.json
fi
```

### Decision Tree

```
User mentions GA/analytics/traffic
    │
    ├─► Config exists AND configured=true
    │       └─► Route to appropriate query template
    │
    └─► Config missing OR configured=false
            └─► Trigger setup wizard (setup.md)
```

## Query Routing

| Intent | Template | Notes |
|--------|----------|-------|
| Traffic/visits/sessions | `queries/traffic.md` | Supports date ranges |
| Top/popular pages | `queries/top-pages.md` | Configurable limit |
| Current/realtime visitors | `queries/realtime.md` | Live data |
| Compare periods | `queries/comparison.md` | Week-over-week, etc. |
| Setup/configure | `setup.md` | Guided wizard |

## API Details

**API:** Google Analytics Data API v1 (GA4)
**Base URL:** `https://analyticsdata.googleapis.com/v1beta`
**Auth:** Service Account (preferred) or OAuth 2.0

### Required Scopes
- `https://www.googleapis.com/auth/analytics.readonly`

### Rate Limits
- 50,000 requests per day per project
- 10 concurrent requests

## Tool Call Pattern

### Check Configuration
```bash
cat ~/.ekoa/integrations/google-analytics.json 2>/dev/null | jq -r '.configured // "false"'
```

### Execute Query (Service Account)
```bash
# Get access token
ACCESS_TOKEN=$(cat ~/.ekoa/integrations/google-analytics.json | \
  jq -r '.credentials.serviceAccountKey' | \
  python3 -c "
import sys, json, time
from google.oauth2 import service_account
from google.auth.transport.requests import Request

key = json.load(sys.stdin)
creds = service_account.Credentials.from_service_account_info(
    key, scopes=['https://www.googleapis.com/auth/analytics.readonly']
)
creds.refresh(Request())
print(creds.token)
")

# Make API request
PROPERTY_ID=$(jq -r '.propertyId' ~/.ekoa/integrations/google-analytics.json)
curl -s "https://analyticsdata.googleapis.com/v1beta/properties/${PROPERTY_ID}:runReport" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d @request.json
```

## Example

**User:** "How many visits did I get yesterday?"

**Skill Execution:**
1. Check config: `~/.ekoa/integrations/google-analytics.json` exists ✓
2. Load `queries/traffic.md` template
3. Set date range: yesterday
4. Execute GA4 Data API request
5. Parse response and format

**Response:**
> 📊 **Yesterday's Traffic (Feb 3, 2026)**
> - **Sessions:** 1,234
> - **Users:** 987
> - **Page Views:** 3,456
> - **Avg. Session Duration:** 2m 34s
> - **Bounce Rate:** 42.3%

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| `PERMISSION_DENIED` | Service account lacks access | Add to GA4 property |
| `INVALID_ARGUMENT` | Bad property ID | Verify in GA4 admin |
| `QUOTA_EXCEEDED` | Daily limit hit | Wait 24h or upgrade |
| `UNAUTHENTICATED` | Token expired | Re-authenticate |

## Notes

- Uses **GA4 Data API** (not Universal Analytics)
- Service Account is recommended for server-side use
- Property ID format: `properties/XXXXXXXXX` (numeric ID from GA4)
- Realtime data may have ~2 minute delay
- Historical data available for 14 months (standard) or 50 months (360)
