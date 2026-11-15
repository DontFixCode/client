import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/backend_config.dart';
import 'ui/widgets/kakao_place_map.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackendConfig.load();
  SupabaseClient? auth;
  if (!BackendConfig.demo && BackendConfig.authConfigured) {
    await Supabase.initialize(
      url: BackendConfig.supabaseUrl,
      publishableKey: BackendConfig.supabaseKey,
      debug: false,
    );
    auth = Supabase.instance.client;
  }
  await KakaoPlaceMap.initialize();
  runApp(BusroApp(demoMode: BackendConfig.demo, authClient: auth));
}
