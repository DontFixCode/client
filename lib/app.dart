import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ui/pages/auth/reset_password_page.dart';

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
  const BusroApp({
    super.key,
    this.demoMode = false,
    this.authClient,
    this.state,
  });
  final bool demoMode;
  final SupabaseClient? authClient;
  final AppState? state;
  @override
  State<BusroApp> createState() => _BusroAppState();
}

class _BusroAppState extends State<BusroApp> {
  late final AppState _state;
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  bool _recoveryShown = false;
  bool _deletionShown = false;
  @override
  void initState() {
    super.initState();
    _state =
        widget.state ??
        AppState(demoMode: widget.demoMode, auth: widget.authClient);
    _state.addListener(_authChanged);
    unawaited(_state.initialize());
  }

  void _authChanged() {
    if (!_state.accountDeleted) _deletionShown = false;
    if (_state.accountDeleted && !_deletionShown) {
      _deletionShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_state.accountDeleted) return;
        _navigator.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.welcome,
          (_) => false,
        );
        _messenger.currentState?.showSnackBar(
          const SnackBar(
            content: Text('탈퇴 처리된 계정이에요. 이 계정으로는 서비스를 이용할 수 없어요.'),
          ),
        );
      });
    }
    if (_state.passwordRecovery && !_recoveryShown) {
      _recoveryShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _navigator.currentState?.push(
          MaterialPageRoute<void>(builder: (_) => const ResetPasswordPage()),
        );
        _recoveryShown = false;
      });
    }
  }

  @override
  void dispose() {
    _state.removeListener(_authChanged);
    if (widget.state == null) _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    state: _state,
    child: MaterialApp(
      navigatorKey: _navigator,
      scaffoldMessengerKey: _messenger,
      title: '버스로',
      debugShowCheckedModeBanner: false,
      initialRoute: _state.hasServerSession
          ? AppRoutes.main
          : AppRoutes.welcome,
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
