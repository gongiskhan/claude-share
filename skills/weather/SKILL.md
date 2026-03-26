# Weather Skill

Get current weather and forecasts for any location.

## Purpose
Retrieve weather information including current conditions, temperature, and forecasts.

## Invocation
When the user asks about weather, temperature, or forecasts for a location.

### Trigger Patterns
- "What's the weather in [location]?"
- "Is it raining in [location]?"
- "Temperature in [location]"
- "Weather forecast for [location]"

## How to Use

### Tool Call Pattern
```
tool: web_fetch
url: https://wttr.in/{location}?format=j1
```

### Response Format
Extract from the JSON response:
- `current_condition[0].temp_C` - Current temperature in Celsius
- `current_condition[0].weatherDesc[0].value` - Weather description
- `current_condition[0].humidity` - Humidity percentage
- `current_condition[0].windspeedKmph` - Wind speed

### Example

**User:** What's the weather in Lisbon?

**Skill Execution:**
1. Call wttr.in API: `https://wttr.in/Lisbon?format=j1`
2. Parse JSON response
3. Format human-readable response

**Response:** 
The weather in Lisbon is currently 18°C and partly cloudy. Humidity is at 65% with winds of 15 km/h.

## Notes
- wttr.in is a free weather API that requires no API key
- Supports city names, coordinates, or airport codes
- For forecast, use `weather[0-2]` from the response (today, tomorrow, day after)
