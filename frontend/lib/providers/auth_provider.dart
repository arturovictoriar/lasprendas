import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> _resilientWrite(String key, String value) async {
    try {
      await _storage.write(
        key: key, 
        value: value,
        iOptions: const IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
      );
    } on PlatformException catch (e) {
      if (e.code.toString().contains('-25299')) {
        await _storage.delete(
          key: key,
          iOptions: const IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
        );
        await _storage.write(
          key: key, 
          value: value,
          iOptions: const IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
        );
      } else {
        rethrow;
      }
    }
  }
  Future<void> _resilientDelete(String key) async {
    await _storage.delete(
      key: key,
      iOptions: const IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
    );
  }

  String? _token;
  String? _userName;
  String? _userEmail;
  bool _isVerified = false;
  bool _isLoading = false;
  String? _lastError;

  String? get token => _token;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  bool get isVerified => _isVerified;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get isAuthenticated => _token != null;

  AuthProvider() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    _token = await _storage.read(key: 'jwt_token');
    _userName = await _storage.read(key: 'user_name');
    _userEmail = await _storage.read(key: 'user_email');
    _isVerified = (await _storage.read(key: 'is_verified')) == 'true';
    notifyListeners();
  }

  Future<void> _clearWorkbench() async {
    await _resilientDelete('selected_garments');
    await _resilientDelete('person_type');
    await _resilientDelete('processing_session_id');
    await _resilientDelete('processing_items');
    await _resilientDelete('processing_person_type');
    await _resilientDelete('result_path');
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final result = await ApiService.login(email, password);
      _token = result['access_token'];
      await _resilientWrite('jwt_token', _token!);
      
      await fetchProfile();
      await _clearWorkbench();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
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
      _isVerified = profile['isVerified'] ?? false;
      await _resilientWrite('user_name', _userName!);
      await _resilientWrite('user_email', _userEmail!);
      await _resilientWrite('is_verified', _isVerified.toString());
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      print('Failed to fetch profile: $e');
    }
  }

  Future<bool> register(String email, String password, String name) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      await ApiService.register(email, password, name);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyAccount(String email, String code) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final result = await ApiService.verify(email, code);
      
      // Manejar Seamless Login (Login automático tras verificar)
      if (result.containsKey('access_token')) {
        _token = result['access_token'];
        await _resilientWrite('jwt_token', _token!);
        await fetchProfile();
        await _clearWorkbench();
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendVerificationCode(String email) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      await ApiService.resendCode(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      await ApiService.forgotPassword(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> validateResetCode(String email, String code) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      await ApiService.verifyResetCode(email, code);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email, String code, String newPassword) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      await ApiService.resetPassword(email, code, newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _resilientDelete('jwt_token');
    await _resilientDelete('user_name');
    await _resilientDelete('user_email');
    await _resilientDelete('is_verified');
    await _clearWorkbench();
    _token = null;
    _userName = null;
    _userEmail = null;
    _isVerified = false;
    notifyListeners();
  }
}
