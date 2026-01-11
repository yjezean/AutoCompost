# Hardware Setup Guide

This guide provides step-by-step instructions for setting up the ESP32 hardware for the compost monitoring system.

## Prerequisites

### Hardware Components

- **ESP32 Development Board** (e.g., ESP32 DevKit, NodeMCU-32S)
- **DHT11 Temperature & Humidity Sensor**
- **2x Servo Motors** (SG90 or similar, for lid and stirrer)
- **Relay Module** (1-channel, 5V)
- **DC Fan** (5V or 12V, compatible with relay)
- **3x Push Buttons** (momentary, normally open)
- **2x LEDs** (Green and Red)
- **Buzzer** (5V active buzzer)
- **Resistors**:
  - 1x 4.7kΩ or 10kΩ (pull-up for DHT11)
  - 2x 220Ω (for LEDs)
- **Breadboard** and jumper wires
- **Power Supply**: USB cable for ESP32, external 5V/12V for fan (if needed)

### Software

- **Arduino IDE 1.8.13+** or **Arduino IDE 2.0+**
- **ESP32 Board Support** (via Board Manager)
- **Required Libraries** (install via Library Manager)

## Step 1: Install Arduino IDE and ESP32 Support

### 1.1 Install Arduino IDE

1. Download from: https://www.arduino.cc/en/software
2. Install Arduino IDE
3. Launch Arduino IDE

### 1.2 Add ESP32 Board Support

1. Open Arduino IDE
2. Go to **File > Preferences**
3. In "Additional Board Manager URLs", add:
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
4. Go to **Tools > Board > Boards Manager**
5. Search for "ESP32"
6. Install "esp32 by Espressif Systems"
7. Wait for installation to complete

### 1.3 Select ESP32 Board

1. Go to **Tools > Board > ESP32 Arduino**
2. Select your ESP32 board (e.g., "ESP32 Dev Module")

## Step 2: Install Required Libraries

### 2.1 Install Libraries via Library Manager

Go to **Sketch > Include Library > Manage Libraries** and install:

1. **ESP32Servo** by Kevin Harrington
2. **DHT sensor library** by Adafruit
3. **PubSubClient** by Nick O'Leary
4. **ArduinoJson** by Benoit Blanchon

### 2.2 Verify Library Installation

Libraries should appear in **Sketch > Include Library > Contributed Libraries**

## Step 3: Hardware Wiring

### 3.1 Pin Reference

| Component            | ESP32 Pin | Notes                     |
| -------------------- | --------- | ------------------------- |
| DHT11 Data           | GPIO 21   | Requires pull-up resistor |
| DHT11 VCC            | 3.3V      |                           |
| DHT11 GND            | GND       |                           |
| Lid Servo Signal     | GPIO 27   | PWM pin                   |
| Lid Servo VCC        | 5V        |                           |
| Lid Servo GND        | GND       |                           |
| Stirrer Servo Signal | GPIO 26   | PWM pin                   |
| Stirrer Servo VCC    | 5V        |                           |
| Stirrer Servo GND    | GND       |                           |
| Relay Signal         | GPIO 25   |                           |
| Relay VCC            | 5V        |                           |
| Relay GND            | GND       |                           |
| Buzzer               | GPIO 23   |                           |
| Green LED            | GPIO 18   | With 220Ω resistor        |
| Red LED              | GPIO 19   | With 220Ω resistor        |
| Lid Button           | GPIO 33   | Internal pull-up          |
| Relay Button         | GPIO 22   | Internal pull-up          |
| Stirrer Button       | GPIO 32   | Internal pull-up          |

### 3.2 Wiring Diagram

```
ESP32                    Components
------                    ----------
3.3V  ──────────────────── DHT11 VCC
GND   ──────────────────── DHT11 GND, Servos GND, Relay GND, LEDs GND, Buzzer GND
GPIO21 ───[4.7kΩ]─── VCC ─ DHT11 DATA
         └─────────────── DHT11 DATA

5V    ──────────────────── Servos VCC, Relay VCC
GPIO27 ──────────────────── Lid Servo Signal
GPIO26 ──────────────────── Stirrer Servo Signal
GPIO25 ──────────────────── Relay Signal (IN)

GPIO23 ──────────────────── Buzzer (+)
GPIO18 ───[220Ω]─────────── Green LED (+)
GPIO19 ───[220Ω]─────────── Red LED (+)

GPIO33 ──────────────────── Lid Button (one side)
                            Lid Button (other side) ──── GND
GPIO22 ──────────────────── Relay Button (one side)
                            Relay Button (other side) ──── GND
GPIO32 ──────────────────── Stirrer Button (one side)
                            Stirrer Button (other side) ──── GND

Relay Output:
  NO (Normally Open) ──── Fan (+)
  COM (Common) ────────── Power Supply (+)
  Fan (-) ──────────────── Power Supply (-)
```

### 3.3 Detailed Wiring Instructions

#### DHT11 Sensor

1. Connect DHT11 VCC to ESP32 3.3V
2. Connect DHT11 GND to ESP32 GND
3. Connect DHT11 DATA to ESP32 GPIO 21
4. Connect 4.7kΩ or 10kΩ resistor between DATA and VCC (pull-up)

#### Servo Motors

1. **Lid Servo**:

   - Signal wire (usually orange/yellow) → GPIO 27
   - VCC (red) → ESP32 5V
   - GND (brown/black) → ESP32 GND

2. **Stirrer Servo**:
   - Signal wire → GPIO 26
   - VCC → ESP32 5V
   - GND → ESP32 GND

**Note**: If servos draw too much current, use external 5V power supply with common GND.

#### Relay Module

1. Relay IN (signal) → GPIO 25
2. Relay VCC → ESP32 5V
3. Relay GND → ESP32 GND
4. Connect fan to relay NO (Normally Open) and COM terminals
5. Connect fan power supply to relay COM and fan negative terminal

#### LEDs

1. **Green LED**:

   - Anode (+) → GPIO 18 → 220Ω resistor → LED → GND
   - Cathode (-) → GND

2. **Red LED**:
   - Anode (+) → GPIO 19 → 220Ω resistor → LED → GND
   - Cathode (-) → GND

#### Buzzer

1. Positive terminal → GPIO 23
2. Negative terminal → GND

**Note**: Use active buzzer (5V). For passive buzzer, use PWM for tone control.

#### Buttons

1. **Lid Button**:

   - One terminal → GPIO 33
   - Other terminal → GND
   - ESP32 internal pull-up enabled in code

2. **Relay Button**:

   - One terminal → GPIO 22
   - Other terminal → GND

3. **Stirrer Button**:
   - One terminal → GPIO 32
   - Other terminal → GND

## Step 4: Configure Firmware

### 4.1 Open Firmware File

1. Open Arduino IDE
2. Open `hardware/main.ino`

### 4.2 Configure Wi-Fi

Edit the following lines:

```cpp
const char* WIFI_SSID = "Your_WiFi_SSID";
const char* WIFI_PASSWORD = "Your_WiFi_Password";
```

**Important**: ESP32 only supports 2.4GHz Wi-Fi networks (not 5GHz).

### 4.3 Configure MQTT Broker

Edit the following line:

```cpp
const char* MQTT_SERVER = "34.87.144.95";  // Your MQTT broker IP
```

### 4.4 Configure Time Zone (Optional)

Edit if needed:

```cpp
const long gmtOffset_sec = 8 * 3600;  // GMT+8 (adjust for your timezone)
```

## Step 5: Upload Firmware

### 5.1 Connect ESP32

1. Connect ESP32 to computer via USB cable
2. Wait for drivers to install (if needed)

### 5.2 Select Port

1. Go to **Tools > Port**
2. Select the COM port for your ESP32
   - Windows: COMx
   - Linux: /dev/ttyUSBx or /dev/ttyACMx
   - macOS: /dev/cu.usbserial-xxxxx

### 5.3 Upload Code

1. Click **Upload** button (→) or press Ctrl+U
2. Wait for compilation and upload to complete
3. You should see "Done uploading" message

### 5.4 Verify Upload

1. Open **Tools > Serial Monitor**
2. Set baud rate to **115200**
3. You should see initialization messages and sensor readings

## Step 6: Testing

### 6.1 Serial Monitor Output

You should see:

```
=== Starting Composting Prototype ===
Initializing DHT sensor...
DHT11 test read successful: 25.3°C, 60.0%
All hardware initialized successfully!
WiFi connection will be attempted in main loop...
WiFi connected!
IP address: 192.168.1.100
MQTT: Connected successfully!
Temperature: 25.3°C, Humidity: 60.0%
```

### 6.2 Test Sensors

1. Check Serial Monitor for temperature and humidity readings
2. Verify readings change when you breathe on sensor or change temperature
3. Green LED should be ON when sensor is working

### 6.3 Test Buttons

1. Press Lid Button → Lid should open/close
2. Press Relay Button → Fan should turn ON/OFF
3. Press Stirrer Button → Stirrer should start/stop

### 6.4 Test MQTT Communication

1. Subscribe to MQTT topic on your broker:
   ```bash
   mosquitto_sub -h YOUR_BROKER_IP -t compost/sensor/data -v
   ```
2. You should see JSON messages every 5 seconds

3. Test control commands:
   ```bash
   mosquitto_pub -h YOUR_BROKER_IP -t compost/cmd/fan -m "ON"
   ```
4. Fan should turn ON and status should be published

## Troubleshooting

### ESP32 Not Detected

**Problem**: ESP32 not showing in Port menu

**Solutions**:

1. Install USB-to-Serial drivers (CH340, CP2102, or FTDI)
2. Try different USB cable (data cable, not charge-only)
3. Try different USB port
4. Check Device Manager (Windows) for COM port

### Upload Fails

**Problem**: Upload error or timeout

**Solutions**:

1. Hold BOOT button while clicking Upload
2. Release BOOT button when "Connecting..." appears
3. Check USB cable connection
4. Try different USB port
5. Lower upload speed: Tools > Upload Speed > 115200

### DHT11 Not Reading

**Problem**: Sensor returns NaN or no readings

**Solutions**:

1. Check wiring (VCC, GND, DATA)
2. Verify pull-up resistor (4.7kΩ-10kΩ) between DATA and VCC
3. Check power supply (3.3V or 5V)
4. Try different DHT11 sensor
5. Add delay after power-on (sensor needs time to stabilize)

### Wi-Fi Connection Fails

**Problem**: Cannot connect to Wi-Fi

**Solutions**:

1. Verify SSID and password are correct
2. Ensure Wi-Fi is 2.4GHz (ESP32 doesn't support 5GHz)
3. Check Wi-Fi signal strength
4. Try moving ESP32 closer to router
5. Check router settings (MAC filtering, etc.)

### MQTT Connection Fails

**Problem**: Cannot connect to MQTT broker

**Solutions**:

1. Verify MQTT broker IP and port are correct
2. Test MQTT broker accessibility:
   ```bash
   mosquitto_sub -h YOUR_BROKER_IP -t test/topic
   ```
3. Check firewall rules (port 1883)
4. Verify network connectivity
5. Check MQTT broker logs

### Servo Not Moving

**Problem**: Servo doesn't respond to commands

**Solutions**:

1. Check servo wiring (signal, VCC, GND)
2. Verify servo is receiving power (5V)
3. Check if servo is compatible (standard servos work best)
4. Test servo with simple test code
5. Use external 5V power supply if ESP32 5V is insufficient

### Relay Not Switching

**Problem**: Relay doesn't turn fan ON/OFF

**Solutions**:

1. Check relay wiring (signal, VCC, GND)
2. Verify relay module is active LOW or active HIGH (check module type)
3. Test relay with simple test code
4. Check fan power supply connection
5. Verify relay contacts (NO/COM) are connected correctly

### Buttons Not Working

**Problem**: Buttons don't trigger actions

**Solutions**:

1. Check button wiring (one side to GPIO, other to GND)
2. Verify internal pull-up is enabled in code
3. Test button continuity with multimeter
4. Check for button bounce (code includes debouncing)

### System Fault LED Blinking

**Problem**: Red LED blinks indicating fault

**Solutions**:

1. Check Serial Monitor for error messages
2. Verify sensor is working (green LED should be ON)
3. Check Wi-Fi and MQTT connections
4. Review fault detection logic in code

## Power Supply Considerations

### USB Power

- ESP32 can be powered via USB (5V)
- Sufficient for development and testing
- May be insufficient for all components (servos, fan)

### External Power Supply

- Use external 5V/3A power supply for production
- Connect to ESP32 VIN pin (if supported) or 5V pin
- Ensure common GND connection
- Use appropriate power supply for fan (5V or 12V)

### Power Consumption

- ESP32: ~80-240mA (depending on Wi-Fi usage)
- Servos: ~100-500mA each (when moving)
- Fan: Depends on fan type (check specifications)
- Total: May require 1-2A power supply for all components

## Safety Notes

1. **Electrical Safety**:

   - Double-check all connections before powering on
   - Use appropriate voltage levels (3.3V for sensors, 5V for servos)
   - Ensure proper GND connections

2. **Component Protection**:

   - Use current-limiting resistors for LEDs
   - Use pull-up resistors for DHT11
   - Protect ESP32 from overvoltage

3. **Mechanical Safety**:
   - Ensure servos have proper mounting
   - Test lid and stirrer movements before full operation
   - Avoid pinching or crushing hazards

## Next Steps

- Verify all components are working
- Test MQTT communication with backend
- Calibrate sensor readings if needed
- Deploy to compost container location
- Monitor Serial output for any issues

## Additional Resources

- [ESP32 Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/)
- [Arduino ESP32 Reference](https://github.com/espressif/arduino-esp32)
- [DHT11 Datasheet](https://www.mouser.com/datasheet/2/758/DHT11-Technical-Data-Sheet-Translated-Version-1143054.pdf)
- [MQTT Protocol](https://mqtt.org/)
