import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'https://beta-api.lasprendas.com'; 
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> register(String email, String password, String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password, 'name': name}),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Registration failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> _getUploadParams(String filename, String mimeType) async {
    final response = await http.get(
      Uri.parse('$baseUrl/storage/upload-params?filename=$filename&mimeType=$mimeType'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get upload params: ${response.body}');
    }
  }

  static Future<void> _uploadFileToS3(String uploadUrl, File file, String mimeType) async {
    final bytes = await file.readAsBytes();
    final response = await http.put(
      Uri.parse(uploadUrl),
      headers: {
        'Content-Type': mimeType,
        'x-amz-acl': 'public-read', // Match what backend specified if needed
      },
      body: bytes,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to upload to S3: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> uploadGarments(List<File> images, String category, {List<String>? garmentIds, String personType = 'female'}) async {
    final List<String> garmentKeys = [];

    // 1. Upload each image directly to S3
    for (var image in images) {
      final filename = basename(image.path);
      const mimeType = 'image/png'; // Default or detect

      final params = await _getUploadParams(filename, mimeType);
      final uploadUrl = params['uploadUrl'];
      final key = params['key'];

      await _uploadFileToS3(uploadUrl, image, mimeType);
      garmentKeys.add(key);
    }

    // 2. Create try-on session with the keys
    final response = await http.post(
      Uri.parse('$baseUrl/try-on'),
      headers: await _headers(),
      body: json.encode({
        'category': category,
        'personType': personType,
        'garmentKeys': garmentKeys,
        'garmentIds': garmentIds,
      }),
    );
    
    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create try-on session: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getSessionStatus(String sessionId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/try-on/sessions/$sessionId'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch session status');
    }
  }

  static Future<List<dynamic>> getSessions() async {
    final response = await http.get(Uri.parse('$baseUrl/try-on/sessions'), headers: await _headers());
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load sessions');
    }
  }

  static Future<void> deleteGarment(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/try-on/garments/$id'), headers: await _headers());
    if (response.statusCode != 200) {
      throw Exception('Failed to delete garment');
    }
  }

  static Future<void> deleteSession(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/try-on/sessions/$id'), headers: await _headers());
    if (response.statusCode != 200) {
      throw Exception('Failed to delete outfit');
    }
  }

  static Future<List<dynamic>> getGarments() async {
    final response = await http.get(Uri.parse('$baseUrl/try-on/garments'), headers: await _headers());
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load garments');
    }
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    final response = await http.get(Uri.parse('$baseUrl/auth/me'), headers: await _headers());
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch profile: ${response.body}');
    }
  }
  static String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    if (path.startsWith('results/')) return '$baseUrl/$path';
    if (path.startsWith('uploads/')) return '$baseUrl/$path';
    return '$baseUrl/$path';
  }
}
