# Database Migration Guide

This guide explains how to apply database migrations to your server.

## Migration File Location

### On Your Local Machine
Migrations are stored in: `cloud/migrations/`

### On Your Server
Copy migrations to: `/opt/compost-backend/migrations/`

## Step-by-Step Migration Process

### 1. Copy Migration File to Server

**From your local machine:**

```bash
# Copy the new migration file to server
scp cloud/migrations/003_optimization_settings.sql mrchongyijian@34.87.144.95:/opt/compost-backend/migrations/

# Or copy all migrations at once
scp cloud/migrations/*.sql mrchongyijian@34.87.144.95:/opt/compost-backend/migrations/
```

**Or if you're already on the server:**

```bash
# Create migrations directory if it doesn't exist
mkdir -p /opt/compost-backend/migrations

# Copy file (if you have it locally on server)
cp /path/to/003_optimization_settings.sql /opt/compost-backend/migrations/
```

### 2. Connect to Database

**SSH into your server first:**

```bash
ssh mrchongyijian@34.87.144.95
```

**Then connect to PostgreSQL:**

```bash
# Connect to database
psql -h localhost -U compost_user -d compost_db
```

**If prompted for password, enter:** `db1234`

### 3. Run the Migration

**Option A: Run migration from psql prompt**

```bash
# After connecting to psql
\i /opt/compost-backend/migrations/003_optimization_settings.sql
```

**Option B: Run migration directly from command line**

```bash
# Exit psql first (type \q), then run:
psql -h localhost -U compost_user -d compost_db -f /opt/compost-backend/migrations/003_optimization_settings.sql
```

**Option C: Run migration with password prompt**

```bash
PGPASSWORD=db1234 psql -h localhost -U compost_user -d compost_db -f /opt/compost-backend/migrations/003_optimization_settings.sql
```

### 4. Verify Migration Was Applied

**Check if table exists:**

```bash
psql -h localhost -U compost_user -d compost_db

# In psql prompt:
\dt system_settings

# Or check table structure:
\d system_settings

# Check if default value was inserted:
SELECT * FROM system_settings WHERE setting_key = 'optimization_enabled';

# Should show:
# id | setting_key          | setting_value | description                                    | updated_at
# ---+---------------------+---------------+-----------------------------------------------+------------
#  1 | optimization_enabled | true          | Automated temperature and humidity control... | 2026-01-06 ...
```

**Exit psql:**
```bash
\q
```

### 5. Restart Services (If Needed)

After running migrations, restart services to ensure they pick up the new schema:

```bash
# Restart API service (uses system_settings table)
sudo systemctl restart compost-api

# Restart MQTT listener (checks optimization status)
sudo systemctl restart compost-mqtt-listener

# Check status
sudo systemctl status compost-api
sudo systemctl status compost-mqtt-listener
```

## Complete Migration Command Sequence

**One-liner to copy and run migration:**

```bash
# From your local machine
scp cloud/migrations/003_optimization_settings.sql mrchongyijian@34.87.144.95:/opt/compost-backend/migrations/ && \
ssh mrchongyijian@34.87.144.95 "PGPASSWORD=db1234 psql -h localhost -U compost_user -d compost_db -f /opt/compost-backend/migrations/003_optimization_settings.sql"
```

**Or step by step on server:**

```bash
# 1. SSH into server
ssh mrchongyijian@34.87.144.95

# 2. Navigate to backend directory
cd /opt/compost-backend

# 3. Ensure migrations directory exists
mkdir -p migrations

# 4. Run migration
PGPASSWORD=db1234 psql -h localhost -U compost_user -d compost_db -f migrations/003_optimization_settings.sql

# 5. Verify
PGPASSWORD=db1234 psql -h localhost -U compost_user -d compost_db -c "SELECT * FROM system_settings WHERE setting_key = 'optimization_enabled';"

# 6. Restart services
sudo systemctl restart compost-api
sudo systemctl restart compost-mqtt-listener
```

## Check Migration Status

**List all tables (verify system_settings exists):**

```bash
psql -h localhost -U compost_user -d compost_db -c "\dt"
```

**Check system_settings table:**

```bash
psql -h localhost -U compost_user -d compost_db -c "SELECT setting_key, setting_value, description FROM system_settings;"
```

**Check if optimization is enabled:**

```bash
psql -h localhost -U compost_user -d compost_db -c "SELECT setting_value FROM system_settings WHERE setting_key = 'optimization_enabled';"
```

## Troubleshooting

### Error: "relation system_settings already exists"

This means the migration was already applied. You can safely ignore this error, or check the table:

```bash
psql -h localhost -U compost_user -d compost_db -c "\d system_settings"
```

### Error: "permission denied"

Make sure you're using the correct database user:

```bash
# Check current user
whoami

# Use compost_user (not root)
psql -h localhost -U compost_user -d compost_db
```

### Error: "could not connect to server"

Check if PostgreSQL is running:

```bash
sudo systemctl status postgresql
```

### Error: "password authentication failed"

Verify your `.env` file has the correct password:

```bash
cd /opt/compost-backend
cat .env | grep DB_PASSWORD
```

## Migration Checklist

- [ ] Copy migration file to `/opt/compost-backend/migrations/`
- [ ] Connect to database
- [ ] Run migration SQL file
- [ ] Verify table exists: `\dt system_settings`
- [ ] Verify default value inserted: `SELECT * FROM system_settings;`
- [ ] Restart API service: `sudo systemctl restart compost-api`
- [ ] Restart MQTT listener: `sudo systemctl restart compost-mqtt-listener`
- [ ] Test API endpoint: `curl http://localhost:8000/api/v1/optimization/status`

## Previous Migrations

- **001_initial_schema.sql** - Initial database schema (if exists)
- **002_phase2_schema_updates.sql** - Phase 2 multi-cycle management updates
- **003_optimization_settings.sql** - Optimization settings table (current)

## Notes

- Migrations use `CREATE TABLE IF NOT EXISTS` and `ON CONFLICT DO NOTHING` for safety
- Running a migration multiple times is safe (idempotent)
- Always verify migrations were applied before restarting services
- Keep migration files in version control (git)

