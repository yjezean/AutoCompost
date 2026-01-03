"""
Configuration settings for the compost monitoring backend
"""
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Database configuration
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "compost_db")
DB_USER = os.getenv("DB_USER", "compost_user")
DB_PASSWORD = os.getenv("DB_PASSWORD", "db1234")

# Database connection string
DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

# MQTT configuration
MQTT_BROKER_HOST = os.getenv("MQTT_BROKER_HOST", "localhost")
MQTT_BROKER_PORT = int(os.getenv("MQTT_BROKER_PORT", "1883"))
MQTT_USERNAME = os.getenv("MQTT_USERNAME", None)
MQTT_PASSWORD = os.getenv("MQTT_PASSWORD", None)

# MQTT Topics
MQTT_SENSOR_TOPIC = os.getenv("MQTT_SENSOR_TOPIC", "compost/sensor/data")
MQTT_CMD_FAN_TOPIC = "compost/cmd/fan"
MQTT_CMD_LID_TOPIC = "compost/cmd/lid"
MQTT_CMD_STIRRER_TOPIC = "compost/cmd/stirrer"
MQTT_STATUS_FAN_TOPIC = "compost/status/fan"
MQTT_STATUS_LID_TOPIC = "compost/status/lid"
MQTT_STATUS_STIRRER_TOPIC = "compost/status/stirrer"

# Control thresholds
FAN_TEMP_THRESHOLD = float(os.getenv("FAN_TEMP_THRESHOLD", "60.0"))
FAN_HUMIDITY_THRESHOLD = float(os.getenv("FAN_HUMIDITY_THRESHOLD", "80.0"))
LID_TEMP_THRESHOLD = float(os.getenv("LID_TEMP_THRESHOLD", "65.0"))

# API configuration
API_HOST = os.getenv("API_HOST", "0.0.0.0")
API_PORT = int(os.getenv("API_PORT", "8000"))

