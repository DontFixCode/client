import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/bus_api.dart';
import '../theme/app_theme.dart';
import 'data_reason.dart';

/// 제공된 GeoJSON 형상만 표시하며 임의의 도로·위치를 만들지 않습니다.
class RouteGeometry extends StatelessWidget {
  const RouteGeometry({super.key, required this.legs});
  final List<Json> legs;
  @override
  Widget build(BuildContext context) {
    final lines = <List<Offset>>[];
    void read(dynamic value) {
      if (value is! Map) return;
      final coordinates = value['coordinates'];
      switch (value['type']) {
        case 'LineString':
          if (coordinates is List) {
            final points = coordinates
                .whereType<List>()
                .where((p) => p.length >= 2 && p[0] is num && p[1] is num)
                .map(
                  (p) => Offset(
                    (p[0] as num).toDouble(),
                    (p[1] as num).toDouble(),
                  ),
                )
                .where((p) => p.dx.isFinite && p.dy.isFinite)
                .toList();
            if (points.length > 1) lines.add(points);
          }
        case 'MultiLineString':
          for (final line in coordinates as List? ?? []) {
            read({'type': 'LineString', 'coordinates': line});
          }
        case 'Feature':
          read(value['geometry']);
        case 'FeatureCollection':
          for (final feature in value['features'] as List? ?? []) {
            read(feature);
          }
      }
    }

    final provenance = <String>{};
    final missing = <String>{};
    for (final leg in legs) {
      final before = lines.length;
      if (leg['kind'] != 'bus' || leg['geometryStatus'] == 'available') {
        read(leg['geometry']);
      }
      if (lines.length > before) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lines.isNotEmpty)
          SizedBox(
            height: 190,
            width: double.infinity,
            child: CustomPaint(painter: _GeometryPainter(lines)),
          ),
        Text(
          lines.isEmpty
              ? '경로 형상이 없어 아래 정류소·이동 순서로 안내해요.'
              : '제공처 경로 형상 · 배경 지도 없음${missing.isNotEmpty ? '\n일부 버스 형상은 없어 표시하지 않았어요.' : ''}',
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

class _GeometryPainter extends CustomPainter {
  _GeometryPainter(this.lines);
  final List<List<Offset>> lines;
  @override
  void paint(Canvas canvas, Size size) {
    final points = lines.expand((l) => l);
    final minX = points.map((p) => p.dx).reduce(math.min),
        maxX = points.map((p) => p.dx).reduce(math.max);
    final minY = points.map((p) => p.dy).reduce(math.min),
        maxY = points.map((p) => p.dy).reduce(math.max);
    final scale = math.min(
      (size.width - 28) / math.max(maxX - minX, 0.00001),
      (size.height - 28) / math.max(maxY - minY, 0.00001),
    );
    Offset project(Offset p) => Offset(
      size.width / 2 + (p.dx - (maxX + minX) / 2) * scale,
      size.height / 2 - (p.dy - (maxY + minY) / 2) * scale,
    );
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final line in lines) {
      final path = Path()
        ..moveTo(project(line.first).dx, project(line.first).dy);
      for (final p in line.skip(1)) {
        final projected = project(p);
        path.lineTo(projected.dx, projected.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GeometryPainter oldDelegate) =>
      oldDelegate.lines != lines;
}
