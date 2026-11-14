import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import 'app.dart';
import 'ui/widgets/kakao_place_map.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (KakaoPlaceMap.available) {
    await KakaoMapSdk.instance.initialize(KakaoPlaceMap.appKey);
  }
  runApp(const BusroApp());
}
