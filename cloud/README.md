# Cloud Backend Module

This module contains the backend services for the IoT Compost Monitoring System, deployed on Google Cloud Platform (GCP) Compute Engine.

## Purpose

The cloud backend serves as the central processing hub for the compost monitoring system:

- **Data Persistence**: Stores all sensor readings in PostgreSQL for historical analysis
- **Automated Control**: Monitors sensor data and automatically controls devices (fan, lid, stirrer) based on optimal composting conditions
- **REST API**: Provides HTTP endpoints for the Flutter mobile app to access historical data and manage compost batches
- **Analytics**: Calculates compost completion status and provides insights through temperature curve analysis

## Components

### 1. MQTT Listener Service (`mqtt_listener.py`)

**Purpose**: Real-time sensor data processing and automated control

**Functions**:

- Subscribes to MQTT topic `compost/sensor/data` from ESP32 hardware
- Saves sensor readings to PostgreSQL database
- Implements automated control logic based on temperature and humidity thresholds
- Publishes control commands to MQTT topics (`compost/cmd/fan`, `compost/cmd/lid`, `compost/cmd/stirrer`)
- Manages periodic stirrer operation (5 minutes ON, 30 minutes OFF)

**Control Logic**:

- **Temperature Control**: Maintains 55-65°C optimal range
  - < 55°C: Fan OFF, Lid CLOSED (retain heat)
  - 55-65°C: Optimal range (maintain current state)
  - > 65°C: Fan ON, Lid OPEN (cooling)
  - > 70°C: Emergency cooling (Fan ON, Lid OPEN)
- **Humidity Control**: Maintains 50-60% optimal range
  - < 50%: Fan OFF (retain moisture)
  - 50-60%: Optimal range
  - > 60%: Fan ON, Lid OPEN (dehumidification)
- **Priority**: Temperature control takes priority over humidity control

### 2. FastAPI Application (`main.py`)

**Purpose**: HTTP REST API for mobile app

**Key Features**:

- Sensor data retrieval (historical data with time range filtering)
- Compost batch management (create, read, update batches)
- Cycle management (multi-cycle support with waste tracking)
- Analytics endpoints (completion status, C:N ratio calculations)
- CORS enabled for Flutter app access

**Endpoints**:

- `GET /api/v1/sensor-data?days=7` - Historical sensor data
- `GET /api/v1/compost-batch/current` - Current active batch
- `POST /api/v1/compost-batch` - Create new batch
- `GET /api/v1/analytics/completion-status` - Compost completion analysis

### 3. Calculation Module (`compost_calculations.py`)

**Purpose**: Centralized calculation and control logic

**Functions**:

- `calculate_cn_ratio()` - C:N ratio calculation for waste optimization
- `check_temperature_control()` - Temperature control recommendations
- `check_humidity_control()` - Humidity control recommendations
- `get_combined_control_recommendation()` - Combined control logic with priority handling

### 4. Configuration (`config.py`)

**Purpose**: Centralized configuration management

**Features**:

- Loads environment variables from `.env` file
- Database connection settings
- MQTT broker configuration
- Control thresholds (temperature, humidity optimal ranges)
- API host and port settings

## Features

- **Real-time Data Processing**: MQTT listener processes sensor data as it arrives
- **Automated Control**: Intelligent control logic maintains optimal composting conditions
- **Historical Data Storage**: All sensor readings stored with timestamps for analytics
- **Batch Management**: Track multiple compost batches with lifecycle management
- **Analytics**: Temperature curve analysis to determine compost completion status
- **C:N Ratio Calculations**: Optimize waste input ratios for better composting
- **RESTful API**: Standard HTTP API with automatic documentation (Swagger/ReDoc)
- **Service Management**: Systemd integration for automatic startup and monitoring

## Quick Start

### Prerequisites

- GCP Compute Engine instance (Ubuntu/Debian)
- Python 3.8+
- PostgreSQL 12+
- Mosquitto MQTT broker
- Virtual environment (recommended)

### Basic Setup

1. **Install dependencies**:

   ```bash
   cd /opt/compost-backend
   source venv/bin/activate
   pip install -r requirements.txt
   ```

2. **Configure environment**:

   - Create `.env` file (see [SETUP.md](SETUP.md) for details)
   - Set database credentials
   - Set MQTT broker address
   - Configure control thresholds

3. **Run services**:

   ```bash
   # MQTT Listener (in one terminal)
   python mqtt_listener.py

   # FastAPI Server (in another terminal)
   uvicorn main:app --host 0.0.0.0 --port 8000
   ```

4. **Access API documentation**:
   - Swagger UI: `http://YOUR_SERVER_IP:8000/docs`
   - ReDoc: `http://YOUR_SERVER_IP:8000/redoc`

### Production Deployment

For production deployment with automatic startup and service management:

- See [SETUP.md](SETUP.md) for detailed installation instructions
- See [SYSTEMD_SETUP.md](SYSTEMD_SETUP.md) for systemd service configuration

## File Structure

```
cloud/
├── main.py                    # FastAPI application
├── mqtt_listener.py           # MQTT listener service
├── compost_calculations.py    # Control logic calculations
├── config.py                  # Configuration settings
├── test_control_logic.py      # Control logic tests
├── requirements.txt           # Python dependencies
├── .env                       # Environment variables (create manually)
├── migrations/                # Database migration scripts
│   ├── 002_phase2_schema_updates.sql
│   ├── 003_optimization_settings.sql
│   └── 004_insert_mock_completed_cycles.sql
├── systemd/                   # Systemd service files
│   ├── compost-api.service
│   └── compost-mqtt-listener.service
├── README.md                  # This file
├── SETUP.md                   # Detailed setup guide
└── SYSTEMD_SETUP.md          # Systemd service setup guide
```

## ESP32 Data Format

The ESP32 publishes JSON messages to topic `compost/sensor/data`:

```json
{
  "temperature": 30.8,
  "humidity": 70.0,
  "timestamp": "2024-01-03T16:58:08Z",
  "lid": "CLOSED",
  "relay": "OFF",
  "stirrer": "OFF"
}
```

**Required Fields**:

- `temperature` (float) - Temperature in Celsius
- `humidity` (float) - Humidity percentage

**Optional Fields**:

- `timestamp` (ISO 8601 string) - UTC timestamp (defaults to current time if missing)
- `lid` (string) - "OPEN" or "CLOSED"
- `relay` (string) - "ON" or "OFF" (controls fan)
- `stirrer` (string) - "ON" or "OFF"

## MQTT Topics

### Subscribed Topics

- `compost/sensor/data` - Sensor data from ESP32

### Published Topics

- `compost/cmd/fan` - Fan control commands (ON/OFF)
- `compost/cmd/lid` - Lid control commands (OPEN/CLOSED)
- `compost/cmd/stirrer` - Stirrer control commands (ON/OFF)

## Dependencies

See [requirements.txt](requirements.txt) for complete list. Key dependencies:

- `fastapi==0.104.1` - Web framework
- `uvicorn==0.24.0` - ASGI server
- `paho-mqtt==1.6.1` - MQTT client
- `psycopg2-binary==2.9.9` - PostgreSQL adapter
- `pandas==2.1.3` - Data analysis
- `numpy==1.26.2` - Numerical computations
- `python-dotenv==1.0.0` - Environment variable management

## Documentation

- **[SETUP.md](SETUP.md)** - Detailed installation and configuration guide
- **[SYSTEMD_SETUP.md](SYSTEMD_SETUP.md)** - Systemd service deployment guide

## Logging

Logs are written to:

- MQTT Listener: `/var/log/compost/mqtt-listener.log`
- FastAPI: `/var/log/compost/api.log`

View logs:

```bash
# MQTT Listener logs
sudo journalctl -u compost-mqtt-listener.service -f

# FastAPI logs
sudo journalctl -u compost-api.service -f
``
```