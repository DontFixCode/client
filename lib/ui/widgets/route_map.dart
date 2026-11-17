import 'package:flutter/material.dart';

import '../../models/place.dart';
import '../theme/app_theme.dart';
import 'kakao_place_map.dart';
import 'kakao_route_map.dart';
import 'route_map_data.dart';

/// 체험 화면에서도 실제 지도와 제공된 좌표만 표시합니다.
class RouteMap extends StatelessWidget {
  const RouteMap({super.key, this.height = 240, this.origin, this.destination});

  final double height;
  final Place? origin, destination;

  @override
  Widget build(BuildContext context) {
    final data = RouteMapData.fromLegs(
      [],
      origin: origin,
      destination: destination,
    );
    const fallback = KakaoMapUnavailable();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.markers.isEmpty) ...[
          const Text(
            '대전 지역 지도',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: height,
          width: double.infinity,
          child: KakaoPlaceMap.available
              ? KakaoRouteMap(
                  key: ValueKey(data.fingerprint),
                  data: data,
                  fallback: fallback,
                )
              : fallback,
        ),
        const SizedBox(height: 8),
        const Text(
          '체험용 지도 · 경로선은 실제 검색에서 확인할 수 있어요.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
