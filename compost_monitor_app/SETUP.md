# Flutter App Setup Guide

This guide provides step-by-step instructions for setting up and building the Compost Monitor mobile application.

## Prerequisites

### Required Software

- **Flutter SDK 3.0.0 or higher**
  - Download from: https://flutter.dev/docs/get-started/install
  - Verify installation: `flutter doctor`

- **Android Studio** (for Android development)
  - Download from: https://developer.android.com/studio
  - Install Android SDK and emulator

- **Xcode** (for iOS development, macOS only)
  - Available from Mac App Store
  - Required for iOS builds

- **Code Editor** (optional but recommended)
  - VS Code with Flutter extension
  - Android Studio IDE

### System Requirements

- **Windows**: Windows 10 or higher
- **macOS**: macOS 10.14 or higher (for iOS development)
- **Linux**: Ubuntu 18.04 or higher
- **RAM**: 4GB minimum, 8GB recommended
- **Disk Space**: 2GB for Flutter SDK + dependencies

## Step 1: Install Flutter

### 1.1 Download Flutter SDK

```bash
# Download Flutter SDK from https://flutter.dev/docs/get-started/install
# Extract to a location (e.g., C:\flutter on Windows, ~/flutter on Linux/macOS)
```

### 1.2 Add Flutter to PATH

**Windows**:
1. Add Flutter bin directory to system PATH
2. Example: `C:\flutter\bin`

**Linux/macOS**:
```bash
export PATH="$PATH:$HOME/flutter/bin"
# Add to ~/.bashrc or ~/.zshrc for permanent
```

### 1.3 Verify Installation

```bash
flutter doctor
```

This will check your setup and show any missing dependencies.

### 1.4 Install Additional Dependencies

Follow `flutter doctor` recommendations to install:
- Android toolchain (for Android development)
- Xcode (for iOS development, macOS only)
- VS Code or Android Studio plugins

## Step 2: Clone/Download Project

### 2.1 Navigate to Project Directory

```bash
cd compost_monitor_app
```

### 2.2 Verify Project Structure

Ensure you have:
- `pubspec.yaml` - Dependencies file
- `lib/` - Source code directory
- `android/` - Android-specific files
- `ios/` - iOS-specific files (if available)

## Step 3: Install Dependencies

### 3.1 Get Flutter Packages

```bash
flutter pub get
```

This will download all dependencies listed in `pubspec.yaml`.

### 3.2 Verify Dependencies

```bash
flutter pub deps
```

## Step 4: Configure Backend Connection

### 4.1 Default Configuration

The app comes with default backend URLs:
- **MQTT Broker**: `tcp://34.87.144.95:1883`
- **API Base URL**: `http://34.87.144.95:8000/api/v1`

### 4.2 Change Configuration (Optional)

You can change these settings:
1. Run the app
2. Navigate to Settings screen
3. Update MQTT broker URL or API base URL
4. Settings are saved automatically

### 4.3 Verify Backend Accessibility

Before running the app, ensure:
- Backend API is running and accessible
- MQTT broker is running and accessible
- Network connectivity is available

Test API:
```bash
curl http://YOUR_API_URL/health
```

Test MQTT:
```bash
mosquitto_sub -h YOUR_MQTT_BROKER -t test/topic
```

## Step 5: Run the App

### 5.1 List Available Devices

```bash
flutter devices
```

### 5.2 Run on Connected Device/Emulator

```bash
# Run in debug mode
flutter run

# Run in release mode
flutter run --release
```

### 5.3 Run on Specific Device

```bash
flutter run -d <device-id>
```

## Step 6: Build for Production

### 6.1 Build Android APK

```bash
# Debug APK
flutter build apk

# Release APK (optimized)
flutter build apk --release

# Split APK by ABI (smaller file size)
flutter build apk --split-per-abi
```

**Output**: `build/app/outputs/flutter-apk/app-release.apk`

### 6.2 Build Android App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

**Output**: `build/app/outputs/bundle/release/app-release.aab`

### 6.3 Build iOS (macOS only)

```bash
# Build for iOS
flutter build ios --release

# Build IPA for distribution
flutter build ipa
```

**Note**: Requires Xcode and Apple Developer account for distribution.

## Step 7: Platform-Specific Setup

### 7.1 Android Setup

#### Configure AndroidManifest.xml

Check `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

#### Configure build.gradle

Check `android/app/build.gradle`:
- Minimum SDK version: 21 (Android 5.0)
- Target SDK version: Latest stable

#### Signing Configuration (for release builds)

1. Generate keystore:
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Create `android/key.properties`:
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<path-to-keystore>
```

3. Update `android/app/build.gradle` to use signing config.

### 7.2 iOS Setup (macOS only)

#### Configure Info.plist

Check `ios/Runner/Info.plist`:
- Add network permissions if needed

#### Configure Podfile

```bash
cd ios
pod install
```

#### Xcode Configuration

1. Open `ios/Runner.xcworkspace` in Xcode
2. Configure signing & capabilities
3. Set deployment target (iOS 11.0+)

## Step 8: Testing

### 8.1 Run Tests

```bash
flutter test
```

### 8.2 Run on Emulator

**Android Emulator**:
1. Open Android Studio
2. Tools > Device Manager
3. Create/Start emulator
4. Run: `flutter run`

**iOS Simulator** (macOS only):
1. Open Xcode
2. Xcode > Open Developer Tool > Simulator
3. Select device
4. Run: `flutter run`

## Troubleshooting

### Flutter Doctor Issues

**Problem**: Flutter doctor shows errors

**Solutions**:
1. Follow `flutter doctor` recommendations
2. Install missing dependencies
3. Accept Android licenses: `flutter doctor --android-licenses`

### Dependency Issues

**Problem**: `flutter pub get` fails

**Solutions**:
1. Check internet connection
2. Clear Flutter cache: `flutter clean`
3. Update Flutter: `flutter upgrade`
4. Delete `pubspec.lock` and run `flutter pub get` again

### Build Errors

**Problem**: Build fails with errors

**Solutions**:
1. Clean build: `flutter clean`
2. Get dependencies: `flutter pub get`
3. Check Flutter version: `flutter --version`
4. Check platform-specific setup (Android/iOS)
5. Review error messages for specific issues

### MQTT Connection Issues

**Problem**: App cannot connect to MQTT broker

**Solutions**:
1. Verify MQTT broker is running
2. Check MQTT broker URL in Settings
3. Test MQTT connection manually:
   ```bash
   mosquitto_sub -h YOUR_BROKER -t test/topic
   ```
4. Check network connectivity
5. Verify firewall rules (port 1883)

### API Connection Issues

**Problem**: App cannot connect to API

**Solutions**:
1. Verify API server is running
2. Check API base URL in Settings
3. Test API endpoint:
   ```bash
   curl http://YOUR_API_URL/health
   ```
4. Check CORS settings on API server
5. Verify network connectivity

### App Crashes on Startup

**Problem**: App crashes immediately after launch

**Solutions**:
1. Check device logs: `flutter logs`
2. Verify backend services are running
3. Check app permissions (internet access)
4. Clear app data and reinstall
5. Run in debug mode for detailed error messages

### No Sensor Data Displayed

**Problem**: Dashboard shows no sensor data

**Solutions**:
1. Verify ESP32 is publishing to MQTT
2. Check MQTT connection status in app
3. Verify MQTT topic: `compost/sensor/data`
4. Check MQTT broker logs
5. Test MQTT subscription manually

### Build APK Size Too Large

**Problem**: APK file is very large

**Solutions**:
1. Use split APK: `flutter build apk --split-per-abi`
2. Enable ProGuard/R8 (Android)
3. Remove unused assets
4. Use app bundle instead: `flutter build appbundle`

## Development Tips

### Hot Reload

- Press `r` in terminal during `flutter run`
- Or use IDE hot reload button
- Fast refresh for UI changes

### Hot Restart

- Press `R` in terminal during `flutter run`
- Or use IDE hot restart button
- Full app restart for state changes

### Debug Mode

- Run: `flutter run` (default is debug mode)
- Includes debugging tools and verbose logging
- Slower performance

### Release Mode

- Run: `flutter run --release`
- Optimized performance
- No debugging tools

### View Logs

```bash
# Device logs
flutter logs

# Specific device
flutter logs -d <device-id>
```

## Performance Optimization

### Release Build

Always use release builds for production:
```bash
flutter build apk --release
```

### Enable ProGuard (Android)

In `android/app/build.gradle`:
```gradle
buildTypes {
    release {
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
    }
}
```

### Optimize Images

- Use appropriate image formats
- Compress images before adding to assets
- Use network images when possible

## Next Steps

- Connect to backend API and MQTT broker
- Test all app features
- Build release APK for distribution
- Configure app signing for Play Store/App Store

## Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Flutter Cookbook](https://flutter.dev/docs/cookbook)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Provider Package](https://pub.dev/packages/provider)
- [MQTT Client Package](https://pub.dev/packages/mqtt_client)

