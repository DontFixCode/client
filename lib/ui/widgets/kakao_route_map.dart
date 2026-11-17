import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart' as kakao;

import '../theme/app_theme.dart';
import 'route_map_data.dart';

class KakaoMapUnavailable extends StatelessWidget {
  const KakaoMapUnavailable({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            '카카오 지도를 불러오지 못했어요',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            '아래 정류소·이동 순서로 계속 확인할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class KakaoRouteMap extends StatefulWidget {
  const KakaoRouteMap({super.key, required this.data, required this.fallback});

  final RouteMapData data;
  final Widget fallback;

  @override
  State<KakaoRouteMap> createState() => _KakaoRouteMapState();
}

class _KakaoRouteMapState extends State<KakaoRouteMap> {
  kakao.KakaoMapController? _controller;
  bool _failed = false;
  int _generation = 0;

  List<Offset> get _points => [
    for (final line in widget.data.lines) ...line.points,
    for (final marker in widget.data.markers) marker.point,
  ];

  kakao.LatLng _position(Offset point) => kakao.LatLng(point.dy, point.dx);

  bool _current(kakao.KakaoMapController controller, int generation) =>
      mounted &&
      !_failed &&
      identical(_controller, controller) &&
      _generation == generation;

  void _showError() {
    if (mounted && !_failed) setState(() => _failed = true);
  }

  Future<void> _onMapReady(kakao.KakaoMapController controller) async {
    if (!mounted || _failed) return;
    setState(() => _controller = controller);
    final generation = ++_generation;
    try {
      final busStyle = kakao.RouteStyle(
        AppColors.primary,
        7,
        strokeColor: Colors.white,
        strokeWidth: 2,
      );
      final walkingStyle = kakao.RouteStyle(
        AppColors.muted,
        5,
        strokeColor: Colors.white,
        strokeWidth: 1,
      );
      for (final line in widget.data.lines) {
        if (!_current(controller, generation)) return;
        if (line.points.length < 2) continue;
        await controller.routeLayer.addRoute(
          line.points.map(_position).toList(),
          line.walking ? walkingStyle : busStyle,
        );
      }
      final styles = <bool, kakao.PoiStyle>{};
      for (final marker in widget.data.markers) {
        if (!_current(controller, generation)) return;
        var style = styles[marker.endpoint];
        if (style == null) {
          final icon = await kakao.KImage.fromWidget(
            DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                marker.endpoint ? Icons.location_on : Icons.directions_bus,
                color: marker.endpoint ? AppColors.primary : AppColors.blue,
                size: 18,
              ),
            ),
            const Size(22, 22),
          );
          if (!_current(controller, generation)) return;
          style = kakao.PoiStyle(
            icon: icon,
            padding: 2,
            textStyle: marker.endpoint
                ? const [
                    kakao.PoiTextStyle(
                      size: 13,
                      color: AppColors.text,
                      stroke: 2,
                      strokeColor: Colors.white,
                    ),
                  ]
                : const [],
          );
          styles[marker.endpoint] = style;
        }
        await controller.labelLayer.addPoi(
          _position(marker.point),
          style: style,
          text: marker.endpoint
              ? marker.label
                    .split('\n')
                    .map((line) => line.split(' · ').first)
                    .where((label) => label == '출발' || label == '도착')
                    .toSet()
                    .join('·')
              : null,
          rank: marker.endpoint ? 100 : 0,
          onClick: () {
            if (!_current(controller, generation)) return;
            ScaffoldMessenger.maybeOf(context)
              ?..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(marker.label)));
          },
        );
      }
      if (_current(controller, generation)) await _fitRoute();
    } catch (_) {
      if (_current(controller, generation)) _showError();
    }
  }

  Future<void> _fitRoute() async {
    final controller = _controller;
    final generation = _generation;
    final points = _points;
    if (controller == null || points.isEmpty) return;
    final minX = points.map((point) => point.dx).reduce(math.min);
    final maxX = points.map((point) => point.dx).reduce(math.max);
    final minY = points.map((point) => point.dy).reduce(math.min);
    final maxY = points.map((point) => point.dy).reduce(math.max);
    try {
      if (minX == maxX && minY == maxY) {
        await controller.moveCamera(
          kakao.CameraUpdate.newCenterPosition(
            _position(points.first),
            zoomLevel: 16,
          ),
        );
      } else {
        // SDK 1.3.1 ignores fitMapPoints.padding on iOS, so expand the bounds.
        final padX = math.max((maxX - minX) * .18, .0003);
        final padY = math.max((maxY - minY) * .18, .0003);
        await controller.moveCamera(
          kakao.CameraUpdate.fitMapPoints(
            [
              kakao.LatLng(
                (minY - padY).clamp(-90.0, 90.0).toDouble(),
                (minX - padX).clamp(-180.0, 180.0).toDouble(),
              ),
              kakao.LatLng(
                (maxY + padY).clamp(-90.0, 90.0).toDouble(),
                (maxX + padX).clamp(-180.0, 180.0).toDouble(),
              ),
            ],
            padding: 24,
            zoomLevel: 16,
          ),
        );
      }
    } catch (_) {
      if (_current(controller, generation)) _showError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    if (_failed) return widget.fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            label: points.isEmpty
                ? '대전 지역 지도'
                : '경로 지도. ${widget.data.markers.map((marker) => marker.label).join(', ')}',
            child: kakao.KakaoMap(
              option: kakao.KakaoMapOption(
                position: points.isEmpty
                    ? const kakao.LatLng(36.3324, 127.4342)
                    : _position(points.first),
                zoomLevel: points.isEmpty ? 12 : 16,
              ),
              onMapReady: _onMapReady,
              onMapError: (_) => _showError(),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filledTonal(
              tooltip: '전체 경로 보기',
              style: IconButton.styleFrom(backgroundColor: Colors.white),
              onPressed: _controller == null ? null : _fitRoute,
              icon: const Icon(
                Icons.zoom_out_map,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
