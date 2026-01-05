# Database Cleanup - Clear Sensor Data

## Clear All Sensor Data

**WARNING:** This will delete ALL sensor data from the database. Make sure you want to do this!

### Option 1: Delete All Data (Complete Cleanup)

```bash
# Connect to database
psql -h localhost -U compost_user -d compost_db

# Run the delete command
DELETE FROM sensor_data;

# Verify deletion
SELECT COUNT(*) as remaining_records FROM sensor_data;

# Exit
\q
```

### Option 2: Delete Data Older Than Specific Date (Safer)

```bash
# Connect to database
psql -h localhost -U compost_user -d compost_db

# Delete data older than January 5, 2026 (GMT+8)
DELETE FROM sensor_data WHERE timestamp < '2026-01-05 00:00:00+08';

# Or delete data older than 7 days
DELETE FROM sensor_data WHERE timestamp < NOW() - INTERVAL '7 days';

# Verify deletion
SELECT COUNT(*) as remaining_records FROM sensor_data;
SELECT MIN(timestamp) as oldest_record, MAX(timestamp) as newest_record FROM sensor_data;

# Exit
\q
```

### Option 3: Reset Sequence (Start IDs from 1)

```bash
# Connect to database
psql -h localhost -U compost_user -d compost_db

# Delete all data
DELETE FROM sensor_data;

# Reset the sequence counter
ALTER SEQUENCE sensor_data_id_seq RESTART WITH 1;

# Verify
SELECT COUNT(*) FROM sensor_data;
\q
```

### Option 4: Using SQL File

```bash
# Copy the SQL file to server (if needed)
# scp cloud/CLEAR_SENSOR_DATA.sql mrchongyijian@34.87.144.95:/opt/compost-backend/

# On server
cd /opt/compost-backend
psql -h localhost -U compost_user -d compost_db -f CLEAR_SENSOR_DATA.sql
```

---

## Check Current Data

Before deleting, check what data you have:

```bash
psql -h localhost -U compost_user -d compost_db

# Count total records
SELECT COUNT(*) as total_records FROM sensor_data;

# View date range
SELECT
    MIN(timestamp) as oldest_record,
    MAX(timestamp) as newest_record,
    COUNT(*) as total_records
FROM sensor_data;

# View latest 10 records
SELECT id, timestamp, temperature, humidity
FROM sensor_data
ORDER BY timestamp DESC
LIMIT 10;

# Check timezone of timestamps
SELECT
    timestamp,
    timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Singapore' as gmt8_time
FROM sensor_data
ORDER BY timestamp DESC
LIMIT 5;

\q
```

---

## After Cleanup

1. **Verify data is cleared:**

   ```bash
   psql -h localhost -U compost_user -d compost_db -c "SELECT COUNT(*) FROM sensor_data;"
   ```

2. **Restart services (if needed):**

   ```bash
   sudo systemctl restart compost-mqtt-listener
   sudo systemctl restart compost-api
   ```

3. **Monitor new data coming in:**

   ```bash
   # Watch MQTT listener logs
   sudo journalctl -u compost-mqtt-listener -f

   # Check database for new records
   watch -n 5 'psql -h localhost -U compost_user -d compost_db -c "SELECT COUNT(*) FROM sensor_data;"'
   ```

---

## Timezone Fix

The code has been updated to ensure all timestamps are stored and retrieved in GMT+8. After clearing the data, new data will be properly stored with GMT+8 timezone.

**Files updated:**

- `cloud/mqtt_listener.py` - Ensures timestamps are in GMT+8 before saving
- `cloud/main.py` - Converts timestamps to GMT+8 when retrieving
