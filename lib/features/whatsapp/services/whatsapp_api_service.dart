import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/utils/auth_utils.dart';

class WhatsappApiService {
  static Future<Map<String, dynamic>> getSettings() async {
    final token = await AuthUtils.getToken();
    final gymId = await AuthUtils.getGymId();
    
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/v1/whatsapp/settings'),
      headers: {
        'Authorization': 'Bearer $token',
        'x-gym-id': gymId ?? '',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load settings');
    }
  }

  static Future<Map<String, dynamic>> getLogs({int page = 1, int limit = 20, String status = ''}) async {
    final token = await AuthUtils.getToken();
    final gymId = await AuthUtils.getGymId();
    
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/v1/whatsapp/logs?page=$page&limit=$limit&status=$status'),
      headers: {
        'Authorization': 'Bearer $token',
        'x-gym-id': gymId ?? '',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load logs');
    }
  }

  static Future<bool> sendBroadcast(Map<String, dynamic> data) async {
    final token = await AuthUtils.getToken();
    final gymId = await AuthUtils.getGymId();
    
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/api/v1/whatsapp/broadcast'),
      headers: {
        'Authorization': 'Bearer $token',
        'x-gym-id': gymId ?? '',
        'Content-Type': 'application/json',
      },
      body: json.encode(data),
    );

    return response.statusCode == 200;
  }
}
