#!/usr/bin/env python3
"""
MQTT Listener Service
Subscribes to sensor data from ESP32, saves to PostgreSQL, and implements control logic
"""
import json
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict
import paho.mqtt.client as mqtt
import psycopg2
import config

# GMT+8 timezone
GMT8 = timezone(timedelta(hours=8))

# Configure logging with GMT+8 timezone
import logging.handlers

class GMT8Formatter(logging.Formatter):
    """Custom formatter that converts timestamps to GMT+8"""
    def formatTime(self, record, datefmt=None):
        dt = datetime.fromtimestamp(record.created, GMT8)
        if datefmt:
            return dt.strftime(datefmt)
        return dt.strftime('%Y-%m-%d %H:%M:%S')

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/compost/mqtt-listener.log'),
        logging.StreamHandler()
    ]
)

# Apply GMT+8 formatter to all handlers
gmt8_formatter = GMT8Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
for handler in logging.root.handlers:
    handler.setFormatter(gmt8_formatter)

logger = logging.getLogger(__name__)

class CompostMQTTListener:
    def __init__(self):
        self.db_conn = None
        self.mqtt_client = None
        self.last_fan_state = None
        self.last_lid_state = None
        
    def connect_database(self):
        """Connect to PostgreSQL database"""
        try:
            self.db_conn = psycopg2.connect(
                host=config.DB_HOST,
                port=config.DB_PORT,
                database=config.DB_NAME,
                user=config.DB_USER,
                password=config.DB_PASSWORD
            )
            logger.info("Connected to PostgreSQL database")
            return True
        except Exception as e:
            logger.error(f"Database connection error: {e}")
            return False
    
    def parse_json_message(self, message: str) -> Optional[Dict]:
        """
        Parse JSON message from ESP32
        Expected format: {"temperature": float, "humidity": float, "timestamp": "ISO8601", 
                          "lid": "OPEN|CLOSED", "relay": "ON|OFF", "stirrer": "ON|OFF"}
        Maps ESP32 field names to backend field names
        """
        try:
            data = json.loads(message)
            
            # Validate required fields
            if 'temperature' not in data or 'humidity' not in data:
                logger.warning(f"Missing required fields (temperature/humidity) in message: {message}")
                return None
            
            # Parse and normalize timestamp
            if 'timestamp' in data and data['timestamp']:
                try:
                    # Handle ISO 8601 format with 'Z' suffix (UTC)
                    timestamp_str = data['timestamp'].replace('Z', '+00:00')
                    # Parse as UTC and convert to GMT+8
                    utc_timestamp = datetime.fromisoformat(timestamp_str)
                    data['timestamp'] = utc_timestamp.astimezone(GMT8)
                except (ValueError, AttributeError) as e:
                    logger.warning(f"Invalid timestamp format, using current time: {e}")
                    data['timestamp'] = datetime.now(GMT8)
            else:
                # Fallback to current time if timestamp not provided
                data['timestamp'] = datetime.now(GMT8)
            
            # Map ESP32 field names to backend field names
            # ESP32 sends: "relay", "lid", "stirrer"
            # Backend expects: "fan_state", "lid_state", "stirrer_state"
            if 'relay' in data:
                data['fan_state'] = data['relay'].upper()
            if 'lid' in data:
                data['lid_state'] = data['lid'].upper()
            if 'stirrer' in data:
                data['stirrer_state'] = data['stirrer'].upper()
            
            return data
            
        except json.JSONDecodeError as e:
            logger.error(f"JSON decode error: {e}")
            return None
        except Exception as e:
            logger.error(f"Error parsing message: {e}")
            return None
    
    def save_sensor_data(self, data: Dict):
        """Save sensor data to PostgreSQL"""
        try:
            cursor = self.db_conn.cursor()
            cursor.execute(
                """
                INSERT INTO sensor_data (timestamp, temperature, humidity)
                VALUES (%s, %s, %s)
                """,
                (data['timestamp'], data['temperature'], data['humidity'])
            )
            self.db_conn.commit()
            cursor.close()
            
            # Log sensor data with device states if available
            log_msg = f"Saved sensor data: Temp={data['temperature']:.2f}°C, Hum={data['humidity']:.2f}%"
            device_info = []
            if 'fan_state' in data:
                device_info.append(f"Fan={data['fan_state']}")
            if 'lid_state' in data:
                device_info.append(f"Lid={data['lid_state']}")
            if 'stirrer_state' in data:
                device_info.append(f"Stirrer={data['stirrer_state']}")
            if device_info:
                log_msg += f" | {', '.join(device_info)}"
            logger.info(log_msg)
        except Exception as e:
            logger.error(f"Error saving sensor data: {e}")
            self.db_conn.rollback()
    
    def check_thresholds_and_control(self, data: Dict):
        """Check sensor readings against thresholds and publish control commands"""
        temp = data['temperature']
        humidity = data['humidity']
        
        # Fan control logic (relay controls the fan)
        fan_should_be_on = (temp > config.FAN_TEMP_THRESHOLD) or (humidity > config.FAN_HUMIDITY_THRESHOLD)
        current_fan_state = data.get('fan_state', self.last_fan_state)
        
        if fan_should_be_on and current_fan_state != 'ON':
            self.publish_command(config.MQTT_CMD_FAN_TOPIC, {"action": "ON"})
            self.last_fan_state = 'ON'
            logger.info(f"Fan ON triggered: Temp={temp:.2f}°C, Hum={humidity:.2f}%")
        elif not fan_should_be_on and current_fan_state == 'ON':
            self.publish_command(config.MQTT_CMD_FAN_TOPIC, {"action": "OFF"})
            self.last_fan_state = 'OFF'
            logger.info(f"Fan OFF triggered: Temp={temp:.2f}°C, Hum={humidity:.2f}%")
        
        # Lid control logic (emergency release)
        if temp > config.LID_TEMP_THRESHOLD:
            current_lid_state = data.get('lid_state', self.last_lid_state)
            if current_lid_state != 'OPEN':
                self.publish_command(config.MQTT_CMD_LID_TOPIC, {"action": "OPEN"})
                self.last_lid_state = 'OPEN'
                logger.warning(f"Lid OPEN triggered (emergency): Temp={temp:.2f}°C")
    
    def publish_command(self, topic: str, payload: Dict):
        """Publish command to MQTT topic"""
        try:
            message = json.dumps(payload)
            self.mqtt_client.publish(topic, message)
            logger.debug(f"Published command to {topic}: {message}")
        except Exception as e:
            logger.error(f"Error publishing command: {e}")
    
    def on_connect(self, client, userdata, flags, rc):
        """Callback when MQTT client connects"""
        if rc == 0:
            logger.info("Connected to MQTT broker")
            # Subscribe to sensor data topic
            client.subscribe(config.MQTT_SENSOR_TOPIC)
            logger.info(f"Subscribed to topic: {config.MQTT_SENSOR_TOPIC}")
        else:
            logger.error(f"Failed to connect to MQTT broker, return code: {rc}")
    
    def on_message(self, client, userdata, msg):
        """Callback when MQTT message is received"""
        try:
            topic = msg.topic
            message = msg.payload.decode('utf-8')
            logger.debug(f"Received message on {topic}: {message}")
            
            # Parse JSON message
            data = self.parse_json_message(message)
            
            if data:
                # Save to database (includes logging with device states)
                self.save_sensor_data(data)
                
                # Check thresholds and control devices
                self.check_thresholds_and_control(data)
            else:
                logger.warning(f"Could not parse message: {message}")
                
        except Exception as e:
            logger.error(f"Error processing message: {e}")
    
    def on_disconnect(self, client, userdata, rc):
        """Callback when MQTT client disconnects"""
        logger.warning(f"Disconnected from MQTT broker (rc: {rc})")
    
    def start(self):
        """Start the MQTT listener service"""
        # Connect to database
        if not self.connect_database():
            logger.error("Failed to connect to database. Exiting.")
            return
        
        # Create MQTT client
        self.mqtt_client = mqtt.Client(client_id="compost_mqtt_listener")
        
        # Set callbacks
        self.mqtt_client.on_connect = self.on_connect
        self.mqtt_client.on_message = self.on_message
        self.mqtt_client.on_disconnect = self.on_disconnect
        
        # Set credentials if provided
        if config.MQTT_USERNAME and config.MQTT_PASSWORD:
            self.mqtt_client.username_pw_set(config.MQTT_USERNAME, config.MQTT_PASSWORD)
        
        # Connect to MQTT broker
        try:
            self.mqtt_client.connect(config.MQTT_BROKER_HOST, config.MQTT_BROKER_PORT, 60)
            logger.info(f"Connecting to MQTT broker at {config.MQTT_BROKER_HOST}:{config.MQTT_BROKER_PORT}")
            
            # Start loop (blocks)
            self.mqtt_client.loop_forever()
            
        except KeyboardInterrupt:
            logger.info("Shutting down...")
            self.mqtt_client.disconnect()
            if self.db_conn:
                self.db_conn.close()
        except Exception as e:
            logger.error(f"Error in MQTT loop: {e}")
            if self.db_conn:
                self.db_conn.close()

def main():
    """Main entry point"""
    # Ensure log directory exists
    import os
    os.makedirs('/var/log/compost', exist_ok=True)
    
    listener = CompostMQTTListener()
    listener.start()

if __name__ == "__main__":
    main()
