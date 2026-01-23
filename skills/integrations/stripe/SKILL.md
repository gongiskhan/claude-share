---
name: stripe
description: Use this integration when users need to manage payments, customers, subscriptions, invoices, refunds, products, prices, or checkout sessions through Stripe. Covers billing operations, subscription lifecycle management, and e-commerce checkout flows.
---

# Stripe

Comprehensive payment processing and billing integration with Stripe. Manage customers, payments, subscriptions, invoices, refunds, products, prices, and checkout sessions.

## Security Model
All actions are executed through the Maestric Integration Proxy. API keys are stored encrypted on the server and never exposed to the LLM. The proxy injects credentials at execution time.

## Available Actions

### Customers

#### list_customers
Retrieve a list of customers from your Stripe account.
**Arguments:**
- `limit` (integer, optional): Maximum number of customers to return (1-100, default 10)
- `email` (string, optional): Filter by exact email match
- `starting_after` (string, optional): Cursor for pagination (customer ID)
**Example:**