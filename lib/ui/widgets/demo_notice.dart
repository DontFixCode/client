import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key, this.message = '체험용 데이터 · 실제 운행정보와 다를 수 있어요'});
  final String message;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.muted),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    ],
  );
}
