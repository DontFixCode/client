import 'package:flutter/material.dart';

import 'config/app_routes.dart';
import 'models/travel_route.dart';
import 'state/app_state.dart';
import 'ui/pages/auth/forgot_password_page.dart';
import 'ui/pages/auth/login_page.dart';
import 'ui/pages/auth/signup_page.dart';
import 'ui/pages/journey/journey_guide_page.dart';
import 'ui/pages/main_page.dart';
import 'ui/pages/routes/route_detail_page.dart';
import 'ui/pages/routes/route_results_page.dart';
import 'ui/pages/splash_page.dart';
import 'ui/theme/app_theme.dart';

class BusroApp extends StatefulWidget {
  const BusroApp({super.key});
  @override
  State<BusroApp> createState() => _BusroAppState();
}

class _BusroAppState extends State<BusroApp> {
  final _state = AppState();
  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    state: _state,
    child: MaterialApp(
      title: '버스로',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => ColoredBox(
        color: AppColors.border,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ClipRect(child: child!),
          ),
        ),
      ),
      onGenerateRoute: (settings) {
        final Widget page = switch (settings.name) {
          AppRoutes.welcome => const SplashPage(),
          AppRoutes.main => const MainPage(),
          AppRoutes.login => const LoginPage(),
          AppRoutes.signup => const SignupPage(),
          AppRoutes.forgotPassword => const ForgotPasswordPage(),
          AppRoutes.results => const RouteResultsPage(),
          AppRoutes.routeDetail when settings.arguments is TravelRoute =>
            RouteDetailPage(route: settings.arguments! as TravelRoute),
          AppRoutes.guide => const JourneyGuidePage(),
          _ => const MainPage(),
        };
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => page,
        );
      },
    ),
  );
}
