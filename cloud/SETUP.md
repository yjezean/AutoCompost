# Cloud Backend Setup Guide

This guide provides step-by-step instructions for setting up the cloud backend on a GCP Compute Engine instance.

## Prerequisites

- GCP Compute Engine instance (Ubuntu 20.04+ or Debian 11+)
- SSH access to the server
- Root or sudo privileges
- Python 3.8 or higher
- PostgreSQL 12 or higher
- Mosquitto MQTT broker

## Step 1: Server Preparation

### 1.1 Update System Packages

```bash
sudo apt update
sudo apt upgrade -y
```

### 1.2 Install Required System Packages

```bash
sudo apt install -y python3 python3-pip python3-venv postgresql postgresql-contrib mosquitto mosquitto-clients git
```

### 1.3 Create Application Directory

```bash
sudo mkdir -p /opt/compost-backend
sudo chown $USER:$USER /opt/compost-backend
cd /opt/compost-backend
```

## Step 2: Install Application Code

### 2.1 Clone or Upload Code

**Option A: Using Git (if repository is available)**
```bash
cd /opt/compost-backend
git clone <repository-url> .
```

**Option B: Using SCP (from local machine)**
```bash
# From your local machine
scp -r cloud/* user@server-ip:/opt/compost-backend/
```

**Option C: Manual Upload**
- Upload all files from the `cloud/` directory to `/opt/compost-backend/` on the server

### 2.2 Create Virtual Environment

```bash
cd /opt/compost-backend
python3 -m venv venv
source venv/bin/activate
```

### 2.3 Install Python Dependencies

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

## Step 3: Database Setup

### 3.1 Create PostgreSQL Database and User

```bash
sudo -u postgres psql
```

In PostgreSQL prompt:
```sql
-- Create database
CREATE DATABASE compost_db;

-- Create user
CREATE USER compost_user WITH PASSWORD 'your_secure_password';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE compost_db TO compost_user;

-- Connect to database and grant schema privileges
\c compost_db
GRANT ALL ON SCHEMA public TO compost_user;

-- Exit PostgreSQL
\q
```

### 3.2 Run Database Migrations

```bash
cd /opt/compost-backend
source venv/bin/activate

# Run migrations in order
psql -U compost_user -d compost_db -f migrations/002_phase2_schema_updates.sql
psql -U compost_user -d compost_db -f migrations/003_optimization_settings.sql
psql -U compost_user -d compost_db -f migrations/004_insert_mock_completed_cycles.sql
```

**Note**: If you need the initial schema, check for migration `001_initial_schema.sql` or create tables manually based on your requirements.

## Step 4: MQTT Broker Configuration

### 4.1 Configure Mosquitto (if needed)

Edit Mosquitto configuration:
```bash
sudo nano /etc/mosquitto/mosquitto.conf
```

Ensure the following settings:
```
listener 1883
allow_anonymous true
```

**Note**: For production, use authentication. See Mosquitto documentation for secure setup.

### 4.2 Start and Enable Mosquitto

```bash
sudo systemctl start mosquitto
sudo systemctl enable mosquitto
sudo systemctl status mosquitto
```

### 4.3 Test MQTT Connection

```bash
# In one terminal - subscribe to test topic
mosquitto_sub -h localhost -t test/topic

# In another terminal - publish test message
mosquitto_pub -h localhost -t test/topic -m "Hello MQTT"
```

## Step 5: Application Configuration

### 5.1 Create Environment File

```bash
cd /opt/compost-backend
nano .env
```

Add the following content (adjust values as needed):

```env
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=compost_db
DB_USER=compost_user
DB_PASSWORD=your_secure_password

# MQTT Configuration
MQTT_BROKER_HOST=localhost
MQTT_BROKER_PORT=1883
MQTT_USERNAME=
MQTT_PASSWORD=

# MQTT Topic
MQTT_SENSOR_TOPIC=compost/sensor/data

# Control Thresholds (Optional - defaults provided)
TEMP_OPTIMAL_MIN=55.0
TEMP_OPTIMAL_MAX=65.0
TEMP_CRITICAL_HIGH=70.0
HUMIDITY_OPTIMAL_MIN=50.0
HUMIDITY_OPTIMAL_MAX=60.0

# API Configuration
API_HOST=0.0.0.0
API_PORT=8000
```

### 5.2 Set File Permissions

```bash
chmod 600 .env  # Restrict access to environment file
```

## Step 6: Create Log Directory

```bash
sudo mkdir -p /var/log/compost
sudo chown $USER:$USER /var/log/compost
```

## Step 7: Test Services Manually

### 7.1 Test MQTT Listener

```bash
cd /opt/compost-backend
source venv/bin/activate
python mqtt_listener.py
```

You should see:
- Database connection successful
- MQTT connection successful
- Waiting for messages on `compost/sensor/data`

Press `Ctrl+C` to stop.

### 7.2 Test FastAPI Server

In a new terminal:
```bash
cd /opt/compost-backend
source venv/bin/activate
uvicorn main:app --host 0.0.0.0 --port 8000
```

Or run directly:
```bash
python main.py
```

You should see:
- Server starting on `http://0.0.0.0:8000`
- Database connection successful

Test the API:
```bash
curl http://localhost:8000/health
```

Access API documentation:
- Swagger UI: `http://YOUR_SERVER_IP:8000/docs`
- ReDoc: `http://YOUR_SERVER_IP:8000/redoc`

Press `Ctrl+C` to stop.

## Step 8: Configure Firewall (GCP)

### 8.1 Allow HTTP Traffic

```bash
# Allow port 8000 for API
sudo ufw allow 8000/tcp

# Or use GCP Console:
# VPC Network > Firewall Rules > Create Rule
# - Allow TCP port 8000
# - Source: 0.0.0.0/0 (or restrict to specific IPs)
```

### 8.2 Allow MQTT Traffic (if external access needed)

```bash
# Allow port 1883 for MQTT
sudo ufw allow 1883/tcp

# Note: For production, use MQTT over TLS (port 8883) with authentication
```

## Step 9: Deploy as Systemd Services

For production deployment, set up systemd services for automatic startup and management.

See [SYSTEMD_SETUP.md](SYSTEMD_SETUP.md) for detailed instructions.

Quick setup:
```bash
# Copy service files
sudo cp systemd/compost-mqtt-listener.service /etc/systemd/system/
sudo cp systemd/compost-api.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable and start services
sudo systemctl enable compost-mqtt-listener.service
sudo systemctl enable compost-api.service
sudo systemctl start compost-mqtt-listener.service
sudo systemctl start compost-api.service
```

## Step 10: Verify Installation

### 10.1 Check Service Status

```bash
sudo systemctl status compost-mqtt-listener.service
sudo systemctl status compost-api.service
```

### 10.2 Check Logs

```bash
# MQTT Listener logs
sudo journalctl -u compost-mqtt-listener.service -f

# FastAPI logs
sudo journalctl -u compost-api.service -f
```

### 10.3 Test API Endpoints

```bash
# Health check
curl http://localhost:8000/health

# Get current batch (may return 404 if no batch exists)
curl http://localhost:8000/api/v1/compost-batch/current
```

