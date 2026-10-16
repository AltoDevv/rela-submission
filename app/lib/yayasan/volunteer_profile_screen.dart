import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../relawan/join_screen.dart' show volunteerDays;
import '../shared/models.dart';
import '../shared/schedule.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'data.dart';
import 'ui.dart';
import 'verify_volunteers_screen.dart';

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Menonaktifkan relawan lewat Edge Function `pairing`: lansia pasangannya diteruskan ke yayasan.
Future<void> deactivateVolunteer(String volunteerId, String reason) => Supabase.instance.client.functions
    .invoke('pairing', body: {'action': 'deactivate', 'volunteer_id': volunteerId, 'reason': reason});

/// Profil relawan untuk pengurus: lansia, keahlian, jadwal, kehadiran, masukan keluarga. Relawan yang belum
/// terverifikasi diverifikasi tatap muka di sini; pengajuan pengunduran diri diterima di sini.
class VolunteerProfileScreen extends StatefulWidget {
  const VolunteerProfileScreen({super.key, required this.data, required this.volunteerId, this.deactivate});

  final YayasanData data;
  final String volunteerId;

  /// Diganti di test. Default: [deactivateVolunteer].
  final Future<void> Function(String volunteerId, String reason)? deactivate;

  @override
  State<VolunteerProfileScreen> createState() => _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  late final Volunteer v = widget.data.volunteers.firstWhere((x) => x.id == widget.volunteerId);
  late final String name = widget.data.nameOf(v.id);
  late final Future<String?> _photo = _photoUrl();
  bool _idChecked = false, _oriented = false, _busy = false;

  Future<String?> _photoUrl() async {
    if (v.photoPath == null) return null;
    try {
      return await Supabase.instance.client.storage.from('volunteer-photos').createSignedUrl(v.photoPath!, 3600);
    } catch (_) {
      return null; // foto belum ada, atau di test
    }
  }

  Future<void> _check(bool identity) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ChecklistDialog(
        title: identity ? 'Cek identitas' : 'Orientasi',
        volunteerName: name,
        items: identity ? identityChecklist : orientationChecklist,
      ),
    );
    if (ok == true) setState(() => identity ? _idChecked = true : _oriented = true);
  }

  /// Tatap muka: kedua centang → kode sekali pakai → relawan memasukkannya di HP-nya → aktif.
  Future<void> _verify() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final db = Supabase.instance.client;
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VerificationCodeDialog(
        volunteerName: name,
        issue: () async {
          final rows = (await db.rpc('issue_verification_code', params: {'p_volunteer_id': v.id})) as List;
          final r = rows.first as Map;
          return (code: r['code'] as String, expiresAt: DateTime.parse(r['expires_at'] as String));
        },
        isActive: () async => (await db.from('volunteers').select('status').eq('id', v.id).single())['status'] == 'aktif',
      ),
    );
    if (done == true) {
      messenger.showSnackBar(SnackBar(content: Text('$name sekarang relawan aktif.')));
      nav.pop();
    }
  }

  Future<void> _runDeactivate(String reason, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await (widget.deactivate ?? deactivateVolunteer)(v.id, reason);
      messenger.showSnackBar(SnackBar(content: Text(done)));
      nav.pop();
    } on FunctionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${(e.details as Map?)?['error'] ?? 'Gagal, coba lagi'}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Figma "PopUp pengunduran diri": alasan relawan + Terima (keputusan pengguna 16 Okt: tanpa Tolak, relawan tidak
  /// bisa dipaksa tetap). Terima = nonaktifkan: lansia pasangannya dicocokkan ulang otomatis.
  Future<void> _resignPopup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alasan Pengunduran Diri', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: RelaColors.paper, borderRadius: BorderRadius.circular(16)),
            child: Text(v.resignReason ?? '-'),
          ),
          const SizedBox(height: 12),
          const Text('Menerima berarti relawan dinonaktifkan dan lansia pasangannya langsung mendapat usulan relawan '
              'pengganti.',
              style: TextStyle(color: RelaColors.muted)),
        ]),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Tutup')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RelaColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terima'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _runDeactivate('Pengunduran diri diterima: ${v.resignReason ?? ''}'.trim(),
          'Pengunduran diri diterima; lansianya langsung dicarikan pengganti.');
    }
  }

  Future<void> _deactivatePrompt() async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nonaktifkan $name?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Sistem langsung mencarikan relawan pengganti untuk semua lansia pasangannya, keluarganya diberi '
              'tahu. Relawan bisa aktif lagi setelah verifikasi tatap muka ulang.'),
          TextField(
            key: const Key('alasan-nonaktif'),
            controller: c,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'Alasan (dibaca relawan)'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RelaColors.danger),
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
    if (reason != null && reason.length >= 3) {
      await _runDeactivate(reason, 'Relawan dinonaktifkan; lansianya langsung dicarikan pengganti.');
    }
  }

  /// Permintaan berhenti mendampingi satu lansia: yayasan menerima, lalu sistem mencarikan pengganti otomatis.
  Future<void> _approveStop(Elder e, Map req) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final ok = await confirmAction(context,
        title: 'Terima permintaan berhenti?',
        body: 'Alasan relawan: ${req['reason']}\n\nSistem langsung mengusulkan relawan pengganti untuk ${e.fullName} '
            'ke keluarga (bisa dari yayasan lain). Bila tidak ditanggapi, permintaan diterima otomatis setelah 7 hari.',
        okLabel: 'Terima & cari pengganti');
    if (!ok) return;
    try {
      await Supabase.instance.client.functions
          .invoke('pairing', body: {'action': 'approve_stop', 'request_id': req['id']});
      messenger.showSnackBar(const SnackBar(content: Text('Diterima. Usulan relawan pengganti dikirim ke keluarga.')));
      nav.pop();
    } on FunctionException catch (err) {
      messenger.showSnackBar(SnackBar(content: Text('${(err.details as Map?)?['error'] ?? 'Gagal, coba lagi'}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final state = volunteerState(v, d.loadOf(v.id));
    final active = v.status == 'aktif';
    final elders = d.eldersOf(v.id);
    final reviews = d.reviewsOf(v.id);
    final attendance = visitedPercent(elders, d.lastVisit, DateTime.now());
    const muted = TextStyle(color: RelaColors.muted);
    final skills = [
      if (v.orientedAt != null) 'Orientasi selesai',
      if (v.canDementia) 'Pendamping demensia',
      if (v.canMobility) 'Mobilitas sulit',
    ];
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
        Center(
          child: FutureBuilder<String?>(
            future: _photo,
            builder: (context, snap) => CircleAvatar(
              radius: 52,
              backgroundColor: RelaColors.sand,
              backgroundImage: snap.data == null ? null : NetworkImage(snap.data!),
              child: snap.data == null
                  ? Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: RelaColors.ink))
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Center(
          child: active
              ? const Pill(label: 'Terverifikasi', fg: RelaColors.okText, bg: RelaColors.okBg)
              : volunteerPill(state),
        ),
        const SizedBox(height: 8),
        Text(
          [if (v.areaLabel != null) v.areaLabel!, if (v.languages.isNotEmpty) 'Bahasa ${v.languages.map(_cap).join(', ')}']
              .join(' · '),
          textAlign: TextAlign.center,
          style: muted,
        ),
        if (v.statusNote != null && v.resignRequestedAt == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(v.statusNote!, textAlign: TextAlign.center, style: TextStyle(color: Colors.orange.shade900)),
          ),
        const SizedBox(height: 16),
        if (v.resignRequestedAt != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF6DADA),
                foregroundColor: RelaColors.danger,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _busy ? null : _resignPopup,
              child: Text('$name mengajukan pengunduran diri'),
            ),
          ),
        if (active) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(children: [
                _Stat('${d.loadOf(v.id)}/${v.maxLoad}', 'Lansia aktif'),
                _Stat('${reviews.where((r) => r['kind'] == 'apresiasi').length}', 'Apresiasi'),
                _Stat('${reviews.where((r) => r['kind'] != 'apresiasi').length}', 'Kritik & Saran'),
              ]),
            ),
          ),
          SectionCard(
            title: 'LANSIA',
            child: Column(children: [
              if (elders.isEmpty) const Align(alignment: Alignment.centerLeft, child: Text('Belum ada lansia pasangan.')),
              for (final e in elders) _elderCard(e, d.stopRequest(e.id)),
            ]),
          ),
        ],
        SectionCard(
          title: 'PELATIHAN & KEAHLIAN',
          child: skills.isEmpty
              ? const Text('Belum ada.', style: muted)
              : Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in skills) Pill(label: s, fg: RelaColors.primary, bg: const Color(0xFFDDEBF4)),
                ]),
        ),
        SectionCard(
          title: 'JADWAL TERSEDIA',
          child: DayCircles(on: {for (var i = 0; i < 7; i++) if (v.availableDays.contains(volunteerDays[i])) i}),
        ),
        if (active) ...[
          SectionCard(
            title: 'KEHADIRAN',
            trailing: Text(attendance == null ? '–' : '$attendance%', style: muted),
            child: LinearProgressIndicator(
              value: (attendance ?? 0) / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: RelaColors.cream,
            ),
          ),
          SectionCard(
            title: 'MASUKAN KELUARGA',
            color: RelaColors.paper,
            child: Column(children: [
              if (reviews.isEmpty) const Align(alignment: Alignment.centerLeft, child: Text('Belum ada masukan.')),
              for (final r in reviews) ReviewCard(review: r, data: d, showVolunteer: false),
            ]),
          ),
          if (v.resignRequestedAt == null)
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: RelaColors.danger),
              onPressed: _busy ? null : _deactivatePrompt,
              child: const Text('Nonaktifkan relawan'),
            ),
        ] else ...[
          const Center(
            child: Text('VERIFIKASI', style: TextStyle(color: RelaColors.muted, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                CheckboxListTile(
                  key: const Key('cek-identitas'),
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _idChecked,
                  title: const Text('Identitas sudah dicek', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${identityChecklist.length} butir, ketuk untuk memeriksa'),
                  onChanged: (_) => _check(true),
                ),
                CheckboxListTile(
                  key: const Key('cek-orientasi'),
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _oriented,
                  title: const Text('Telah melewati orientasi', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${orientationChecklist.length} butir, ketuk untuk memeriksa'),
                  onChanged: (_) => _check(false),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: bigFilled,
                  onPressed: _idChecked && _oriented ? _verify : null,
                  child: const Text('Verifikasi'),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _elderCard(Elder e, Map? stop) {
    final pills = [
      if (e.hasMobilityIssue) 'Mobilitas Sulit',
      if (e.hasDementia) 'Demensia',
    ];
    const muted = TextStyle(color: RelaColors.muted);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RelaColors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RelaColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SquareInitial(name: e.fullName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Text(
                  hasSchedule(e)
                      ? 'Tiap ${scheduleLabel(e.scheduleWeekday!, e.scheduleTime!)}'
                      : e.scheduleStatus == 'diusulkan'
                          ? 'Jadwal menunggu persetujuan keluarga'
                          : 'Belum ada jadwal rutin',
                  style: muted),
              Text(lastVisitText(widget.data.lastVisit(e.id)), style: muted),
            ]),
          ),
          StatusBadge(status: e.status),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.location_on_outlined, size: 20),
          const SizedBox(width: 6),
          Expanded(child: Text(e.address, style: muted)),
        ]),
        if (pills.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final p in pills) Pill(label: p, fg: const Color(0xFF7A5A00), bg: const Color(0xFFF8E6B8)),
          ]),
        ],
        if (stop != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFF6DADA),
              foregroundColor: RelaColors.danger,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => _approveStop(e, stop),
            child: Text('Berhenti mendampingi: ${stop['reason']}', textAlign: TextAlign.center),
          ),
        ],
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value, label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: RelaColors.primary)),
        Text(label, style: const TextStyle(color: RelaColors.muted)),
      ]),
    );
  }
}
