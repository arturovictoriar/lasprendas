import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false, // Prevents iCloud sync conflicts which cause -25299
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Simple mutex to prevent concurrent writes to the same or different keys
  // which can sometimes confuse the keychain on iOS.
  static final _lock = StreamController<bool>.broadcast();
  static bool _isLocked = false;

  Future<T> _synchronized<T>(Future<T> Function() action) async {
    while (_isLocked) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _isLocked = true;
    try {
      return await action();
    } finally {
      _isLocked = false;
    }
  }

  Future<void> write({required String key, required String value}) async {
    await _synchronized(() async {
      try {
        await _storage.write(key: key, value: value);
      } on PlatformException catch (e) {
        if (e.code.toString().contains('-25299')) {
          // If item already exists, delete and retry once
          await _storage.delete(key: key);
          await _storage.write(key: key, value: value);
        } else {
          rethrow;
        }
      }
    });
  }

  Future<String?> read({required String key}) async {
    return await _storage.read(key: key);
  }

  Future<void> delete({required String key}) async {
    await _synchronized(() async {
      await _storage.delete(key: key);
    });
  }

  Future<void> deleteAll() async {
    await _synchronized(() async {
      await _storage.deleteAll();
    });
  }

  Future<Map<String, String>> readAll() async {
    return await _storage.readAll();
  }
}
