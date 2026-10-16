import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/models.dart';
import '../shared/rubric.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';

const _monthsLong = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November',
  'Desember',
];

/// Usia dalam tahun penuh pada [now].
int ageFrom(DateTime birth, {DateTime? now}) {
  final n = now ?? DateTime.now();
  return n.year - birth.year - ((n.month < birth.month || (n.month == birth.month && n.day < birth.day)) ? 1 : 0);
}

/// "4 Mei 1948"
String longDate(DateTime t) {
  final l = t.toLocal();
  return '${l.day} ${_monthsLong[l.month - 1]} ${l.year}';
}

/// "Ibu Sri, 78 tahun" (tanpa usia bila tanggal lahir belum diisi).
String elderTitle(Elder e) => e.birthDate == null ? e.fullName : '${e.fullName}, ${ageFrom(e.birthDate!)} tahun';

const statusLabels = {'stabil': 'Stabil', 'perlu_perhatian': 'Perlu Perhatian', 'segera_dikabari': 'Segera Dikabari'};

Pill statusPill(String status) => switch (status) {
      'perlu_perhatian' => const Pill(label: 'Perlu Perhatian', fg: Color(0xFF7A5A00), bg: Color(0xFFF8E6B8)),
      'segera_dikabari' => const Pill(label: 'Segera Dikabari', fg: RelaColors.danger, bg: Color(0xFFF6DADA)),
      _ => Pill(label: statusLabels[status] ?? status, fg: RelaColors.okText, bg: RelaColors.okBg),
    };

/// Ringkasan kunjungan untuk kartu Beranda, dari kategori yang disebut: "Nafsu makan: Baik · Obat: Teratur · …".
String visitSummary(Map<String, dynamic>? result, {int max = 3}) {
  if (result == null) return '';
  return [
    for (final d in rubricDomains)
      if ((result[d.key] as Map?)?['level'] case final int level) '${d.name}: ${d.labels[level]}',
  ].take(max).join(' · ');
}

/// Kehadiran relawan untuk lansia ini (keputusan pengguna 16 Okt): persen minggu sejak pasangan dimulai (maks. 12
/// minggu terakhir) yang punya minimal satu kunjungan terkonfirmasi relawan itu. null bila belum mulai.
int? attendanceForElder(List<Visit> visits, String? volunteerId, DateTime? pairedAt, {DateTime? now}) {
  if (volunteerId == null || pairedAt == null) return null;
  final n = now ?? DateTime.now();
  final weeks = (n.difference(pairedAt).inDays ~/ 7 + 1).clamp(1, 12);
  final start = n.subtract(Duration(days: weeks * 7));
  final hit = <int>{
    for (final v in visits)
      if (v.volunteerId == volunteerId && v.confirmedAt != null && v.visitedAt.isAfter(start))
        n.difference(v.visitedAt).inDays ~/ 7,
  };
  return (hit.length * 100 / weeks).round().clamp(0, 100);
}

/// Foto lansia (bucket privat elder-photos) atau inisial di lingkaran pasir.
class ElderAvatar extends StatefulWidget {
  const ElderAvatar({super.key, required this.name, this.photoPath, this.bucket = 'elder-photos', this.radius = 36});

  final String name;
  final String? photoPath;
  final String bucket;
  final double radius;

  @override
  State<ElderAvatar> createState() => _ElderAvatarState();
}

class _ElderAvatarState extends State<ElderAvatar> {
  late Future<String?> _url = _load();

  Future<String?> _load() async {
    if (widget.photoPath == null) return null;
    try {
      return await Supabase.instance.client.storage.from(widget.bucket).createSignedUrl(widget.photoPath!, 3600);
    } catch (_) {
      return null; // foto belum ada, atau di test
    }
  }

  @override
  void didUpdateWidget(ElderAvatar old) {
    super.didUpdateWidget(old);
    if (old.photoPath != widget.photoPath) _url = _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snap) => CircleAvatar(
        radius: widget.radius,
        backgroundColor: RelaColors.sand,
        backgroundImage: snap.data == null ? null : NetworkImage(snap.data!),
        child: snap.data == null
            ? Text(widget.name.isEmpty ? '?' : _initial(widget.name),
                style: TextStyle(fontSize: widget.radius * 0.8, fontWeight: FontWeight.w700, color: RelaColors.ink))
            : null,
      ),
    );
  }
}

/// Inisial nama tanpa sapaan: "Ibu Sri" → "S".
String _initial(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  const honorifics = {'ibu', 'bu', 'bapak', 'pak', 'mbah', 'eyang', 'nenek', 'kakek', 'oma', 'opa'};
  final w = words.length > 1 && honorifics.contains(words.first.toLowerCase()) ? words[1] : words.first;
  return w[0].toUpperCase();
}

/// Kotak berbingkai krem dengan judul di atasnya (Informasi lansia, Profil kesehatan, ...).
class TitledBox extends StatelessWidget {
  const TitledBox({super.key, required this.title, required this.child, this.action, this.color});

  final String title;
  final Widget child;
  final Widget? action;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
          ?action,
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color ?? Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: RelaColors.border, width: 1.5),
          ),
          child: child,
        ),
      ]),
    );
  }
}

/// Baris "Label: nilai" (nilai tebal, atau "Belum diisi" pudar).
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final empty = value == null || value!.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text.rich(TextSpan(
        style: const TextStyle(color: RelaColors.muted, fontSize: 15),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: empty ? 'Belum diisi' : value,
            style: empty ? null : const TextStyle(color: RelaColors.ink, fontWeight: FontWeight.w600),
          ),
        ],
      )),
    );
  }
}
