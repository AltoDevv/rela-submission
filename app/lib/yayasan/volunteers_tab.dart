import 'package:flutter/material.dart';

import '../shared/models.dart';
import '../shared/theme.dart';
import 'data.dart';
import 'ui.dart';
import 'volunteer_profile_screen.dart';

/// Tab Relawan: daftar relawan yayasan dengan filter Semua · Aktif · Verifikasi · Undur Diri.
class VolunteersTab extends StatelessWidget {
  const VolunteersTab({
    super.key,
    required this.data,
    required this.header,
    required this.filter,
    required this.onFilter,
    required this.onOpen,
  });

  final YayasanData data;
  final Widget header;
  final int filter;
  final ValueChanged<int> onFilter;
  final Future<void> Function(Widget) onOpen;

  @override
  Widget build(BuildContext context) {
    final all = [for (final v in data.volunteers) (v: v, s: volunteerState(v, data.loadOf(v.id)))];
    bool Function(({Volunteer v, VolunteerState s})) test(int i) => switch (i) {
          1 => (r) => r.v.status == 'aktif' && r.s != VolunteerState.mundur,
          2 => (r) => r.s == VolunteerState.belum || r.s == VolunteerState.nonaktif,
          3 => (r) => r.s == VolunteerState.mundur,
          _ => (r) => true,
        };
    final labels = ['Semua', 'Aktif', 'Verifikasi', 'Undur Diri'];
    final shown = all.where(test(filter)).toList();
    return ListView(padding: const EdgeInsets.all(20), children: [
      header,
      const SizedBox(height: 20),
      SegmentTabs(
        labels: [for (var i = 0; i < 4; i++) '${labels[i]} (${all.where(test(i)).length})'],
        selected: filter,
        onChanged: onFilter,
      ),
      const SizedBox(height: 16),
      if (shown.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Tidak ada relawan di sini.')),
      for (final r in shown) _VolunteerCard(data: data, v: r.v, state: r.s, onOpen: onOpen),
      const SizedBox(height: 8),
      OutlinedButton(
        style: bigOutlined.copyWith(foregroundColor: const WidgetStatePropertyAll(RelaColors.primary)),
        // Tanpa kode undangan bersama (keputusan pengguna 16 Okt): relawan memilih yayasan saat mendaftar.
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          builder: (_) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Undang relawan baru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text('1. Minta calon relawan memasang ReLa dan mendaftar sebagai Relawan.\n'
                    '2. Saat bergabung, ia mencari dan memilih "${data.foundation}".\n'
                    '3. Ia muncul di tab Relawan sebagai "Belum verifikasi".\n'
                    '4. Saat bertemu, buka profilnya, centang identitas & orientasi, lalu tekan Verifikasi: kode 6 angka '
                    'khusus untuknya muncul dan ia memasukkannya di HP-nya.'),
              ]),
            ),
          ),
        ),
        child: const Text('Undang relawan baru'),
      ),
    ]);
  }
}

class _VolunteerCard extends StatelessWidget {
  const _VolunteerCard({required this.data, required this.v, required this.state, required this.onOpen});

  final YayasanData data;
  final Volunteer v;
  final VolunteerState state;
  final Future<void> Function(Widget) onOpen;

  @override
  Widget build(BuildContext context) {
    final name = data.nameOf(v.id);
    final unverified = state == VolunteerState.belum || state == VolunteerState.nonaktif;
    const muted = TextStyle(color: RelaColors.muted);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => onOpen(VolunteerProfileScreen(data: data, volunteerId: v.id)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SquareInitial(name: name, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(unverified ? 'Menunggu verifikasi tatap muka' : shortDays(v.availableDays), style: muted),
                ]),
              ),
              volunteerPill(state),
            ]),
            if (!unverified) ...[
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 20),
                const SizedBox(width: 6),
                Expanded(child: Text(v.areaLabel ?? '-', style: muted)),
              ]),
              const SizedBox(height: 8),
              Text('${data.reviewsOf(v.id).length} umpan balik keluarga', style: muted),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text(unverified ? '' : 'Lansia: ${data.loadOf(v.id)}', style: muted)),
              Text(unverified ? 'Verifikasi ›' : 'Lihat Profil ›', style: const TextStyle(color: RelaColors.primary)),
            ]),
          ]),
        ),
      ),
    );
  }
}
