import 'package:dio/dio.dart';

class ErrorHandler {
  static String parse(dynamic e) {
    if (e is DioException) {
      final res = e.response;
      if (res != null && res.data is Map) {
        final data = res.data as Map;
        // Check for common error fields from backend
        final error = data['error']?.toString() ?? data['message']?.toString();
        if (error != null) {
          return error;
        }
      }
      
      // Fallback for Dio errors
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Koneksi timeout. Silakan coba lagi.';
        case DioExceptionType.connectionError:
          return 'Terjadi kesalahan koneksi jaringan.';
        case DioExceptionType.badResponse:
          final code = e.response?.statusCode;
          if (code == 404) return 'Layanan tidak ditemukan (404).';
          if (code == 403) return 'Akses ditolak (403).';
          if (code == 500) return 'Terjadi kesalahan pada server (500).';
          return 'Server memberikan respon tidak valid: $code';
        case DioExceptionType.cancel:
          return 'Permintaan dibatalkan.';
        default:
          return 'Gagal terhubung ke server.';
      }
    }
    
    if (e is String) return e;
    
    // Fallback for everything else
    final msg = e.toString();
    if (msg.contains('Exception: ')) return msg.replaceFirst('Exception: ', '');
    return 'Terjadi kesalahan tidak terduga.';
  }
}
