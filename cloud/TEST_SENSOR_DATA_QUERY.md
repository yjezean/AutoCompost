# Testing Sensor Data Query

## Quick Test Commands

### 1. Test the API directly

```bash
# On server
curl http://localhost:8000/api/v1/sensor-data?days=1

# Or with more days
curl http://localhost:8000/api/v1/sensor-data?days=30
```

### 2. Check API logs

```bash
# View recent API logs
sudo journalctl -u compost-api -n 50 --no-pager | grep -i "sensor\|data\|retrieved"
```

### 3. Test database query directly

```bash
# Connect to database
psql -h localhost -U compost_user -d compost_db

# Check what data exists
SELECT COUNT(*) as total FROM sensor_data;
SELECT MIN(timestamp) as oldest, MAX(timestamp) as newest FROM sensor_data;

# Test query similar to what API uses
SELECT timestamp, temperature, humidity
FROM sensor_data
ORDER BY timestamp DESC
LIMIT 10;

# Test with date range (current time in UTC)
SELECT timestamp, temperature, humidity
FROM sensor_data
WHERE timestamp >= NOW() - INTERVAL '1 day'
ORDER BY timestamp ASC;

# Exit
\q
```

### 4. Check timezone conversion

```bash
psql -h localhost -U compost_user -d compost_db -c "
SELECT
    timestamp as db_timestamp,
    timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Singapore' as gmt8_time,
    temperature,
    humidity
FROM sensor_data
ORDER BY timestamp DESC
LIMIT 5;
"
```

---

## Debugging Steps

1. **Check if data exists:**

   ```bash
   psql -h localhost -U compost_user -d compost_db -c "SELECT COUNT(*) FROM sensor_data;"
   ```

2. **Check date range:**

   ```bash
   psql -h localhost -U compost_user -d compost_db -c "
   SELECT
       MIN(timestamp) as oldest,
       MAX(timestamp) as newest,
       COUNT(*) as total
   FROM sensor_data;
   "
   ```

3. **Check API response:**

   ```bash
   curl -v http://localhost:8000/api/v1/sensor-data?days=1
   ```

4. **Check API logs for errors:**
   ```bash
   sudo journalctl -u compost-api -f
   # Then make a request in another terminal
   ```

---

## Temporary Fix: Query All Data

If the date filtering is the issue, you can temporarily modify the query to return all data:

```python
# In main.py, temporarily change the query to:
cursor.execute(
    """
    SELECT timestamp, temperature, humidity
    FROM sensor_data
    ORDER BY timestamp DESC
    LIMIT 1000
    """
)
```

This will return the latest 1000 records regardless of date.
