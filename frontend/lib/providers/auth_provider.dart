import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  String? _token;
  String? _userName;
  String? _userEmail;
  bool _isLoading = false;

  String? get token => _token;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  AuthProvider() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    _token = await _storage.read(key: 'jwt_token');
    _userName = await _storage.read(key: 'user_name');
    _userEmail = await _storage.read(key: 'user_email');
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await ApiService.login(email, password);
      _token = result['access_token'];
      await _storage.write(key: 'jwt_token', value: _token);
      
      // Fetch profile to get name and email
      await fetchProfile();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchProfile() async {
    try {
      final profile = await ApiService.getUserProfile();
      _userName = profile['name'];
      _userEmail = profile['email'];
      await _storage.write(key: 'user_name', value: _userName);
      await _storage.write(key: 'user_email', value: _userEmail);
      notifyListeners();
    } catch (e) {
      print('Failed to fetch profile: $e');
    }
  }

  Future<bool> register(String email, String password, String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      await ApiService.register(email, password, name);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_name');
    await _storage.delete(key: 'user_email');
    _token = null;
    _userName = null;
    _userEmail = null;
    notifyListeners();
  }
}
