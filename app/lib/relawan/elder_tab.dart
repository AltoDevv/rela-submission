import 'package:flutter/material.dart';

import '../shared/models.dart';
import '../shared/schedule_widgets.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'ui.dart';

/// Tab Lansia: kartu lansia + profil kesehatan yang diisi keluarga, dalam bentuk akordeon.
class ElderTab extends StatelessWidget {
  const ElderTab({
    super.key,
    required this.data,
    required this.elder,
    required this.onPick,
    required this.onReload,
    this.now,
    this.scheduleSubmit,
  });

  final RelawanData data;
  final Elder? elder;
  final ValueChanged<String> onPick;
  final VoidCallback onReload;
  final DateTime? now;
  final Future<String> Function(Map<String, dynamic>, String)? scheduleSubmit;

  @override
  Widget build(BuildContext context) {
    final e = elder;
    if (e == null) {
      return const Center(child: Text('Belum ada lansia pasangan.'));
    }
    final h = data.health[e.id];
    final meds = (h?.medications ?? const [])
        .map(
          (m) => '${m['name']}${m['times'] != null ? ' (${m['times']})' : ''}',
        )
        .join('\n');
    final sections = {
      'Kondisi / Penyakit': h?.conditions,
      'Obat rutin dan jadwal minum': meds,
      'Dokter atau rumah sakit langganan': h?.doctorHospital,
      'Alergi & Pantangan makanan': [
        h?.allergies,
        h?.dietRestrictions,
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join('\n'),
      'Kemampuan bergerak dan alat bantu': h?.mobilityAids,
      'Instruksi darurat': h?.emergencyInstructions,
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ElderPicker(elders: data.elders, selected: e.id, onChanged: onPick),
        ElderCard(elder: e, contact: data.contacts[e.id]),
        const SizedBox(height: 24),
        const Text('Jadwal Kunjungan', style: TextStyle(fontSize: 22)),
        VolunteerScheduleRow(
          elder: e,
          availableDays: data.volunteer.availableDays,
          onDone: onReload,
          now: now,
          submit: scheduleSubmit,
        ),
        const SizedBox(height: 24),
        const Text('Info Keluarga', style: TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        const DisclaimerLabel(),
        for (final s in sections.entries)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ExpansionTile(
              title: Text(s.key, style: const TextStyle(fontSize: 17)),
              backgroundColor: Colors.white,
              collapsedBackgroundColor: RelaColors.paper,
              shape: _shape,
              collapsedShape: _shape,
              expandedAlignment: Alignment.centerLeft,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(
                  s.value == null || s.value!.trim().isEmpty
                      ? 'Belum diisi oleh keluarga.'
                      : s.value!,
                  style: const TextStyle(color: RelaColors.muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

final _shape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(20),
  side: const BorderSide(color: RelaColors.border),
);
