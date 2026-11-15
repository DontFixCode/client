import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../config/backend_config.dart';
import '../theme/app_theme.dart';
import 'error_view.dart';

class KakaoPlaceMap extends StatefulWidget {
  const KakaoPlaceMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 240,
  });
  final double latitude;
  final double longitude;
  final double height;

  static String get appKey => BackendConfig.kakaoNativeKey;
  static bool _initialized = false;
  static bool get available => _initialized;

  static Future<void> initialize() async {
    _initialized = false;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS) ||
        appKey.isEmpty) {
      return;
    }
    try {
      await KakaoMapSdk.instance
          .initialize(appKey)
          .timeout(const Duration(seconds: 5));
      _initialized = true;
    } on Exception {
      debugPrint('카카오 지도를 초기화하지 못했습니다.');
    }
  }

  @override
  State<KakaoPlaceMap> createState() => _KakaoPlaceMapState();
}

class _KakaoPlaceMapState extends State<KakaoPlaceMap> {
  bool _failed = false;

  void _showError() {
    if (mounted) setState(() => _failed = true);
  }

  Future<void> _addMarker(KakaoMapController controller) async {
    try {
      final icon = await KImage.fromWidget(
        const Icon(Icons.location_on, color: AppColors.primary, size: 40),
        const Size(40, 40),
      );
      if (!mounted) return;
      await controller.labelLayer.addPoi(
        LatLng(widget.latitude, widget.longitude),
        style: PoiStyle(icon: icon),
      );
    } catch (_) {
      _showError();
    }
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppTheme.radius),
    child: SizedBox(
      height: widget.height,
      child: _failed || !KakaoPlaceMap.available
          ? const ErrorView(
              title: '지도를 불러오지 못했어요',
              message: '장소 정보와 경로 안내는 계속 이용할 수 있어요.',
            )
          : KakaoMap(
              option: KakaoMapOption(
                position: LatLng(widget.latitude, widget.longitude),
                zoomLevel: 16,
              ),
              onMapReady: _addMarker,
              onMapError: (_) => _showError(),
            ),
    ),
  );
}
