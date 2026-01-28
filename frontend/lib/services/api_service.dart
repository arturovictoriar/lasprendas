import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

class ApiService {
  // Use 192.168.10.11 for physical devices on your Mac's network
  static const String baseUrl = 'http://192.168.10.11:3000'; 
  
  static Future<Map<String, dynamic>> uploadGarment(File image, String category) async {
    final url = Uri.parse('$baseUrl/try-on');
    final request = http.MultipartRequest('POST', url);
    
    request.fields['category'] = category;
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        image.path,
        filename: basename(image.path),
      ),
    );

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    
    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(responseData);
    } else {
      throw Exception('Failed to upload garment: $responseData');
    }
  }
}
