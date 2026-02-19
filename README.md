# FitFlow Admin Mobile

The official mobile application for FitFlow Gym Administrators and Owners. Manage your gym, members, and check-ins on the go.

## 🚀 Key Features

- **📊 Dashboard**: Real-time gym statistics (Revenue, Total Members, etc.).
- **👥 Member Management**: View, add, and renew memberships.
- **✅ QR Check-in**: Streamlined check-in process via QR code or manual search.
- **🔒 Secure Access**: Dedicated admin login with role-based features.

## 🛠 Tech Stack

- **Framework**: [React Native](https://reactnative.dev/) (v0.84+)
- **State Management**: [Redux Toolkit](https://redux-toolkit.js.org/) with [Redux Persist](https://github.com/rt2zz/redux-persist)
- **Navigation**: [React Navigation v7](https://reactnavigation.org/)
- **API Client**: [Axios](https://axios-http.com/)
- **Icons**: [React Native Vector Icons](https://github.com/oblador/react-native-vector-icons)
- **QR Scanning**: [React Native Vision Camera](https://mrousavy.com/react-native-vision-camera/docs/guides/barcode-scanning)

## 📦 Getting Started

### Prerequisites

- Node.js >= 22.11.0
- React Native Environment Setup ([Official Guide](https://reactnative.dev/docs/set-up-your-environment))

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   npm install
   ```
3. Set up environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your local API URL
   ```
4. Install iOS dependencies (macOS only):
   ```bash
   bundle install
   cd ios && bundle exec pod install && cd ..
   ```

### Running the App

```bash
# Start Metro bundler
npm start

# Run on Android
npm run android

# Run on iOS
npm run ios
```

## 📐 Architecture

For a detailed overview of the project structure and technical design, see [ARCHITECTURE.md](./ARCHITECTURE.md).

---

© 2026 FitFlow Inc.
