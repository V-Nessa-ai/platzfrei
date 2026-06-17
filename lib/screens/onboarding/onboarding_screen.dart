import 'package:flutter/material.dart';
import 'package:platzfrei/main.dart';
import 'package:platzfrei/screens/auth/login_screen.dart';
import 'package:platzfrei/screens/admin/admin_screen.dart';
import 'package:platzfrei/screens/member/member_home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _showCreate = false;
  bool _showJoin = false;
  final _orgNameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String _sportType = 'horse_riding';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _orgNameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _createOrg() async {
    if (_orgNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Bitte gib einen Vereinsnamen ein.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('organizations').insert({
        'name': _orgNameCtrl.text.trim(),
        'sport_type': _sportType,
        'owner_id': userId,
      });
      final org = await supabase.from('organizations')
          .select('id').eq('owner_id', userId).single();
      await supabase.from('memberships').insert({
        'organization_id': org['id'],
        'profile_id': userId,
        'status': 'active',
        'joined_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminScreen()),
        );
      }
    } catch (e) {
      setState(() => _error = 'Fehler: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinOrg() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Bitte gib den Einladungscode ein.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final orgs = await supabase.from('organizations')
          .select('id').eq('invite_code', code);
      if (orgs.isEmpty) {
        setState(() { _error = 'Ungültiger Code.'; _loading = false; });
        return;
      }
      final orgId = orgs.first['id'];
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('memberships').insert({
        'organization_id': orgId,
        'profile_id': userId,
        'status': 'active',
        'joined_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MemberHomeScreen()),
        );
      }
    } catch (e) {
      setState(() => _error = 'Fehler: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.sports, size: 56, color: Colors.green),
                const SizedBox(height: 12),
                Text('Willkommen!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Gründe deinen Verein oder tritt einem bei.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),

                if (!_showCreate && !_showJoin) ...[
                  FilledButton.icon(
                    icon: const Icon(Icons.add_business),
                    label: const Text('Verein gründen'),
                    onPressed: () => setState(() => _showCreate = true),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.group_add),
                    label: const Text('Verein beitreten'),
                    onPressed: () => setState(() => _showJoin = true),
                  ),
                ],

                if (_showCreate) ...[
                  Text('Neuen Verein gründen',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _orgNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Vereinsname',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _sportType,
                    decoration: const InputDecoration(
                      labelText: 'Sportart',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'horse_riding', child: Text('Reiten')),
                      DropdownMenuItem(value: 'tennis', child: Text('Tennis')),
                      DropdownMenuItem(value: 'other', child: Text('Sonstiges')),
                    ],
                    onChanged: (v) => setState(() => _sportType = v!),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _createOrg,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Verein erstellen'),
                  ),
                  TextButton(
                    onPressed: () => setState(() { _showCreate = false; _error = null; }),
                    child: const Text('Zurück'),
                  ),
                ],

                if (_showJoin) ...[
                  Text('Verein beitreten',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Einladungscode',
                      border: OutlineInputBorder(),
                      hintText: 'z.B. A1B2C3D4',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _joinOrg,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Beitreten'),
                  ),
                  TextButton(
                    onPressed: () => setState(() { _showJoin = false; _error = null; }),
                    child: const Text('Zurück'),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],

                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    await supabase.auth.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                  child: const Text('Abmelden'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
