import 'package:flutter/material.dart';

import '../../models/travel_route.dart';
import '../theme/app_theme.dart';

class TransferProbabilityPill extends StatelessWidget {
  const TransferProbabilityPill(this.probability, {super.key});
  final int? probability;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (probability) {
      null => (AppColors.muted, AppColors.surface),
      < 40 => (AppColors.error, AppColors.errorLight),
      < 60 => (AppColors.amber, AppColors.amberLight),
      _ => (AppColors.success, AppColors.successLight),
    };
    return Semantics(
      label: '환승 성공 가능성 ${transferProbabilityLabel(probability)}',
      excludeSemantics: true,
      child: StatusPill(
        transferProbabilityLabel(probability),
        color: color,
        background: background,
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.color = AppColors.primaryDark,
    this.background = AppColors.primaryLight,
    this.icon,
  });
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
