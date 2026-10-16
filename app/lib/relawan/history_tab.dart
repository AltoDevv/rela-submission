import 'package:flutter/material.dart';

import '../shared/models.dart';
import '../shared/condition_summary.dart';
import '../shared/theme.dart';
import 'ui.dart';
import 'visit_confirm_screen.dart';

/// Tab Riwayat: semua kunjungan terkonfirmasi lansia terpilih, terbaru dulu.
class HistoryTab extends StatelessWidget {
  const HistoryTab({
    super.key,
    required this.data,
    required this.elder,
    required this.onPick,
    required this.onOpen,
    this.onRecord,
  });

  final RelawanData data;
  final Elder? elder;
  final ValueChanged<String> onPick;
  final Future<void> Function(Widget) onOpen;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final e = elder;
    if (e == null) {
      return const Center(child: Text('Belum ada lansia pasangan.'));
    }
    final visits =
        data
            .visitsOf(e.id)
            .where((v) => v.confirmedAt != null && v.finalResult != null)
            .toList()
          ..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Riwayat kunjungan',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        Text(e.fullName, style: const TextStyle(color: RelaColors.muted)),
        const SizedBox(height: 16),
        ElderPicker(elders: data.elders, selected: e.id, onChanged: onPick),
        if (onRecord != null) ...[
          FilledButton.icon(
            style: bigFilled,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Rekap Kunjungan'),
            onPressed: data.elders.any((e) => e.verifyState == 'terverifikasi')
                ? onRecord
                : null,
          ),
          const SizedBox(height: 16),
        ],
        if (visits.isEmpty) const Text('Belum ada kunjungan.'),
        for (final v in visits)
          VisitHistoryTile(
            visit: v,
            onTap: () => onOpen(
              VisitDetailScreen(elder: e, visit: v, latest: v == visits.first),
            ),
          ),
        ConditionSummary(visits: visits),
      ],
    );
  }
}

/// Detail satu kunjungan. Server hanya mengizinkan koreksi kunjungan terakhir, lalu menghitung ulang status lansia.
class VisitDetailScreen extends StatelessWidget {
  const VisitDetailScreen({
    super.key,
    required this.elder,
    required this.visit,
    this.latest = false,
  });

  final Elder elder;
  final Visit visit;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final result = visit.finalResult ?? const <String, dynamic>{};
    return Scaffold(
      appBar: AppBar(
        title: Text('${elder.fullName} · ${visitDate(visit.visitedAt)}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          VisitResultView(answers: visit.answers, result: result),
          if (latest) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              style: bigOutlined,
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => VisitConfirmScreen(
                    visitId: visit.id,
                    aiResult: result,
                    answers: visit.answers,
                  ),
                ),
              ),
              child: const Text('Koreksi kunjungan ini'),
            ),
          ],
        ],
      ),
    );
  }
}
