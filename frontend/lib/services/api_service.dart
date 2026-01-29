import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

class ApiService {
  // Use 192.168.10.11 for physical devices on your Mac's network
  static const String baseUrl = 'http://192.168.10.11:3000'; 
  
  static Future<Map<String, dynamic>> uploadGarments(List<File> images, String category, {List<String>? garmentIds}) async {
    final url = Uri.parse('$baseUrl/try-on');
    final request = http.MultipartRequest('POST', url);
    
    request.fields['category'] = category;
    if (garmentIds != null) {
      for (var i = 0; i < garmentIds.length; i++) {
        request.fields['garmentIds[$i]'] = garmentIds[i];
      }
    }
    
    for (var image in images) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'images', // Changed to 'images' to match the expected backend field for multiple files
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

  static Future<List<dynamic>> getSessions() async {
    final response = await http.get(Uri.parse('$baseUrl/try-on/sessions'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load sessions');
    }
  }

  static Future<List<dynamic>> getGarments() async {
    final response = await http.get(Uri.parse('$baseUrl/try-on/garments'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load garments');
    }
  }
}
