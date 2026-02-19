# Project Architecture

This document describes the architectural design and technical patterns used in the FitFlow Admin Mobile project.

## 📂 Folder Structure

```text
src/
├── api/          # Axios client, endpoints, and interceptors
├── components/   # Shared UI components
├── navigation/   # Navigation configuration (Main and Sub-navigators)
├── screens/      # Page-level components organized by feature
├── store/        # Redux Toolkit slices, hooks, and persistence
└── utils/        # Helper functions (formatting, date handling, etc.)
```

## 🗺 Navigation Flow

The app uses `React Navigation v7` for its navigation system:

- **Main Navigator**: A Bottom Tab Navigator containing:
  - **Dashboard**: High-level stats.
  - **CheckIn**: Camera scanner for QR check-ins.
  - **Members**: Nested Stack Navigator for member flows.
- **Members Stack**:
  - `MembersList` -> `MemberDetail` -> `AddMember` / `RenewMember`.

## 💾 State Management

We use **Redux Toolkit** for global state management with **Redux Persist** for local storage:

- **Auth Slice**: Manages the authentication token, user information, and error states.
- **Persistence**: Auth state is persisted using `AsyncStorage` to keep users logged in.
- **Hooks**: Custom `useAppDispatch` and `useAppSelector` are exported for better typing.

## 📡 API Layer

The API layer is built on **Axios** with a modular design:

- **Client (`api/client.ts`)**: Base configuration, including `baseURL` and interceptors (e.g., adding `Authorization` header).
- **Endpoints (`api/endpoints.ts`)**: Centralized repository of all API calls, categorized by feature (Auth, Dashboard, Members, etc.).

## 🎨 Styling

- **Theme**: Consistent dark theme (`#1E1E1E` background) with FitFlow green (`#C8F000`) accents.
- **Patterns**: Standard `StyleSheet` usage with local styles for components and screens.
