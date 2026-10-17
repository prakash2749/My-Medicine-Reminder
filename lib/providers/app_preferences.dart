import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-health preferences only. Guest data uses its own encrypted local owner.
class AppPreferences extends ChangeNotifier {
  static const guestOwner = 'local:guest:v1';
  SharedPreferences? _storage;
  late final Future<void> ready;
  bool loaded = false, guestEnabled = false;
  String language = 'device';
  String? error;

  AppPreferences({SharedPreferences? storage}) : _storage = storage {
    ready = _load();
  }

  Future<void> _load() async {
    try {
      final storage = _storage ??= await SharedPreferences.getInstance();
      guestEnabled = storage.getBool('local.guest.enabled') ?? false;
      language = storage.getString('app.language') ?? 'device';
      if (!['device', 'en', 'hi'].contains(language)) language = 'device';
    } catch (_) {
      error = 'Could not load settings. Please retry.';
    }
    loaded = true;
    notifyListeners();
  }

  Locale? get locale => language == 'device' ? null : Locale(language);

  Future<bool> setGuest(bool enabled) async {
    await ready;
    try {
      final storage = _storage ??= await SharedPreferences.getInstance();
      if (!await storage.setBool('local.guest.enabled', enabled)) {
        throw StateError('Preference write failed');
      }
      guestEnabled = enabled;
      error = null;
      notifyListeners();
      return true;
    } catch (_) {
      error = 'Could not save settings. Please retry.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> setLanguage(String value) async {
    if (!['device', 'en', 'hi'].contains(value)) return false;
    await ready;
    try {
      final storage = _storage ??= await SharedPreferences.getInstance();
      if (!await storage.setString('app.language', value)) {
        throw StateError('Preference write failed');
      }
      language = value;
      error = null;
      notifyListeners();
      return true;
    } catch (_) {
      error = 'Could not save settings. Please retry.';
      notifyListeners();
      return false;
    }
  }
}
