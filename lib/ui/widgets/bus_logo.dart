import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BusLogo extends StatelessWidget {
  const BusLogo({
    super.key,
    this.size = 36,
    this.showName = true,
    this.light = false,
  });
  final double size;
  final bool showName;
  final bool light;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: light ? AppColors.lime : AppColors.primary,
          borderRadius: BorderRadius.circular(size * .3),
        ),
        child: Icon(
          Icons.directions_bus_rounded,
          color: light ? AppColors.primaryDark : Colors.white,
          size: size * .65,
        ),
      ),
      if (showName) ...[
        const SizedBox(width: 9),
        Text(
          '버스로',
          style: TextStyle(
            fontSize: size * .66,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.3,
            color: light ? Colors.white : AppColors.primaryDark,
          ),
        ),
      ],
    ],
  );
}
