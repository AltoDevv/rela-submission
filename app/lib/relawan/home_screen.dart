import 'package:flutter/material.dart';

import '../shared/models.dart';
import '../shared/notifications.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'appreciation_section.dart';
import 'elder_tab.dart';
import 'emergency_screen.dart';
import 'history_tab.dart';
import 'profile_tab.dart';
import 'schedule_board.dart';
import 'ui.dart';
import 'verification_card.dart';
import 'visit_entry.dart';

String _date(DateTime t) =>
    '${t.toLocal().day}/${t.toLocal().month}/${t.toLocal().year}';

String greeting(DateTime now) => switch (now.hour) {
  < 11 => 'Selamat Pagi!',
  < 15 => 'Selamat Siang!',
  < 18 => 'Selamat Sore!',
  _ => 'Selamat Malam!',
};

/// Beranda relawan yang sudah bergabung ke yayasan (yang belum diarahkan ke JoinScreen, main.dart).
/// Empat tab sesuai Figma: Beranda · Lansia · Riwayat · Profil.
class RelawanHomeScreen extends StatefulWidget {
  const RelawanHomeScreen({
    super.key,
    this.load,
    this.now,
    this.onStartVisit,
    this.scheduleSubmit,
  });

  /// Diganti di test. Default: [loadRelawanData].
  final Future<RelawanData> Function()? load;
  final Future<void> Function(Elder)?
  onStartVisit; // diganti di test; produksi tetap lewat startStory
  final DateTime?
  now; // waktu tetap untuk pengujian jadwal; produksi memakai waktu HP
  final Future<String> Function(Map<String, dynamic>, String)? scheduleSubmit;

  @override
  State<RelawanHomeScreen> createState() => _RelawanHomeScreenState();
}

class _RelawanHomeScreenState extends State<RelawanHomeScreen> {
  late Future<RelawanData> _data = (widget.load ?? loadRelawanData)();
  int _tab = 0;
  String? _elderId; // lansia yang dipilih di tab Lansia & Riwayat
  bool _recording = false;

  void _reload() => setState(() {
    _data = (widget.load ?? loadRelawanData)();
  });

  /// Membuka layar lalu memuat ulang data saat kembali.
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _reload();
  }

  Future<void> _run(Future<void> Function() action) async {
    await action();
    _reload();
  }

  Future<void> _record(RelawanData data, {Elder? current}) async {
    if (_recording) return;
    setState(() => _recording = true);
    var started = false;
    try {
      await startVisitEntry(
        context,
        elders: data.elders,
        current: current,
        onStart: (e) async {
          started = true;
          setState(() => _elderId = e.id);
          await (widget.onStartVisit ?? (elder) => startStory(context, elder))(
            e,
          );
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gagal membuka rekap. Periksa koneksi lalu coba lagi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _recording = false);
        if (started) _reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<RelawanData>(
          future: _data,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gagal memuat data relawan: ${snap.error}',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: _reload,
                      child: const Text('Coba lagi'),
                    ),
                    const LogoutButton(),
                  ],
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final d = snap.data!;
            final now = widget.now ?? DateTime.now();
            final homeElder = nextScheduledVisit(d, now)?.elder;
            final elder =
                d.elders.where((e) => e.id == _elderId).firstOrNull ??
                homeElder ??
                d.elders.firstOrNull;
            void pick(String id) => setState(() => _elderId = id);
            return switch (_tab) {
              1 => ElderTab(
                data: d,
                elder: elder,
                onPick: pick,
                onReload: _reload,
                now: now,
                scheduleSubmit: widget.scheduleSubmit,
              ),
              2 => HistoryTab(
                data: d,
                elder: elder,
                onPick: pick,
                onOpen: _open,
                onRecord: () => _record(d),
              ),
              3 => ProfileTab(data: d, onOpen: _open, onRun: _run),
              _ => _Beranda(
                data: d,
                now: now,
                elder: homeElder,
                onRecord: (e) => _record(d, current: e),
                onOpen: _open,
                onActivated: _reload,
                onShowElders: () => setState(() {
                  _elderId = homeElder?.id;
                  _tab = 1;
                }),
                onShowElder: (id) => setState(() {
                  _elderId = id;
                  _tab = 1;
                }),
                onHistory: () => setState(() {
                  _elderId = homeElder?.id;
                  _tab = 2;
                }),
              ),
            };
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Lansia',
          ),
          NavigationDestination(icon: Icon(Icons.schedule), label: 'Riwayat'),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _Beranda extends StatelessWidget {
  const _Beranda({
    required this.data,
    required this.now,
    required this.elder,
    required this.onOpen,
    required this.onActivated,
    required this.onShowElders,
    required this.onShowElder,
    required this.onHistory,
    required this.onRecord,
  });

  final RelawanData data;
  final DateTime now;
  final Future<void> Function(Widget) onOpen;
  final VoidCallback onActivated;
  final Elder? elder;
  final VoidCallback onShowElders;
  final ValueChanged<String> onShowElder;
  final VoidCallback onHistory;
  final Future<void> Function(Elder) onRecord;

  @override
  Widget build(BuildContext context) {
    final active = data.volunteer.status == 'aktif';
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 19, 24, 24),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: RelaColors.primary),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/rela-logo.png',
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting(now),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    data.name ?? 'Relawan',
                    style: const TextStyle(color: RelaColors.muted),
                  ),
                ],
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                color: RelaColors.cream,
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: 40, height: 40, child: NotificationBell()),
            ),
          ],
        ),
        const SizedBox(height: 27),
        ActiveChip(active: active, foundation: data.foundation, compact: true),
        const SizedBox(height: 14),
        if (!active) VerificationCard(onActivated: onActivated),
        if (active && data.elders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Belum ada lansia pasangan. Yayasan akan mengusulkan lansia di dekat Anda.',
            ),
          ),
        ScheduleBoard(
          data: data,
          onShowElders: onShowElders,
          onShowElder: onShowElder,
          now: now,
        ),
        if (elder != null) ...[
          const SizedBox(height: 16),
          _ElderBlock(
            data: data,
            elder: elder!,
            onOpen: onOpen,
            onHistory: onHistory,
            onRecord: onRecord,
          ),
          const SizedBox(height: 32),
        ],
        const AppreciationSection(),
      ],
    );
  }
}

/// Satu lansia di Beranda: kartu, Rekap Kunjungan, 3 kunjungan terakhir, Darurat.
class _ElderBlock extends StatelessWidget {
  const _ElderBlock({
    required this.data,
    required this.elder,
    required this.onOpen,
    required this.onHistory,
    required this.onRecord,
  });

  final RelawanData data;
  final Elder elder;
  final Future<void> Function(Widget) onOpen;
  final VoidCallback onHistory;
  final Future<void> Function(Elder) onRecord;

  @override
  Widget build(BuildContext context) {
    final e = elder;
    final warn = TextStyle(color: Colors.orange.shade900);
    final visits = data.visitsOf(e.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (e.verifyState != 'terverifikasi')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Dokumen keluarga belum diverifikasi yayasan. Jangan berkunjung dulu; Anda diberi tahu lewat notifikasi '
              'setelah lolos.',
              style: warn,
            ),
          )
        else if (!e.paid)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Langganan keluarga sudah berakhir. Kunjungan masih bisa dicatat sampai '
              '${e.paidUntil == null ? '-' : _date(e.paidUntil!.add(const Duration(days: 7)))}; keluarga sudah '
              'diingatkan untuk memperpanjang.',
              style: warn,
            ),
          ),
        if (data.pendingStops.contains(e.id))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Permintaan berhenti menunggu yayasan.', style: warn),
          ),
        FilledButton.icon(
          style: bigFilled.copyWith(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
          ),
          icon: const Icon(Icons.add_circle, color: RelaColors.cream),
          label: const Text('Rekap Kunjungan'),
          onPressed: e.verifyState == 'terverifikasi'
              ? () => onRecord(e)
              : null,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Riwayat kunjungan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: onHistory,
              child: const Text('Lihat semua ›'),
            ),
          ],
        ),
        if (visits.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Belum ada kunjungan.'),
          ),
        for (final v in visits.take(3))
          VisitHistoryTile(
            compact: true,
            visit: v,
            onTap: () => onOpen(
              VisitDetailScreen(elder: e, visit: v, latest: v == visits.first),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          style: bigDanger.copyWith(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
          ),
          onPressed: () =>
              onOpen(EmergencyScreen(elderId: e.id, elderName: e.fullName)),
          child: const Text('Darurat'),
        ),
      ],
    );
  }
}
