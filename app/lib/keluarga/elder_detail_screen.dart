import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../relawan/join_screen.dart' show volunteerDays;
import '../relawan/ui.dart' show visitDate;
import '../shared/models.dart';
import '../shared/schedule_widgets.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'care_cards.dart';
import 'family_members_screen.dart';
import 'proposal_screen.dart';
import 'register_elder_screen.dart';
import 'review_dialog.dart';
import 'elder_list.dart' show openElder, proposeAndOpen;
import 'history_tab.dart' show FamilyVisitDetailScreen;
import 'ui.dart';
import '../yayasan/ui.dart' show DayCircles;

/// Sama dengan DISCLAIMER di supabase/functions/_shared/status.ts.
const statusDisclaimer =
    'Ini bukan diagnosis. Status ini hanya ringkasan dari cerita relawan untuk membantu keluarga dan yayasan.';

/// F7: halaman keluarga. Realtime lewat `stream()`, jadi status dan grafik berubah begitu relawan menyimpan.
class ElderDetailScreen extends StatefulWidget {
  const ElderDetailScreen({super.key, required this.elderId});

  final String elderId;

  @override
  State<ElderDetailScreen> createState() => _ElderDetailScreenState();
}

class _ElderDetailScreenState extends State<ElderDetailScreen> {
  final _db = Supabase.instance.client;
  // Dibuat sekali di initState supaya rebuild tidak membuka langganan Realtime baru.
  late final _elder = _db.from('elders').stream(primaryKey: ['id']).eq('id', widget.elderId);
  late final _visits =
      _db.from('visits').stream(primaryKey: ['id']).eq('elder_id', widget.elderId).order('visited_at', ascending: true);
  late var _health = _loadHealth();
  Future<Map<String, dynamic>?> _loadHealth() =>
      _db.from('health_profiles').select().eq('elder_id', widget.elderId).maybeSingle();
  // F8: riwayat darurat (dibaca saat layar dibuka, misalnya setelah mengetuk notifikasi darurat).
  late final _emergencies =
      _db.from('emergencies').select().eq('elder_id', widget.elderId).order('created_at', ascending: false);

  Future<void> _edit(Elder elder) async {
    final nav = Navigator.of(context);
    final h = await _health;
    final saved = await nav.push<bool>(MaterialPageRoute(
      builder: (_) => RegisterElderScreen(elder: elder, health: h == null ? null : HealthProfile.fromMap(h)),
    ));
    if (saved == true && mounted) setState(() { _health = _loadHealth(); });
  }

  Future<void> _end(String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showDialog<(String, String)>(context: context, builder: (_) => EndDialog(name: name));
    if (picked == null) return;
    try {
      await _db.functions.invoke('pairing',
          body: {'action': 'end', 'elder_id': widget.elderId, 'reason': picked.$1, 'note': picked.$2});
      messenger.showSnackBar(const SnackBar(content: Text('Pendampingan diakhiri. Riwayat tetap bisa dilihat.')));
      if (mounted) await _review(intro: 'Ulasan penutup untuk relawan (boleh dilewati).');
    } on FunctionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal: ${(e.details as Map?)?['error'] ?? 'coba lagi'}')));
    }
  }

  /// Hak penghapusan (UU PDP): semua data lansia ini hilang permanen; relawan, anggota keluarga, dan yayasan diberi tahu.
  Future<void> _delete(String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteAccountDialog(
        title: 'Hapus semua data $name?',
        body: 'Tindakan ini tidak bisa dibatalkan. Profil kesehatan, riwayat kunjungan, riwayat darurat, dan anggota '
            'keluarga yang ikut memantau akan terhapus. Pendampingan berakhir dan relawan serta yayasan diberi tahu.\n'
            'Bila hanya ingin berhenti didampingi, pilih "Akhiri pendampingan" saja.',
        okLabel: 'Hapus data',
      ),
    );
    if (ok != true) return;
    try {
      await _db.functions.invoke('pairing', body: {'action': 'delete', 'elder_id': widget.elderId, 'confirm': 'HAPUS'});
      messenger.showSnackBar(SnackBar(content: Text('Data $name sudah dihapus.')));
      nav.popUntil((r) => r.isFirst);
    } on FunctionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal: ${(e.details as Map?)?['error'] ?? 'coba lagi'}')));
    }
  }

  Future<void> _reopen() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _db.functions.invoke('pairing', body: {'action': 'reopen', 'elder_id': widget.elderId});
      messenger.showSnackBar(const SnackBar(content: Text('Pendampingan aktif kembali. Cari relawan dari beranda.')));
    } on FunctionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal: ${(e.details as Map?)?['error'] ?? 'coba lagi'}')));
    }
  }

  Future<void> _acknowledge() async {
    final messenger = ScaffoldMessenger.of(context);
    final note = await showDialog<String>(context: context, builder: (_) => const AckDialog());
    if (note == null) return;
    try {
      await _db.rpc('acknowledge_status', params: {'p_elder_id': widget.elderId, 'p_note': note});
      messenger.showSnackBar(const SnackBar(content: Text('Ditandai sudah ditangani.')));
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal: ${e.message}')));
    }
  }

  /// Ganti pendamping: wajib alasan, maks. 1× per lansia; pengganti dicarikan otomatis dan keluarga meninjau kartunya.
  /// Jatah habis → masalah serius tetap bisa dilaporkan ke yayasan.
  Future<void> _requestChange(String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final picked = await showDialog<(String, String)>(context: context, builder: (_) => ChangeDialog(name: name));
    if (picked == null) return;
    try {
      final res = await _db.functions.invoke('pairing',
          body: {'action': 'change', 'elder_id': widget.elderId, 'reason': picked.$1, 'note': picked.$2});
      final proposalId = (res.data as Map?)?['proposal_id'] as String?;
      if (proposalId != null) {
        nav.push(MaterialPageRoute(builder: (_) => ProposalScreen(proposalId: proposalId)));
      } else {
        messenger.showSnackBar(const SnackBar(
            content: Text('Pendamping dilepas. Belum ada relawan lain yang cocok; yayasan akan membantu mencarikan.')));
      }
    } on FunctionException catch (e) {
      final details = e.details is Map ? e.details as Map : const {};
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Text('${details['error'] ?? 'Gagal, coba lagi'}'),
        action: e.status == 429
            ? SnackBarAction(
                label: 'Lapor masalah serius',
                onPressed: () => askReview(context, widget.elderId, initialKind: 'serius'),
              )
            : null,
      ));
    }
  }

  int _reviewsVersion = 0; // naik setiap masukan terkirim → ReviewsSection dimuat ulang

  Future<void> _review({String? intro}) async {
    if (await askReview(context, widget.elderId, intro: intro) && mounted) {
      setState(() => _reviewsVersion++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _elder,
      builder: (context, elderSnap) {
        final rows = elderSnap.data;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              bottom: const TabBar(tabs: [Tab(text: 'Lansia'), Tab(text: 'Relawan')]),
              actions: [
                if (rows?.isNotEmpty == true)
                  PopupMenuButton<String>(
                    onSelected: (v) => switch (v) {
                      'ubah' => _edit(Elder.fromMap(rows!.first)),
                      'anggota' => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => FamilyMembersScreen(
                              elderId: widget.elderId, elderName: rows!.first['full_name'] as String))),
                      'aktifkan' => _reopen(),
                      'hapus' => _delete(rows!.first['full_name'] as String),
                      _ => _end(rows!.first['full_name'] as String),
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'ubah', child: Text('Ubah data & profil kesehatan')),
                      const PopupMenuItem(value: 'anggota', child: Text('Anggota keluarga')),
                      // Keputusan besar hanya untuk pendaftar (anggota keluarga lain tidak bisa).
                      if (rows!.first['family_id'] == _db.auth.currentUser?.id && rows.first['pairing_state'] != 'selesai')
                        const PopupMenuItem(value: 'akhiri', child: Text('Akhiri pendampingan')),
                      if (rows.first['family_id'] == _db.auth.currentUser?.id && rows.first['pairing_state'] == 'selesai')
                        const PopupMenuItem(value: 'aktifkan', child: Text('Aktifkan kembali pendampingan')),
                      if (rows.first['family_id'] == _db.auth.currentUser?.id)
                        PopupMenuItem(
                          value: 'hapus',
                          child: Text('Hapus data lansia', style: TextStyle(color: Colors.red.shade700)),
                        ),
                    ],
                  ),
              ],
            ),
            body: switch (elderSnap) {
              AsyncSnapshot(hasError: true) => const Center(child: Text('Gagal memuat data lansia.')),
              AsyncSnapshot(data: null) => const Center(child: CircularProgressIndicator()),
              AsyncSnapshot(data: []) => const Center(child: Text('Lansia tidak ditemukan.')),
              _ => StreamBuilder(
                  stream: _visits,
                  builder: (context, visitSnap) => FutureBuilder(
                    future: _health,
                    builder: (context, healthSnap) => FutureBuilder(
                      future: _emergencies,
                      builder: (context, emSnap) {
                        final elder = Elder.fromMap(rows!.first);
                        final visits = (visitSnap.data ?? const []).map(Visit.fromMap).toList();
                        return TabBarView(children: [
                          ElderDetailView(
                            elder: elder,
                            visits: visits,
                            health: healthSnap.data == null ? null : HealthProfile.fromMap(healthSnap.data!),
                            emergencies: (emSnap.data ?? const []).map(Emergency.fromMap).toList(),
                            onAcknowledge: _acknowledge,
                            onEdit: () => _edit(elder),
                            footer: elder.familyId == _db.auth.currentUser?.id
                                ? SubscriptionCard(key: ValueKey(elder.paidUntil), elder: elder)
                                : null,
                          ),
                          VolunteerTab(
                            elder: elder,
                            visits: visits,
                            reviewsVersion: _reviewsVersion,
                            onChange: () => _requestChange(elder.fullName),
                            onReviewSent: () => setState(() => _reviewsVersion++),
                          ),
                        ]);
                      },
                    ),
                  ),
                ),
            },
          ),
        );
      },
    );
  }
}

/// Kontak relawan pendamping. Seperti Gojek setelah pesanan diterima: nama lengkap dan nomor HP baru terlihat setelah
/// dokumen keluarga diperiksa yayasan (RPC my_volunteer_contact menolak sebelum itu).
Future<Map<String, dynamic>?> loadVolunteerContact(String elderId) async {
  final rows = await Supabase.instance.client.rpc('my_volunteer_contact', params: {'p_elder_id': elderId}) as List;
  return rows.isEmpty ? null : (rows.first as Map).cast<String, dynamic>();
}

/// Bagian atas tab Relawan (Figma "Detail lansia — Dengan pendamping"): foto, nama, Informasi Relawan, jadwal.
class VolunteerContactCard extends StatelessWidget {
  const VolunteerContactCard({super.key, required this.elder, this.load, this.attendance});

  final Elder elder;
  final Future<Map<String, dynamic>?> Function()? load;
  final int? attendance; // persen; null = belum ada data

  @override
  Widget build(BuildContext context) {
    if (elder.pairingState != 'berpasangan') return const SizedBox.shrink();
    if (elder.verifyState != 'terverifikasi') {
      return TitledBox(
        title: 'Relawan pendamping sudah dipilih',
        color: elder.verifyState == 'ditolak' ? Colors.orange.shade50 : RelaColors.paper,
        child: Text(elder.verifyState == 'ditolak'
            ? 'Dokumen Anda ditolak yayasan: ${elder.verifyNote ?? '-'}. Unggah ulang dari Beranda.'
            : 'Nama lengkap dan nomor HP relawan muncul setelah yayasan memeriksa dokumen Anda.'),
      );
    }
    return FutureBuilder<Map<String, dynamic>?>(
      future: (load ?? () => loadVolunteerContact(elder.id))(),
      builder: (context, snap) {
        final c = snap.data;
        if (c == null) return const SizedBox.shrink();
        final phone = c['phone'] as String?;
        final birth = c['birth_date'] == null ? null : DateTime.parse(c['birth_date'] as String);
        final days = ((c['available_days'] as List?) ?? const []).cast<String>();
        final skills = [
          if (c['can_dementia'] == true) 'Berpengalaman mendampingi lansia dengan demensia',
          if (c['can_mobility'] == true) 'Mampu membantu lansia dengan mobilitas sulit',
        ];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            ElderAvatar(
                name: (c['nickname'] ?? c['full_name'] ?? '') as String,
                photoPath: c['photo_path'] as String?,
                bucket: 'volunteer-photos'),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Relawan: ${c['full_name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Pill(label: 'Terverifikasi', fg: RelaColors.okText, bg: RelaColors.okBg),
              ]),
            ),
          ]),
          TitledBox(
            title: 'Informasi Relawan',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InfoRow('Nama panggilan', c['nickname'] as String?),
              InfoRow('Usia', birth == null ? null : '${ageFrom(birth)} tahun'),
              Row(children: [
                Expanded(child: InfoRow('Nomor Telepon', phone)),
                if (phone != null)
                  IconButton(
                    tooltip: 'Telepon relawan',
                    icon: const Icon(Icons.call, color: RelaColors.primary),
                    onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                  ),
              ]),
              InfoRow('Kemampuan', skills.isEmpty ? 'Pendampingan umum' : skills.join('; ')),
              InfoRow('Yayasan', c['foundation_name'] as String?),
            ]),
          ),
          TitledBox(
            title: 'Jadwal Tersedia',
            child: DayCircles(on: {for (var i = 0; i < 7; i++) if (days.contains(volunteerDays[i])) i}),
          ),
          TitledBox(
            title: 'Kehadiran',
            child: Row(children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: (attendance ?? 0) / 100,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: RelaColors.cream,
                ),
              ),
              const SizedBox(width: 16),
              Text(attendance == null ? '–' : '$attendance%',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]);
      },
    );
  }
}

/// Tab Relawan: pendamping saat ini, masukan untuk relawan, dan Ubah Relawan; atau tombol cari bila belum ada.
class VolunteerTab extends StatelessWidget {
  const VolunteerTab({
    super.key,
    required this.elder,
    required this.visits,
    required this.onChange,
    required this.onReviewSent,
    this.reviewsVersion = 0,
  });

  final Elder elder;
  final List<Visit> visits;
  final VoidCallback onChange;
  final VoidCallback onReviewSent;
  final int reviewsVersion;

  @override
  Widget build(BuildContext context) {
    final e = elder;
    final owner = e.familyId == Supabase.instance.client.auth.currentUser?.id;
    final children = <Widget>[];
    switch (e.pairingState) {
      case 'berpasangan':
        children.addAll([
          VolunteerContactCard(
              elder: e, attendance: attendanceForElder(visits, e.volunteerId, e.pairedAt ?? e.firstVisitAt)),
          FamilyScheduleCard(elder: e),
          TitledBox(title: 'Ulasan Relawan', child: ReviewComposer(elderId: e.id, onSent: onReviewSent)),
          ReviewsSection(key: ValueKey(reviewsVersion), elder: e),
          const SizedBox(height: 16),
          FilledButton(style: bigDanger, onPressed: onChange, child: const Text('Ubah Relawan')),
        ]);
      case 'menunggu_keluarga':
        children.addAll([
          const TitledBox(title: 'Ada usulan relawan', color: RelaColors.paper, child: Text('Tinjau relawan yang diusulkan sistem.')),
          const SizedBox(height: 16),
          if (owner) FilledButton(style: bigFilled, onPressed: () => openElder(context, e), child: const Text('Lihat usulan relawan')),
        ]);
      case 'selesai':
        children.add(TitledBox(
          title: 'Pendampingan selesai',
          color: RelaColors.paper,
          child: Text(e.endedReason ?? 'Riwayat kunjungan tetap bisa dilihat.'),
        ));
        if (e.volunteerId != null || visits.isNotEmpty) children.add(ReviewsSection(key: ValueKey(reviewsVersion), elder: e));
      default:
        final waiting = e.pairingState == 'perlu_yayasan';
        children.addAll([
          TitledBox(
            title: 'Belum ada pendamping',
            color: RelaColors.paper,
            child: Text(waiting
                ? 'Sistem sedang mencarikan relawan pendamping untuk ${e.fullName}.'
                : '${e.fullName} belum memiliki relawan pendamping. Cari relawan untuk mendampingi ${e.fullName}.'),
          ),
          const SizedBox(height: 16),
          if (owner && !waiting)
            FilledButton(
              style: bigFilled,
              onPressed: () => e.needsSetup ? openElder(context, e) : proposeAndOpen(context, e.id),
              child: const Text('Cari relawan pendamping'),
            ),
        ]);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: children);
  }
}

/// Figma "Ulasan Relawan": tab Apresiasi · Kritik & Saran · Masalah Serius, kotak teks, Kirim (Edge Function `review`).
class ReviewComposer extends StatefulWidget {
  const ReviewComposer({super.key, required this.elderId, required this.onSent, this.send});

  final String elderId;
  final VoidCallback onSent;
  final Future<void> Function(String kind, String body)? send; // diganti di test

  @override
  State<ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends State<ReviewComposer> {
  static const _kinds = {'apresiasi': 'Apresiasi', 'perbaikan': 'Kritik & Saran', 'serius': 'Masalah Serius'};
  String _kind = 'apresiasi';
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await (widget.send ??
          (k, b) => Supabase.instance.client.functions
              .invoke('review', body: {'elder_id': widget.elderId, 'kind': k, 'body': b}))(_kind, _text.text.trim());
      messenger.showSnackBar(SnackBar(
        content: Text(_kind == 'serius'
            ? 'Laporan dikirim ke yayasan. Bila perlu, tekan "Ubah Relawan".'
            : 'Terima kasih, masukan terkirim.'),
      ));
      _text.clear();
      widget.onSent();
    } on FunctionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${(e.details as Map?)?['error'] ?? 'Gagal mengirim, coba lagi'}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (final k in _kinds.entries)
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _kind = k.key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _kind == k.key ? RelaColors.primary : RelaColors.border,
                      width: _kind == k.key ? 3 : 1,
                    ),
                  ),
                ),
                child: Text(
                  k.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _kind == k.key ? RelaColors.primary : RelaColors.muted,
                    fontWeight: _kind == k.key ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      TextField(
        key: const Key('isi-ulasan'),
        controller: _text,
        maxLength: 500,
        minLines: 3,
        maxLines: 5,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: switch (_kind) {
            'apresiasi' => 'Tulis ucapan terima kasih di sini...',
            'serius' => 'Ceritakan masalahnya. Langsung ke yayasan dan tidak dibaca relawan.',
            _ => 'Berikan kritik & saran di sini... (hanya dibaca yayasan)',
          },
        ),
      ),
      Center(
        child: FilledButton(
          onPressed: _busy || _text.text.trim().length < 3 ? null : _send,
          child: Text(_busy ? 'Mengirim…' : 'Kirim'),
        ),
      ),
    ]);
  }
}

/// Tab Lansia (Figma "Detail lansia"), tanpa Supabase supaya bisa dites dengan data biasa.
class ElderDetailView extends StatelessWidget {
  const ElderDetailView({
    super.key,
    required this.elder,
    required this.visits,
    required this.health,
    this.emergencies = const [],
    this.onAcknowledge,
    this.onEdit,
    this.footer,
  });

  final Elder elder;
  final List<Visit> visits; // urut lama → baru
  final HealthProfile? health;
  final List<Emergency> emergencies; // urut baru → lama
  final VoidCallback? onAcknowledge;
  final VoidCallback? onEdit;
  final Widget? footer; // kartu langganan (hanya pendaftar)

  @override
  Widget build(BuildContext context) {
    final confirmed = visits.where((v) => v.finalResult != null).toList();
    final reason = elder.statusReason?.trim() ?? '';
    final h = health;
    final (contactName, contactPhone, instructions) = splitContact(h?.emergencyInstructions);
    final meds = (h?.medications ?? const [])
        .map((m) => '${m['name']}${((m['times'] as List?) ?? const []).isEmpty ? '' : ' (${(m['times'] as List).join(', ')})'}')
        .join('; ');
    final last = confirmed.isEmpty ? null : confirmed.last;

    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
      Row(children: [
        ElderAvatar(name: elder.fullName, photoPath: elder.photoPath),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(elderTitle(elder), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            statusPill(elder.status),
          ]),
        ),
      ]),
      if (elder.pairingState == 'selesai')
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('Pendampingan selesai${elder.endedReason == null ? '' : ': ${elder.endedReason}'}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      // Alasan status dan tindak lanjut (tidak ada di Figma; keputusan pengguna 16 Okt: di tab Lansia).
      TitledBox(
        title: 'Kondisi terkini',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Status hanya dihitung ulang saat kunjungan: tanpa ini "Stabil" bisa basi berminggu-minggu.
          LastVisitBadge(last: last?.visitedAt),
          if (reason.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(reason)),
          if (!reason.contains('bukan diagnosis'))
            const Text(statusDisclaimer, style: TextStyle(fontStyle: FontStyle.italic)),
          if (elder.statusAckAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Sudah ditangani oleh ${elder.statusAckBy ?? '-'}'
                '${elder.statusAckNote?.isNotEmpty == true ? ': ${elder.statusAckNote}' : ''}',
                style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600),
              ),
            )
          else if (elder.status != 'stabil' && onAcknowledge != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.task_alt),
                label: const Text('Tandai sudah ditangani'),
                onPressed: onAcknowledge,
              ),
            ),
        ]),
      ),
      TitledBox(
        title: 'Informasi lansia',
        action: onEdit == null
            ? null
            : TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('Edit')),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InfoRow('Nama', elder.fullName),
          InfoRow('Usia', elder.birthDate == null ? null : '${ageFrom(elder.birthDate!)} tahun'),
          InfoRow('Tanggal lahir', elder.birthDate == null ? null : longDate(elder.birthDate!)),
          InfoRow('Alamat', elder.address),
          InfoRow('Kontak keluarga', contactName.isEmpty ? null : '$contactName · $contactPhone'),
        ]),
      ),
      TitledBox(
        title: 'Profil kesehatan',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InfoRow('Kebutuhan pendamping', elder.needs),
          InfoRow('Kondisi atau penyakit yang dimiliki', h?.conditions),
          InfoRow('Obat rutin dan jadwal minum', meds),
          InfoRow('Alergi dan pantangan makanan',
              [h?.allergies, h?.dietRestrictions].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ')),
          InfoRow('Kemampuan bergerak', h?.mobility),
          InfoRow('Alat bantu', h?.mobilityAids),
          InfoRow('Dokter atau rumah sakit langganan', h?.doctorHospital),
          InfoRow('Instruksi darurat', instructions),
          const SizedBox(height: 8),
          const DisclaimerLabel(),
        ]),
      ),
      if (last != null)
        TitledBox(
          title: 'Kunjungan Terakhir',
          color: RelaColors.cream,
          child: InkWell(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => FamilyVisitDetailScreen(elder: elder, visit: last))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(visitDate(last.visitedAt), style: const TextStyle(fontWeight: FontWeight.w700))),
                const Text('Lihat detail →', style: TextStyle(color: RelaColors.primary, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              Text(visitSummary(last.finalResult)),
            ]),
          ),
        ),
      if (emergencies.isNotEmpty) ...[
        const SizedBox(height: 20),
        const Text('Riwayat darurat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        for (final e in emergencies) _EmergencyTile(emergency: e),
      ],
      if (footer != null) ...[const SizedBox(height: 20), footer!],
    ]);
  }
}

class _EmergencyTile extends StatelessWidget {
  const _EmergencyTile({required this.emergency});

  final Emergency emergency;

  @override
  Widget build(BuildContext context) {
    final at = emergency.createdAt?.toLocal();
    final hasLoc = emergency.lat != null && emergency.lng != null;
    return Card(
      color: Colors.red.shade50,
      child: ListTile(
        leading: const Icon(Icons.emergency, color: Colors.red),
        title: Text(at == null
            ? 'Darurat'
            : 'Darurat ${_date(at)} pukul ${at.hour.toString().padLeft(2, '0')}.${at.minute.toString().padLeft(2, '0')}'),
        subtitle: Text(emergency.summary ?? ''),
        trailing: hasLoc
            ? IconButton(
                tooltip: 'Buka lokasi',
                icon: const Icon(Icons.map),
                onPressed: () => launchUrl(Uri.parse('https://maps.google.com/?q=${emergency.lat},${emergency.lng}'),
                    mode: LaunchMode.externalApplication),
              )
            : null,
      ),
    );
  }
}

String _date(DateTime d) {
  final l = d.toLocal();
  return '${l.day}/${l.month}';
}

const endReasons = {
  'meninggal': 'Lansia meninggal dunia',
  'pindah': 'Lansia pindah',
  'tidak_butuh': 'Tidak lagi membutuhkan pendamping',
  'lainnya': 'Lainnya',
};

/// Mengembalikan (alasan, catatan) atau null bila dibatalkan. "Lainnya" wajib disertai catatan.
class EndDialog extends StatefulWidget {
  const EndDialog({super.key, required this.name});

  final String name;

  @override
  State<EndDialog> createState() => _EndDialogState();
}

class _EndDialogState extends State<EndDialog> {
  String? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _valid => _reason != null && (_reason != 'lainnya' || _note.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Akhiri pendampingan ${widget.name}?'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Relawan berhenti berkunjung. Riwayat kunjungan tetap tersimpan dan bisa dilihat.'),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) => setState(() { _reason = v; }),
            child: Column(children: [
              for (final e in endReasons.entries)
                RadioListTile<String>(value: e.key, title: Text(e.value), contentPadding: EdgeInsets.zero),
            ]),
          ),
          TextField(
            controller: _note,
            maxLength: 200,
            decoration: InputDecoration(labelText: _reason == 'lainnya' ? 'Tulis alasannya (wajib)' : 'Catatan (opsional)'),
            onChanged: (_) => setState(() {}),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: _valid ? () => Navigator.pop(context, (_reason!, _note.text.trim())) : null,
          child: const Text('Akhiri'),
        ),
      ],
    );
  }
}

/// Catatan tindak lanjut (mis. "Sudah ditelepon, besok ke puskesmas"). Mengembalikan catatan atau null.
class AckDialog extends StatefulWidget {
  const AckDialog({super.key});

  @override
  State<AckDialog> createState() => _AckDialogState();
}

class _AckDialogState extends State<AckDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tandai sudah ditangani'),
      content: TextField(
        controller: _note,
        maxLength: 300,
        decoration: const InputDecoration(labelText: 'Apa yang sudah dilakukan?', hintText: 'Mis. sudah ditelepon, besok ke puskesmas'),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: _note.text.trim().isEmpty ? null : () => Navigator.pop(context, _note.text.trim()),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

/// Alasan minta ganti pendamping. Alasan tidak diperlihatkan ke relawan lama; yayasannya membaca untuk pembinaan.
const changeReasons = {
  'jadwal': 'Jadwal tidak cocok',
  'tidak_cocok': 'Kurang cocok dengan lansia',
  'perbaikan': 'Ada yang perlu diperbaiki',
  'serius': 'Masalah serius (keselamatan, kasar, minta uang)',
};

class ChangeDialog extends StatefulWidget {
  const ChangeDialog({super.key, required this.name});

  final String name;

  @override
  State<ChangeDialog> createState() => _ChangeDialogState();
}

class _ChangeDialogState extends State<ChangeDialog> {
  String? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _reason != null && (_reason != 'serius' || _note.text.trim().length >= 3);
    return AlertDialog(
      title: const Text('Alasan Perubahan', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(shrinkWrap: true, children: [
          Text('Relawan saat ini berhenti mendampingi ${widget.name} dan sistem langsung mencarikan relawan baru.'),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v),
            child: Column(children: [
              for (final e in changeReasons.entries)
                RadioListTile<String>(
                  key: Key('ganti-${e.key}'),
                  contentPadding: EdgeInsets.zero,
                  value: e.key,
                  title: Text(e.value),
                ),
            ]),
          ),
          TextField(
            key: const Key('catatan-ganti'),
            controller: _note,
            maxLength: 300,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _reason == 'serius' ? 'Ceritakan masalahnya (wajib)' : 'Catatan untuk yayasan (opsional)',
            ),
          ),
          const Text('Pastikan alasan sudah sesuai sebelum dikirim. Alasan dibaca yayasan, tidak diperlihatkan ke relawan.',
              style: TextStyle(fontSize: 12, color: RelaColors.muted)),
          const SizedBox(height: 8),
          const Text('KESEMPATAN MENGUBAH RELAWAN HANYA 1 KALI UNTUK LANSIA INI',
              style: TextStyle(color: RelaColors.danger, fontSize: 12)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: RelaColors.danger),
          onPressed: ok ? () => Navigator.pop(context, (_reason!, _note.text.trim())) : null,
          child: const Text('Kirim'),
        ),
      ],
    );
  }
}

