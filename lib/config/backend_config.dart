import 'dart:convert';

import 'package:flutter/services.dart';

class BackendConfig {
  static const _overrides = {
    if (bool.hasEnvironment('API_BASE_URL'))
      'API_BASE_URL': String.fromEnvironment('API_BASE_URL'),
    if (bool.hasEnvironment('SUPABASE_URL'))
      'SUPABASE_URL': String.fromEnvironment('SUPABASE_URL'),
    if (bool.hasEnvironment('SUPABASE_ANON_KEY'))
      'SUPABASE_ANON_KEY': String.fromEnvironment('SUPABASE_ANON_KEY'),
    if (bool.hasEnvironment('AUTH_REDIRECT_URL'))
      'AUTH_REDIRECT_URL': String.fromEnvironment('AUTH_REDIRECT_URL'),
    if (bool.hasEnvironment('KAKAO_NATIVE_KEY'))
      'KAKAO_NATIVE_KEY': String.fromEnvironment('KAKAO_NATIVE_KEY'),
  };
  static Map<String, String> _values = _overrides;

  static Future<void> load({AssetBundle? bundle}) async {
    final json = await (bundle ?? rootBundle).loadString(
      'config/backend.local.json',
    );
    _values = {
      ...Map<String, String>.from(jsonDecode(json) as Map),
      ..._overrides,
    };
  }

  static String get apiUrl =>
      _values['API_BASE_URL'] ?? 'http://localhost:8001';
  static String get supabaseUrl => _values['SUPABASE_URL'] ?? '';
  static String get supabaseKey => _values['SUPABASE_ANON_KEY'] ?? '';
  static String get authRedirect => _values['AUTH_REDIRECT_URL'] ?? '';
  static String get kakaoNativeKey => _values['KAKAO_NATIVE_KEY'] ?? '';
  static const demo = bool.fromEnvironment('DEMO_MODE');
  static bool get authConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
