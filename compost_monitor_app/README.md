# Compost Monitor Mobile App

Flutter mobile application for IoT Compost Monitoring System.

## Features

- **Real-time Monitoring**: Live temperature and humidity data via MQTT
- **Historical Charts**: View sensor data over time (1, 7, or 30 days)
- **Device Control**: Control fan, lid, and stirrer remotely
- **Batch Tracking**: Monitor compost batch progress and completion status
- **Settings**: Configure MQTT broker and API endpoints

## Setup

1. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

2. **Configure backend URLs:**
   - Default MQTT: `tcp://34.87.144.95:1883`
   - Default API: `http://34.87.144.95:8000/api/v1`
   - Can be changed in Settings screen

3. **Run the app:**
   ```bash
   flutter run
   ```

## Project Structure

- `lib/models/` - Data models
- `lib/services/` - MQTT and API services
- `lib/providers/` - State management
- `lib/screens/` - App screens
- `lib/widgets/` - Reusable widgets
- `lib/theme/` - App theme configuration

## Requirements

- Flutter SDK 3.0.0 or higher
- Backend API running (FastAPI)
- MQTT broker accessible
- Active compost batch in database

## Backend Connection

The app connects to:
- **MQTT Broker**: For real-time sensor data and device control
- **FastAPI Backend**: For historical data and batch information

See `cloud/API_DOCS.md` for API endpoint documentation.

