# Hardware Module

ESP32-based firmware for the IoT Compost Monitoring System, responsible for sensor reading, actuator control, and MQTT communication.

## Purpose

The hardware module provides the edge computing layer of the compost monitoring system:

- **Sensor Reading**: Continuously reads temperature and humidity from DHT11 sensor
- **Actuator Control**: Controls fan (via relay), lid (via servo), and stirrer (via servo)
- **MQTT Communication**: Publishes sensor data and subscribes to control commands
- **Safety Features**: Built-in fault detection and emergency response mechanisms
- **Local Control**: Physical buttons for manual device control

## Hardware Components

### Microcontroller

- **ESP32 Development Board**
  - Built-in Wi-Fi connectivity
  - Dual-core processor
  - Multiple GPIO pins
  - Supports PWM for servo control

### Sensors

- **DHT11 Temperature & Humidity Sensor**
  - Temperature range: 0-50°C
  - Humidity range: 20-90% RH
  - Digital output
  - Requires pull-up resistor (4.7k-10kΩ)

### Actuators

- **DC Fan + Relay Module**

  - 5V or 12V DC fan
  - Relay module for switching
  - Provides cooling and dehumidification

- **Servo Motor (Lid Control)**

  - Standard servo motor (SG90 or similar)
  - 0-180° rotation
  - Opens/closes compost container lid

- **Servo Motor (Stirrer)**
  - Standard servo motor
  - Continuous rotation or standard servo
  - Mixes compost for aeration

### Indicators

- **Green LED**: System status indicator (ON = OK, OFF = Error)
- **Red LED**: Fault indicator (blinks when system fault detected)
- **Buzzer**: Audio feedback for faults and actions

### Input Controls

- **Button 1**: Lid toggle control
- **Button 2**: Relay/Fan control
- **Button 3**: Stirrer control

## Features

### Real-Time Sensor Monitoring

- Reads temperature and humidity every 5 seconds
- Validates sensor readings
- Handles sensor errors gracefully

### MQTT Communication

- **Publishes**: Sensor data to `compost/sensor/data` topic every 5 seconds
- **Subscribes**: Control commands from `compost/cmd/fan`, `compost/cmd/lid`, `compost/cmd/stirrer`
- **Publishes Status**: Device status to `compost/status/*` topics
- Automatic reconnection on connection loss

### Automated Control

- Responds to MQTT control commands from backend
- Executes fan, lid, and stirrer operations
- Publishes status confirmation after actions

### Manual Control

- Physical buttons for local device control
- Button debouncing to prevent false triggers
- Visual and audio feedback for actions

### Safety Features

- **Fault Detection**: Monitors sensor health and connection status
- **Emergency Response**: Critical temperature thresholds trigger immediate actions
- **Failsafe Logic**: Hard-coded safety limits in firmware
- **System Status**: LED indicators show system health

### Time Synchronization

- NTP time synchronization (GMT+8)
- Accurate timestamps for sensor data
- Automatic time sync on Wi-Fi connection

## Pin Assignments

### Sensor Pins

- **DHT11 Data**: GPIO 21
- **DHT11 VCC**: 3.3V or 5V
- **DHT11 GND**: GND

### Actuator Pins

- **Lid Servo**: GPIO 27
- **Stirrer Servo**: GPIO 26
- **Relay (Fan)**: GPIO 25
- **Buzzer**: GPIO 23

### Indicator Pins

- **Green LED**: GPIO 18
- **Red LED**: GPIO 19

### Input Pins

- **Lid Button**: GPIO 33 (with internal pull-up)
- **Relay Button**: GPIO 22 (with internal pull-up)
- **Stirrer Button**: GPIO 32 (with internal pull-up)

## MQTT Topics

### Published Topics

- **`compost/sensor/data`**: Sensor readings (temperature, humidity, device status)

  - Published every 5 seconds
  - JSON format with timestamp

- **`compost/status/fan`**: Fan status confirmation
- **`compost/status/lid`**: Lid status confirmation
- **`compost/status/stirrer`**: Stirrer status confirmation

### Subscribed Topics

- **`compost/cmd/fan`**: Fan control commands (ON/OFF)
- **`compost/cmd/lid`**: Lid control commands (OPEN/CLOSED)
- **`compost/cmd/stirrer`**: Stirrer control commands (ON/OFF)

## Data Format

### Sensor Data Message (Published)

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

**Fields**:

- `temperature` (float): Temperature in Celsius
- `humidity` (float): Humidity percentage
- `timestamp` (string): ISO 8601 UTC timestamp
- `lid` (string): "OPEN" or "CLOSED"
- `relay` (string): "ON" or "OFF" (fan control)
- `stirrer` (string): "ON" or "OFF"

### Control Commands (Received)

**Fan Control**:

```json
"ON"
```

or

```json
"OFF"
```

**Lid Control**:

```json
"OPEN"
```

or

```json
"CLOSED"
```

**Stirrer Control**:

```json
"ON"
```

or

```json
"OFF"
```

## Configuration

### Wi-Fi Configuration

Edit in `main.ino`:

```cpp
const char* WIFI_SSID = "Your_WiFi_SSID";
const char* WIFI_PASSWORD = "Your_WiFi_Password";
```

### MQTT Configuration

Edit in `main.ino`:

```cpp
const char* MQTT_SERVER = "34.87.144.95";  // MQTT broker IP
const int MQTT_PORT = 1883;                 // MQTT port
```

## Libraries Required

Install via Arduino Library Manager:

- **ESP32Servo** - Servo motor control
- **DHT sensor library** - DHT11 sensor reading
- **WiFi** - Built-in ESP32 library
- **PubSubClient** - MQTT client
- **ArduinoJson** - JSON parsing and generation
- **time** - Built-in ESP32 library

## Operation Modes

### Normal Operation

- Sensor reads every 5 seconds
- Data published to MQTT every 5 seconds
- Responds to MQTT commands immediately
- LED indicators show system status

### Fault Mode

- Red LED blinks when fault detected
- Buzzer beeps periodically
- System continues operation but indicates fault
- Fault conditions:
  - Sensor reading failure
  - Wi-Fi connection loss
  - MQTT connection loss

### Emergency Mode

- Critical temperature thresholds trigger immediate actions
- Overrides normal control logic
- Ensures safety even if backend is unavailable

## Safety Features

### Sensor Validation

- Checks for valid sensor readings
- Handles NaN (Not a Number) errors
- Provides error messages via Serial

### Connection Resilience

- Automatic Wi-Fi reconnection
- Automatic MQTT reconnection
- Continues operation during connection loss
- Queues data for transmission when reconnected

## Quick Start

1. **Hardware Setup**: Wire components according to pin assignments (see [SETUP.md](SETUP.md))
2. **Install Libraries**: Install required Arduino libraries
3. **Configure**: Update Wi-Fi and MQTT settings in code
4. **Upload**: Upload firmware to ESP32 via Arduino IDE
5. **Monitor**: Open Serial Monitor (115200 baud) to view status

For detailed setup instructions, see [SETUP.md](SETUP.md).

## Troubleshooting

### Sensor Not Reading

- Check wiring (VCC, GND, DATA)
- Verify pull-up resistor (4.7k-10kΩ)
- Check power supply stability
- See Serial Monitor for error messages

### Wi-Fi Connection Issues

- Verify SSID and password
- Check Wi-Fi signal strength
- Ensure 2.4GHz network (ESP32 doesn't support 5GHz)
- Check router settings

### MQTT Connection Issues

- Verify MQTT broker IP and port
- Check network connectivity
- Test MQTT broker accessibility
- Check firewall rules

### Device Not Responding to Commands

- Verify MQTT subscription is active
- Check command topic names
- Monitor Serial output for received messages
- Verify device wiring

See [SETUP.md](SETUP.md) for detailed troubleshooting guide.

## Serial Monitor Output

The firmware provides detailed Serial output for debugging:

- Wi-Fi connection status
- MQTT connection status
- Sensor readings
- Device control actions
- Error messages
- System status

**Baud Rate**: 115200

## Development

### Uploading Firmware

1. Connect ESP32 via USB
2. Select board: Tools > Board > ESP32 Arduino > Your ESP32 Board
3. Select port: Tools > Port > COMx (Windows) or /dev/ttyUSBx (Linux)
4. Upload: Sketch > Upload

### Debugging

- Use Serial Monitor (115200 baud) for debugging
- Check Serial output for connection status
- Monitor MQTT messages via MQTT client
- Use LED indicators for visual feedback

## Documentation

- **[SETUP.md](SETUP.md)** - Detailed hardware setup and wiring guide
- **[../README.md](../README.md)** - Project overview
- **[../cloud/README.md](../cloud/README.md)** - Backend documentation
