import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart' as kakao;

import '../theme/app_theme.dart';
import 'route_map_data.dart';

Color busLineColor(String? type) {
  final value = type ?? '';
  if (value.contains('급행')) return AppColors.busExpress;
  if (value.contains('간선')) return AppColors.busTrunk;
  if (value.contains('지선')) return AppColors.busFeeder;
  return AppColors.primary;
}

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
  const KakaoRouteMap({
    super.key,
    required this.data,
    required this.fallback,
    this.bottomInset = 0,
  });

  final RouteMapData data;
  final Widget fallback;
  final double bottomInset;

  @override
  State<KakaoRouteMap> createState() => _KakaoRouteMapState();
}

class _KakaoRouteMapState extends State<KakaoRouteMap> {
  kakao.KakaoMapController? _controller;
  bool _failed = false;
  int _generation = 0;
  Size _viewport = Size.zero;

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
      final walkingStyle = kakao.RouteStyle(
        AppColors.muted,
        6,
        strokeColor: Colors.white,
        strokeWidth: 2,
      );
      for (final line in widget.data.lines) {
        if (!_current(controller, generation)) return;
        if (line.points.length < 2) continue;
        final style = line.walking
            ? walkingStyle
            : kakao.RouteStyle(
                busLineColor(
                  line.routeType,
                ).withValues(alpha: line.approximate ? .55 : 1),
                line.approximate ? 7 : 9,
                strokeColor: Colors.white,
                strokeWidth: line.approximate ? 2 : 3,
              );
        await controller.routeLayer.addRoute(
          line.points.map(_position).toList(),
          style,
          zOrder: line.approximate
              ? 9999
              : line.walking
              ? 10000
              : 10001,
        );
      }
      final styles = <RouteEndpoint?, kakao.PoiStyle>{};
      for (final marker in widget.data.markers) {
        if (!_current(controller, generation)) return;
        final endpoint = marker.endpoint;
        final style = styles[endpoint] ??= await _markerStyle(endpoint);
        if (!_current(controller, generation)) return;
        await controller.labelLayer.addPoi(
          _position(marker.point),
          style: style,
          rank: endpoint == null ? 0 : 100,
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

  Future<kakao.PoiStyle> _markerStyle(RouteEndpoint? endpoint) async {
    if (endpoint == null) {
      return kakao.PoiStyle(
        anchor: const kakao.KPoint(.5, .5),
        icon: await kakao.KImage.fromWidget(
          const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.directions_bus, color: AppColors.blue, size: 13),
          ),
          const Size(18, 18),
        ),
      );
    }

    final color = endpoint == RouteEndpoint.arrival
        ? AppColors.error
        : AppColors.primaryDark;
    return kakao.PoiStyle(
      // The center of the dot is the actual route endpoint coordinate.
      anchor: const kakao.KPoint(.5, 31 / 35),
      icon: await kakao.KImage.fromWidget(
        Column(
          children: [
            Container(
              width: double.infinity,
              height: 23,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: Colors.white, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                endpoint.label,
                style: const TextStyle(
                  inherit: false,
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
            Container(width: 2, height: 4, color: color),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ],
        ),
        Size(endpoint == RouteEndpoint.both ? 66 : 42, 35),
      ),
    );
  }

  Future<void> _fitRoute() async {
    final controller = _controller;
    final generation = _generation;
    final camera = widget.data.cameraFor(
      _viewport,
      bottomInset: widget.bottomInset,
    );
    if (controller == null || camera == null) return;
    try {
      await controller.moveCamera(
        kakao.CameraUpdate.newCenterPosition(
          _position(camera.center),
          zoomLevel: camera.zoomLevel,
        ),
      );
    } catch (_) {
      if (_current(controller, generation)) _showError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    if (_failed) return widget.fallback;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        if (viewport != _viewport) {
          _viewport = viewport;
          if (_controller != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fitRoute();
            });
          }
        }
        final camera = widget.data.cameraFor(
          viewport,
          bottomInset: widget.bottomInset,
        );
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
                    position: camera == null
                        ? const kakao.LatLng(36.3324, 127.4342)
                        : _position(camera.center),
                    zoomLevel: camera?.zoomLevel ?? 12,
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
      },
    );
  }
}
