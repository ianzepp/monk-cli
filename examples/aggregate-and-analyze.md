# Aggregate and Analyze: Statistical Queries and Data Summaries

Learn how to perform aggregation queries with `monk aggregate` to calculate statistics, generate summaries, and analyze your data with GROUP BY operations.

## Prerequisites
- Monk CLI configured and authenticated
- Schemas with data already created
- Basic understanding of JSON
- Familiarity with `monk find` for filtering (optional but helpful)

## Overview

The `monk aggregate` command enables:

1. **Statistical Functions** - COUNT, SUM, AVG, MIN, MAX, DISTINCT
2. **Filtering** - Same WHERE clauses as `monk find`
3. **Grouping** - GROUP BY one or more fields
4. **Combined Operations** - Multiple aggregations in a single query

Choose `monk aggregate` when you need:
- Summary statistics (totals, averages, counts)
- Grouped analysis (by category, date, status, etc.)
- Data analytics and reporting
- Dashboard metrics

## Basic Query Structure

```bash
echo '{
  "where": {
    // Optional filter conditions
  },
  "aggregate": {
    "result_name": { "$function": "field" }
  },
  "groupBy": ["field1", "field2"]
}' | monk aggregate <schema>
```

### Components
- **where** (optional): Filter conditions using Filter DSL
- **aggregate** (required): Named aggregation functions
- **groupBy** (optional): Fields to group results by

## Aggregation Functions

### $count - Count Records

Count all records:
```bash
echo '{
  "aggregate": {
    "total_users": { "$count": "*" }
  }
}' | monk aggregate users
```

Count non-null values in a field:
```bash
echo '{
  "aggregate": {
    "users_with_email": { "$count": "email" },
    "users_with_phone": { "$count": "phone" }
  }
}' | monk aggregate users
```

### $sum - Sum Numeric Values

Calculate total revenue:
```bash
echo '{
  "aggregate": {
    "total_revenue": { "$sum": "amount" }
  }
}' | monk aggregate orders
```

Multiple sums:
```bash
echo '{
  "aggregate": {
    "total_sales": { "$sum": "amount" },
    "total_quantity": { "$sum": "quantity" },
    "total_tax": { "$sum": "tax" }
  }
}' | monk aggregate orders
```

### $avg - Calculate Average

Average order value:
```bash
echo '{
  "aggregate": {
    "avg_order_value": { "$avg": "amount" }
  }
}' | monk aggregate orders
```

Multiple averages:
```bash
echo '{
  "aggregate": {
    "avg_age": { "$avg": "age" },
    "avg_salary": { "$avg": "salary" },
    "avg_rating": { "$avg": "rating" }
  }
}' | monk aggregate employees
```

### $min and $max - Find Extremes

Find minimum and maximum prices:
```bash
echo '{
  "aggregate": {
    "lowest_price": { "$min": "price" },
    "highest_price": { "$max": "price" }
  }
}' | monk aggregate products
```

Date ranges:
```bash
echo '{
  "aggregate": {
    "first_order": { "$min": "created_at" },
    "latest_order": { "$max": "created_at" }
  }
}' | monk aggregate orders
```

### $distinct - Count Unique Values

Count unique values:
```bash
echo '{
  "aggregate": {
    "unique_customers": { "$distinct": "customer_id" },
    "unique_products": { "$distinct": "product_id" },
    "unique_countries": { "$distinct": "country" }
  }
}' | monk aggregate orders
```

## Filtering with WHERE

### Simple Filters

Count active users:
```bash
echo '{
  "where": {
    "status": "active"
  },
  "aggregate": {
    "active_users": { "$count": "*" }
  }
}' | monk aggregate users
```

Calculate paid order total:
```bash
echo '{
  "where": {
    "status": "paid"
  },
  "aggregate": {
    "paid_orders": { "$count": "*" },
    "total_revenue": { "$sum": "amount" }
  }
}' | monk aggregate orders
```

### Complex Filters

Orders in date range:
```bash
echo '{
  "where": {
    "$and": [
      { "created_at": { "$gte": "2024-01-01" } },
      { "created_at": { "$lt": "2024-02-01" } }
    ]
  },
  "aggregate": {
    "january_orders": { "$count": "*" },
    "january_revenue": { "$sum": "amount" }
  }
}' | monk aggregate orders
```

High-value orders:
```bash
echo '{
  "where": {
    "amount": { "$gte": 1000 }
  },
  "aggregate": {
    "high_value_orders": { "$count": "*" },
    "total_value": { "$sum": "amount" },
    "avg_value": { "$avg": "amount" }
  }
}' | monk aggregate orders
```

## GROUP BY Operations

### Single Field Grouping

Revenue by country:
```bash
echo '{
  "aggregate": {
    "orders": { "$count": "*" },
    "revenue": { "$sum": "amount" },
    "avg_order": { "$avg": "amount" }
  },
  "groupBy": ["country"]
}' | monk aggregate orders
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "country": "US",
      "orders": 450,
      "revenue": 125000.50,
      "avg_order": 277.78
    },
    {
      "country": "UK",
      "orders": 230,
      "revenue": 67500.25,
      "avg_order": 293.48
    }
  ]
}
```

Users by role:
```bash
echo '{
  "aggregate": {
    "user_count": { "$count": "*" },
    "avg_age": { "$avg": "age" }
  },
  "groupBy": ["role"]
}' | monk aggregate users
```

### Multiple Field Grouping

Orders by country and status:
```bash
echo '{
  "aggregate": {
    "count": { "$count": "*" },
    "total": { "$sum": "amount" },
    "avg": { "$avg": "amount" }
  },
  "groupBy": ["country", "status"]
}' | monk aggregate orders
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "country": "US",
      "status": "paid",
      "count": 420,
      "total": 118500.00,
      "avg": 282.14
    },
    {
      "country": "US",
      "status": "pending",
      "count": 30,
      "total": 6500.50,
      "avg": 216.68
    }
  ]
}
```

### Grouping with Filters

Active users by department and role:
```bash
echo '{
  "where": {
    "status": "active"
  },
  "aggregate": {
    "users": { "$count": "*" },
    "avg_salary": { "$avg": "salary" }
  },
  "groupBy": ["department", "role"]
}' | monk aggregate users
```

## Practical Examples

### Example 1: Dashboard Metrics

Overall statistics:
```bash
echo '{
  "aggregate": {
    "total_users": { "$count": "*" },
    "active_users": { "$count": "last_login" },
    "avg_age": { "$avg": "age" },
    "unique_countries": { "$distinct": "country" },
    "unique_roles": { "$distinct": "role" }
  }
}' | monk aggregate users
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "total_users": 1523,
      "active_users": 1245,
      "avg_age": 34.5,
      "unique_countries": 42,
      "unique_roles": 5
    }
  ]
}
```

### Example 2: Sales Report

Daily sales summary:
```bash
echo '{
  "where": {
    "created_at": { "$gte": "2024-11-12" }
  },
  "aggregate": {
    "orders": { "$count": "*" },
    "revenue": { "$sum": "amount" },
    "avg_order": { "$avg": "amount" },
    "min_order": { "$min": "amount" },
    "max_order": { "$max": "amount" },
    "unique_customers": { "$distinct": "customer_id" }
  }
}' | monk aggregate orders
```

Sales by status:
```bash
echo '{
  "where": {
    "created_at": { "$gte": "2024-11-12" }
  },
  "aggregate": {
    "orders": { "$count": "*" },
    "revenue": { "$sum": "amount" }
  },
  "groupBy": ["status"]
}' | monk aggregate orders
```

### Example 3: Product Analytics

Products by category:
```bash
echo '{
  "aggregate": {
    "product_count": { "$count": "*" },
    "avg_price": { "$avg": "price" },
    "min_price": { "$min": "price" },
    "max_price": { "$max": "price" },
    "total_inventory": { "$sum": "stock_quantity" }
  },
  "groupBy": ["category"]
}' | monk aggregate products
```

In-stock products only:
```bash
echo '{
  "where": {
    "in_stock": true
  },
  "aggregate": {
    "available_products": { "$count": "*" },
    "total_value": { "$sum": "price" }
  },
  "groupBy": ["category"]
}' | monk aggregate products
```

### Example 4: User Engagement Analysis

Activity by role and country:
```bash
echo '{
  "where": {
    "last_login": { "$gte": "2024-01-01" }
  },
  "aggregate": {
    "active_users": { "$count": "*" },
    "total_logins": { "$sum": "login_count" },
    "avg_logins": { "$avg": "login_count" },
    "max_logins": { "$max": "login_count" }
  },
  "groupBy": ["role", "country"]
}' | monk aggregate users
```

### Example 5: Financial Analysis

Revenue by month and payment method:
```bash
echo '{
  "where": {
    "status": "paid",
    "created_at": { "$gte": "2024-01-01" }
  },
  "aggregate": {
    "transactions": { "$count": "*" },
    "total_amount": { "$sum": "amount" },
    "avg_transaction": { "$avg": "amount" }
  },
  "groupBy": ["payment_method"]
}' | monk aggregate orders
```

## Combining with jq for Enhanced Analysis

### Pretty Print Results
```bash
echo '{
  "aggregate": {
    "revenue": { "$sum": "amount" }
  },
  "groupBy": ["country"]
}' | monk aggregate orders | jq '.data'
```

### Sort Results
```bash
# Sort by revenue descending
echo '{
  "aggregate": {
    "revenue": { "$sum": "amount" }
  },
  "groupBy": ["country"]
}' | monk aggregate orders | jq '.data | sort_by(-.revenue)'
```

### Filter Results
```bash
# Show only countries with revenue > 50000
echo '{
  "aggregate": {
    "revenue": { "$sum": "amount" }
  },
  "groupBy": ["country"]
}' | monk aggregate orders | jq '.data | map(select(.revenue > 50000))'
```

### Calculate Percentages
```bash
# Calculate percentage of total
echo '{
  "aggregate": {
    "count": { "$count": "*" }
  },
  "groupBy": ["status"]
}' | monk aggregate orders | jq '
  .data as $data |
  ($data | map(.count) | add) as $total |
  $data | map(. + {percentage: ((.count / $total) * 100 | round)})
'
```

## Saving Complex Queries

Create reusable query files:

```bash
# sales-by-country.json
cat > sales-by-country.json << 'EOF'
{
  "where": {
    "status": "paid"
  },
  "aggregate": {
    "orders": { "$count": "*" },
    "revenue": { "$sum": "amount" },
    "avg_order": { "$avg": "amount" },
    "unique_customers": { "$distinct": "customer_id" }
  },
  "groupBy": ["country"]
}
EOF

# Use it
cat sales-by-country.json | monk aggregate orders
```

## Use Cases by Industry

### E-commerce
```bash
# Product performance
echo '{
  "aggregate": {
    "units_sold": { "$sum": "quantity" },
    "revenue": { "$sum": "total_price" }
  },
  "groupBy": ["product_id"]
}' | monk aggregate order_items

# Customer lifetime value
echo '{
  "aggregate": {
    "orders": { "$count": "*" },
    "total_spent": { "$sum": "amount" },
    "avg_order_value": { "$avg": "amount" }
  },
  "groupBy": ["customer_id"]
}' | monk aggregate orders
```

### SaaS
```bash
# User activity metrics
echo '{
  "aggregate": {
    "users": { "$count": "*" },
    "total_usage": { "$sum": "api_calls" },
    "avg_usage": { "$avg": "api_calls" }
  },
  "groupBy": ["plan_type"]
}' | monk aggregate users

# Churn analysis
echo '{
  "where": {
    "status": "cancelled"
  },
  "aggregate": {
    "churned_users": { "$count": "*" },
    "avg_lifetime_days": { "$avg": "lifetime_days" }
  },
  "groupBy": ["cancellation_reason"]
}' | monk aggregate subscriptions
```

### Content Platform
```bash
# Content engagement
echo '{
  "aggregate": {
    "posts": { "$count": "*" },
    "total_views": { "$sum": "view_count" },
    "avg_views": { "$avg": "view_count" }
  },
  "groupBy": ["category"]
}' | monk aggregate posts

# Author statistics
echo '{
  "where": {
    "status": "published"
  },
  "aggregate": {
    "posts": { "$count": "*" },
    "total_views": { "$sum": "view_count" }
  },
  "groupBy": ["author_id"]
}' | monk aggregate posts
```

## Tips and Best Practices

### Start Simple
Begin with basic aggregations and add complexity:
```bash
# Step 1: Simple count
echo '{"aggregate": {"total": {"$count": "*"}}}' | monk aggregate orders

# Step 2: Add filter
echo '{
  "where": {"status": "paid"},
  "aggregate": {"total": {"$count": "*"}}
}' | monk aggregate orders

# Step 3: Add grouping
echo '{
  "where": {"status": "paid"},
  "aggregate": {"total": {"$count": "*"}},
  "groupBy": ["country"]
}' | monk aggregate orders

# Step 4: Multiple aggregations
echo '{
  "where": {"status": "paid"},
  "aggregate": {
    "orders": {"$count": "*"},
    "revenue": {"$sum": "amount"}
  },
  "groupBy": ["country"]
}' | monk aggregate orders
```

### Name Results Meaningfully
Use descriptive names for aggregation results:
```bash
# Good
{
  "aggregate": {
    "total_revenue": { "$sum": "amount" },
    "avg_order_value": { "$avg": "amount" }
  }
}

# Less clear
{
  "aggregate": {
    "sum1": { "$sum": "amount" },
    "avg1": { "$avg": "amount" }
  }
}
```

### Validate JSON First
```bash
# Test JSON syntax
echo '{
  "aggregate": {
    "total": { "$sum": "amount" }
  }
}' | jq .

# Then use in query
```

### Use WHERE Clauses Effectively
Filter data before aggregation for better performance:
```bash
# Filter first, then aggregate
echo '{
  "where": {
    "$and": [
      {"status": "paid"},
      {"created_at": {"$gte": "2024-01-01"}}
    ]
  },
  "aggregate": {
    "revenue": {"$sum": "amount"}
  }
}' | monk aggregate orders
```

## Troubleshooting

### No Results
```bash
# Verify data exists
monk data list orders

# Try without filter
echo '{"aggregate": {"total": {"$count": "*"}}}' | monk aggregate orders

# Check filter conditions
echo '{"where": {"status": "paid"}}' | monk find orders
```

### Unexpected Values
```bash
# Check for null values
echo '{
  "aggregate": {
    "all_records": {"$count": "*"},
    "non_null_amounts": {"$count": "amount"}
  }
}' | monk aggregate orders

# Verify data types
monk data list orders | jq '.[0]'
```

### JSON Syntax Errors
```bash
# Validate JSON
echo '{"aggregate": {"total": {"$count": "*"}}}' | jq empty

# Common issues: trailing commas, missing quotes, unmatched braces
```

## Next Steps

- `monk examples find-and-filter` - Learn advanced filtering
- `monk examples describe-and-data` - Schema and data management
- `monk docs aggregate` - Complete Aggregate API reference
- `monk docs find` - Filter DSL reference

## Related Commands

```bash
monk find <schema>              # Advanced search with filtering
monk data list <schema>         # List records
monk describe select <schema>   # View schema definition
```

Master aggregations to unlock powerful data analytics and reporting capabilities!
