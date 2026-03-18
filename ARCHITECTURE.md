# Project Architecture — Flutter Edition

This document describes the architectural design and technical patterns used in the FitFlow Admin Flutter project.

## 📂 Folder Structure

```
lib/
├── main.dart                            # Entry point, ProviderScope, locale setup
├── core/
│   ├── network/
│   │   └── api_client.dart              # Dio + auth interceptor + secureStorageProvider
│   ├── router/
│   │   └── app_router.dart              # go_router config, auth redirect guard, all routes
│   └── theme/
│       └── app_theme.dart               # AppColors constants + ThemeData (dark)
├── data/
│   ├── models/
│   │   └── models.dart                  # AdminInfo, Member, Product, DashboardStats, etc.
│   └── repositories/
│       └── api_repository.dart          # All API calls via Dio, one method per endpoint
├── features/
│   ├── auth/
│   │   ├── providers/
│   │   │   └── auth_provider.dart       # AsyncNotifier — login, logout, session restore
│   │   └── screens/
│   │       ├── splash_screen.dart
│   │       └── login_screen.dart
│   ├── dashboard/
│   │   └── screens/
│   │       └── dashboard_screen.dart    # Stats grid + recent check-ins list
│   ├── checkin/
│   │   └── screens/
│   │       └── checkin_screen.dart      # QR scanner via mobile_scanner
│   ├── members/
│   │   └── screens/
│   │       ├── members_screen.dart      # List + search + status filter
│   │       ├── member_detail_screen.dart
│   │       ├── add_member_screen.dart
│   │       ├── edit_member_screen.dart
│   │       ├── renew_member_screen.dart
│   │       └── import_member_screen.dart
│   ├── store/
│   │   └── screens/
│   │       ├── store_screen.dart        # Product grid with delete confirm dialog
│   │       └── add_edit_product_screen.dart
│   └── profile/
│       └── screens/
│           └── profile_screen.dart      # Admin info + logout
└── shared/
    ├── utils/
    │   └── format.dart                  # formatCurrency, formatDate, formatTime
    └── widgets/
        └── main_shell.dart              # Bottom tab bar shell (ShellRoute)
```

## 🗺 Navigation Flow

Uses **go_router** with an auth redirect guard. Unauthenticated users are always
sent to `/login`; authenticated users are redirected away from auth screens to `/dashboard`.

```
/              → SplashScreen      (redirect hub — loading spinner while auth restores)
/login         → LoginScreen
/dashboard  ─┐
/checkin      │  ShellRoute → MainShell (bottom tab bar)
/members      │
/store        │
/profile    ─┘
/members/add           → AddMemberScreen      (full screen, outside shell)
/members/import        → ImportMemberScreen
/members/:id           → MemberDetailScreen
/members/:id/edit      → EditMemberScreen
/members/:id/renew     → RenewMemberScreen
/store/add             → AddEditProductScreen
/store/:id/edit        → AddEditProductScreen  (edit mode)
```

## 💾 State Management

**Riverpod** replaces Redux Toolkit + redux-persist:

| React Native (RN)               | Flutter equivalent                              |
|---------------------------------|-------------------------------------------------|
| `createSlice` + thunks          | `AsyncNotifier` (`AuthNotifier`)                |
| `useAppSelector(state => ...)` | `ref.watch(provider)`                           |
| `useAppDispatch(action())`     | `ref.read(provider.notifier).method()`          |
| redux-persist (AsyncStorage)    | `flutter_secure_storage` (token only)           |
| RTK `createAsyncThunk`         | `FutureProvider.autoDispose` per screen         |
| RTK `createEntityAdapter`      | `FutureProvider.autoDispose.family` (per id)    |

## 📡 API Layer

**Dio** replaces Axios:

- `api_client.dart` — Base URL from `.env` via `flutter_dotenv`; `InterceptorsWrapper`
  reads the token from `flutter_secure_storage` and injects `Authorization: Bearer <token>`
  on every request automatically.
- `api_repository.dart` — Single class with one method per endpoint, mirroring `endpoints.ts`.
  Injected via `apiRepositoryProvider`.

## 🎨 Theme

Same visual identity as the original React Native version:

| Token         | Value                  |
|---------------|------------------------|
| Background    | `#111111`              |
| Card          | `#262626`              |
| Accent        | `#C8F000` (FitFlow green) |
| Tab bar bg    | `#161616`              |
| Text primary  | `#FFFFFF`              |
| Text muted    | `#6B7280`              |
| Error         | `#EF4444`              |
| Success       | `#22C55E`              |

## 🔄 React Native → Flutter Migration Map

| React Native                        | Flutter                               |
|-------------------------------------|---------------------------------------|
| React Navigation Stack              | go_router (path-based routes)         |
| React Navigation Bottom Tabs        | go_router ShellRoute + BottomNavigationBar |
| Redux Toolkit slices                | Riverpod AsyncNotifier / StateNotifier |
| Axios + interceptors                | Dio + InterceptorsWrapper             |
| AsyncStorage                        | flutter_secure_storage                |
| react-native-vision-camera          | mobile_scanner                        |
| react-native-config (.env)          | flutter_dotenv                        |
| StyleSheet                          | ThemeData + BoxDecoration             |
| lucide-react-native                 | Material Icons (built-in)             |
