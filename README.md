# FitFlow Admin — Flutter

The official mobile application for FitFlow Gym Administrators and Owners, rebuilt in Flutter.

## 🚀 Key Features

- **📊 Dashboard**: Real-time gym statistics (Revenue, Total Members, Active Members, Daily Check-ins)
- **👥 Member Management**: View, add, edit, import, and renew memberships
- **✅ QR Check-in**: Streamlined check-in via `mobile_scanner`
- **🛒 Store**: Manage gym products (add, edit, delete)
- **🔒 Secure Auth**: Admin login with token persisted in secure storage

## 🛠 Tech Stack

| Layer            | Library                                |
|------------------|----------------------------------------|
| Framework        | Flutter (Dart)                         |
| State Management | flutter_riverpod + riverpod_annotation |
| Navigation       | go_router                              |
| HTTP Client      | Dio                                    |
| Secure Storage   | flutter_secure_storage                 |
| QR Scanning      | mobile_scanner                         |
| Environment      | flutter_dotenv                         |
| Localisation     | intl + flutter_localizations           |

## 📦 Getting Started

### Prerequisites

- Flutter SDK ≥ 3.3.0
- Dart SDK ≥ 3.3.0 (bundled with Flutter)

### Installation

```bash
# Install dependencies
flutter pub get

# Set up environment
cp .env.example .env
# Edit .env with your API URL
```

### Running

```bash
# Android
flutter run

# iOS (requires macOS + Xcode)
cd ios && pod install && cd ..
flutter run -d ios

# Release build — Android APK
flutter build apk --release

# Release build — Android App Bundle
flutter build appbundle --release
```

### Code Generation (Riverpod)

```bash
dart run build_runner build --delete-conflicting-outputs
```

## 📐 Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for full breakdown and the React Native → Flutter migration map.

## 🔧 Setup

See [SETUP.md](./SETUP.md) for first-run instructions, platform permissions, and troubleshooting.

---

© 2026 FitFlow Inc.
