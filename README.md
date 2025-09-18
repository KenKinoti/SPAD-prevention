# RailSafe SPAD Prevention POC

A Flutter mobile application that uses a device's camera and machine learning to detect railway signals and prevent Signal Passed At Danger (SPAD) incidents.

## ⚠️ Important Safety Notice

**THIS IS A PROOF OF CONCEPT ONLY**

- This is NOT a certified safety system
- It is a driver aid POC and must be treated as such
- Never rely solely on this app for safety-critical decisions
- Always follow established railway safety protocols

## Features

### Core Functionality

- ✅ Real-time camera feed access
- ✅ Signal detection and classification (Red, Green, Yellow, Unknown)
- ✅ Distance estimation using pinhole camera model
- ✅ Critical alert system for red signals within 100m
- ✅ Visual, audible, and haptic warnings
- ✅ Detection history and logging
- ✅ Start/Stop detection controls
- ✅ **Training data collection system for ML model development**
- ✅ **TensorFlow Lite integration with fallback detection**

### Alert System

- **Visual Alerts**: Full-screen red flash with warning text "STOP! RED SIGNAL AHEAD"
- **Audible Alerts**: Loud siren sound with system sound fallback
- **Haptic Feedback**: Strong vibration patterns
- **Critical Threshold**: Red signal within 100 meters

### User Interface

- Home screen with safety warning and train icon
- Camera viewfinder with real-time overlay
- Bounding boxes around detected signals
- Signal state and distance display
- Detection confidence indicator
- History screen with detailed logs and statistics
- Filtering options for alarm events
- **Training screen for collecting ML training data**
- **Real-time training statistics and progress tracking**

## Technical Stack

- **Framework**: Flutter 3.35.4
- **Camera**: camera ^0.10.5+5
- **ML Processing**: tflite_flutter ^0.10.4 (with simulation for demo)
- **Audio**: audioplayers ^5.2.1
- **Permissions**: permission_handler ^11.0.1
- **Image Processing**: image ^4.1.3
- **Storage**: path_provider ^2.1.1

## Installation & Testing

### Prerequisites

1. **Flutter SDK** (3.35.4+) - [Installation Guide](https://docs.flutter.dev/get-started/install)
2. **Android Studio** (already installed) ✅
3. **Android SDK** version 26+ (required for TensorFlow Lite)
4. **Java Development Kit (JDK)** 11 or 17

### Environment Setup

1. **Verify Flutter Installation**
   ```bash
   flutter doctor
   ```

2. **Install Dependencies**
   ```bash
   cd "D:\DASYIN\SPAD - Analyser"
   flutter pub get
   ```

3. **Android Licenses** (if needed)
   ```bash
   flutter doctor --android-licenses
   ```

### 📱 Android Testing Setup

#### Step 1: Create Virtual Device

1. **Open Android Studio**
2. **Open AVD Manager**: Tools → AVD Manager
3. **Create New AVD**:
   - Select **Pixel 7** or **Pixel 6** (recommended)
   - Choose **API 33** (Android 13) or **API 34** (Android 14)
   - Select **x86_64** image for better performance

#### Step 2: Configure AVD for Camera Testing

1. **AVD Name**: `RailSafe_Test_Device`
2. **Advanced Settings**:
   - **RAM**: 4096 MB (minimum for smooth performance)
   - **Internal Storage**: 6 GB
   - **Camera Front/Back**: Webcam0 (enables camera functionality)
   - **Graphics**: Hardware - GLES 2.0

#### Step 3: Launch and Test

1. **Start Emulator**:
   ```bash
   flutter emulators --launch RailSafe_Test_Device
   ```

2. **Run the App**:
   ```bash
   cd "D:\DASYIN\SPAD - Analyser"
   flutter run
   ```

3. **Expected Behavior**:
   - App installs automatically on AVD
   - Grants camera permissions when prompted
   - Shows camera viewfinder with detection overlays

### 🧪 Testing the RailSafe SPAD App

#### Functionality Test Checklist

1. **App Launch**:
   - ✅ App opens to home screen with safety warning
   - ✅ Train icon and "RailSafe SPAD POC" title displayed
   - ✅ "START DETECTION" button visible

2. **Camera Permission & Access**:
   - ✅ Tap "START DETECTION"
   - ✅ Camera permission requested and granted
   - ✅ Camera screen loads with live feed

3. **Detection Interface**:
   - ✅ Tap green "START" button to begin detection
   - ✅ Status shows "Detecting signals..."
   - ✅ Detection info overlay appears (top of screen)

4. **Mock Signal Detection** (Every 3-10 seconds):
   - ✅ Colored bounding boxes appear on screen
   - ✅ Signal state displayed (RED/GREEN/YELLOW/UNKNOWN)
   - ✅ Distance values shown (10-1000m range)
   - ✅ Confidence percentage displayed

5. **Critical Alert System** (When red signal ≤ 100m):
   - ✅ Screen flashes bright red
   - ✅ "STOP! RED SIGNAL AHEAD" message appears
   - ✅ Warning icon displayed
   - ✅ Device vibrates repeatedly
   - ✅ Alarm sound plays (with fallback to system sound)

6. **Detection History**:
   - ✅ Tap history button (bottom right)
   - ✅ History screen shows logged detections
   - ✅ Statistics displayed (Total, Red Signals, Alarms)
   - ✅ Filter toggle for "Show only alarms"
   - ✅ Individual detection cards with timestamps

7. **Training Data Collection**:
   - ✅ Blue "TRAINING" button accessible from camera screen
   - ✅ Training screen with live camera preview
   - ✅ Signal type selection (Red/Green/Yellow/None)
   - ✅ Optional description input field
   - ✅ Real-time training statistics display
   - ✅ Successful image capture and storage

8. **App Controls**:
   - ✅ Back button returns to home screen
   - ✅ Stop button ends detection
   - ✅ Clear history function works
   - ✅ Navigation between screens smooth

#### Performance Benchmarks

- **App launch**: < 3 seconds
- **Camera activation**: < 2 seconds
- **Detection simulation**: 3-10 second intervals
- **Alert trigger latency**: < 500ms
- **History loading**: < 1 second

### 🔧 Troubleshooting

#### Common Issues & Solutions

**1. "Flutter SDK not found"**
```bash
# Verify Flutter installation
flutter doctor -v
# Add Flutter to PATH if needed
```

**2. "Camera permission denied"**
- In AVD: Settings → Apps → RailSafe SPAD POC → Permissions → Camera → Allow
- Or uninstall/reinstall app to re-trigger permission request

**3. "Build failed - Android SDK"**
```bash
# Accept Android licenses
flutter doctor --android-licenses
# Update Android SDK tools in Android Studio
```

**4. "No connected devices"**
```bash
# Check connected devices
flutter devices
# Restart ADB if needed
adb kill-server
adb start-server
```

**5. "Gradle build failed"**
```bash
# Clean build
flutter clean
flutter pub get
flutter run
```

**6. "TensorFlow Lite errors"**
- This is expected - app uses simulation mode for demo
- Real TensorFlow Lite integration would require trained model

#### Performance Tips

- **Emulator**: Enable hardware acceleration for better camera performance
- **Physical Device**: Use real Android device for accurate camera testing
- **Memory**: Close other apps while testing

### Quick Start Commands

```bash
# 1. Navigate to project
cd "D:\DASYIN\SPAD - Analyser"

# 2. Get dependencies
flutter pub get

# 3. Run on connected device/emulator
flutter run

# 4. For release build
flutter build apk --release
```

## Usage Guide

### Basic Operation

1. **Launch App**: Open RailSafe SPAD POC
2. **Read Safety Warning**: Review the safety notice on home screen
3. **Start Detection**: Tap "START DETECTION" button
4. **Grant Permissions**: Allow camera access when prompted
5. **Begin Monitoring**: Tap green "START" button in camera view
6. **Monitor Display**: Watch for signal detection overlays
7. **Respond to Alerts**: Stop immediately if red screen alarm triggers
8. **View History**: Tap history icon to review detections
9. **Stop Detection**: Tap red "STOP" button when finished

### Understanding the Interface

**Home Screen:**
- Safety warning with train icon
- Clear disclaimer about POC nature
- Single "START DETECTION" button

**Camera Screen:**
- Live camera feed as background
- Detection status overlay (top)
- Signal classification with confidence
- Distance estimation display
- Bounding boxes around detected signals
- Control buttons (back, start/stop, history)

**History Screen:**
- Detection statistics summary
- Chronological list of all detections
- Filter toggle for alarm events only
- Individual cards showing signal type, distance, confidence, timestamp
- Clear history option

**Alert Mode:**
- Full red screen overlay
- Large warning icon and text
- "STOP! RED SIGNAL AHEAD" message
- Automatic audio and vibration alerts

## Project Structure

```
lib/
├── main.dart                       # App entry point and home screen
├── models/
│   └── detection_result.dart       # Data models for detections
├── screens/
│   ├── camera_screen.dart          # Main camera interface with training access
│   ├── history_screen.dart         # Detection history view
│   └── training_screen.dart        # Training data collection interface
└── services/
    ├── signal_detector.dart        # Color-based detection (current)
    ├── ml_signal_detector.dart     # TensorFlow Lite ML detector
    ├── training_data_collector.dart # Training image capture and storage
    ├── alert_service.dart          # Alert management
    └── detection_logger.dart       # History logging
```

## Configuration

Key parameters in the application:

- **Critical Distance**: 100m (red signal alert threshold)
- **Standard Signal Height**: 30cm (for distance calculation)
- **Detection Confidence**: Variable (displayed as percentage)
- **Alert Duration**: Continuous until signal changes
- **History Limit**: 1000 detections maximum

## Machine Learning Integration

### 🎯 **Training Data Collection System**

The app now includes a comprehensive training data collection system:

**Training Screen Features:**
- Live camera preview for real-time data capture
- Signal type selection: Red, Green, Yellow, None (backgrounds)
- Optional description field for sample labeling
- Real-time statistics showing collected samples per category
- Organized storage in categorized folders

**Training Data Organization:**
```
Documents/training_data/
├── red_signals/       # Red signal samples
├── green_signals/     # Green signal samples
├── yellow_signals/    # Yellow signal samples
├── no_signals/        # Background/negative samples
└── dataset_info.csv   # Export manifest for training
```

**How to Collect Training Data:**
1. Open the app and navigate to camera screen
2. Tap the blue **"TRAINING"** button
3. Select signal type (Red/Green/Yellow/None)
4. Point camera at target signal or background
5. Add optional description
6. Tap **"CAPTURE"** to save training image
7. Repeat for diverse conditions and angles

### 🤖 **ML Model Integration Architecture**

**Current Implementation:**
- **MLSignalDetector** service with TensorFlow Lite integration
- Automatic fallback to color-based detection when no model is available
- Camera frame preprocessing and model inference pipeline
- Confidence scoring and signal classification

**Training Data Requirements:**
- **Minimum**: 50+ images per category for basic training
- **Recommended**: 200+ images per category for robust performance
- **Diversity**: Different lighting, angles, distances, weather conditions

### 🔄 **ML Integration Steps**

**Phase 1: Data Collection (Current)**
```bash
# Use the training screen to collect samples
1. Point camera at red signals → Capture 100+ samples
2. Point camera at green signals → Capture 100+ samples
3. Point camera at yellow signals → Capture 100+ samples
4. Point camera at backgrounds → Capture 100+ samples
```

**Phase 2: Model Training (External)**
```python
# Example training pipeline (external to app)
1. Export training data from device
2. Create TensorFlow model using collected images
3. Train CNN for signal classification
4. Convert to TensorFlow Lite format (.tflite)
5. Optimize for mobile deployment
```

**Phase 3: Model Deployment**
```dart
1. Place trained model in assets/models/signal_classifier.tflite
2. App automatically switches from color-based to ML detection
3. MLSignalDetector handles inference and classification
4. Fallback remains available if model fails
```

### 🎯 **Model Requirements**

**Input Specifications:**
- **Format**: RGB image, 224x224 pixels
- **Normalization**: [-1, 1] range (MobileNet preprocessing)
- **Source**: Live camera frames

**Output Specifications:**
- **Classes**: [no_signal, red_signal, green_signal, yellow_signal]
- **Format**: 4-element probability vector
- **Threshold**: 0.7+ confidence for alarm triggers

**Performance Targets:**
- **Inference Speed**: <100ms per frame
- **Accuracy**: 95%+ for safety-critical red signal detection
- **Model Size**: <50MB for mobile deployment

## Hardware Requirements

### Minimum Requirements
- **Android Device**: API level 26+ (Android 8.0) - required for TensorFlow Lite
- **RAM**: 4GB for smooth operation
- **Storage**: 200MB (app + training data)
- **Camera**: Rear camera with autofocus
- **Processor**: ARM64 or x86_64 architecture

### Recommended Specifications
- **Modern Android**: API 33+ (Android 13+)
- **High-Performance CPU**: Snapdragon 8xx series or equivalent
- **Good Camera**: OIS, good low-light performance
- **Mounting**: Sturdy vehicle mount for hands-free operation

## Safety Considerations & Limitations

### Critical Limitations
- **Single Point of Failure**: Relies on one camera and device
- **Environmental Sensitivity**: Performance degrades in fog, rain, direct sunlight
- **Distance Accuracy**: Estimation assumes standard signal dimensions
- **ML Accuracy**: Simulation mode - real models will have error rates

### Safety Guidelines
- **Never rely solely** on this app for safety decisions
- **Always follow** established railway safety protocols
- **Regular calibration** would be required for production use
- **Redundant systems** needed for actual safety applications

### Risk Factors
- **False Positives**: May trigger unnecessary alarms
- **False Negatives**: Could miss actual red signals (catastrophic)
- **Weather Dependencies**: Reduced accuracy in adverse conditions
- **Mounting Stability**: Camera angle affects detection accuracy

## Performance Optimization

### Current Optimizations
- Frame processing limited to prevent overload
- Detection history capped at 1000 entries
- Efficient image processing pipeline
- Background processing for ML inference

### Production Considerations
- **Model Optimization**: Quantized TensorFlow Lite models
- **Hardware Acceleration**: Use NPU/GPU when available
- **Power Management**: Optimize for battery life
- **Thermal Management**: Prevent device overheating

## Development Notes

### Adding Features
1. **Update Models**: Modify `detection_result.dart` for new data types
2. **Implement Service**: Add logic in appropriate service file
3. **Update UI**: Modify screens to display new features
4. **Test Thoroughly**: Verify functionality across devices

### Testing Strategy
```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# Performance profiling
flutter run --profile
```

## Contributing

This is a proof of concept for educational and research purposes. For production railway safety systems:
- Work with certified safety engineers
- Follow railway safety standards (EN 50126, EN 50128, EN 50129)
- Implement redundant safety systems
- Undergo rigorous testing and certification

## License

This project is for educational and demonstration purposes only. **Not for production safety-critical use.**

---

## Quick Reference

### Essential Commands
```bash
# Development
flutter run                    # Run on connected device
flutter run --release         # Run release build
flutter build apk             # Build APK file

# Debugging
flutter logs                   # View device logs
flutter analyze              # Static code analysis
flutter doctor               # Check development setup

# Maintenance
flutter clean                 # Clean build cache
flutter pub get              # Update dependencies
flutter pub upgrade          # Upgrade to latest versions
```

### Key App Shortcuts
- **Home → Camera**: Tap "START DETECTION"
- **Start Detection**: Green "START" button
- **Stop Detection**: Red "STOP" button
- **View History**: History icon (bottom right)
- **Clear History**: Delete icon in history screen
- **Return Home**: Back button

---

**⚠️ REMEMBER: This is a POC only. Never use for actual railway safety decisions. Always follow established safety protocols.**