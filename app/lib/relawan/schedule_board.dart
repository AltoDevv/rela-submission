import 'package:flutter/material.dart';

import '../shared/models.dart';
import '../shared/schedule.dart';
import '../shared/theme.dart';
import 'ui.dart';

typedef TodaySlot = ({Elder elder, DateTime at});

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';

/// Jadwal disetujui pada tanggal ini; dihitung sejak awal hari agar slot yang sudah lewat tetap tampil.
List<TodaySlot> todaySchedule(List<Elder> elders, DateTime now) {
  final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(microseconds: 1));
  final slots = <TodaySlot>[];
  for (final e in elders.where(hasSchedule)) {
    final at = nextVisit(
      e.scheduleWeekday!,
      e.scheduleTime!,
      e.scheduleShiftAt,
      start,
    );
    if (_sameDay(at, now)) slots.add((elder: e, at: at));
  }
  return slots..sort((a, b) => a.at.compareTo(b.at));
}

bool visitedToday(RelawanData data, String elderId, DateTime now) => data
    .visitsOf(elderId)
    .any(
      (v) =>
          v.confirmedAt != null &&
          v.finalResult != null &&
          _sameDay(v.visitedAt.toLocal(), now),
    );

/// Dahulukan slot hari ini yang belum dicatat (termasuk yang terlambat), lalu jadwal terdekat berikutnya.
TodaySlot? nextScheduledVisit(RelawanData data, DateTime now) {
  final pending = todaySchedule(
    data.elders,
    now,
  ).where((s) => !visitedToday(data, s.elder.id, now));
  if (pending.isNotEmpty) return pending.first;
  final upcoming = [
    for (final e in data.elders.where(hasSchedule))
      (
        elder: e,
        at: nextVisit(
          e.scheduleWeekday!,
          e.scheduleTime!,
          e.scheduleShiftAt,
          visitedToday(data, e.id, now)
              ? DateTime(
                  now.year,
                  now.month,
                  now.day + 1,
                ).subtract(const Duration(microseconds: 1))
              : now,
        ),
      ),
  ]..sort((a, b) => a.at.compareTo(b.at));
  return upcoming.firstOrNull;
}

const _cardCream = Color(0xFFFCF5E5);
const _timelineSand = Color(0xFFEADBC0);

/// Timeline baca saja sesuai Home.png. Titik aktif mengikuti kunjungan berikutnya secara otomatis.
class ScheduleBoard extends StatelessWidget {
  const ScheduleBoard({
    super.key,
    required this.data,
    required this.onShowElders,
    required this.onShowElder,
    required this.now,
  });

  final RelawanData data;
  final VoidCallback onShowElders;
  final ValueChanged<String> onShowElder;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final slots = todaySchedule(data.elders, now);
    final done = slots.where((s) => visitedToday(data, s.elder.id, now)).length;
    final next = nextScheduledVisit(data, now);
    final nextToday = next != null && _sameDay(next.at, now);
    final ordinal = nextToday
        ? slots.indexWhere((s) => s.elder.id == next.elder.id) + 1
        : slots.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            const Text(
              'Jadwal hari ini',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              '${weekdayNames[now.weekday - 1]}, ${visitDate(now).replaceFirst(' ${now.year}', '')}',
              style: const TextStyle(
                color: RelaColors.muted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (slots.isEmpty)
          const Text(
            'Belum ada jadwal kunjungan hari ini.',
            style: TextStyle(color: RelaColors.muted),
          )
        else ...[
          Row(
            children: [
              for (var i = 0; i < slots.length; i++)
                Expanded(
                  child: Container(
                    height: 6,
                    margin: EdgeInsets.only(
                      right: i == slots.length - 1 ? 0 : 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          visitedToday(data, slots[i].elder.id, now) ||
                              (nextToday && next.elder.id == slots[i].elder.id)
                          ? RelaColors.primary
                          : _timelineSand,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: nextToday
                      ? 'Kunjungan $ordinal dari ${slots.length}'
                      : '$done dari ${slots.length} kunjungan selesai',
                  style: const TextStyle(
                    color: RelaColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (nextToday)
                  TextSpan(text: ' · berikutnya pukul ${_time(next.at)}'),
              ],
            ),
            style: const TextStyle(color: RelaColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < slots.length; i++)
            _TimelineRow(
              elderId: slots[i].elder.id,
              first: i == 0,
              last: i == slots.length - 1,
              active: nextToday && next.elder.id == slots[i].elder.id,
              done: visitedToday(data, slots[i].elder.id, now),
              child: nextToday && next.elder.id == slots[i].elder.id
                  ? _NextVisitCard(
                      elder: slots[i].elder,
                      now: now,
                      label: _time(slots[i].at),
                      note: _note(slots[i].at),
                    )
                  : _LaterVisitCard(
                      elder: slots[i].elder,
                      at: slots[i].at,
                      done: visitedToday(data, slots[i].elder.id, now),
                      onShow: () => onShowElder(slots[i].elder.id),
                    ),
            ),
        ],
        if (next != null && !nextToday) ...[
          const SizedBox(height: 16),
          const Text(
            'Kunjungan berikutnya',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _TimelineRow(
            elderId: 'next-${next.elder.id}',
            first: true,
            last: true,
            active: true,
            done: false,
            child: _NextVisitCard(
              elder: next.elder,
              now: now,
              label:
                  '${weekdayNames[next.at.weekday - 1].substring(0, 3)} ${visitDate(next.at)} · ${_time(next.at)}',
            ),
          ),
        ],
        if (next == null && data.elders.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Atur jadwal kunjungan melalui tab Lansia.',
            style: TextStyle(color: RelaColors.muted),
          ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: CustomPaint(
            foregroundPainter: const _DashedBorder(),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: _cardCream,
                foregroundColor: RelaColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: onShowElders,
              icon: const Icon(Icons.person_outline, size: 20),
              label: const Text('Lihat lansia lain ›'),
            ),
          ),
        ),
      ],
    );
  }

  String _note(DateTime at) {
    final minutes = at.difference(now).inMinutes;
    if (minutes < 0) return 'Belum dicatat';
    if (minutes == 0) return 'Sekarang';
    if (minutes < 60) return 'Dalam $minutes menit';
    return 'Dalam ${minutes ~/ 60} jam';
  }
}

/// Tiap segmen garis memenuhi tinggi kartu dan jarak ke baris berikutnya, tanpa tinggi tetap.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.elderId,
    required this.first,
    required this.last,
    required this.active,
    required this.done,
    required this.child,
  });
  final String elderId;
  final bool first, last, active, done;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final diameter = active ? 24.0 : 12.0;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (!first)
                  Positioned(
                    left: 7,
                    top: 0,
                    height: 24,
                    width: 2,
                    child: ColoredBox(
                      key: ValueKey('timeline-line-above-$elderId'),
                      color: _timelineSand,
                    ),
                  ),
                if (!last)
                  Positioned(
                    left: 7,
                    top: 24,
                    bottom: 0,
                    width: 2,
                    child: ColoredBox(
                      key: ValueKey('timeline-line-below-$elderId'),
                      color: _timelineSand,
                    ),
                  ),
                Positioned(
                  left: (16 - diameter) / 2,
                  top: 24 - diameter / 2,
                  width: diameter,
                  height: diameter,
                  child: Container(
                    key: ValueKey('timeline-dot-$elderId'),
                    padding: active ? const EdgeInsets.all(4) : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? const Color(0xFFD2E4EB)
                          : done
                          ? RelaColors.primary
                          : Colors.white,
                      border: active || done
                          ? null
                          : Border.all(color: RelaColors.sand, width: 2),
                    ),
                    child: active
                        ? const DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: RelaColors.primary,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextVisitCard extends StatelessWidget {
  const _NextVisitCard({
    required this.elder,
    required this.label,
    required this.now,
    this.note,
  });
  final Elder elder;
  final String label;
  final DateTime now;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final birth = elder.birthDate;
    final age = birth == null
        ? null
        : now.year -
              birth.year -
              (now.month < birth.month ||
                      (now.month == birth.month && now.day < birth.day)
                  ? 1
                  : 0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardCream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RelaColors.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              _label(label, RelaColors.ink, RelaColors.cream),
              if (note != null)
                _label(note!, const Color(0xFFF8E6B8), const Color(0xFF7A5A00)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScheduleAvatar(name: elder.fullName, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      elder.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      '${age == null ? '' : '$age tahun · '}${elder.address}',
                      style: const TextStyle(
                        color: RelaColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: fg,
        fontWeight: FontWeight.w700,
        fontSize: 13,
        height: 1.15,
      ),
    ),
  );
}

class _LaterVisitCard extends StatelessWidget {
  const _LaterVisitCard({
    required this.elder,
    required this.at,
    required this.done,
    required this.onShow,
  });
  final Elder elder;
  final DateTime at;
  final bool done;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _timelineSand),
    ),
    child: Row(
      children: [
        _ScheduleAvatar(name: elder.fullName, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                elder.fullName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              Text(
                '${_time(at)} · ${done ? 'Selesai' : 'Kunjungan rutin'}',
                style: const TextStyle(
                  color: RelaColors.muted,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 40),
            side: const BorderSide(color: RelaColors.primary),
            foregroundColor: RelaColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.15,
            ),
          ),
          onPressed: onShow,
          child: const Text('Tampilkan'),
        ),
      ],
    ),
  );
}

class _ScheduleAvatar extends StatelessWidget {
  const _ScheduleAvatar({required this.name, required this.size});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final short = name
        .replaceFirst(
          RegExp(r'^(Ibu|Bapak|Pak|Bu)\s+', caseSensitive: false),
          '',
        )
        .trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: RelaColors.sand,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        short.isEmpty ? '?' : short[0].toUpperCase(),
        style: TextStyle(
          fontSize: size / 2.8,
          fontWeight: FontWeight.w700,
          color: RelaColors.ink,
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.5),
          const Radius.circular(16),
        ),
      );
    final paint = Paint()
      ..color = RelaColors.sand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 8) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorder oldDelegate) => false;
}
