import 'package:flutter/material.dart';

import '../relawan/ui.dart' show visitDate;
import '../shared/models.dart';
import '../shared/schedule.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'dashboard_section.dart';
import 'data.dart';
import 'profile_tab.dart';
import 'reviews_screen.dart';
import 'ui.dart';
import 'volunteer_profile_screen.dart';
import 'volunteers_tab.dart';

const _weekdays = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// Beranda pengurus yayasan. Empat tab sesuai Figma: Beranda · Relawan · Ulasan · Profil.
class YayasanHomeScreen extends StatefulWidget {
  const YayasanHomeScreen({super.key, this.load});

  /// Diganti di test. Default: [loadYayasanData].
  final Future<YayasanData> Function()? load;

  @override
  State<YayasanHomeScreen> createState() => _YayasanHomeScreenState();
}

class _YayasanHomeScreenState extends State<YayasanHomeScreen> {
  late Future<YayasanData> _data = (widget.load ?? loadYayasanData)();
  int _tab = 0;
  int _volunteerFilter = 0; // tab Relawan: Semua · Aktif · Verifikasi · Undur Diri

  void _reload() => setState(() {
    _data = (widget.load ?? loadYayasanData)();
  });

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _reload();
  }

  void _go(int tab, {int? filter}) => setState(() {
    _tab = tab;
    if (filter != null) _volunteerFilter = filter;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<YayasanData>(
          future: _data,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Gagal memuat data yayasan: ${snap.error}', textAlign: TextAlign.center),
                    TextButton(onPressed: _reload, child: const Text('Coba lagi')),
                    const LogoutButton(),
                  ],
                ),
              );
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final d = snap.data!;
            final header = YayasanHeader(foundation: d.foundation, onProfile: () => _go(3));
            return switch (_tab) {
              1 => VolunteersTab(
                data: d,
                header: header,
                filter: _volunteerFilter,
                onFilter: (i) => setState(() => _volunteerFilter = i),
                onOpen: _open,
              ),
              2 => ReviewsTab(data: d, header: header, onChanged: _reload),
              3 => ProfileTab(foundation: d.foundation),
              _ => _Beranda(data: d, header: header, onOpen: _open, onGo: _go),
            };
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => _go(i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Relawan'),
          NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'Ulasan'),
          NavigationDestination(icon: Icon(Icons.account_circle_outlined), label: 'Profil'),
        ],
      ),
    );
  }
}

/// Daftar semua lansia (urut paling mendesak) dengan aksi yang sudah ada: pasang manual, lepas, verifikasi
/// dokumen keluarga, terima permintaan berhenti. Tidak ada di Figma; dibuka dari "Perlu Perhatian".
class ElderListScreen extends StatelessWidget {
  const ElderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar lansia')),
      body: ListView(children: const [DashboardSection()]),
    );
  }
}

class _Beranda extends StatelessWidget {
  const _Beranda({required this.data, required this.header, required this.onOpen, required this.onGo});

  final YayasanData data;
  final Widget header;
  final Future<void> Function(Widget) onOpen;
  final void Function(int tab, {int? filter}) onGo;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = weekStart(now);
    final end = start.add(const Duration(days: 6));
    final d = data;
    final missed = d.missedElders(now);
    final percent = visitedPercent(d.elders, d.lastVisit, now);
    final states = {for (final v in d.volunteers) v.id: volunteerState(v, d.loadOf(v.id))};
    final active = d.volunteers.where((v) => v.status == 'aktif').toList();
    final capacity = active.fold<int>(0, (s, v) => s + v.maxLoad);
    final used = active.fold<int>(0, (s, v) => s + d.loadOf(v.id));
    final usedPct = capacity == 0 ? 0 : (used * 100 / capacity).round();
    final newThisWeek = d.elders.where((e) => e.pairedAt != null && !e.pairedAt!.isBefore(start)).length;
    final dashElders = (d.dash['elders'] as List).cast<Map>();
    int countElders(bool Function(Map e) test) => dashElders.where(test).length;
    final attention = <(int, String, VoidCallback)>[
      (
        states.values.where((s) => s == VolunteerState.belum).length,
        'Relawan menunggu verifikasi',
        () => onGo(1, filter: 2),
      ),
      (
        states.values.where((s) => s == VolunteerState.mundur).length,
        'Relawan mengundurkan diri',
        () => onGo(1, filter: 3),
      ),
      (
        countElders((e) => e['pairing_state'] == 'perlu_yayasan' || e['pairing_state'] == 'tanpa_pendamping'),
        'Lansia perlu dipasangkan',
        () => onOpen(const ElderListScreen()),
      ),
      (
        countElders((e) => e['verify_state'] == 'menunggu'),
        'Dokumen keluarga menunggu',
        () => onOpen(const ElderListScreen()),
      ),
      (
        countElders((e) => e['status'] == 'segera_dikabari' && e['status_ack_at'] == null),
        'Lansia segera dikabari',
        () => onOpen(const ElderListScreen()),
      ),
      (
        countElders((e) => e['stop_request'] != null),
        'Permintaan berhenti mendampingi',
        () => onOpen(const ElderListScreen()),
      ),
    ].where((a) => a.$1 > 0).toList();
    const h2 = TextStyle(fontSize: 22, fontWeight: FontWeight.w700);
    const white = TextStyle(color: Colors.white);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        header,
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: Text('Ringkasan minggu ini', style: h2)),
            Text(
              '${start.day} – ${end.day} ${_months[end.month - 1]}',
              style: const TextStyle(color: RelaColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: RelaColors.primary, borderRadius: BorderRadius.circular(24)),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'KUNJUNGAN',
                          style: TextStyle(color: Colors.white70, letterSpacing: 1.2, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${d.weekVisits.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${d.elders.length - missed.length} lansia terkunjungi · ${missed.length} terlewat',
                          style: white,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 104,
                    height: 104,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: (percent ?? 0) / 100,
                            strokeWidth: 8,
                            color: RelaColors.cream,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              percent == null ? '–' : '$percent%',
                              style: const TextStyle(color: Colors.white, fontSize: 24),
                            ),
                            const Text('terlaksana', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DayCircles(values: visitsPerDay(d.weekVisits, now), highlight: now.weekday - 1, dark: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  color: RelaColors.cream,
                  title: 'RELAWAN',
                  value: '${active.length}',
                  subtitle: 'aktif dari ${d.volunteers.length} terdaftar',
                  footer: Row(
                    children: [
                      for (final v in active.take(3))
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: CircleAvatar(
                            radius: 13,
                            backgroundColor: RelaColors.sand,
                            child: Text(
                              initials(d.nameOf(v.id))[0],
                              style: const TextStyle(fontSize: 12, color: RelaColors.ink),
                            ),
                          ),
                        ),
                      if (active.length > 3)
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: Colors.white,
                          child: Text(
                            '+${active.length - 3}',
                            style: const TextStyle(fontSize: 11, color: RelaColors.ink),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  color: RelaColors.ink,
                  dark: true,
                  title: 'PENDAMPINGAN',
                  value: '${d.elders.length}',
                  subtitle: '▲ $newThisWeek baru minggu ini',
                  footer: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < 10; i++)
                            Expanded(
                              child: Container(
                                height: 6,
                                margin: const EdgeInsets.only(right: 3),
                                decoration: BoxDecoration(
                                  color: i < (usedPct / 10).round() ? RelaColors.cream : Colors.white24,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Kapasitas terpakai $usedPct%',
                        style: const TextStyle(color: RelaColors.cream, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Perlu Perhatian', style: h2),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              if (attention.isEmpty) const ListTile(title: Text('Tidak ada yang perlu ditangani.')),
              for (final a in attention)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: RelaColors.cream,
                    child: Text(
                      '${a.$1}',
                      style: const TextStyle(color: RelaColors.ink, fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(a.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: a.$3,
                ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: RelaColors.paper,
                  child: Icon(Icons.elderly, color: RelaColors.ink),
                ),
                title: const Text('Lihat semua lansia'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpen(const ElderListScreen()),
              ),
            ],
          ),
        ),
        if (missed.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('Kunjungan Terlewat', style: h2),
          const SizedBox(height: 12),
          for (final e in missed) _MissedCard(data: d, elder: e, onOpen: onOpen),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: Text('Ulasan terbaru', style: h2)),
            TextButton(onPressed: () => onGo(2), child: const Text('Lihat semua')),
          ],
        ),
        if (d.reviews.isEmpty) const Text('Belum ada masukan dari keluarga.'),
        for (final r in d.reviews.take(2)) ReviewCard(review: r, data: d),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.footer,
    this.dark = false,
  });

  final Color color;
  final String title, value, subtitle;
  final Widget footer;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : RelaColors.ink;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: dark ? RelaColors.cream : RelaColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            value,
            style: TextStyle(color: fg, fontSize: 44, fontWeight: FontWeight.w800),
          ),
          Text(subtitle, style: TextStyle(color: fg)),
          const Spacer(),
          const SizedBox(height: 8),
          footer,
        ],
      ),
    );
  }
}

class _MissedCard extends StatelessWidget {
  const _MissedCard({required this.data, required this.elder, required this.onOpen});

  final YayasanData data;
  final Elder elder;
  final Future<void> Function(Widget) onOpen;

  @override
  Widget build(BuildContext context) {
    final vid = elder.volunteerId!;
    final name = data.nameOf(vid);
    final last = data.lastVisit(elder.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                SquareInitial(name: name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      Text('Lansia · ${elder.fullName}', style: const TextStyle(color: RelaColors.muted)),
                if (hasSchedule(elder))
                  Text('Jadwal: tiap ${scheduleLabel(elder.scheduleWeekday!, elder.scheduleTime!)}',
                      style: const TextStyle(color: RelaColors.muted)),
                    ],
                  ),
                ),
                const Pill(label: 'Terlewat', fg: RelaColors.danger, bg: Color(0xFFF6DADA)),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    last == null
                        ? 'Belum pernah dikunjungi'
                        : 'Terakhir: ${_weekdays[last.toLocal().weekday - 1]}, ${visitDate(last)}',
                    style: const TextStyle(color: RelaColors.muted),
                  ),
                ),
                TextButton(
                  onPressed: () => onOpen(VolunteerProfileScreen(data: data, volunteerId: vid)),
                  child: const Text('Detail profil ›'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
