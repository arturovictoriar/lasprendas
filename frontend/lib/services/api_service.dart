import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://172.20.10.6:3000'; 
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

  static Future<Map<String, dynamic>> uploadGarments(List<File> images, String category, {List<String>? garmentIds, String personType = 'female'}) async {
    final url = Uri.parse('$baseUrl/try-on');
    final request = http.MultipartRequest('POST', url);
    
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    request.fields['category'] = category;
    request.fields['personType'] = personType;
    if (garmentIds != null) {
      for (var i = 0; i < garmentIds.length; i++) {
        request.fields['garmentIds[$i]'] = garmentIds[i];
      }
    }
    
    for (var image in images) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'images',
          image.path,
          filename: basename(image.path),
        ),
      );
    }

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    
    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(responseData);
    } else {
      throw Exception('Failed to upload garments: $responseData');
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
}
