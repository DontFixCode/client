import 'dart:convert';

import 'package:bus/config/backend_config.dart';
import 'package:bus/data/bus_api.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _ConfigAsset extends CachingAssetBundle {
  _ConfigAsset(this.content);
  final String content;

  @override
  Future<ByteData> load(String key) async {
    expect(key, 'config/backend.local.json');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}

void main() {
  test(
    'loads local settings before API creation; explicit defines take priority',
    () async {
      await BackendConfig.load(
        bundle: _ConfigAsset(
          jsonEncode({
            'API_BASE_URL': 'https://api.local.test',
            'SUPABASE_URL': 'https://auth.local.test',
            'SUPABASE_ANON_KEY': 'public-test-key',
            'AUTH_REDIRECT_URL': 'busro://local-callback',
          }),
        ),
      );

      expect(
        BackendConfig.apiUrl,
        const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'https://api.local.test',
        ),
      );
      expect(
        BackendConfig.supabaseUrl,
        const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: 'https://auth.local.test',
        ),
      );
      expect(
        BackendConfig.supabaseKey,
        const String.fromEnvironment(
          'SUPABASE_ANON_KEY',
          defaultValue: 'public-test-key',
        ),
      );
      expect(
        BackendConfig.authRedirect,
        const String.fromEnvironment(
          'AUTH_REDIRECT_URL',
          defaultValue: 'busro://local-callback',
        ),
      );
      expect(
        BackendConfig.authConfigured,
        BackendConfig.supabaseUrl.isNotEmpty &&
            BackendConfig.supabaseKey.isNotEmpty,
      );

      final api = BusApi(accessToken: () async => null);
      addTearDown(api.close);
      expect(api.uri('/me').toString(), '${BackendConfig.apiUrl}/api/v1/me');
    },
  );

  test(
    'rejects invalid JSON instead of silently using another server',
    () async {
      await expectLater(
        BackendConfig.load(bundle: _ConfigAsset('{')),
        throwsFormatException,
      );
    },
  );
}
