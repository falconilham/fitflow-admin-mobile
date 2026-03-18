# FitFlow Admin Flutter — Project Summary

## Overview
A Flutter mobile app that is a full port of the original React Native (`fitflow-admin-mobile`) project.
It allows gym administrators/owners to manage members, check-ins, store POS, and gym settings on the go.

---

## Tech Stack

| Layer | Library | Version |
|---|---|---|
| Framework | Flutter (Dart) | 3.41.4 / Dart 3.11.1 |
| State Management | flutter_riverpod | ^2.6.1 |
| Navigation | go_router | ^14.6.0 |
| HTTP Client | Dio | ^5.7.0 |
| Token Storage | flutter_secure_storage | ^9.2.4 |
| QR Scanner | mobile_scanner | ^5.2.3 |
| Environment | flutter_dotenv | ^5.2.1 |
| Localisation | intl + flutter_localizations | ^0.20.2 |
| Code Gen | riverpod_generator + build_runner | ^2.6.5 |

---

## Project Structure

```
lib/
├── main.dart                        # Entry point, ProviderScope, locale, global error handler
├── core/
│   ├── network/api_client.dart      # Dio setup, Bearer token interceptor, secureStorageProvider
│   ├── router/app_router.dart       # go_router + RouterNotifier (auth redirect guard)
│   └── theme/app_theme.dart         # AppColors constants + dark ThemeData
├── data/
│   ├── models/models.dart           # All data models (see Models section)
│   └── repositories/api_repository.dart  # All API calls (one method per endpoint)
├── features/
│   ├── auth/
│   │   ├── providers/auth_provider.dart  # AsyncNotifier: login, logout, session restore
│   │   └── screens/splash_screen.dart + login_screen.dart
│   ├── dashboard/screens/dashboard_screen.dart
│   ├── checkin/screens/checkin_screen.dart
│   ├── members/screens/
│   │   ├── members_screen.dart
│   │   ├── member_detail_screen.dart
│   │   ├── add_member_screen.dart
│   │   ├── edit_member_screen.dart
│   │   ├── renew_member_screen.dart
│   │   └── import_member_screen.dart
│   ├── store/screens/
│   │   ├── store_screen.dart        # POS tab + Products tab
│   │   └── add_edit_product_screen.dart
│   └── profile/screens/profile_screen.dart
└── shared/
    ├── utils/format.dart            # formatCurrency, formatDate, formatTime, formatDateTime
    └── widgets/main_shell.dart      # Bottom tab navigator (ShellRoute)
```

---

## Models (`lib/data/models/models.dart`)

```dart
AdminInfo    { id, name, email, role, gymId?, gymName?, gym? }
GymInfo      { id, name, subdomain, logo?, features? }
GymSimple    { id, name }
GymSettings  { mandatoryContact ('email'|'phone'), requireMemberId }
Member       { id, name, email, phone?, memberId?, status, suspended,
               photoUrl?, endDate?, joinDate?, packageName?, packageId?,
               packagePrice?, userId? }
             // NOTE: name/email/phone come from nested User object in API response
MembershipPackage { id, name, price, durationMonths }
DashboardStats    { totalMembers, activeMembers, dailyCheckIns, expenses }
CheckInRecord     { id, memberName?, memberPhoto?, checkedInAt }
Product      { id, name, price, stock, category, description?, imageUrl? }
```

**IMPORTANT parsing note:** `Member.fromJson` reads from nested `json['User']` first:
```dart
name  = json['User']?['name']  ?? json['name']  ?? ''
email = json['User']?['email'] ?? json['email'] ?? ''
phone = json['User']?['phone'] ?? json['phone']
```

---

## API Endpoints (`lib/data/repositories/api_repository.dart`)

Base URL from `.env` → `API_URL=https://api.fitflow.id`
Auth: Bearer token auto-injected by Dio interceptor.

| Method | Endpoint | Usage |
|---|---|---|
| POST | /admin/login | login(email, password) |
| GET | /admin/stats?gymId= | getStats(gymId) |
| GET | /admin/my-gyms | getMyGyms() |
| GET | /admin/members | getMembers(gymId, search?, status?, page, limit) |
| GET | /admin/members/:id | getMemberDetail(id) |
| POST | /admin/members | createMember(gymId, data) |
| PUT | /admin/members/:id | updateMember(id, data) |
| POST | /admin/members/import | importMembers(gymId, data) |
| GET | /admin/members/generate-id | generateMemberId(gymId) |
| GET | /admin/settings/public | getGymSettings(gymId) |
| GET | /admin/membership-packages | getPackages(gymId) |
| POST | /admin/check-in | checkInByQr(gymId, userId, membershipId) |
| GET | /admin/check-ins | getRecentCheckIns(gymId, limit) |
| GET | /admin/products | getProducts(gymId) |
| POST | /admin/products | createProduct(data) |
| PUT | /admin/products/:id | updateProduct(id, data) |
| DELETE | /admin/products/:id | deleteProduct(id) |
| POST | /admin/transactions | createTransaction(data) |

**Response parsing:** Members API returns multiple shapes:
```dart
List<dynamic> rows = data is List ? data
  : data['data'] ?? data['members'] ?? [];
int total = data['pagination']?['total'] ?? data['total'] ?? rows.length;
```

---

## Navigation (`lib/core/router/app_router.dart`)

Uses **go_router** with `RouterNotifier extends ChangeNotifier` as `refreshListenable`.

**Redirect logic:**
```
authAsync.isLoading  → stay on /  (splash)
!isAuthenticated     → /login
isAuthenticated + on auth page → /dashboard
otherwise → stay
```

**Routes:**
```
/           SplashScreen
/login      LoginScreen
/dashboard  DashboardScreen  ─┐ ShellRoute (MainShell bottom tabs)
/checkin    CheckInScreen      │
/members    MembersScreen      │
/store      StoreScreen        │
/profile    ProfileScreen     ─┘
/members/add              AddMemberScreen
/members/import           ImportMemberScreen
/members/:id              MemberDetailScreen
/members/:id/edit         EditMemberScreen
/members/:id/renew        RenewMemberScreen
/store/add                AddEditProductScreen
/store/:id/edit           AddEditProductScreen (edit mode)
```

---

## Auth State (`lib/features/auth/providers/auth_provider.dart`)

```dart
AuthState { status, token?, admin?, activeGymId?, error? }
AuthNotifier extends AsyncNotifier<AuthState>
  build()    → restores token from flutter_secure_storage
  login()    → POST /admin/login → saves token, sets admin + activeGymId
  logout()   → deletes token from storage
  setActiveGym(gymId) → for gym switcher (owner with multiple gyms)
```

**Known issue:** On startup, token is restored but `admin` object is NOT (only token persisted).
Pages depending on `admin.name/email` show `-` until a fresh login.
**Fix needed:** Also persist admin JSON in secure storage and restore on build().

---

## Theme (`lib/core/theme/app_theme.dart`)

```dart
AppColors.background = #111111
AppColors.surface    = #1E1E1E
AppColors.card       = #262626
AppColors.accent     = #C8F000  // FitFlow green
AppColors.tabBar     = #161616
AppColors.error      = #EF4444
AppColors.success    = #22C55E
AppColors.warning    = #F59E0B
AppColors.textPrimary   = #FFFFFF
AppColors.textSecondary = #9CA3AF
AppColors.textMuted     = #6B7280
AppColors.border        = #262626
```

---

## Screen Details

### Dashboard
- Calls `getMyGyms()` on load; if `activeGymId == null` (owner with no gym yet), auto-sets to first gym
- Shows: gym name header, 4 stat cards (totalMembers, activeMembers, dailyCheckIns, expenses)
- Quick Actions: Add Member, Members
- Recent Activity: last 5 check-ins
- Gym Switcher: horizontal scroll of gym chips (owners with 2+ gyms)

### Members
- Paginated list (10/page), infinite scroll
- Search by name/email/ID
- Filter chips: All / Active / Expired / Suspended
- Status color: green=active, red=expired/suspended, yellow=other

### Member Detail
- Shows: avatar, name, memberId, status badge, suspend/activate button
- Info: email, phone, joinDate, endDate, packageName, packagePrice
- Actions: Edit, Perpanjang (renew), Suspend/Aktifkan toggle

### Add/Edit Member
- Fetches GymSettings: `mandatoryContact` ('email'|'phone'), `requireMemberId`
- Auto-generate Member ID button → GET /admin/members/generate-id
- Package selector with `durationMonths`

### Renew Member
- Pre-selects current `member.packageId`
- Payload: `{ packageId, renew: true }`

### Import Member
- Full payload: memberId?, name, email, phone, address, packageId, price, joinDate, endDate,
  priceOverride:false, paymentMethod:'Cash', skipEmailVerification:true, recordTransaction:false

### Check-In
- Two tabs: Manual search + QR Scanner
- **Manual:** search members by name/ID → tap Check-in button
- **QR:** `mobile_scanner`, expects JSON `{"userId":N,"gymId":N,"membershipId":N}`
  Fallback: `userId:membershipId` colon format
- Response: `{ access:'granted'|'denied', type:'checkin'|'checkout', member:{name}, message }`

### Store
- **POS tab:** product grid with category filter + search, cart management,
  checkout modal with payment method (Cash/Transfer/QR), calls `createTransaction`
- **Products tab:** list with edit/delete, add product button
- Cart: tap product → adds to cart, FAB shows count + total, bottom sheet for qty adjustment

### Add/Edit Product
- Fields: name, category (chip selector), price, stock, description
- Payload includes `gymId`

### Profile
- Shows: admin avatar (initial), name, role badge, email, gym name
- Logout with confirm dialog

---

## Known Bugs (as of current state)

### Bug 1: `type 'Null' is not a subtype of type 'String'` in Recent Activity
**Cause:** `CheckInRecord.fromJson` casts `memberName` as non-nullable `String`
but API may return null for this field.
**Fix:**
```dart
// In models.dart CheckInRecord.fromJson:
memberName: json['memberName'] as String? ?? json['member']?['name'] as String? ?? 'Unknown',
```

### Bug 2: Profile shows `-` for name/email after app restart
**Cause:** `AuthNotifier.build()` only restores the token from secure storage,
not the `admin` object. So `authState.admin` is null on restart.
**Fix:** Also persist admin JSON and restore it on build:
```dart
// In auth_provider.dart build():
final adminJson = await storage.read(key: 'admin_data');
AdminInfo? admin;
if (adminJson != null) admin = AdminInfo.fromJson(jsonDecode(adminJson));

// In login() after successful response:
await storage.write(key: 'admin_data', value: jsonEncode(data['admin']));

// In logout():
await storage.delete(key: 'admin_data');
```

---

## Setup & Run

```bash
# Prerequisites: Flutter 3.3+, Java 17, Android emulator
cd ~/Programming/iseng/fitflow/fitflow-admin-flutter

# Install deps
flutter pub get

# Copy env
cp .env.example .env  # set API_URL=https://api.fitflow.id

# Run on Android emulator
flutter emulators --launch FitFlowEmulator
flutter run -d emulator-5554

# Hot reload: r   Hot restart: R   Quit: q
```

**PATH setup (add to ~/.zshrc):**
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
export PATH="$PATH:/opt/homebrew/Caskroom/flutter/3.41.4/flutter/bin"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
export PATH="$JAVA_HOME/bin:$PATH"
```

---

## Android Config

- `android/app/build.gradle.kts`: `minSdk = 21` (required by mobile_scanner)
- `android/app/src/main/AndroidManifest.xml`: CAMERA, FLASHLIGHT, INTERNET permissions
- `ios/Runner/Info.plist`: `NSCameraUsageDescription` for QR scanner

---

## Demo Credentials
- Email: `demogym@gmail.com`
- Password: `demogym`
- Note: This account has `gymId: null` (owner with no gym yet) — handled gracefully
