import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/bus_api.dart';
import '../../models/place.dart';
import '../theme/app_theme.dart';
import 'data_reason.dart';
import 'kakao_place_map.dart';
import 'kakao_route_map.dart';
import 'route_map_data.dart';

class RouteGeometry extends StatefulWidget {
  const RouteGeometry({
    super.key,
    required this.legs,
    this.origin,
    this.destination,
    this.api,
    this.showMap = true,
    this.showLegend = true,
  });
  final List<Json> legs;
  final Place? origin, destination;
  final BusApi? api;
  final bool showMap, showLegend;

  @override
  State<RouteGeometry> createState() => _RouteGeometryState();
}

class _RouteGeometryState extends State<RouteGeometry> {
  Set<BusPattern> _patterns = const {};
  Future<Map<BusPattern, List<Json>>>? _stops;

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  @override
  void didUpdateWidget(covariant RouteGeometry oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadStops(apiChanged: oldWidget.api != widget.api);
  }

  void _loadStops({bool apiChanged = false}) {
    final api = widget.api;
    final patterns = api != null && KakaoPlaceMap.available
        ? RouteMapData.fromLegs(widget.legs).missingPatterns
        : <BusPattern>{};
    if (!apiChanged && setEquals(_patterns, patterns)) return;
    _patterns = patterns;
    _stops = api == null || patterns.isEmpty
        ? null
        : _fetchStops(api, patterns);
  }

  Future<Map<BusPattern, List<Json>>> _fetchStops(
    BusApi api,
    Set<BusPattern> patterns,
  ) async {
    final result = <BusPattern, List<Json>>{};
    await Future.wait(
      patterns.map((pattern) async {
        final id = Uri.encodeComponent(pattern.routeId);
        final key = Uri.encodeComponent(pattern.patternKey);
        try {
          final data = await api.request(
            'GET',
            '/routes/$id/patterns/$key/stops',
          );
          final items = data['items'];
          if (data['routeId'] == pattern.routeId &&
              data['patternKey'] == pattern.patternKey &&
              items is List) {
            result[pattern] = items.whereType<Json>().toList();
          }
        } on ApiException {
          // Exact lines and the stop list remain usable if this request fails.
        }
      }),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _stops,
    builder: (context, snapshot) => _buildGeometry(
      snapshot.connectionState == ConnectionState.done
          ? snapshot.data ?? const {}
          : const {},
      loadingStops: snapshot.connectionState == ConnectionState.waiting,
    ),
  );

  Widget _buildGeometry(
    Map<BusPattern, List<Json>> patternStops, {
    required bool loadingStops,
  }) {
    final legs = widget.legs;
    final data = RouteMapData.fromLegs(
      legs,
      origin: widget.origin,
      destination: widget.destination,
      patternStops: patternStops,
    );
    final lines = data.lines;
    final approximate = <String>{};
    final useMap = KakaoPlaceMap.available;
    final provenance = <String>{};
    final missing = <String>{};
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final segment = lines.where((line) => line.legIndex == i);
      final route = leg['route'];
      final number = route is Map ? route['routeNo'] : null;
      if (segment.any((line) => line.approximate)) {
        approximate.add(number == null ? '버스' : '$number번');
      } else if (segment.isNotEmpty) {
        final source = leg['geometrySource'] ?? leg['provider'];
        final fetchedAt = DateTime.tryParse(
          (leg['geometryFetchedAt'] ?? leg['fetchedAt'] ?? '').toString(),
        )?.toLocal();
        if (source != null) {
          provenance.add(
            '출처: $source${fetchedAt == null ? '' : ' · 수집: ${clockLabel(fetchedAt)}'}',
          );
        }
      } else if (leg['kind'] == 'bus') {
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
        if (widget.showMap && (lines.isNotEmpty || data.markers.isNotEmpty))
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
        if (widget.showMap && widget.showLegend) const SizedBox(height: 8),
        if (!widget.showLegend)
          const SizedBox.shrink()
        else if (loadingStops)
          const Text('누락된 버스 구간의 정류소를 불러오는 중이에요.')
        else if (lines.isEmpty)
          const Text(
            '경로 형상이 없어 아래 정류소·이동 순서로 안내해요.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          )
        else if (missing.isNotEmpty || lines.any((line) => !line.approximate))
          Text(
            '선택한 경로 · 버스 노선 색 선 / 회색 도보${missing.isNotEmpty ? '\n일부 버스 형상은 없어 표시하지 않았어요.' : ''}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        if (widget.showLegend && approximate.isNotEmpty)
          Text(
            '${approximate.join('·')} 흐린 선 · 정류소를 연결한 개략 경로',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        if (widget.showLegend)
          for (final text in [...provenance, if (!loadingStops) ...missing])
            Text(
              text,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
      ],
    );
  }
}
