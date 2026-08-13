import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureSecretStore {
  const SecureSecretStore();

  static const MethodChannel _channel = MethodChannel('weaview/secure_storage');
  static const String _desktopFallbackKey =
      'weaview_non_android_secure_secrets';

  Future<Map<String, String>> readAll(SharedPreferences prefs) async {
    if (!Platform.isAndroid) return _readDesktopFallback(prefs);
    try {
      final result = await _channel.invokeMapMethod<String, String>('readAll');
      return Map<String, String>.from(result ?? const {});
    } on PlatformException {
      return const {};
    } on MissingPluginException {
      return const {};
    }
  }

  Future<bool> replaceAll(
    SharedPreferences prefs,
    Map<String, String> values,
  ) async {
    if (!Platform.isAndroid) {
      return prefs.setString(_desktopFallbackKey, jsonEncode(values));
    }
    try {
      await _channel.invokeMethod<void>('replaceAll', values);
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> clear(SharedPreferences prefs) async {
    if (!Platform.isAndroid) {
      await prefs.remove(_desktopFallbackKey);
      return;
    }
    try {
      await _channel.invokeMethod<void>('clear');
    } on PlatformException {
      // Preference clearing must continue even if native secure storage fails.
    } on MissingPluginException {
      // Tests and unsupported hosts do not register the Android channel.
    }
  }

  Map<String, String> _readDesktopFallback(SharedPreferences prefs) {
    final text = prefs.getString(_desktopFallbackKey);
    if (text == null || text.isEmpty) return const {};
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return const {};
    }
  }
}
