---
name: newsapi
description: Use this integration to fetch news headlines and articles from NewsAPI. Good for getting current news, top headlines by country, and searching for news on specific topics.
---

# NewsAPI

Fetch the latest news headlines and articles from NewsAPI.org. This integration provides access to breaking news and top headlines from news sources and blogs across the web.

## Security Model

All actions are executed through the Maestric Integration Proxy. Your API key is stored encrypted on the server and is never exposed to agents. When you call an action, the proxy handles authentication automatically.

## Available Actions

### get_top_headlines

Fetches the top headlines for the United States from major news sources.

**Arguments:**
- None required (defaults to US headlines)

**Returns:**
- `status` (string): Response status ("ok" or "error")
- `totalResults` (number): Total number of results available
- `articles` (array): List of article objects containing:
  - `source`: News source information
  - `author`: Article author
  - `title`: Article headline
  - `description`: Brief description
  - `url`: Link to full article
  - `urlToImage`: Featured image URL
  - `publishedAt`: Publication timestamp
  - `content`: Truncated article content

**Example:**