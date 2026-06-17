import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:platzfrei/main.dart';
import 'package:platzfrei/models/models.dart';
import 'package:platzfrei/screens/auth/login_screen.dart';
import 'package:platzfrei/screens/member/profile_screen.dart';

class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({super.key});
  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  List<Court> _courts = [];
  Court? _selectedCourt;
  List<Booking> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCourts();
  }

  Future<void> _loadCourts() async {
    final userId = supabase.auth.currentUser!.id;
    final membership = await supabase.from('memberships')
        .select('organization_id')
        .eq('profile_id', userId)
        .eq('status', 'active')
        .single();
    final orgId = membership['organization_id'];
    final data = await supabase.from('courts')
        .select().eq('organization_id', orgId).eq('is_active', true).order('name');
    final courts = (data as List).map((c) => Court.fromJson(c)).toList();
    setState(() {
      _courts = courts;
      _selectedCourt = courts.isNotEmpty ? courts.first : null;
      _loading = false;
    });
    if (_selectedCourt != null) _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (_selectedCourt == null) return;
    setState(() => _loading = true);
    final start = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final end = start.add(const Duration(days: 1));
    final data = await supabase.from('bookings')
        .select('*, profiles(display_name), profile_infos(label)')
        .eq('court_id', _selectedCourt!.id)
        .eq('status', 'confirmed')
        .gte('start_time', start.toUtc().toIso8601String())
        .lt('start_time', end.toUtc().toIso8601String());
    setState(() {
      _bookings = (data as List).map((b) => Booking.fromJson(b)).toList();
      _loading = false;
    });
  }

  Future<void> _cancelBooking(String bookingId) async {
    await supabase.from('bookings')
        .update({'status': 'cancelled'}).eq('id', bookingId);
    _loadBookings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buchung storniert.')),
      );
    }
  }

  List<TimeOfDay> _buildSlots() {
    if (_selectedCourt == null) return [];
    final from = _selectedCourt!.openFrom.split(':');
    final until = _selectedCourt!.openUntil.split(':');
    var current = TimeOfDay(hour: int.parse(from[0]), minute: int.parse(from[1]));
    final end = TimeOfDay(hour: int.parse(until[0]), minute: int.parse(until[1]));
    final slots = <TimeOfDay>[];
    while (current.hour < end.hour ||
        (current.hour == end.hour && current.minute < end.minute)) {
      slots.add(current);
      final totalMin = current.hour * 60 + current.minute + 15;
      current = TimeOfDay(hour: totalMin ~/ 60, minute: totalMin % 60);
    }
    return slots;
  }

  Booking? _bookingAt(TimeOfDay slot) {
    final slotDt = DateTime(
        _selectedDay.year, _selectedDay.month, _selectedDay.day,
        slot.hour, slot.minute);
    for (final b in _bookings) {
      if (!b.startTime.isAfter(slotDt) && b.endTime.isAfter(slotDt)) return b;
    }
    return null;
  }

  bool _isMyBookingStart(TimeOfDay slot) {
    final slotDt = DateTime(
        _selectedDay.year, _selectedDay.month, _selectedDay.day,
        slot.hour, slot.minute);
    return _bookings.any((b) =>
        b.profileId == supabase.auth.currentUser!.id &&
        b.startTime == slotDt);
  }

  void _showBookDialog(TimeOfDay startSlot) {
    final slots = _buildSlots();
    final startIndex = slots.indexWhere(
        (s) => s.hour == startSlot.hour && s.minute == startSlot.minute);
    if (startIndex < 0) return;
    final endSlots = slots.sublist(startIndex + 1);
    if (endSlots.isEmpty) return;

    TimeOfDay selectedEnd = endSlots.first;
    String? selectedInfoId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Buchen ab ${_fmtTime(startSlot)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<TimeOfDay>(
                value: selectedEnd,
                decoration: const InputDecoration(
                  labelText: 'Bis',
                  border: OutlineInputBorder(),
                ),
                items: endSlots.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(_fmtTime(s)),
                )).toList(),
                onChanged: (v) => setDialogState(() => selectedEnd = v!),
              ),
              const SizedBox(height: 12),
              _InfoDropdown(
                onChanged: (id) => setDialogState(() => selectedInfoId = id),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _book(startSlot, selectedEnd, selectedInfoId);
              },
              child: const Text('Buchen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _book(TimeOfDay start, TimeOfDay end, String? infoId) async {
    final userId = supabase.auth.currentUser!.id;
    final startDt = DateTime(
        _selectedDay.year, _selectedDay.month, _selectedDay.day,
        start.hour, start.minute).toUtc();
    final endDt = DateTime(
        _selectedDay.year, _selectedDay.month, _selectedDay.day,
        end.hour, end.minute).toUtc();
    try {
      await supabase.from('bookings').insert({
        'court_id': _selectedCourt!.id,
        'profile_id': userId,
        'start_time': startDt.toIso8601String(),
        'end_time': endDt.toIso8601String(),
        'status': 'confirmed',
        if (infoId != null) 'info_id': infoId,
      });
      _loadBookings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              'Gebucht: ${_fmtTime(start)} – ${_fmtTime(end)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final slots = _buildSlots();
    final now = DateTime.now();
    final isToday = isSameDay(_selectedDay, now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Platzfrei'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
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
      ),
      body: Column(
        children: [
          // Platzselektor
          if (_courts.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: DropdownButtonFormField<String>(
                value: _selectedCourt?.id,
                decoration: const InputDecoration(
                  labelText: 'Platz',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _courts.map((c) => DropdownMenuItem(
                  value: c.id, child: Text(c.name),
                )).toList(),
                onChanged: (id) {
                  setState(() => _selectedCourt = _courts.firstWhere((c) => c.id == id));
                  _loadBookings();
                },
              ),
            )
          else if (_courts.length == 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Text(_courts.first.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),

          // Kalender (4 Wochen)
          TableCalendar(
            firstDay: DateTime.now(),
            lastDay: DateTime.now().add(const Duration(days: 28)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
            calendarFormat: CalendarFormat.week,
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            onDaySelected: (selected, focused) {
              setState(() { _selectedDay = selected; _focusedDay = focused; });
              _loadBookings();
            },
            locale: 'de_DE',
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text(DateFormat('EEEE, d. MMMM', 'de_DE').format(_selectedDay),
                    style: Theme.of(context).textTheme.titleSmall),
                if (_selectedCourt != null) ...[
                  const Spacer(),
                  Text('${_selectedCourt!.openFrom} – ${_selectedCourt!.openUntil} Uhr',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ],
            ),
          ),

          const Divider(height: 1),

          // Zeitraster
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : slots.isEmpty
                    ? const Center(child: Text('Keine Zeitslots verfügbar.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: slots.length,
                        itemBuilder: (_, i) {
                          final slot = slots[i];
                          final booking = _bookingAt(slot);
                          final isStart = booking != null &&
                              isSameDay(booking.startTime, _selectedDay) &&
                              booking.startTime.hour == slot.hour &&
                              booking.startTime.minute == slot.minute;
                          final isMiddle = booking != null && !isStart;
                          final isMyBookingStart = isStart &&
                              booking.profileId == supabase.auth.currentUser!.id;

                          final slotDt = DateTime(_selectedDay.year,
                              _selectedDay.month, _selectedDay.day,
                              slot.hour, slot.minute);
                          final isPast = slotDt.isBefore(now);

                          if (isMiddle) return const SizedBox(height: 2);

                          return _SlotRow(
                            time: _fmtTime(slot),
                            booking: isStart ? booking : null,
                            isPast: isPast,
                            isMyBooking: isMyBookingStart,
                            onBook: isPast ? null : () => _showBookDialog(slot),
                            onCancel: isMyBookingStart
                                ? () => _cancelBooking(booking!.id)
                                : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.time,
    required this.booking,
    required this.isPast,
    required this.isMyBooking,
    required this.onBook,
    required this.onCancel,
  });

  final String time;
  final Booking? booking;
  final bool isPast;
  final bool isMyBooking;
  final VoidCallback? onBook;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    if (isMyBooking) bg = Colors.green.shade50;
    else if (booking != null) bg = Colors.red.shade50;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMyBooking
              ? Colors.green.shade200
              : booking != null
                  ? Colors.red.shade200
                  : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(time,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPast ? Colors.grey : Colors.black87,
                )),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: booking != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking!.displayName ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (booking!.infoLabel != null)
                        Text(booking!.infoLabel!,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  )
                : Text(isPast ? '' : 'Verfügbar',
                    style: TextStyle(color: Colors.grey[400])),
          ),
          if (isMyBooking)
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Stornieren'),
            )
          else if (booking == null && !isPast)
            FilledButton(
              onPressed: onBook,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero),
              child: const Text('Buchen'),
            ),
        ],
      ),
    );
  }
}

class _InfoDropdown extends StatefulWidget {
  final void Function(String?) onChanged;
  const _InfoDropdown({required this.onChanged});

  @override
  State<_InfoDropdown> createState() => _InfoDropdownState();
}

class _InfoDropdownState extends State<_InfoDropdown> {
  List<ProfileInfo> _infos = [];

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
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_infos.isEmpty) return const SizedBox();
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Info anzeigen (optional)',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Keine')),
        ..._infos.map((i) => DropdownMenuItem(value: i.id, child: Text(i.label))),
      ],
      onChanged: widget.onChanged,
    );
  }
}
