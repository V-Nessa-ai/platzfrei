import 'package:flutter/material.dart';
import 'package:platzfrei/main.dart';
import 'package:platzfrei/models/models.dart';

class CourtFormScreen extends StatefulWidget {
  final String organizationId;
  final Court? court;
  const CourtFormScreen({super.key, required this.organizationId, this.court});

  @override
  State<CourtFormScreen> createState() => _CourtFormScreenState();
}

class _CourtFormScreenState extends State<CourtFormScreen> {
  final _nameCtrl = TextEditingController();
  TimeOfDay _openFrom = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _openUntil = const TimeOfDay(hour: 22, minute: 0);
  bool _isActive = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.court != null) {
      final c = widget.court!;
      _nameCtrl.text = c.name;
      _isActive = c.isActive;
      _openFrom = _parseTime(c.openFrom);
      _openUntil = _parseTime(c.openUntil);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isFrom) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isFrom ? _openFrom : _openUntil,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) _openFrom = picked; else _openUntil = picked;
      });
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Bitte gib einen Namen ein.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final data = {
        'organization_id': widget.organizationId,
        'name': _nameCtrl.text.trim(),
        'is_active': _isActive,
        'open_from': _formatTime(_openFrom),
        'open_until': _formatTime(_openUntil),
        'slot_minutes': 15,
      };
      if (widget.court == null) {
        await supabase.from('courts').insert(data);
      } else {
        await supabase.from('courts').update(data).eq('id', widget.court!.id);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Fehler: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.court != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Platz bearbeiten' : 'Neuer Platz')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name (z.B. Dressurplatz, Halle)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.schedule),
                        label: Text('Öffnet: ${_formatTime(_openFrom)}'),
                        onPressed: () => _pickTime(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.schedule),
                        label: Text('Schließt: ${_formatTime(_openUntil)}'),
                        onPressed: () => _pickTime(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Platz aktiv'),
                  subtitle: const Text('Inaktive Plätze können nicht gebucht werden'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Speichern' : 'Platz erstellen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
