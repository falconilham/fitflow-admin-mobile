# Setup Guide — FitFlow Admin Flutter

## Prerequisites

| Tool          | Min Version | Install                                          |
|---------------|-------------|--------------------------------------------------|
| Flutter SDK   | 3.3.0       | https://docs.flutter.dev/get-started/install     |
| Dart SDK      | 3.3.0       | Bundled with Flutter                             |
| Xcode         | 14+         | macOS only — for iOS builds                      |
| Android Studio| Latest      | For Android emulator / device                    |
| JDK           | 17+         | Required for Android Gradle builds               |

---

## 1. Install Dependencies

```bash
cd ~/Programming/iseng/fitflow/fitflow-admin-flutter
flutter pub get
```

---

## 2. Environment Variables

```bash
cp .env.example .env
```

Edit `.env`:
```
API_URL=https://api.fitflow.id
# For local dev on Android emulator:
# API_URL=http://10.0.2.2:3000
# For local dev on iOS simulator:
# API_URL=http://localhost:3000
```

> **Tip:** Android emulator uses `10.0.2.2` to reach `localhost` on your host machine.

---

## 3. Platform Setup

### Android

No extra steps needed. The following are already configured:
- `android/app/src/main/AndroidManifest.xml` — `CAMERA`, `FLASHLIGHT`, `INTERNET` permissions
- `android/app/build.gradle` — `minSdkVersion 21` (required by `mobile_scanner`)

### iOS (macOS only)

Install CocoaPods dependencies:
```bash
cd ios && pod install && cd ..
```

`ios/Runner/Info.plist` already contains the required camera permission:
```xml
<key>NSCameraUsageDescription</key>
<string>FitFlow Admin membutuhkan akses kamera untuk memindai QR code check-in member.</string>
```

---

## 4. Run the App

```bash
# List connected devices / simulators
flutter devices

# Run on default device
flutter run

# Run on specific device
flutter run -d "iPhone 15 Pro"
flutter run -d emulator-5554
```

---

## 5. Build for Release

```bash
# Android — APK
flutter build apk --release

# Android — App Bundle (Google Play)
flutter build appbundle --release

# iOS (requires a signing certificate configured in Xcode)
flutter build ios --release
```

---

## 6. Code Generation

If you add new `@riverpod` annotated providers, regenerate:
```bash
dart run build_runner build --delete-conflicting-outputs

# Watch mode during active development
dart run build_runner watch --delete-conflicting-outputs
```

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `minSdkVersion` build error | Check `android/app/build.gradle` has `minSdkVersion 21` |
| Camera permission denied on iOS | Verify `NSCameraUsageDescription` exists in `ios/Runner/Info.plist` |
| `pod install` fails | Run `flutter clean && flutter pub get && cd ios && pod install` |
| API unreachable on Android emulator | Use `http://10.0.2.2:PORT` instead of `localhost` in `.env` |
| `intl` locale errors | Confirm `initializeDateFormatting('id_ID', null)` is called in `main()` ✅ |
| `flutter_secure_storage` crash on Android | Ensure `minSdkVersion 18+` (21 already set) |
