import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../theme/app_theme.dart';

class KakaoPlaceMap extends StatelessWidget {
  const KakaoPlaceMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 240,
  });
  final double latitude;
  final double longitude;
  final double height;

  static const appKey = String.fromEnvironment('KAKAO_NATIVE_KEY');
  static bool get available => !kIsWeb && appKey.isNotEmpty;

  Future<void> _addMarker(KakaoMapController controller) async {
    final icon = await KImage.fromWidget(
      const Icon(Icons.location_on, color: AppColors.primary, size: 40),
      const Size(40, 40),
    );
    await controller.labelLayer.addPoi(
      LatLng(latitude, longitude),
      style: PoiStyle(icon: icon),
    );
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppTheme.radius),
    child: SizedBox(
      height: height,
      child: KakaoMap(
        option: KakaoMapOption(
          position: LatLng(latitude, longitude),
          zoomLevel: 16,
        ),
        onMapReady: _addMarker,
      ),
    ),
  );
}
