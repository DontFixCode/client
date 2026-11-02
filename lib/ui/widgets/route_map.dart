import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 지도 API 연결 전 사용하는 노선 개념도입니다. 실제 지도가 아닙니다.
class RouteMap extends StatelessWidget {
  const RouteMap({
    super.key,
    this.height = 240,
    this.showRoute = true,
    this.originLabel = '대전역',
    this.destinationLabel = '한밭수목원',
    this.activeStep = 0,
  });
  final double height;
  final bool showRoute;
  final String originLabel;
  final String destinationLabel;
  final int activeStep;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppTheme.radius),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _MapPainter(showRoute, activeStep)),
          ),
          const Positioned(
            top: 14,
            left: 14,
            child: _MapLabel('대전 · 경로 개념도', icon: Icons.map_outlined),
          ),
          Positioned(
            left: 20,
            bottom: 24,
            child: _MapLabel(originLabel, icon: Icons.trip_origin_rounded),
          ),
          Positioned(
            right: 20,
            top: height * .28,
            child: _MapLabel(destinationLabel, icon: Icons.flag_rounded),
          ),
          const Positioned(
            right: 12,
            bottom: 10,
            child: Text(
              '실제 지도가 아닌 예시입니다',
              style: TextStyle(fontSize: 9, color: AppColors.muted),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MapLabel extends StatelessWidget {
  const _MapLabel(this.label, {required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 170),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .95),
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryDark.withValues(alpha: .04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.primary),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.showRoute, this.activeStep);
  final bool showRoute;
  final int activeStep;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);
    final parkPaint = Paint()..color = AppColors.lime;
    for (final rect in [
      Rect.fromLTWH(w * .05, h * .1, w * .27, h * .24),
      Rect.fromLTWH(w * .73, h * .08, w * .25, h * .3),
      Rect.fromLTWH(w * .57, h * .68, w * .32, h * .27),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(25)),
        parkPaint,
      );
    }
    final river = Path()
      ..moveTo(w * .42, -20)
      ..cubicTo(w * .7, h * .35, w * .16, h * .6, w * .44, h + 30);
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xFFD6DEEC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28,
    );
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 6; i++) {
      final y = h * (.05 + i * .2);
      canvas.drawLine(Offset(-20, y), Offset(w + 20, y - h * .18), roadPaint);
    }
    for (int i = 0; i < 6; i++) {
      final x = w * (.04 + i * .2);
      canvas.drawLine(
        Offset(x, -20),
        Offset(x + w * .12, h + 20),
        roadPaint..strokeWidth = i == 2 ? 14 : 8,
      );
    }
    final random = math.Random(8);
    for (int i = 0; i < 34; i++) {
      final x = random.nextDouble() * w, y = random.nextDouble() * h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            y,
            9 + random.nextDouble() * 12,
            6 + random.nextDouble() * 7,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = AppColors.border.withValues(alpha: .65),
      );
    }
    if (!showRoute) return;
    final points = [
      Offset(w * .19, h * .73),
      Offset(w * .31, h * .68),
      Offset(w * .34, h * .45),
      Offset(w * .64, h * .39),
      Offset(w * .69, h * .22),
      Offset(w * .81, h * .19),
    ];
    final route = Path()..addPolygon(points, false);
    canvas.drawPath(
      route,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 10,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 5,
    );
    for (final p in [points.first, points[2], points.last]) {
      canvas.drawCircle(p, 7, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, Paint()..color = AppColors.primary);
    }
    final current =
        points[(activeStep.clamp(0, 6) * (points.length - 1) / 6).round()];
    canvas.drawCircle(
      current,
      15,
      Paint()..color = AppColors.primary.withValues(alpha: .15),
    );
    canvas.drawCircle(current, 7, Paint()..color = AppColors.primary);
    canvas.drawCircle(current, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) =>
      showRoute != oldDelegate.showRoute ||
      activeStep != oldDelegate.activeStep;
}
