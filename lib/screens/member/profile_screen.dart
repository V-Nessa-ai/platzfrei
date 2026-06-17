import 'package:flutter/material.dart';
import 'package:platzfrei/main.dart';
import 'package:platzfrei/models/models.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<ProfileInfo> _infos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase.from('profile_infos')
        .select().eq('profile_id', userId).order('label');
    setState(() {
      _infos = (data as List).map((i) => ProfileInfo.fromJson(i)).toList();
      _loading = false;
    });
  }

  Future<void> _addInfo() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Info hinzufügen'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Bezeichnung (z.B. Noki)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('profile_infos').insert({
        'profile_id': userId,
        'label': result,
      });
      _load();
    }
  }

  Future<void> _deleteInfo(String id) async {
    await supabase.from('profile_infos').delete().eq('id', id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Mein Profil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Text(
                        (user?.email ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(user?.email ?? ''),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Meine Infos',
                        style: Theme.of(context).textTheme.titleMedium),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Hinzufügen'),
                      onPressed: _addInfo,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Diese Infos kannst du bei einer Buchung auswählen und werden für alle sichtbar angezeigt.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (_infos.isEmpty)
                  const Text('Noch keine Infos. Füge z.B. deinen Pferdenamen hinzu.')
                else
                  ..._infos.map((info) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.label_outline, color: Colors.green),
                      title: Text(info.label),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteInfo(info.id),
                      ),
                    ),
                  )),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addInfo,
        child: const Icon(Icons.add),
      ),
    );
  }
}
