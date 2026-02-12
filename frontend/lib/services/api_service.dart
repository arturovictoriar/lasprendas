import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'storage_service.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.10.13:3000';
  static final _storage = StorageService();

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

  static Future<Map<String, dynamic>> verify(String email, String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'code': code}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Verification failed: ${response.body}');
    }
  }

  static Future<void> resendCode(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/resend-code'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to resend code: ${response.body}');
    }
  }

  static Future<void> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    );

    if (response.statusCode != 200) {
      throw Exception('Forgot password request failed: ${response.body}');
    }
  }

  static Future<void> verifyResetCode(String email, String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-reset-code'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'code': code}),
    );

    if (response.statusCode != 200) {
      throw Exception('Invalid or expired reset code: ${response.body}');
    }
  }

  static Future<void> resetPassword(String email, String code, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'code': code, 'password': newPassword}),
    );

    if (response.statusCode != 200) {
      throw Exception('Password reset failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> _getUploadParams(String filename, String mimeType, {String? hash}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/storage/upload-params?filename=$filename&mimeType=$mimeType${hash != null ? '&hash=$hash' : ''}'),
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

  static Future<Map<String, dynamic>> uploadGarments(List<File> images, {List<String>? garmentIds, String personType = 'female', List<String>? hashes}) async {
    final List<String> garmentKeys = [];
    final List<String> garmentHashes = [];
    final List<String> finalGarmentIds = garmentIds != null ? List.from(garmentIds) : [];
    // Track which garment corresponds to which input image
    final List<dynamic> resolvedForImages = List.filled(images.length, null);

    // 1. Upload each image directly to S3
    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      final hash = (hashes != null && i < hashes.length) ? hashes[i] : null;
      
      final filename = basename(image.path);
      const mimeType = 'image/png'; // Default or detect

      final params = await _getUploadParams(filename, mimeType, hash: hash);
      
      if (params['alreadyExists'] == true && params['garment'] != null) {
        // Skip upload, use existing garment ID
        finalGarmentIds.add(params['garment']['id']);
        resolvedForImages[i] = params['garment'];
      } else {
        final uploadUrl = params['uploadUrl'];
        final key = params['key'];

        await _uploadFileToS3(uploadUrl, image, mimeType);
        garmentKeys.add(key);
        if (hash != null) {
          garmentHashes.add(hash);
        }
        // Mark as needing to be filled from backend response
        resolvedForImages[i] = {'_tempKey': key};
      }
    }

    // 2. Create try-on session with the keys
    final response = await http.post(
      Uri.parse('$baseUrl/try-on'),
      headers: await _headers(),
      body: json.encode({
        'personType': personType,
        'garmentKeys': garmentKeys,
        'garmentIds': finalGarmentIds,
        'garmentHashes': garmentHashes,
      }),
    );
    
    if (response.statusCode == 201 || response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final List<dynamic> uploaded = responseData['uploadedGarments'] ?? [];

      // Map uploaded garments back to resolvedForImages
      int uploadIdx = 0;
      for (var i = 0; i < resolvedForImages.length; i++) {
        if (resolvedForImages[i] is Map && resolvedForImages[i].containsKey('_tempKey')) {
          if (uploadIdx < uploaded.length) {
            resolvedForImages[i] = uploaded[uploadIdx];
            uploadIdx++;
          }
        }
      }
      
      responseData['resolvedGarments'] = resolvedForImages;
      return responseData;
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
  static Future<List<dynamic>> smartSearch({String? query, String? color, String? category, String? subcategory}) async {
    final queryParams = <String, String>{
      if (query != null && query.isNotEmpty) 'q': query,
      if (color != null && color.isNotEmpty) 'color': color,
      if (category != null && category.isNotEmpty) 'category': category,
      if (subcategory != null && subcategory.isNotEmpty) 'subcategory': subcategory,
    };

    final uri = Uri.parse('$baseUrl/filter/smart-search').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: await _headers());

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Smart search failed: ${response.body}');
    }
  }

  static Future<List<dynamic>> smartSearchSessions({String? query, String? category}) async {
    final queryParams = <String, String>{
      if (query != null && query.isNotEmpty) 'q': query,
      if (category != null && category.isNotEmpty) 'category': category,
    };

    final uri = Uri.parse('$baseUrl/filter/smart-search-sessions').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: await _headers());

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Smart search sessions failed: ${response.body}');
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
