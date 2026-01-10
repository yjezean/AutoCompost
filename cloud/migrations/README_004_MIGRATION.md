# Migration 004: Mock Completed Cycles Analytics Data

## Overview

This migration inserts mock data for completed compost cycles and associated sensor data to enable analytics testing and visualization.

## Prerequisites

- PostgreSQL database is running
- Database user has appropriate permissions
- Previous migrations (001, 002, 003) have been applied

## Steps to Apply Migration

### 1. Clean Up Existing Mock Data (Optional but Recommended)

If you have existing mock data that you want to replace, run the cleanup script first:

```bash
psql -h localhost -U compost_user -d compost_db -f migrations/004_cleanup_mock_data.sql
```

**Note:** This will delete:

- All completed cycles
- Sensor data older than 1 day (to preserve real-time data)

### 2. Apply the Migration

Run the main migration script:

```bash
psql -h localhost -U compost_user -d compost_db -f migrations/004_insert_mock_completed_cycles.sql
```

### 3. Verify the Migration

After running the migration, verify the data was inserted correctly:

```sql
-- Check completed cycles
SELECT
  COUNT(*) as total_completed_cycles,
  AVG(EXTRACT(DAY FROM (projected_end_date - start_date))) as avg_days,
  SUM(green_waste_kg + brown_waste_kg) as total_waste_kg
FROM compost_batch
WHERE status = 'completed';

-- Check sensor data
SELECT
  COUNT(*) as total_sensor_records,
  AVG(temperature) as avg_temperature,
  AVG(humidity) as avg_humidity
FROM sensor_data
WHERE timestamp >= NOW() - INTERVAL '1 year';

-- Check monthly distribution
SELECT
  TO_CHAR(start_date, 'YYYY-MM') as month,
  COUNT(*) as cycles_count,
  SUM(green_waste_kg + brown_waste_kg) as total_waste_kg
FROM compost_batch
WHERE status = 'completed'
GROUP BY TO_CHAR(start_date, 'YYYY-MM')
ORDER BY month DESC;
```

## What This Migration Does

### 1. Inserts 10 Completed Cycles

- Distributed across the last 6 months
- All cycles have non-zero waste amounts (green + brown > 0)
- Varied batch sizes (small, medium, large)
- Realistic C:N ratios (27.0 - 27.8)

### 2. Generates Sensor Data

- Temperature readings every 6 hours for each cycle
- Humidity readings with 4 different patterns:
  - Pattern 1: High start, gradual decrease
  - Pattern 2: Low start, increases then stabilizes
  - Pattern 3: Stable with small variations
  - Pattern 4: High throughout with small dips
- Values are within realistic ranges:
  - Temperature: 20-70°C
  - Humidity: 35-85%

### 3. Features

- **No Zero Waste**: All cycles have meaningful waste amounts
- **Varied Patterns**: Different humidity and temperature patterns per cycle
- **Monthly Distribution**: Cycles spread across multiple months for trend analysis
- **Realistic Data**: Values follow composting process patterns

## Troubleshooting

### Error: "relation does not exist"

Make sure previous migrations have been applied:

```bash
psql -h localhost -U compost_user -d compost_db -c "\dt"
```

### Error: "permission denied"

Ensure the database user has INSERT permissions:

```sql
GRANT INSERT ON compost_batch TO compost_user;
GRANT INSERT ON sensor_data TO compost_user;
```

### No Data Appearing in Analytics

1. Check that cycles have `status = 'completed'`
2. Verify sensor data timestamps are within the last year
3. Ensure the API endpoint `/api/v1/analytics/completed-cycles` is working

## Rollback (If Needed)

To remove the mock data:

```bash
psql -h localhost -U compost_user -d compost_db -f migrations/004_cleanup_mock_data.sql
```

## Related Files

- `004_cleanup_mock_data.sql` - Cleanup script
- `004_insert_mock_completed_cycles.sql` - Main migration script
- `main.py` - API endpoint `/api/v1/analytics/completed-cycles`
- `cycle_analytics.dart` - Frontend model
- `completed_cycles_analytics_screen.dart` - Frontend UI
