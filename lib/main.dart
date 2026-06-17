import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase/supabase.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';

late final SupabaseClient supabase;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE', null);

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(const _ErrorApp('Supabase Keys fehlen.'));
    return;
  }

  try {
    supabase = SupabaseClient(
      supabaseUrl,
      supabaseAnonKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
  } catch (e) {
    runApp(_ErrorApp('Supabase Fehler: $e'));
    return;
  }

  runApp(const ProviderScope(child: PlatzfreiApp()));
}

class PlatzfreiApp extends StatelessWidget {
  const PlatzfreiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Platzfrei',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: supabase.auth.currentUser != null
          ? const SplashScreen()
          : const LoginScreen(),
    );
  }
}

class _ErrorApp extends StatelessWidget {
  const _ErrorApp(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(message,
              style: const TextStyle(color: Colors.red, fontSize: 16)),
        ),
      ),
    );
  }
}
