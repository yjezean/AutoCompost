# Cloud Backend

This directory contains the backend services for the IoT Compost Monitoring System.

## Structure

```
cloud/
├── mqtt_listener.py      # MQTT listener service (subscribes to sensor data, saves to DB)
├── main.py               # FastAPI application (HTTP API for Flutter app)
├── config.py             # Configuration settings
├── .env                  # Environment variables (create manually)
├── requirements.txt      # Python dependencies
├── README.md            # This file
└── DEPLOY.md            # Deployment instructions
```

## Setup

1. **Copy files to server:**

   - Upload all files from this `cloud/` directory to `/opt/compost-backend/` on your GCP server
   - Or use git to clone/pull, or use `scp` to transfer files

2. **Install dependencies:**

```bash
cd /opt/compost-backend
source venv/bin/activate
pip install -r requirements.txt
```

3. **Create `.env` file:**

```bash
cd /opt/compost-backend
nano .env
```

Add the following content:

```env
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=compost_db
DB_USER=compost_user
DB_PASSWORD=db1234

# MQTT Configuration
MQTT_BROKER_HOST=localhost
MQTT_BROKER_PORT=1883
MQTT_USERNAME=
MQTT_PASSWORD=

# MQTT Topic
MQTT_SENSOR_TOPIC=compost/sensor/data

# Control Thresholds
FAN_TEMP_THRESHOLD=60.0
FAN_HUMIDITY_THRESHOLD=80.0
LID_TEMP_THRESHOLD=65.0

# API Configuration
API_HOST=0.0.0.0
API_PORT=8000
```

4. **Test MQTT listener:**

```bash
cd /opt/compost-backend
source venv/bin/activate
python mqtt_listener.py
```

5. **Run FastAPI server:**

```bash
cd /opt/compost-backend
source venv/bin/activate
uvicorn main:app --host 0.0.0.0 --port 8000
```

Or run directly:

```bash
python main.py
```

6. **Access API Documentation:**

   - Swagger UI: `http://YOUR_SERVER_IP:8000/docs`
   - ReDoc: `http://YOUR_SERVER_IP:8000/redoc`

7. **Set up systemd services (optional but recommended):**
   - See `SYSTEMD_SETUP.md` for instructions to run services automatically

See `API_DOCS.md` for detailed endpoint documentation.

## ESP32 Data Format

The ESP32 publishes JSON messages to topic `compost/sensor/data` with the following format:

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

The listener expects:

- `temperature` (float) - Temperature in Celsius
- `humidity` (float) - Humidity percentage
- `timestamp` (ISO 8601 string, optional) - UTC timestamp. If missing, current time is used
- `lid` (string, optional) - "OPEN" or "CLOSED"
- `relay` (string, optional) - "ON" or "OFF" (controls fan)
- `stirrer` (string, optional) - "ON" or "OFF"
