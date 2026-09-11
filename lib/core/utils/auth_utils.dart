import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthUtils {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _gymIdKey = 'active_gym_id';

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> setToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getGymId() async {
    return await _storage.read(key: _gymIdKey);
  }

  static Future<void> setGymId(String gymId) async {
    await _storage.write(key: _gymIdKey, value: gymId);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _gymIdKey);
  }
}
