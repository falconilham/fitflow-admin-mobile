import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/providers/auth_provider.dart';

const _tokenKey = 'auth_token';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = dotenv.env['API_URL'] ?? 'https://api.fitflow.id';
  final storage = ref.watch(secureStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // Auto-retry interceptor for intermittent cellular/network timeouts
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) async {
        final requestOptions = error.requestOptions;
        final isTimeout = error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError;

        if (isTimeout) {
          final retryCount = (requestOptions.extra['retry_count'] as int?) ?? 0;
          const maxRetries = 2;

          if (retryCount < maxRetries) {
            requestOptions.extra['retry_count'] = retryCount + 1;
            // Short backoff before retrying
            await Future.delayed(
                Duration(milliseconds: 1000 * (retryCount + 1)));
            try {
              final response = await dio.fetch(requestOptions);
              return handler.resolve(response);
            } catch (retryError) {
              if (retryError is DioException) {
                return handler.next(retryError);
              }
            }
          }
        }
        return handler.next(error);
      },
    ),
  );

  // Auth interceptor — attach token automatically
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: _tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401 &&
            !error.requestOptions.path.endsWith('/login')) {
          // Token expired or invalid -> logout
          ref.read(authProvider.notifier).logout();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
