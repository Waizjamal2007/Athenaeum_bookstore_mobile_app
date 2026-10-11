import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const baseUrl = 'https://backendnotifications.vercel.app';

  static String requestId() {
    final random = Random.secure();
    return '${DateTime.now().microsecondsSinceEpoch}_${random.nextInt(1 << 30)}';
  }

  static Future<Map<String, dynamic>> post(
      String action,
      Map<String, dynamic> data,
      ) async {
    final endpoint = Uri.parse('$baseUrl/api/index');

    if (endpoint.scheme != 'https' || endpoint.host.isEmpty) {
      throw StateError(
        'Set a valid HTTPS Vercel URL in api_service.dart.',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Please sign in.');
    }

    try {
      final token = await user.getIdToken();

      if (token == null || token.isEmpty) {
        throw StateError('Please sign out and sign in again.');
      }

      final response = await http
          .post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'action': action,
          'data': data,
        }),
      )
          .timeout(const Duration(seconds: 65));

      final Map<String, dynamic> body;

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is! Map) {
          throw const FormatException('Expected a JSON object.');
        }

        body = Map<String, dynamic>.from(decoded);
      } catch (_) {
        throw StateError(
          'Backend returned an invalid response '
              '(HTTP ${response.statusCode}). '
              'Check the Vercel URL and Deployment Protection.',
        );
      }

      if (response.statusCode != 200 || body['ok'] != true) {
        throw StateError(
          '${body['error'] ?? 'Request failed (${response.statusCode}).'}',
        );
      }

      final result = body['data'];

      if (result is! Map) {
        throw StateError('Backend returned invalid response data.');
      }

      return Map<String, dynamic>.from(result);
    } on TimeoutException {
      throw StateError(
        'Request timed out. Refresh Profile/orders or Admin '
            'before repeating a change.',
      );
    } on http.ClientException {
      throw StateError(
        'Cannot reach the backend. Check internet and the Vercel URL.',
      );
    }
  }
}