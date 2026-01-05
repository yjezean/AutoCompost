#!/usr/bin/env python3
"""
MQTT Listener Service
Subscribes to sensor data from ESP32, saves to PostgreSQL, and implements control logic
"""
import json
import logging
import threading
import time
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict
import paho.mqtt.client as mqtt
import psycopg2
import config
from compost_calculations import get_combined_control_recommendation

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
        self.last_stirrer_state = None
        self.stirrer_timer = None
        self.stirrer_running = False
        self.stirrer_lock = threading.Lock()
        
        # Stirrer periodic control settings
        self.STIRRER_ON_DURATION = 300  # 5 minutes ON
        self.STIRRER_OFF_DURATION = 1800  # 30 minutes OFF
        
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
            
            # Ensure timestamp is in GMT+8 timezone before saving
            timestamp = data['timestamp']
            if timestamp.tzinfo is None:
                # If no timezone info, assume GMT+8
                timestamp = timestamp.replace(tzinfo=GMT8)
            elif timestamp.tzinfo != GMT8:
                # Convert to GMT+8 if in different timezone
                timestamp = timestamp.astimezone(GMT8)
            
            cursor.execute(
                """
                INSERT INTO sensor_data (timestamp, temperature, humidity)
                VALUES (%s, %s, %s)
                """,
                (timestamp, data['temperature'], data['humidity'])
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
    
    def handle_device_status(self, topic: str, message: str):
        """Handle device status updates from hardware"""
        try:
            status_data = json.loads(message)
            
            # Extract device type from topic (e.g., "compost/status/fan" -> "fan")
            device_type = topic.split('/')[-1]
            status = status_data.get('status', '').upper()
            timestamp_str = status_data.get('timestamp')
            
            # Normalize status values
            # Map common status values to standard format
            status_map = {
                'RUNNING': 'ON',
                'START': 'ON',
                'STOPPED': 'OFF',
                'STOP': 'OFF',
                'OPENED': 'OPEN',
                'CLOSED': 'CLOSE',
            }
            normalized_status = status_map.get(status, status)
            
            # For lid, normalize CLOSE to CLOSED for consistency
            if device_type == 'lid' and normalized_status == 'CLOSE':
                normalized_status = 'CLOSED'
            
            # Parse timestamp
            if timestamp_str:
                try:
                    timestamp_str = timestamp_str.replace('Z', '+00:00')
                    timestamp = datetime.fromisoformat(timestamp_str).astimezone(GMT8)
                except (ValueError, AttributeError):
                    timestamp = datetime.now(GMT8)
            else:
                timestamp = datetime.now(GMT8)
            
            # Update internal state tracking
            if device_type == 'fan':
                self.last_fan_state = normalized_status
            elif device_type == 'lid':
                self.last_lid_state = normalized_status
            elif device_type == 'stirrer':
                self.last_stirrer_state = normalized_status
            
            # Log the status update
            logger.info(f"[DEVICE STATUS] {device_type}: {normalized_status} (from: {status})")
            
        except json.JSONDecodeError as e:
            logger.error(f"[DEVICE STATUS] JSON parse error: {e}, message: {message}")
        except Exception as e:
            logger.error(f"[DEVICE STATUS] Error handling status: {e}")
    
    def check_thresholds_and_control(self, data: Dict):
        """
        Check sensor readings against optimal ranges and publish control commands.
        
        Optimal ranges for hot aerobic composting:
        - Temperature: 55-65°C (131-149°F)
        - Humidity: 50-60% water (by weight)
        """
        temp = data['temperature']
        humidity = data['humidity']
        
        # Get combined control recommendations using optimal ranges
        control = get_combined_control_recommendation(temp, humidity)
        
        # Get current device states from sensor data or last known state
        # Try multiple field names (ESP32 might send different field names)
        current_fan_state = data.get('fan_state') or data.get('relay') or data.get('fan')
        if current_fan_state:
            current_fan_state = str(current_fan_state).strip().upper()
        else:
            current_fan_state = self.last_fan_state or 'UNKNOWN'
        
        current_lid_state = data.get('lid_state') or data.get('lid')
        if current_lid_state:
            current_lid_state = str(current_lid_state).strip().upper()
        else:
            current_lid_state = self.last_lid_state or 'UNKNOWN'
        
        # Log control decision
        logger.info(f"[CONTROL] Temp: {temp:.1f}°C, Humidity: {humidity:.1f}%")
        logger.info(f"[CONTROL] Fan: {control['fan_action']} (current: {current_fan_state}) | Lid: {control['lid_action']} (current: {current_lid_state})")
        logger.info(f"[CONTROL] Reason - Temp: {control['temp_status']}, Humidity: {control['humidity_status']}")
        
        # Fan control - send command if action is required and state differs
        if control['fan_action'] == 'ON':
            if current_fan_state != 'ON':
                self.publish_command(config.MQTT_CMD_FAN_TOPIC, {"action": "ON"})
                self.last_fan_state = 'ON'
                logger.warning(f"[CONTROL] ✓ Fan ON - {control['humidity_message'] if control['humidity_status'] == 'too_high' else control['temp_message']}")
            else:
                logger.debug(f"[CONTROL] Fan already ON, skipping")
        elif control['fan_action'] == 'OFF':
            if current_fan_state == 'ON':
                self.publish_command(config.MQTT_CMD_FAN_TOPIC, {"action": "OFF"})
                self.last_fan_state = 'OFF'
                logger.info(f"[CONTROL] ✓ Fan OFF - {control['message']}")
            else:
                logger.debug(f"[CONTROL] Fan already OFF, skipping")
        
        # Lid control - send command if action is required and state differs
        if control['lid_action'] == 'OPEN':
            if current_lid_state != 'OPEN':
                self.publish_command(config.MQTT_CMD_LID_TOPIC, {"action": "OPEN"})
                self.last_lid_state = 'OPEN'
                logger.warning(f"[CONTROL] ✓ Lid OPEN - {control['message']}")
            else:
                logger.debug(f"[CONTROL] Lid already OPEN, skipping")
        elif control['lid_action'] == 'CLOSED':
            if current_lid_state == 'OPEN':
                self.publish_command(config.MQTT_CMD_LID_TOPIC, {"action": "CLOSED"})
                self.last_lid_state = 'CLOSED'
                logger.info(f"[CONTROL] ✓ Lid CLOSED - {control['message']}")
            else:
                logger.debug(f"[CONTROL] Lid already CLOSED, skipping")
    
    def publish_command(self, topic: str, payload: Dict):
        """Publish command to MQTT topic"""
        if not self.mqtt_client or not self.mqtt_client.is_connected():
            logger.error(f"[CONTROL] Cannot publish - MQTT client not connected")
            return
        
        try:
            message = json.dumps(payload)
            result = self.mqtt_client.publish(topic, message)
            if result.rc == 0:
                logger.info(f"[CONTROL] ✓ Published to {topic}: {message}")
            else:
                logger.error(f"[CONTROL] Failed to publish to {topic}: rc={result.rc}")
        except Exception as e:
            logger.error(f"[CONTROL] Error publishing to {topic}: {e}")
    
    def start_periodic_stirrer(self):
        """Start periodic stirrer control (ON for 5 min, OFF for 30 min)"""
        def stirrer_cycle():
            while True:
                try:
                    # Turn stirrer ON
                    with self.stirrer_lock:
                        if self.mqtt_client and self.mqtt_client.is_connected():
                            self.publish_command(config.MQTT_CMD_STIRRER_TOPIC, {"action": "START"})
                            self.last_stirrer_state = 'RUNNING'
                            logger.info(f"[STIRRER] Starting periodic cycle - ON for {self.STIRRER_ON_DURATION}s")
                    
                    # Wait for ON duration
                    time.sleep(self.STIRRER_ON_DURATION)
                    
                    # Turn stirrer OFF
                    with self.stirrer_lock:
                        if self.mqtt_client and self.mqtt_client.is_connected():
                            self.publish_command(config.MQTT_CMD_STIRRER_TOPIC, {"action": "STOP"})
                            self.last_stirrer_state = 'STOPPED'
                            logger.info(f"[STIRRER] Stopping - OFF for {self.STIRRER_OFF_DURATION}s")
                    
                    # Wait for OFF duration
                    time.sleep(self.STIRRER_OFF_DURATION)
                    
                except Exception as e:
                    logger.error(f"[STIRRER] Error in periodic cycle: {e}")
                    time.sleep(60)  # Wait 1 minute before retrying
        
        if not self.stirrer_running:
            self.stirrer_running = True
            self.stirrer_timer = threading.Thread(target=stirrer_cycle, daemon=True)
            self.stirrer_timer.start()
            logger.info("[STIRRER] Periodic stirrer control started")
    
    def stop_periodic_stirrer(self):
        """Stop periodic stirrer control"""
        self.stirrer_running = False
        logger.info("[STIRRER] Periodic stirrer control stopped")
    
    def on_connect(self, client, userdata, flags, rc):
        """Callback when MQTT client connects"""
        if rc == 0:
            logger.info("Connected to MQTT broker")
            # Subscribe to sensor data topic
            client.subscribe(config.MQTT_SENSOR_TOPIC)
            logger.info(f"Subscribed to topic: {config.MQTT_SENSOR_TOPIC}")
            # Subscribe to device status topics
            client.subscribe("compost/status/fan")
            client.subscribe("compost/status/lid")
            client.subscribe("compost/status/stirrer")
            logger.info("Subscribed to device status topics: compost/status/fan, compost/status/lid, compost/status/stirrer")
            
            # Start periodic stirrer control
            self.start_periodic_stirrer()
        else:
            logger.error(f"Failed to connect to MQTT broker, return code: {rc}")
    
    def on_message(self, client, userdata, msg):
        """Callback when MQTT message is received"""
        try:
            topic = msg.topic
            message = msg.payload.decode('utf-8')
            
            # Route device status updates to handle_device_status
            if topic.startswith('compost/status/'):
                self.handle_device_status(topic, message)
                return
            
            # For sensor data, parse and process
            if topic == 'compost/sensor/data':
                data = self.parse_json_message(message)
                
                if data:
                    # Save to database (includes logging with device states)
                    self.save_sensor_data(data)
                    
                    # Check thresholds and control devices
                    self.check_thresholds_and_control(data)
                else:
                    logger.warning(f"Could not parse sensor data message: {message}")
            else:
                logger.debug(f"Received message on unknown topic {topic}: {message}")
                
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
