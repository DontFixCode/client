import 'package:flutter/material.dart';

import '../../config/app_routes.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_navigation_bar.dart';
import 'history/history_page.dart';
import 'home/home_page.dart';
import 'profile/profile_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _index = 1;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [HistoryPage(), HomePage(), ProfilePage()],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.activeRoute != null)
            Material(
              color: AppColors.primaryDark,
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, AppRoutes.guide),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.navigation_rounded,
                        color: AppColors.lime,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${state.activeRoute!.destination.name}까지 안내 중',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Text(
                        '계속하기',
                        style: TextStyle(color: AppColors.lime, fontSize: 12),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.lime,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          AppNavigationBar(
            index: _index,
            onChanged: (index) => setState(() => _index = index),
          ),
        ],
      ),
    );
  }
}
