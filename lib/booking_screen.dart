import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'main.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  List<Map<String, dynamic>> _courts = [];
  String? _selectedCourtId;
  String? _selectedCourtName;

  List<Map<String, dynamic>> _bookings = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCourts();
  }

  Future<void> _loadCourts() async {
    try {
      final data = await supabase
          .from('courts')
          .select()
          .eq('is_active', true);
      setState(() {
        _courts = List<Map<String, dynamic>>.from(data);
        if (_courts.isNotEmpty) {
          _selectedCourtId = _courts.first['id'];
          _selectedCourtName = _courts.first['name'];
          _loadBookings();
        }
      });
    } catch (e) {
      _showError('Plätze konnten nicht geladen werden: $e');
    }
  }

  Future<void> _loadBookings() async {
    if (_selectedCourtId == null) return;
    setState(() => _loading = true);

    final start = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final end = start.add(const Duration(days: 1));

    try {
      final data = await supabase
          .from('bookings')
          .select('*, profiles(display_name)')
          .eq('court_id', _selectedCourtId!)
          .eq('status', 'confirmed')
          .gte('start_time', start.toIso8601String())
          .lt('start_time', end.toIso8601String());
      setState(() => _bookings = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      _showError('Buchungen konnten nicht geladen werden: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _book(DateTime start, DateTime end) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await supabase.from('bookings').insert({
        'court_id': _selectedCourtId,
        'profile_id': userId,
        'start_time': start.toIso8601String(),
        'end_time': end.toIso8601String(),
        'status': 'confirmed',
      });
      await _loadBookings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gebucht: ${DateFormat('HH:mm').format(start)} – ${DateFormat('HH:mm').format(end)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Buchung fehlgeschlagen: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  List<_TimeSlot> _buildSlots() {
    final slots = <_TimeSlot>[];
    final slotMinutes = _courts.isEmpty ? 60 :
        (_courts.firstWhere((c) => c['id'] == _selectedCourtId,
            orElse: () => _courts.first)['slot_minutes'] ?? 60);

    var current = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, 8, 0);
    final dayEnd = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, 20, 0);

    while (current.isBefore(dayEnd)) {
      final slotEnd = current.add(Duration(minutes: slotMinutes));
      final isBooked = _bookings.any((b) {
        final bStart = DateTime.parse(b['start_time']);
        return bStart.hour == current.hour && bStart.minute == current.minute;
      });
      final booking = isBooked ? _bookings.firstWhere((b) {
        final bStart = DateTime.parse(b['start_time']);
        return bStart.hour == current.hour && bStart.minute == current.minute;
      }) : null;

      final isOwnBooking = booking != null &&
          booking['profile_id'] == supabase.auth.currentUser?.id;

      slots.add(_TimeSlot(
        start: current,
        end: slotEnd,
        isBooked: isBooked,
        isOwn: isOwnBooking,
        bookedBy: booking?['profiles']?['display_name'],
      ));
      current = slotEnd;
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final slots = _buildSlots();
    final isPast = _selectedDay.isBefore(
        DateTime.now().subtract(const Duration(days: 1)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Platz buchen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Platzselektor
          if (_courts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DropdownButtonFormField<String>(
                value: _selectedCourtId,
                decoration: const InputDecoration(
                  labelText: 'Platz',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _courts.map((c) => DropdownMenuItem(
                  value: c['id'] as String,
                  child: Text(c['name'] as String),
                )).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCourtId = val;
                    _selectedCourtName = _courts
                        .firstWhere((c) => c['id'] == val)['name'];
                  });
                  _loadBookings();
                },
              ),
            ),

          if (_courts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Keine aktiven Plätze gefunden.',
                  style: TextStyle(color: Colors.grey)),
            ),

          // Kalender
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 30)),
            lastDay: DateTime.now().add(const Duration(days: 90)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
            calendarFormat: CalendarFormat.week,
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
              _loadBookings();
            },
            locale: 'de_DE',
          ),

          const Divider(height: 1),

          // Zeitslots
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : slots.isEmpty
                    ? const Center(child: Text('Keine Zeitslots verfügbar.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: slots.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final slot = slots[i];
                          return _SlotTile(
                            slot: slot,
                            isPast: isPast || slot.start.isBefore(DateTime.now()),
                            onBook: () => _book(slot.start, slot.end),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _TimeSlot {
  final DateTime start;
  final DateTime end;
  final bool isBooked;
  final bool isOwn;
  final String? bookedBy;

  const _TimeSlot({
    required this.start,
    required this.end,
    required this.isBooked,
    required this.isOwn,
    this.bookedBy,
  });
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.isPast,
    required this.onBook,
  });

  final _TimeSlot slot;
  final bool isPast;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final timeLabel =
        '${DateFormat('HH:mm').format(slot.start)} – ${DateFormat('HH:mm').format(slot.end)}';

    Color bgColor;
    String label;
    bool canBook;

    if (slot.isOwn) {
      bgColor = Colors.green.shade100;
      label = 'Deine Buchung';
      canBook = false;
    } else if (slot.isBooked) {
      bgColor = Colors.red.shade50;
      label = slot.bookedBy != null ? 'Gebucht von ${slot.bookedBy}' : 'Gebucht';
      canBook = false;
    } else if (isPast) {
      bgColor = Colors.grey.shade100;
      label = 'Vergangen';
      canBook = false;
    } else {
      bgColor = Colors.white;
      label = 'Verfügbar';
      canBook = true;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListTile(
        title: Text(timeLabel,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(label),
        trailing: canBook
            ? FilledButton(
                onPressed: onBook,
                child: const Text('Buchen'),
              )
            : null,
      ),
    );
  }
}
