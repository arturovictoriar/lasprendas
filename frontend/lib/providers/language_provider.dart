import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class LanguageProvider with ChangeNotifier {
  final _storage = StorageService();
  Locale _locale = const Locale('es');
  static const String _storageKey = 'selected_language';

  LanguageProvider() {
    _loadFromStorage();
  }

  Locale get locale => _locale;

  Future<void> _loadFromStorage() async {
    final savedLanguage = await _storage.read(key: _storageKey);
    if (savedLanguage != null) {
      _locale = Locale(savedLanguage);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    await _storage.write(key: _storageKey, value: locale.languageCode);
    notifyListeners();
  }

  void toggleLanguage() {
    if (_locale.languageCode == 'es') {
      setLocale(const Locale('en'));
    } else {
      setLocale(const Locale('es'));
    }
  }
}
