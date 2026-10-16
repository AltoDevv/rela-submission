import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../relawan/ui.dart' show visitDate;
import '../relawan/visit_story_screen.dart' show storyQuestions;
import '../shared/condition_summary.dart';
import '../shared/models.dart';
import '../shared/rubric.dart';
import '../shared/theme.dart';
import 'elder_list.dart' show companionLine;
import 'home_screen.dart' show FamilyHeader, watchElders;
import 'ui.dart';

export '../shared/condition_summary.dart' show DomainChart, levelSeries;

/// Tab Riwayat (Figma "History"): pilih lansia, daftar kunjungan beserta status, dan ringkasan kondisi per kategori.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  late final Stream<List<Elder>> _elders = watchElders();
  String? _elderId;
  Future<List<Visit>>? _visits;
  String? _visitsFor;

  Future<List<Visit>> _load(String elderId) async => (await Supabase.instance.client
          .from('visits')
          .select()
          .eq('elder_id', elderId)
          .not('confirmed_at', 'is', null)
          .order('visited_at'))
      .map(Visit.fromMap)
      .toList();

  Future<void> _pick(List<Elder> elders) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final e in elders)
            ListTile(
              leading: ElderAvatar(name: e.fullName, photoPath: e.photoPath, radius: 20),
              title: Text(elderTitle(e)),
              onTap: () => Navigator.pop(context, e.id),
            ),
        ]),
      ),
    );
    if (id != null) setState(() => _elderId = id);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Elder>>(
      stream: _elders,
      builder: (context, snap) {
        final children = <Widget>[const FamilyHeader(), const SizedBox(height: 16)];
        if (snap.hasError) {
          children.add(const Text('Gagal memuat daftar lansia'));
        } else if (!snap.hasData) {
          children.add(const LinearProgressIndicator());
        } else if (snap.data!.isEmpty) {
          children.add(const Text('Belum ada lansia.'));
        } else {
          final elders = snap.data!;
          final e = elders.where((x) => x.id == _elderId).firstOrNull ?? elders.first;
          if (_visitsFor != e.id) {
            _visitsFor = e.id;
            _visits = _load(e.id);
          }
          children.addAll([
            const Text('Pilih Lansia Untuk Melihat Riwayat Kunjungan', style: TextStyle(color: RelaColors.muted)),
            const SizedBox(height: 8),
            _ElderSelector(elder: e, onTap: elders.length > 1 ? () => _pick(elders) : null),
            FutureBuilder<List<Visit>>(
              future: _visits,
              builder: (context, vs) {
                if (vs.hasError) return Text('Gagal memuat kunjungan: ${vs.error}');
                if (!vs.hasData) return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
                return HistoryView(
                  elder: e,
                  visits: vs.data!,
                  onOpen: (v) => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => FamilyVisitDetailScreen(elder: e, visit: v))),
                );
              },
            ),
          ]);
        }
        return ListView(padding: const EdgeInsets.all(20), children: children);
      },
    );
  }
}

class _ElderSelector extends StatelessWidget {
  const _ElderSelector({required this.elder, this.onTap});

  final Elder elder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: RelaColors.cream,
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ElderAvatar(name: elder.fullName, photoPath: elder.photoPath, radius: 26),
        title: Text(elder.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        subtitle: FutureBuilder<String?>(
          future: companionLine(elder),
          builder: (context, snap) => Text([
            if (elder.birthDate != null) '${ageFrom(elder.birthDate!)} tahun',
            ?snap.data?.replaceFirst(RegExp(r' · .*$'), ''),
          ].join(' · ')),
        ),
        trailing: onTap == null ? null : const Icon(Icons.expand_more),
        onTap: onTap,
      ),
    );
  }
}

/// Isi tab Riwayat tanpa Supabase (bisa dites): daftar kunjungan (terbaru di atas) dan grafik satu kategori.
class HistoryView extends StatelessWidget {
  const HistoryView({
    super.key,
    required this.elder,
    required this.visits,
    this.onOpen,
  });

  final Elder elder;
  final List<Visit> visits; // urut lama → baru
  final void Function(Visit visit)? onOpen;

  @override
  Widget build(BuildContext context) {
    final confirmed = visits.where((v) => v.finalResult != null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        if (confirmed.isEmpty)
          const Text('Belum ada kunjungan yang disimpan relawan.'),
        for (final v in confirmed.reversed)
          Card(
            key: ValueKey('kunjungan-${v.id}'),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(
                visitDate(v.visitedAt),
                style: const TextStyle(fontSize: 18),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (v.statusAfter != null) statusPill(v.statusAfter!),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: onOpen == null ? null : () => onOpen!(v),
            ),
          ),
        ConditionSummary(visits: confirmed),
      ],
    );
  }
}

String _hm(DateTime t) => '${t.toLocal().hour.toString().padLeft(2, '0')}.${t.toLocal().minute.toString().padLeft(2, '0')}';

/// Detail satu kunjungan (Figma "Visit History Detail"): cerita relawan per bagian, ditambah tanda bahaya dan
/// hasil per kategori supaya keluarga melihat dasar status.
class FamilyVisitDetailScreen extends StatelessWidget {
  const FamilyVisitDetailScreen({super.key, required this.elder, required this.visit, this.companion});

  final Elder elder;
  final Visit visit;
  final String? companion; // diisi di test; default dibaca dari my_volunteer_contact

  @override
  Widget build(BuildContext context) {
    final answers = [
      for (final q in storyQuestions.entries)
        if ('${visit.answers[q.key] ?? ''}'.trim().isNotEmpty) (q.value.$1, '${visit.answers[q.key]}'.trim()),
    ];
    final r = visit.finalResult ?? const <String, dynamic>{};
    final flags = ((r['red_flags'] as List?) ?? const []).cast<Map>();
    final removed = ((visit.overrides?['removed_flags'] as List?) ?? const []).cast<Map>();
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: RelaColors.border, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ElderAvatar(name: elder.fullName, photoPath: elder.photoPath),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(elder.fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    if (visit.statusAfter != null) ...[const SizedBox(height: 6), statusPill(visit.statusAfter!)],
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              if (companion != null)
                Text(companion!)
              else
                FutureBuilder<String?>(
                  future: companionLine(elder),
                  builder: (context, snap) => Text(snap.data?.replaceFirst(RegExp(r' · .*$'), '') ?? ''),
                ),
              const SizedBox(height: 8),
              Text(longDate(visit.visitedAt), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              Text('Pukul: ${_hm(visit.visitedAt)}', style: const TextStyle(color: RelaColors.muted)),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        Row(children: [
          const Expanded(child: Text('Rekap kunjungan', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700))),
          Text('${answers.length} catatan', style: const TextStyle(color: RelaColors.muted)),
        ]),
        for (final (title, text) in answers)
          Card(
            margin: const EdgeInsets.only(top: 12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(text),
              ]),
            ),
          ),
        const SizedBox(height: 20),
        Card(
          key: const ValueKey('rekap'),
          color: RelaColors.paper,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Hasil per kategori', style: TextStyle(fontWeight: FontWeight.w700)),
              for (final f in flags)
                Text('⚠ ${redFlags[f['flag']] ?? f['flag']}: "${f['evidence']}"',
                    style: const TextStyle(color: RelaColors.danger)),
              // Tanda bahaya dari AI yang dicabut relawan tetap terlihat di riwayat, beserta alasannya.
              for (final f in removed)
                Text('Dicabut relawan: ${redFlags[f['flag']] ?? f['flag']} (AI: "${f['evidence']}") — alasan: ${f['reason']}',
                    style: TextStyle(color: Colors.orange.shade900)),
              for (final d in rubricDomains)
                if (r[d.key] case {'level': final int level, 'evidence': final String ev})
                  Text('${d.name}: ${d.labels[level]}${ev.isEmpty ? '' : ' — "$ev"'}')
                else
                  Text('${d.name}: tidak disebut', style: const TextStyle(color: RelaColors.muted)),
              const SizedBox(height: 8),
              const Text('Bukan diagnosis medis.', style: TextStyle(fontStyle: FontStyle.italic)),
            ]),
          ),
        ),
      ]),
    );
  }
}
