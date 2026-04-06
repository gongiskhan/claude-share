---
name: fixer-io
description: Use this integration when users need foreign exchange rates, currency conversion, or historical currency data. Supports real-time rates, currency conversion, historical rates, time series data, and listing available currencies.
---

# Fixer.io Currency Exchange

Provides real-time and historical foreign exchange rates, currency conversion, and comprehensive currency data powered by Fixer.io.

## Security Model
All actions are executed through the Maestric Integration Proxy. API credentials are stored encrypted on the server and never exposed to agents. The proxy handles authentication automatically.

## Available Actions

### get_latest_rates
Retrieves the latest real-time exchange rates for all or specific currencies.

**Arguments:**
- `base` (string, optional): Base currency code (e.g., "USD", "EUR"). Defaults to configured default currency.
- `symbols` (string, optional): Comma-separated list of currency codes to limit results (e.g., "USD,GBP,JPY")

**Example:**