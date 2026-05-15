import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../shared/utils/error_handler.dart';

enum AuthStatus { idle, loading, authenticated, unauthenticated, failed }

class AuthState {
  final AuthStatus status;
  final String? token;
  final AdminInfo? admin;
  final int? activeGymId;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.token,
    this.admin,
    this.activeGymId,
    this.error,
  });

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && token != null;

  AuthState copyWith({
    AuthStatus? status,
    String? token,
    AdminInfo? admin,
    int? activeGymId,
    String? error,
    bool clearError = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        token: token ?? this.token,
        admin: admin ?? this.admin,
        activeGymId: activeGymId ?? this.activeGymId,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  static const _tokenKey = 'auth_token';

  @override
  Future<AuthState> build() async {
    final storage = ref.watch(secureStorageProvider);
    final token = await storage.read(key: _tokenKey);
    if (token != null) {
      try {
        final repo = ref.read(apiRepositoryProvider);
        final admin = await repo.getMe();
        return AuthState(
          status: AuthStatus.authenticated,
          token: token,
          admin: admin,
          activeGymId: admin.gymId,
        );
      } catch (e) {
        // If profile fetch fails, token is likely invalid or expired
        await storage.delete(key: _tokenKey);
        return const AuthState(status: AuthStatus.unauthenticated);
      }
    }
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(apiRepositoryProvider);
      final data = await repo.login(email, password);

      final token = data['token'] as String;
      final admin = AdminInfo.fromJson(data['admin'] as Map<String, dynamic>);

      final storage = ref.read(secureStorageProvider);
      await storage.write(key: _tokenKey, value: token);

      state = AsyncValue.data(AuthState(
        status: AuthStatus.authenticated,
        token: token,
        admin: admin,
        // gymId may be null for owners who haven't created a gym yet
        activeGymId: admin.gymId,
      ));
    } catch (e, st) {
      // Log the real error so we can debug it
      // ignore: avoid_print
      print('Login error: $e\n$st');
      state = AsyncValue.data(AuthState(
        status: AuthStatus.failed,
        error: ErrorHandler.parse(e),
      ));
    }
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: _tokenKey);
    state = const AsyncValue.data(
        AuthState(status: AuthStatus.unauthenticated));
  }

  void setActiveGym(int gymId) {
    state.whenData((s) {
      state = AsyncValue.data(s.copyWith(activeGymId: gymId));
    });
  }

  void clearError() {
    state.whenData((s) {
      state = AsyncValue.data(s.copyWith(clearError: true));
    });
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
