import 'package:flutter/material.dart';
import 'package:platzfrei/main.dart';
import 'package:platzfrei/screens/auth/login_screen.dart';
import 'package:platzfrei/screens/onboarding/onboarding_screen.dart';
import 'package:platzfrei/screens/admin/admin_screen.dart';
import 'package:platzfrei/screens/member/member_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _go(const LoginScreen());
      return;
    }

    // Admin? Prüfe ob user eine Organisation besitzt
    final orgs = await supabase
        .from('organizations')
        .select('id')
        .eq('owner_id', user.id);

    if (orgs.isNotEmpty) {
      _go(const AdminScreen());
      return;
    }

    // Mitglied? Prüfe ob aktive Membership
    final memberships = await supabase
        .from('memberships')
        .select('id')
        .eq('profile_id', user.id)
        .eq('status', 'active');

    if (memberships.isNotEmpty) {
      _go(const MemberHomeScreen());
      return;
    }

    // Kein Verein → Onboarding
    _go(const OnboardingScreen());
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
