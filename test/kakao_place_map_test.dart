import 'dart:convert';

import 'package:bus/config/backend_config.dart';
import 'package:bus/ui/widgets/kakao_place_map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _MapConfig extends CachingAssetBundle {
  _MapConfig(this.keyValue);
  final String keyValue;

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    Uint8List.fromList(utf8.encode(jsonEncode({'KAKAO_NATIVE_KEY': keyValue}))),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'map is optional and SDK failure does not interrupt app startup',
    () async {
      const channel = MethodChannel('flutter_kakao_maps_sdk');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(channel, null);
      });

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await BackendConfig.load(bundle: _MapConfig(''));
      await KakaoPlaceMap.initialize();
      expect(KakaoPlaceMap.available, isFalse);
      expect(calls, isEmpty);

      await BackendConfig.load(bundle: _MapConfig('public-test-native-key'));
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await KakaoPlaceMap.initialize();
      expect(KakaoPlaceMap.available, isFalse);
      expect(calls, isEmpty);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await KakaoPlaceMap.initialize();
      expect(KakaoPlaceMap.available, isTrue);
      expect(calls.single.method, 'initialize');
      expect(calls.single.arguments, {'appKey': 'public-test-native-key'});

      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'unavailable');
      });
      await KakaoPlaceMap.initialize();
      expect(KakaoPlaceMap.available, isFalse);
    },
  );
}
