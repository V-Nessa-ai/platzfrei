import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:platzfrei/main.dart';
import 'package:platzfrei/models/models.dart';
import 'package:platzfrei/screens/auth/login_screen.dart';
import 'package:platzfrei/screens/admin/court_form_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Organization? _org;
  List<Court> _courts = [];
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = supabase.auth.currentUser!.id;
    final orgData = await supabase.from('organizations')
        .select().eq('owner_id', userId).single();
    final org = Organization.fromJson(orgData);

    final courtData = await supabase.from('courts')
        .select().eq('organization_id', org.id).order('name');
    final memberData = await supabase.from('memberships')
        .select('*, profiles(display_name)')
        .eq('organization_id', org.id);

    setState(() {
      _org = org;
      _courts = (courtData as List).map((c) => Court.fromJson(c)).toList();
      _members = List<Map<String, dynamic>>.from(memberData);
      _loading = false;
    });
  }

  Future<void> _deleteCourt(String courtId) async {
    await supabase.from('courts').delete().eq('id', courtId);
    _load();
  }

  Future<void> _removeMember(String membershipId) async {
    await supabase.from('memberships').delete().eq('id', membershipId);
    _load();
  }

  void _copyInviteLink() {
    if (_org == null) return;
    final link = 'https://v-nessa-ai.github.io/platzfrei/?invite=${_org!.inviteCode}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Einladungslink kopiert!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_org?.name ?? 'Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.sports_tennis), text: 'Plätze'),
            Tab(icon: Icon(Icons.people), text: 'Mitglieder'),
            Tab(icon: Icon(Icons.link), text: 'Einladung'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_courtsTab(), _membersTab(), _inviteTab()],
            ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (_, __) => _tabController.index == 0
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: const Text('Platz hinzufügen'),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CourtFormScreen(organizationId: _org!.id),
                    ),
                  );
                  _load();
                },
              )
            : const SizedBox(),
      ),
    );
  }

  Widget _courtsTab() {
    if (_courts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Noch keine Plätze.\nTippe auf "Platz hinzufügen".',
              textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _courts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = _courts[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.place, color: Colors.green),
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${c.openFrom} – ${c.openUntil} Uhr  •  ${c.isActive ? "Aktiv" : "Inaktiv"}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CourtFormScreen(
                          organizationId: _org!.id, court: c),
                      ),
                    );
                    _load();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(
                      'Platz "${c.name}" löschen?', () => _deleteCourt(c.id)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _membersTab() {
    final active = _members.where((m) => m['status'] == 'active').toList();
    if (active.isEmpty) {
      return const Center(child: Text('Noch keine Mitglieder.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: active.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final m = active[i];
        final name = m['profiles']?['display_name'] ?? 'Unbekannt';
        final isOwner = m['profile_id'] == _org?.ownerId;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isOwner ? Colors.green : Colors.grey.shade300,
              child: Text(name[0].toUpperCase(),
                  style: TextStyle(color: isOwner ? Colors.white : Colors.black87)),
            ),
            title: Text(name),
            subtitle: isOwner ? const Text('Admin') : null,
            trailing: isOwner
                ? null
                : IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(
                        '$name entfernen?', () => _removeMember(m['id'])),
                  ),
          ),
        );
      },
    );
  }

  Widget _inviteTab() {
    if (_org == null) return const SizedBox();
    final link = 'https://v-nessa-ai.github.io/platzfrei/?invite=${_org!.inviteCode}';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.share, size: 56, color: Colors.green),
          const SizedBox(height: 16),
          Text('Mitglieder einladen',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Teile diesen Link mit deinen Mitgliedern:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SelectableText(link, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Link kopieren'),
            onPressed: _copyInviteLink,
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Text('Oder Code direkt mitteilen:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(_org!.inviteCode,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  letterSpacing: 6, fontWeight: FontWeight.bold, color: Colors.green)),
        ],
      ),
    );
  }

  void _confirmDelete(String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bestätigen'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () { Navigator.pop(context); onConfirm(); },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}
