import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

// Standalone implementation of _parseQr identical to checkin_screen.dart
Map<String, dynamic>? parseQrTest(String raw, {int fallbackGymId = 8}) {
  try {
    final trimmed = raw.trim();

    // 0. Check if URL containing token or deep link
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        final tokenParam = uri.queryParameters['qrToken'] ??
            uri.queryParameters['token'] ??
            uri.queryParameters['code'];
        if (tokenParam != null && tokenParam.isNotEmpty) {
          final fromToken = parseQrTest(tokenParam, fallbackGymId: fallbackGymId);
          if (fromToken != null) return fromToken;
        }

        final segments = uri.pathSegments;
        final qrIndex = segments.indexOf('qr');
        if (qrIndex != -1 && segments.length >= qrIndex + 3) {
          final uId = int.tryParse(segments[qrIndex + 1]);
          final mId = int.tryParse(segments[qrIndex + 2]);
          if (uId != null && mId != null) {
            return {
              'userId': uId,
              'gymId': fallbackGymId,
              'membershipId': mId,
            };
          }
        }
      }
    }

    // 1. Signed cryptographic JWT token (Format: header.payload.signature)
    if (trimmed.contains('.') && trimmed.split('.').length == 3) {
      final parts = trimmed.split('.');
      final payloadNormalized = base64Url.normalize(parts[1]);
      final decodedBytes = base64Url.decode(payloadNormalized);
      final decodedStr = utf8.decode(decodedBytes);
      final dynamic jwtData = jsonDecode(decodedStr);

      if (jwtData is Map) {
        final userId = int.tryParse(jwtData['userId']?.toString() ?? '') ?? 0;
        final membershipId = int.tryParse(
                (jwtData['memberId'] ?? jwtData['membershipId'])?.toString() ??
                    '') ??
            0;
        final gymId = int.tryParse(jwtData['gymId']?.toString() ?? '') ??
            fallbackGymId;

        return {
          'userId': userId,
          'gymId': gymId,
          'membershipId': membershipId,
          'qrToken': trimmed,
        };
      }
    }

    // 2. Try JSON payload
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decodedJson = jsonDecode(trimmed);
        if (decodedJson is Map) {
          final userId = int.tryParse(decodedJson['userId']?.toString() ?? '') ?? 0;
          final membershipId = int.tryParse(
                  (decodedJson['memberId'] ?? decodedJson['membershipId'])
                          ?.toString() ??
                      '') ??
              0;
          final gymId = int.tryParse(decodedJson['gymId']?.toString() ?? '') ??
              fallbackGymId;

          if (userId > 0 || membershipId > 0) {
            return {
              'userId': userId,
              'gymId': gymId,
              'membershipId': membershipId,
              if (decodedJson['qrToken'] != null)
                'qrToken': decodedJson['qrToken'].toString(),
            };
          }
        }
      } catch (_) {}
    }

    // 3. Fallback: regex for legacy loose json
    final decoded = trimmed.replaceAll("'", '"');
    final Map<String, dynamic> json = Map<String, dynamic>.from(
        RegExp(r'"(\w+)":\s*(\d+)').allMatches(decoded).fold(
            <String, dynamic>{},
            (map, m) => map..[m.group(1)!] = int.tryParse(m.group(2)!)));

    if (json.isNotEmpty) {
      return {
        'userId': json['userId'] ?? 0,
        'gymId': json['gymId'] ?? fallbackGymId,
        'membershipId': json['memberId'] ?? json['membershipId'] ?? 0,
      };
    }
  } catch (_) {}
  return null;
}

void main() {
  group('CheckIn QR Code Parsing Suite', () {
    test('Correctly parses signed dynamic JWT QR code from member web', () {
      // Simulate real JWT from member web dashboard
      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'}))).replaceAll('=', '');
      final payload = base64Url.encode(utf8.encode(jsonEncode({
        'jti': 'unique-uuid-12345',
        'userId': 5,
        'gymId': 8,
        'memberId': 15,
        'membershipId': 15,
        'iat': 1794326115,
        'exp': 1794326175,
      }))).replaceAll('=', '');
      const signature = 'Ba2sFM4EAwXptjjayp0aakLF4yCl2kJNDOW6g7QQnTg';
      final jwtToken = '$header.$payload.$signature';

      final result = parseQrTest(jwtToken);
      expect(result, isNotNull);
      expect(result!['userId'], equals(5));
      expect(result['membershipId'], equals(15));
      expect(result['gymId'], equals(8));
      expect(result['qrToken'], equals(jwtToken));
    });

    test('Correctly parses URL with qrToken query param', () {
      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256'}))).replaceAll('=', '');
      final payload = base64Url.encode(utf8.encode(jsonEncode({
        'userId': 7,
        'gymId': 8,
        'membershipId': 12,
      }))).replaceAll('=', '');
      final jwt = '$header.$payload.sig123';
      final url = 'https://demogym.fitflow.id/checkin?qrToken=$jwt';

      final result = parseQrTest(url);
      expect(result, isNotNull);
      expect(result!['userId'], equals(7));
      expect(result['membershipId'], equals(12));
      expect(result['gymId'], equals(8));
      expect(result['qrToken'], equals(jwt));
    });

    test('Correctly parses deep link path /qr/:userId/:membershipId', () {
      const url = 'https://demogym.fitflow.id/client/qr/10/25';
      final result = parseQrTest(url, fallbackGymId: 8);
      expect(result, isNotNull);
      expect(result!['userId'], equals(10));
      expect(result['membershipId'], equals(25));
      expect(result['gymId'], equals(8));
    });

    test('Correctly parses legacy JSON payload', () {
      const jsonStr = '{"userId": 5, "gymId": 8, "membershipId": 15}';
      final result = parseQrTest(jsonStr);
      expect(result, isNotNull);
      expect(result!['userId'], equals(5));
      expect(result['membershipId'], equals(15));
      expect(result['gymId'], equals(8));
    });

    test('Correctly parses loose unquoted or single quoted JSON fallback', () {
      const loose = "{'userId': 9, 'gymId': 8, 'memberId': 18}";
      final result = parseQrTest(loose);
      expect(result, isNotNull);
      expect(result!['userId'], equals(9));
      expect(result['membershipId'], equals(18));
      expect(result['gymId'], equals(8));
    });

    test('Returns null for garbage or completely invalid format', () {
      expect(parseQrTest('helloworld12345'), isNull);
      expect(parseQrTest(''), isNull);
      expect(parseQrTest('   '), isNull);
    });
  });
}
