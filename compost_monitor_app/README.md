# Compost Monitor Mobile App

Flutter mobile application for the IoT Compost Monitoring System, providing real-time monitoring, historical data visualization, and remote device control.

## Purpose

The mobile app serves as the user interface for the compost monitoring system:

- **Real-Time Monitoring**: Live temperature and humidity data via MQTT connection
- **Historical Visualization**: View sensor data trends over time (1, 7, 30 days)
- **Device Control**: Remote control of fan, lid, and stirrer devices
- **Batch Management**: Create and manage compost batches with lifecycle tracking
- **Analytics**: View compost completion status and optimization recommendations

## Features

### Real-Time Monitoring

- Live temperature and humidity gauges
- Real-time device status indicators (fan, lid, stirrer)
- MQTT-based low-latency updates
- Visual feedback for device state changes

### Historical Data

- Interactive line charts for temperature and humidity
- Time range selection (1, 7, 30 days)
- Data point markers for device activations
- Smooth animations and responsive UI

### Device Control

- Manual control buttons for fan, lid, and stirrer
- Real-time status feedback
- Loading indicators during command execution
- Confirmation messages for successful operations

### Batch Management

- Create new compost cycles/batches
- View current active cycle information
- Track cycle lifecycle (planning, active, completed statuses)
- Cycle progress indicators
- View all cycles, active cycles, and completed cycles in separate tabs

### Analytics

- **Completed Cycles Analytics**: Single analytics page showing comprehensive statistics and trends
  - Summary statistics: Total completed cycles, average composting days, total waste processed, average temperature
  - **Temperature Trend Chart**: Monthly average temperature trends over time
  - **Humidity Trend Chart**: Monthly average humidity trends over time
  - **Total Waste Trend Chart**: Monthly total waste processed trends
  - Cycles completed by month visualization
- Compost completion status calculation
- C:N ratio calculations for waste optimization

### Settings

- Configurable MQTT broker URL
- Configurable API base URL
- Persistent settings storage
- Connection status indicators

## Architecture

### State Management

- **Provider Pattern**: Used for state management across the app
- **Providers**:
  - `SensorProvider` - Real-time sensor data from MQTT
  - `ChartDataProvider` - Historical chart data
  - `DeviceControlProvider` - Device control operations
  - `CompostBatchProvider` - Batch management
  - `CycleProvider` - Cycle management
  - `OptimizationProvider` - Analytics and optimization

### Communication

- **MQTT**: Real-time sensor data and device control
  - Library: `mqtt_client`
  - Topics: `compost/sensor/data`, `compost/cmd/*`, `compost/status/*`
- **HTTP REST**: Historical data and batch management
  - Library: `http`
  - Base URL: Configurable (default: `http://34.87.144.95:8000/api/v1`)

### UI Components

- **Charts**: `fl_chart` for line charts
- **Gauges**: `syncfusion_flutter_gauges` for temperature/humidity gauges
- **Theme**: Custom app theme with Material Design

## Project Structure

```
compost_monitor_app/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── models/                      # Data models
│   │   ├── sensor_data.dart
│   │   ├── compost_batch.dart
│   │   ├── device_status.dart
│   │   └── ...
│   ├── services/                    # Service layer
│   │   ├── api_service.dart         # HTTP API client
│   │   ├── mqtt_service.dart        # MQTT client
│   │   └── config_service.dart      # Settings management
│   ├── providers/                   # State management
│   │   ├── sensor_provider.dart
│   │   ├── chart_data_provider.dart
│   │   ├── device_control_provider.dart
│   │   └── ...
│   ├── screens/                     # App screens
│   │   ├── dashboard_screen.dart    # Main dashboard
│   │   ├── chart_screen.dart        # Historical charts
│   │   ├── control_screen.dart      # Device control
│   │   ├── cycle_management_screen.dart
│   │   └── settings_screen.dart
│   ├── widgets/                     # Reusable widgets
│   │   ├── temperature_gauge.dart
│   │   ├── humidity_gauge.dart
│   │   ├── chart_widget.dart
│   │   └── ...
│   └── theme/
│       └── app_theme.dart            # App theme
├── android/                          # Android-specific files
├── pubspec.yaml                      # Dependencies
├── README.md                         # This file
└── SETUP.md                          # Setup guide
```

## Quick Start

### Prerequisites

- Flutter SDK 3.0.0 or higher
- Android Studio / Xcode (for mobile development)
- Backend API running and accessible
- MQTT broker accessible

### Basic Setup

1. **Install Flutter dependencies**:

   ```bash
   cd compost_monitor_app
   flutter pub get
   ```

2. **Configure backend URLs** (optional):

   - Default MQTT: `tcp://34.87.144.95:1883`
   - Default API: `http://34.87.144.95:8000/api/v1`
   - Can be changed in Settings screen after app launch

3. **Run the app**:
   ```bash
   flutter run
   ```

For detailed setup instructions, see [SETUP.md](SETUP.md).

## Dependencies

Key dependencies (see `pubspec.yaml` for complete list):

- `flutter` - Flutter SDK
- `provider: ^6.1.1` - State management
- `mqtt_client: ^10.0.0` - MQTT client
- `http: ^1.1.0` - HTTP client
- `fl_chart: ^0.65.0` - Charts
- `syncfusion_flutter_gauges: ^24.1.41` - Gauges
- `intl: ^0.18.1` - Internationalization
- `shared_preferences: ^2.2.2` - Settings storage

## Screens

### Dashboard Screen

- Real-time temperature and humidity gauges
- Current device status
- Quick access to other screens

### Chart Screen

- Historical temperature and humidity charts
- Time range selection
- Device activation markers

### Control Screen

- Manual device control buttons
- Real-time status feedback
- Device state indicators

### Cycle Management Screen

- Tab-based interface with four views:
  - **All**: View all compost cycles
  - **Active**: View currently active cycles
  - **Completed**: View completed cycles
  - **Analytics**: Completed cycles analytics (temperature, humidity, and total waste trends)
- Create new compost cycles
- View cycle details and progress
- Activate cycles (deactivates other active cycles)
- Note: Cycles can have "planning" status, but there is no separate planning page/tab

### Settings Screen

- MQTT broker configuration
- API endpoint configuration
- Connection status

## MQTT Topics

### Subscribed Topics

- `compost/sensor/data` - Real-time sensor data from ESP32

### Published Topics

- `compost/cmd/fan` - Fan control commands (ON/OFF)
- `compost/cmd/lid` - Lid control commands (OPEN/CLOSED)
- `compost/cmd/stirrer` - Stirrer control commands (ON/OFF)

### Status Topics

- `compost/status/fan` - Fan status feedback
- `compost/status/lid` - Lid status feedback
- `compost/status/stirrer` - Stirrer status feedback

## API Endpoints Used

- `GET /api/v1/sensor-data?days=7` - Historical sensor data
- `GET /api/v1/compost-batch/current` - Current active batch
- `POST /api/v1/compost-batch` - Create new batch
- `GET /api/v1/analytics/completion-status` - Completion status
- `GET /api/v1/analytics/completed-cycles` - Completed cycles analytics (temperature, humidity, waste trends)

## Configuration

### Default Settings

- MQTT Broker: `tcp://34.87.144.95:1883`
- API Base URL: `http://34.87.144.95:8000/api/v1`

### Changing Settings

1. Open the app
2. Navigate to Settings screen
3. Update MQTT broker URL or API base URL
4. Settings are saved automatically using `shared_preferences`

## Building for Production

### Android

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS

```bash
flutter build ios --release
```
