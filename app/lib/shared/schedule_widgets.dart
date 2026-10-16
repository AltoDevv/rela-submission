import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../relawan/join_screen.dart' show volunteerDays;
import 'models.dart';
import 'schedule.dart';
import 'theme.dart';

/// Aksi jadwal lewat Edge Function `pairing` (kolom jadwal tidak bisa ditulis klien). Mengembalikan pesan untuk snackbar.
Future<String> scheduleAction(Map<String, dynamic> body, String done) async {
  try {
    await Supabase.instance.client.functions.invoke('pairing', body: body);
    return done;
  } on FunctionException catch (e) {
    return '${(e.details as Map?)?['error'] ?? 'Gagal, coba lagi'}';
  }
}

String _hhmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Relawan memilih hari & jam rutin. Hari tersedia relawan ditandai. Mengembalikan (hari 1–7, "HH:MM") atau null.
Future<(int, String)?> pickSchedule(
  BuildContext context, {
  List<String> availableDays = const [],
  Elder? current,
}) {
  return showDialog<(int, String)>(
    context: context,
    builder: (_) =>
        _ScheduleDialog(availableDays: availableDays, current: current),
  );
}

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({required this.availableDays, this.current});

  final List<String> availableDays;
  final Elder? current;

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late int? _day = widget.current?.scheduleWeekday;
  late TimeOfDay _time = () {
    final t = widget.current?.scheduleTime?.split(':');
    return t == null
        ? const TimeOfDay(hour: 10, minute: 0)
        : TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
  }();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Jadwal kunjungan rutin'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keluarga akan diminta menyetujui. Pengingat dikirim sehari sebelumnya.',
          ),
          if (widget.current != null) ...[
            const SizedBox(height: 8),
            Text(
              'Untuk ${widget.current!.fullName}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 1; i <= 7; i++)
                ChoiceChip(
                  key: Key('hari-$i'),
                  label: Text(weekdayNames[i - 1]),
                  selected: _day == i,
                  avatar: widget.availableDays.contains(volunteerDays[i - 1])
                      ? const Icon(Icons.check_circle_outline, size: 18)
                      : null,
                  onSelected: (_) => setState(() => _day = i),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '✓ = hari tersedia Anda',
            style: TextStyle(fontSize: 12, color: RelaColors.muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('jam'),
            icon: const Icon(Icons.schedule),
            label: Text('Pukul ${_hhmm(_time).replaceAll(':', '.')}'),
            onPressed: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _time,
              );
              if (t != null) setState(() => _time = t);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _day == null
              ? null
              : () => Navigator.pop(context, (_day!, _hhmm(_time))),
          child: const Text('Kirim usulan'),
        ),
      ],
    );
  }
}

/// Relawan menggeser satu kunjungan (maks. 7 hari ke depan). Mengembalikan waktu baru atau null.
Future<DateTime?> pickShift(BuildContext context, {DateTime? now}) async {
  now ??= DateTime.now();
  final d = await showDatePicker(
    context: context,
    initialDate: now.add(const Duration(days: 1)),
    firstDate: now,
    lastDate: now.add(const Duration(days: 7)),
    helpText: 'Geser kunjungan minggu ini ke',
  );
  if (d == null || !context.mounted) return null;
  final t = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 10, minute: 0),
  );
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

/// Jadwal per lansia di tab Lansia: status + Atur/Ubah jadwal + Geser kunjungan.
class VolunteerScheduleRow extends StatelessWidget {
  const VolunteerScheduleRow({
    super.key,
    required this.elder,
    required this.availableDays,
    required this.onDone,
    this.now,
    this.submit,
  });

  final Elder elder;
  final List<String> availableDays;
  final VoidCallback onDone; // muat ulang setelah aksi
  final DateTime? now;
  final Future<String> Function(Map<String, dynamic>, String)? submit;

  Future<void> _propose(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await pickSchedule(
      context,
      availableDays: availableDays,
      current: elder,
    );
    if (picked == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          await (submit ?? scheduleAction)({
            'action': 'schedule_propose',
            'elder_id': elder.id,
            'weekday': picked.$1,
            'time': picked.$2,
          }, 'Usulan jadwal dikirim ke keluarga.'),
        ),
      ),
    );
    onDone();
  }

  Future<void> _shift(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final at = await pickShift(context, now: now);
    if (at == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          await (submit ?? scheduleAction)({
            'action': 'schedule_shift',
            'elder_id': elder.id,
            'at': at.toUtc().toIso8601String(),
          }, 'Kunjungan digeser; keluarga diberi tahu.'),
        ),
      ),
    );
    onDone();
  }

  @override
  Widget build(BuildContext context) {
    final e = elder;
    final label = e.scheduleWeekday == null
        ? null
        : scheduleLabel(e.scheduleWeekday!, e.scheduleTime!);
    final text = switch (e.scheduleStatus) {
      'disetujui' =>
        'Jadwal: tiap $label\nBerikutnya: ${nextVisitText(e, now: now)}',
      'diusulkan' => 'Usulan: tiap $label · menunggu persetujuan keluarga',
      _ => 'Belum ada jadwal kunjungan rutin.',
    };
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RelaColors.paper,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event, color: RelaColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ],
          ),
          if (e.scheduleShiftAt?.isAfter(now ?? DateTime.now()) == true &&
              hasSchedule(e))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Kunjungan berikutnya mengikuti jadwal yang digeser.',
                style: TextStyle(color: RelaColors.primary),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => _propose(context),
                child: Text(
                  e.scheduleStatus == null ? 'Atur jadwal' : 'Ubah jadwal',
                ),
              ),
              if (e.scheduleStatus == 'disetujui')
                TextButton(
                  onPressed: () => _shift(context),
                  child: const Text('Geser kunjungan'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kartu jadwal untuk keluarga (tab Relawan): setujui/tolak usulan, atau lihat kunjungan berikutnya.
class FamilyScheduleCard extends StatelessWidget {
  const FamilyScheduleCard({super.key, required this.elder, this.answer});

  final Elder elder;
  final Future<String> Function(bool approve)? answer; // diganti di test

  Future<void> _answer(BuildContext context, bool approve) async {
    final messenger = ScaffoldMessenger.of(context);
    final msg =
        await (answer ??
            (a) => scheduleAction(
              {'action': 'schedule_answer', 'elder_id': elder.id, 'approve': a},
              a
                  ? 'Jadwal disetujui.'
                  : 'Usulan ditolak; relawan diminta mengusulkan waktu lain.',
            ))(approve);
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final e = elder;
    final label = e.scheduleWeekday == null
        ? null
        : scheduleLabel(e.scheduleWeekday!, e.scheduleTime!);
    final shift = e.scheduleShiftAt?.toLocal();
    final children = <Widget>[
      const Text(
        'Jadwal Kunjungan',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
    ];
    switch (e.scheduleStatus) {
      case 'diusulkan':
        children.addAll([
          Text('Relawan mengusulkan kunjungan rutin tiap $label.'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _answer(context, false),
                  child: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _answer(context, true),
                  child: const Text('Setuju'),
                ),
              ),
            ],
          ),
        ]);
      case 'disetujui':
        children.addAll([
          Text(
            'Tiap $label',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text('Kunjungan berikutnya: ${nextVisitText(e)}'),
          if (shift != null && shift.isAfter(DateTime.now()))
            const Text(
              'Kunjungan minggu ini digeser relawan.',
              style: TextStyle(color: RelaColors.primary),
            ),
        ]);
      default:
        children.add(
          const Text(
            'Belum ada jadwal. Relawan akan mengusulkan jadwal kunjungan rutin untuk Anda setujui.',
          ),
        );
    }
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: e.scheduleStatus == 'diusulkan'
            ? RelaColors.cream
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: RelaColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
