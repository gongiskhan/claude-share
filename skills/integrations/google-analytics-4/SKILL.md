---
name: google-analytics-4
description: Use this integration to retrieve analytics data from Google Analytics 4 properties, including sessions, users, pageviews, traffic sources, and custom reports.
---

# Google Analytics 4 Integration

Query Google Analytics 4 data using the GA4 Data API. Retrieve metrics like sessions, users, pageviews, and dimensions like countries, traffic sources, and page paths.

## Security Model

All actions are executed through the Maestric Integration Proxy. Credentials (service account JSON) are stored encrypted on the server and never exposed to the LLM. The proxy decrypts credentials at execution time only.

## Available Actions

### run_report
Run a standard report with metrics and dimensions.

**Arguments:**
- `property_id` (string, required): GA4 property ID (numeric, e.g., "394264564")
- `start_date` (string, required): Start date in YYYY-MM-DD format or relative (e.g., "7daysAgo", "30daysAgo")
- `end_date` (string, required): End date in YYYY-MM-DD format or relative (e.g., "today", "yesterday")
- `metrics` (array, required): Metrics to retrieve (e.g., ["sessions", "totalUsers", "screenPageViews"])
- `dimensions` (array, optional): Dimensions to group by (e.g., ["country", "date", "pagePath"])
- `limit` (number, optional): Maximum rows to return (default: 100)

**Example:**
```
integration_execute("google-analytics-4", "run_report", {
  property_id: "394264564",
  start_date: "7daysAgo",
  end_date: "today",
  metrics: ["sessions", "totalUsers"],
  dimensions: ["date"]
})
```

### run_realtime_report
Get real-time active users and activity.

**Arguments:**
- `property_id` (string, required): GA4 property ID
- `metrics` (array, required): Realtime metrics (e.g., ["activeUsers"])
- `dimensions` (array, optional): Realtime dimensions (e.g., ["country", "deviceCategory"])

**Example:**
```
integration_execute("google-analytics-4", "run_realtime_report", {
  property_id: "394264564",
  metrics: ["activeUsers"],
  dimensions: ["country"]
})
```

## Configuration Requirements

- **Service Account JSON** (Required) [Secret]: The full JSON content of the Google Cloud service account key file. Create a service account in Google Cloud Console with Analytics Viewer role and download the JSON key.
- **Property ID** (Required): Your GA4 property ID (numeric). Found in Google Analytics Admin > Property Settings.

## Common Metrics

- `sessions` - Total sessions
- `totalUsers` - Total unique users
- `newUsers` - New users
- `activeUsers` - Active users (sessions with engagement)
- `screenPageViews` - Total page views
- `bounceRate` - Bounce rate percentage
- `averageSessionDuration` - Average session duration in seconds
- `engagementRate` - Engagement rate

## Common Dimensions

- `date` - Date in YYYYMMDD format
- `country` - User country
- `city` - User city
- `deviceCategory` - Device type (desktop, mobile, tablet)
- `sessionSource` - Traffic source
- `sessionMedium` - Traffic medium
- `pagePath` - Page URL path
- `pageTitle` - Page title

## Error Handling

- `ACCESS_DENIED`: Service account lacks Analytics Viewer role
- `NOT_CONFIGURED`: Admin has not configured credentials
- `INVALID_ARGUMENT`: Invalid property ID, metrics, or dimensions
- `QUOTA_EXCEEDED`: API quota limits reached
