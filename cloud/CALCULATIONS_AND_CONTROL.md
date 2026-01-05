# Compost Calculations and Control Logic

## Overview

This document explains where calculation logic and automated control logic are located in the codebase.

---

## File Structure

### 1. `compost_calculations.py` - Calculation Utilities Module

**Location:** `cloud/compost_calculations.py`

**Purpose:** Centralized calculation functions for:
- C:N ratio calculations
- Temperature control logic
- Humidity control logic
- Combined control recommendations

**Functions:**

#### `calculate_cn_ratio(green_kg, brown_kg)`
- Calculates C:N ratio based on green and brown waste amounts
- Returns optimal ratio suggestions
- Used by: `main.py` API endpoints

#### `check_temperature_control(temp, optimal_min=55.0, optimal_max=65.0)`
- Determines temperature control actions
- Optimal range: **55-65°C (131-149°F)** for hot aerobic composting
- Returns fan and lid control recommendations

#### `check_humidity_control(humidity, optimal_min=50.0, optimal_max=60.0)`
- Determines humidity control actions
- Optimal range: **50-60%** water (by weight)
- Returns fan control recommendations

#### `get_combined_control_recommendation(temp, humidity)`
- Combines temperature and humidity control logic
- Priority: Temperature > Humidity
- Returns final control recommendations for fan and lid

---

### 2. `mqtt_listener.py` - Automated Control Service

**Location:** `cloud/mqtt_listener.py`

**Purpose:** Real-time sensor monitoring and automated device control

**Key Method:** `check_thresholds_and_control(data)`
- Called automatically when new sensor data is received
- Uses `get_combined_control_recommendation()` from `compost_calculations.py`
- Publishes MQTT commands to control fan and lid
- Logs all control actions

**Control Logic:**
- **Temperature Control:**
  - < 55°C: Fan OFF, Lid CLOSED (retain heat)
  - 55-65°C: Maintain current state (optimal)
  - > 65°C: Fan ON, Lid OPEN (cooling)
  - > 70°C: Fan ON, Lid OPEN (emergency cooling)

- **Humidity Control:**
  - < 50%: Fan OFF (retain moisture)
  - 50-60%: Maintain current state (optimal)
  - > 60%: Fan ON (dehumidification)

- **Priority:** Temperature control takes priority over humidity control

---

### 3. `main.py` - API Endpoints

**Location:** `cloud/main.py`

**Purpose:** HTTP API for Flutter app

**Uses `compost_calculations.py`:**
- `calculate_cn_ratio()` - Used in `/api/v1/cycles/{id}/calculate-ratio` endpoint
- All C:N ratio calculations go through the centralized function

---

### 4. `config.py` - Configuration

**Location:** `cloud/config.py`

**Purpose:** Configuration values for optimal ranges

**New Configuration Values:**
```python
# Optimal ranges for hot aerobic composting
TEMP_OPTIMAL_MIN = 55.0  # °C
TEMP_OPTIMAL_MAX = 65.0  # °C
TEMP_CRITICAL_HIGH = 70.0  # °C (emergency threshold)

HUMIDITY_OPTIMAL_MIN = 50.0  # %
HUMIDITY_OPTIMAL_MAX = 60.0  # %
```

**Note:** These can be overridden via environment variables in `.env` file.

---

## Control Flow

### Automated Control (Real-time)

```
ESP32 Sensor Data
    ↓
MQTT Topic: compost/sensor/data
    ↓
mqtt_listener.py receives message
    ↓
check_thresholds_and_control() called
    ↓
get_combined_control_recommendation() from compost_calculations.py
    ↓
Publish MQTT commands (fan/lid)
    ↓
Hardware responds
```

### Manual C:N Ratio Calculation (API)

```
Flutter App Request
    ↓
POST /api/v1/cycles/{id}/calculate-ratio
    ↓
main.py endpoint
    ↓
calculate_cn_ratio() from compost_calculations.py
    ↓
Return C:N ratio and suggestions
```

---

## Optimal Ranges

### Temperature
- **Optimal Range:** 55-65°C (131-149°F)
- **Too Low:** < 55°C → Close lid, turn off fan (retain heat)
- **Too High:** > 65°C → Open lid, turn on fan (cooling)
- **Critical:** > 70°C → Emergency lid opening

### Humidity
- **Optimal Range:** 50-60% water (by weight)
- **Too Low:** < 50% → Turn off fan (retain moisture)
- **Too High:** > 60% → Turn on fan (dehumidification)

---

## Adding New Calculations

To add new calculation logic:

1. **Add function to `compost_calculations.py`:**
   ```python
   def your_new_calculation(param1, param2):
       # Your logic here
       return result
   ```

2. **Import in the file that needs it:**
   ```python
   from compost_calculations import your_new_calculation
   ```

3. **Use in your code:**
   ```python
   result = your_new_calculation(value1, value2)
   ```

---

## Testing

### Test C:N Ratio Calculation
```python
from compost_calculations import calculate_cn_ratio
result = calculate_cn_ratio(10.0, 20.0)  # 10kg green, 20kg brown
print(result)
```

### Test Temperature Control
```python
from compost_calculations import check_temperature_control
result = check_temperature_control(70.0)  # 70°C
print(result)
```

### Test Combined Control
```python
from compost_calculations import get_combined_control_recommendation
result = get_combined_control_recommendation(70.0, 65.0)  # temp, humidity
print(result)
```

---

## Notes

- All calculation logic is centralized in `compost_calculations.py` for maintainability
- Control logic runs automatically in `mqtt_listener.py` when sensor data is received
- Optimal ranges can be configured via environment variables
- Temperature control takes priority over humidity control
- All control actions are logged for debugging and monitoring

