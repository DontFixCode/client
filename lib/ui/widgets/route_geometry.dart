import 'package:flutter/material.dart';

import '../../data/bus_api.dart';
import '../../models/place.dart';
import '../theme/app_theme.dart';
import 'data_reason.dart';
import 'kakao_place_map.dart';
import 'kakao_route_map.dart';
import 'route_map_data.dart';

/// 제공된 GeoJSON 형상만 표시하며 임의의 도로·위치를 만들지 않습니다.
class RouteGeometry extends StatelessWidget {
  const RouteGeometry({
    super.key,
    required this.legs,
    this.origin,
    this.destination,
  });
  final List<Json> legs;
  final Place? origin, destination;
  @override
  Widget build(BuildContext context) {
    final data = RouteMapData.fromLegs(
      legs,
      origin: origin,
      destination: destination,
    );
    final lines = data.lines;
    final useMap = KakaoPlaceMap.available;
    final provenance = <String>{};
    final missing = <String>{};
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      if (lines.any((line) => line.legIndex == i)) {
        final source = leg['geometrySource'] ?? leg['provider'];
        final fetchedAt = DateTime.tryParse(
          (leg['geometryFetchedAt'] ?? leg['fetchedAt'] ?? '').toString(),
        )?.toLocal();
        if (source != null) {
          provenance.add(
            '출처: $source${fetchedAt == null ? '' : ' · 수집: ${fetchedAt.toString().split('.').first}'}',
          );
        }
      } else if (leg['kind'] == 'bus') {
        final number = leg['route']?['routeNo'];
        final reason = leg['geometryReason'] as String?;
        missing.add(
          '${number == null ? '버스 구간' : '$number번'} 형상: ${reason == null ? '아직 확보하지 못했어요.' : dataReason(reason)}',
        );
      }
    }
    const fallback = KakaoMapUnavailable();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lines.isNotEmpty || data.markers.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: SizedBox(
              height: 280,
              width: double.infinity,
              child: useMap
                  ? KakaoRouteMap(
                      key: ValueKey(data.fingerprint),
                      data: data,
                      fallback: fallback,
                    )
                  : fallback,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          lines.isEmpty
              ? '경로 형상이 없어 아래 정류소·이동 순서로 안내해요.'
              : '선택한 경로 · 초록색 버스 / 회색 도보${missing.isNotEmpty ? '\n일부 버스 형상은 없어 표시하지 않았어요.' : ''}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        for (final text in [...provenance, ...missing])
          Text(
            text,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
      ],
    );
  }
}
