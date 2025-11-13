# Aggregate API Documentation

The `monk aggregate` command performs aggregation queries with optional GROUP BY support, enabling statistical analysis and data summaries across your schemas.

## Command Usage

```bash
monk aggregate <schema>
```

The command reads a JSON aggregation query from stdin and returns aggregated results.

## Query Structure

```json
{
  "where": {
    "field": "value"
  },
  "aggregate": {
    "result_name": { "$function": "field" }
  },
  "groupBy": ["field1", "field2"]
}
```

### Components

- **where** (optional): Filter conditions using the same Filter DSL as `monk find`
- **aggregate** (required): Object mapping result names to aggregation functions
- **groupBy** (optional): Array of field names to group results by

## Aggregation Functions

### $count
Count records. Use "*" for all records or a field name for non-null values.

```json
{
  "aggregate": {
    "total_records": { "$count": "*" },
    "active_users": { "$count": "user_id" }
  }
}
```

### $sum
Sum numeric values across records.

```json
{
  "aggregate": {
    "total_revenue": { "$sum": "amount" },
    "total_quantity": { "$sum": "quantity" }
  }
}
```

### $avg
Calculate average of numeric values.

```json
{
  "aggregate": {
    "avg_order_value": { "$avg": "amount" },
    "avg_rating": { "$avg": "rating" }
  }
}
```

### $min
Find minimum value.

```json
{
  "aggregate": {
    "lowest_price": { "$min": "price" },
    "earliest_date": { "$min": "created_at" }
  }
}
```

### $max
Find maximum value.

```json
{
  "aggregate": {
    "highest_price": { "$max": "price" },
    "latest_date": { "$max": "updated_at" }
  }
}
```

### $distinct
Count distinct values.

```json
{
  "aggregate": {
    "unique_users": { "$distinct": "user_id" },
    "unique_countries": { "$distinct": "country" }
  }
}
```

## Examples

### Simple Count

Count all records in a schema:

```bash
echo '{"aggregate": {"total": {"$count": "*"}}}' | monk aggregate users
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "total": 1523
    }
  ]
}
```

### Multiple Aggregations with Filter

Calculate order statistics for paid orders:

```bash
echo '{
  "where": { "status": "paid" },
  "aggregate": {
    "order_count": { "$count": "*" },
    "total_revenue": { "$sum": "amount" },
    "avg_order": { "$avg": "amount" },
    "min_order": { "$min": "amount" },
    "max_order": { "$max": "amount" }
  }
}' | monk aggregate orders
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "order_count": 450,
      "total_revenue": 125000.50,
      "avg_order": 277.78,
      "min_order": 5.99,
      "max_order": 2499.99
    }
  ]
}
```

### Group By Single Field

Revenue by country:

```bash
echo '{
  "aggregate": {
    "orders": { "$count": "*" },
    "revenue": { "$sum": "amount" }
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
      "revenue": 125000.50
    },
    {
      "country": "UK",
      "orders": 230,
      "revenue": 67500.25
    },
    {
      "country": "CA",
      "orders": 180,
      "revenue": 52300.75
    }
  ]
}
```

### Group By Multiple Fields

Sales by country and status:

```bash
echo '{
  "where": {
    "created_at": { "$gte": "2024-01-01" }
  },
  "aggregate": {
    "order_count": { "$count": "*" },
    "total_sales": { "$sum": "amount" },
    "avg_sale": { "$avg": "amount" }
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
      "order_count": 420,
      "total_sales": 118500.00,
      "avg_sale": 282.14
    },
    {
      "country": "US",
      "status": "pending",
      "order_count": 30,
      "total_sales": 6500.50,
      "avg_sale": 216.68
    },
    {
      "country": "UK",
      "status": "paid",
      "order_count": 210,
      "total_sales": 63200.00,
      "avg_sale": 301.00
    }
  ]
}
```

### Complex Filter with Aggregation

Analyze user activity for active users created in the last year:

```bash
echo '{
  "where": {
    "$and": [
      { "status": "active" },
      { "created_at": { "$gte": "2024-01-01" } }
    ]
  },
  "aggregate": {
    "user_count": { "$count": "*" },
    "total_logins": { "$sum": "login_count" },
    "avg_logins": { "$avg": "login_count" },
    "unique_countries": { "$distinct": "country" }
  },
  "groupBy": ["role"]
}' | monk aggregate users
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "role": "admin",
      "user_count": 15,
      "total_logins": 2340,
      "avg_logins": 156.00,
      "unique_countries": 8
    },
    {
      "role": "user",
      "user_count": 1450,
      "total_logins": 45800,
      "avg_logins": 31.59,
      "unique_countries": 42
    }
  ]
}
```

## Using with Query Files

Store complex queries in JSON files:

```bash
# stats-by-country.json
{
  "where": {
    "created_at": { "$gte": "2024-01-01" }
  },
  "aggregate": {
    "orders": { "$count": "*" },
    "revenue": { "$sum": "amount" },
    "avg_order": { "$avg": "amount" },
    "unique_customers": { "$distinct": "customer_id" }
  },
  "groupBy": ["country"]
}
```

Execute:
```bash
cat stats-by-country.json | monk aggregate orders
```

## Combining with Other Commands

### Save Results to File
```bash
echo '{"aggregate": {"total": {"$sum": "amount"}}}' | monk aggregate orders > revenue.json
```

### Pretty Print Results
```bash
echo '{"aggregate": {"revenue": {"$sum": "amount"}}, "groupBy": ["month"]}' | \
  monk aggregate orders | jq '.data'
```

### Process Multiple Schemas
```bash
for schema in orders invoices payments; do
  echo "Revenue for $schema:"
  echo '{"aggregate": {"total": {"$sum": "amount"}}}' | monk aggregate $schema
done
```

## Filter DSL Support

The `where` clause supports the full Filter DSL from `monk find`:

- Comparison: `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`
- Arrays: `$in`, `$nin`, `$any`, `$nany`
- Pattern: `$like`, `$ilike`
- Logical: `$and`, `$or`, `$not`
- Range: `$between`

See `monk docs find` for complete Filter DSL documentation.

## Response Format

Success response:
```json
{
  "success": true,
  "data": [
    { "field": "value", "aggregation": 123 }
  ]
}
```

Error response:
```json
{
  "success": false,
  "error": "Error message"
}
```

## Common Use Cases

### Dashboard Statistics
```bash
echo '{
  "aggregate": {
    "total_users": { "$count": "*" },
    "active_users": { "$count": "last_login" },
    "unique_countries": { "$distinct": "country" }
  }
}' | monk aggregate users
```

### Daily Sales Report
```bash
echo '{
  "where": {
    "created_at": { "$gte": "2024-11-12" }
  },
  "aggregate": {
    "orders": { "$count": "*" },
    "revenue": { "$sum": "amount" },
    "avg_order": { "$avg": "amount" }
  },
  "groupBy": ["status"]
}' | monk aggregate orders
```

### User Engagement Analysis
```bash
echo '{
  "aggregate": {
    "users": { "$count": "*" },
    "total_logins": { "$sum": "login_count" },
    "avg_logins": { "$avg": "login_count" }
  },
  "groupBy": ["country", "role"]
}' | monk aggregate users
```

## See Also

- `monk find` - Advanced search with Filter DSL
- `monk data list` - List records with simple queries
- `monk docs aggregate` - View API documentation
- `monk examples` - Interactive examples and workflows
