import 'package:flutter/material.dart';

import '../relawan/join_screen.dart' show volunteerDays;
import '../shared/notifications.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'data.dart';

const dayLetters = ['S', 'S', 'R', 'K', 'J', 'S', 'M']; // Senin–Minggu

/// "Sen, Rab, Sab" dari available_days.
String shortDays(List<String> days) =>
    volunteerDays.where(days.contains).map((d) => '${d[0].toUpperCase()}${d.substring(1, 3)}').join(', ');

String relativeDay(DateTime t, DateTime now) {
  final d = DateTime(now.year, now.month, now.day).difference(DateTime(t.toLocal().year, t.toLocal().month, t.toLocal().day)).inDays;
  return d <= 0 ? 'Hari ini' : d == 1 ? 'Kemarin' : '$d hari lalu';
}

Pill volunteerPill(VolunteerState s) => switch (s) {
      VolunteerState.mundur => const Pill(label: 'Pengunduran', fg: RelaColors.danger, bg: Color(0xFFF6DADA)),
      VolunteerState.nonaktif => Pill(label: 'Nonaktif', fg: Colors.grey.shade800, bg: Colors.grey.shade200),
      VolunteerState.belum => const Pill(label: 'Belum verifikasi', fg: RelaColors.primary, bg: Color(0xFFDDEBF4)),
      VolunteerState.penuh => const Pill(label: 'Penuh', fg: Color(0xFF7A5A00), bg: Color(0xFFF8E6B8)),
      VolunteerState.tersedia => const Pill(label: 'Tersedia', fg: RelaColors.okText, bg: RelaColors.okBg),
    };

/// Jenis masukan di database → label Figma (keputusan pengguna 16 Okt: `perbaikan` = "Kritik & Saran").
const reviewLabels = {'apresiasi': 'Apresiasi', 'perbaikan': 'Kritik & Saran', 'serius': 'Masalah Serius'};

Pill reviewPill(String kind) => switch (kind) {
      'apresiasi' => const Pill(label: 'Apresiasi', fg: RelaColors.okText, bg: RelaColors.okBg),
      'serius' => const Pill(label: 'Masalah Serius', fg: RelaColors.danger, bg: Color(0xFFF6DADA)),
      _ => const Pill(label: 'Kritik & Saran', fg: Color(0xFF7A5A00), bg: Color(0xFFF8E6B8)),
    };

String initials(String name) {
  final w = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  return w.isEmpty ? '?' : w.take(2).map((s) => s[0].toUpperCase()).join();
}

/// Logo, nama yayasan, dan inisial yayasan (ketuk → tab Profil).
class YayasanHeader extends StatelessWidget {
  const YayasanHeader({super.key, required this.foundation, required this.onProfile});

  final String foundation;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      ClipOval(child: Image.asset('assets/rela-logo.png', width: 56, height: 56, fit: BoxFit.cover)),
      const SizedBox(width: 12),
      Expanded(child: Text(foundation, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
      const NotificationBell(),
      const SizedBox(width: 8),
      InkWell(
        customBorder: const CircleBorder(),
        onTap: onProfile,
        child: CircleAvatar(
          radius: 26,
          backgroundColor: RelaColors.sand,
          child: Text(initials(foundation), style: const TextStyle(color: RelaColors.ink, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }
}

/// Pilihan tab di dalam kotak biru (Semua · Aktif · ...).
class SegmentTabs extends StatelessWidget {
  const SegmentTabs({super.key, required this.labels, required this.selected, required this.onChanged});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: RelaColors.primary, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: i == selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: i == selected ? RelaColors.ink : Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Kartu bagian berjudul huruf kapital (LANSIA, JADWAL TERSEDIA, ...).
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.trailing, this.color});

  final String title;
  final Widget child;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: RelaColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(color: RelaColors.muted, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ),
          ?trailing,
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

/// Tujuh lingkaran hari. [values] = angka di dalam lingkaran (Beranda) atau null (jadwal: centang bila [on]).
class DayCircles extends StatelessWidget {
  const DayCircles({super.key, this.values, this.on = const {}, this.highlight, this.dark = false});

  final List<int>? values;
  final Set<int> on;
  final int? highlight; // hari ini
  final bool dark; // di atas latar biru

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      for (var i = 0; i < 7; i++)
        Column(children: [
          Text(dayLetters[i], style: TextStyle(color: dark ? Colors.white : RelaColors.muted)),
          const SizedBox(height: 6),
          CircleAvatar(
            radius: 20,
            backgroundColor: values != null
                ? (i == highlight ? RelaColors.cream : Colors.white)
                : (on.contains(i) ? RelaColors.primary : RelaColors.cream),
            child: values != null
                ? Text('${values![i]}', style: const TextStyle(color: RelaColors.ink, fontWeight: FontWeight.w700))
                : on.contains(i)
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
          ),
        ]),
    ]);
  }
}

/// Kotak inisial kecil (avatar di kartu daftar).
class SquareInitial extends StatelessWidget {
  const SquareInitial({super.key, required this.name, this.size = 48});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: RelaColors.sand, borderRadius: BorderRadius.circular(10)),
      child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: RelaColors.ink)),
    );
  }
}

/// Kartu masukan keluarga (Beranda, tab Ulasan, profil relawan).
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review, required this.data, this.onHandle, this.showVolunteer = true});

  final Map<String, dynamic> review;
  final YayasanData data;
  final VoidCallback? onHandle; // hanya untuk masalah serius yang belum ditangani
  final bool showVolunteer;

  @override
  Widget build(BuildContext context) {
    final r = review;
    final author = data.authors[r['id']] ?? 'Keluarga';
    final created = DateTime.parse(r['created_at'] as String);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SquareInitial(name: author),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(author, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text(
                  showVolunteer
                      ? 'Relawan ${data.nameOf(r['volunteer_id'] as String)} · ${data.elderName(r['elder_id'] as String)}'
                      : 'Keluarga ${data.elderName(r['elder_id'] as String)}',
                  style: const TextStyle(color: RelaColors.muted),
                ),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              reviewPill(r['kind'] as String),
              const SizedBox(height: 4),
              Text(relativeDay(created, DateTime.now()), style: const TextStyle(color: RelaColors.muted)),
            ]),
          ]),
          const SizedBox(height: 12),
          Text('"${r['body']}"'),
          if (r['handled_at'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Ditangani ${r['handled_by'] ?? ''}: ${r['handled_note'] ?? ''}',
                  style: const TextStyle(color: RelaColors.okText)),
            )
          else if (onHandle != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: RelaColors.danger,
                side: const BorderSide(color: RelaColors.danger),
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: onHandle,
              child: const Text('Tangani', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
  }
}
