import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../keluarga/proposal_screen.dart' show rejectReasons;
import '../shared/models.dart';

typedef _Option = ({Volunteer v, String name, int load, double? km});

typedef _Data = ({
  Elder elder,
  bool hasChronic,
  List<Proposal> history,
  Map<String, String> names,
  List<_Option> options,
});

/// F2a: lansia yang 3 kali menolak usulan dipasangkan manual oleh pengurus yayasan.
/// Data dari RPC manual_pair_options: ringkasan kondisi (`has_chronic`, bukan profil kesehatan) dan jarak relawan
/// yang dihitung server. Alamat/koordinat lansia yang belum punya yayasan tidak dikirim ke yayasan (E2).
class ManualPairScreen extends StatefulWidget {
  const ManualPairScreen({super.key, required this.elderId});

  final String elderId;

  @override
  State<ManualPairScreen> createState() => _ManualPairScreenState();
}

class _ManualPairScreenState extends State<ManualPairScreen> {
  final _db = Supabase.instance.client;
  late Future<_Data> _data = _load();
  bool _busy = false;

  Future<_Data> _load() async {
    final opts = ((await _db.rpc('manual_pair_options', params: {'p_elder_id': widget.elderId})) as Map).cast<String, dynamic>();
    final elder = Elder.fromMap((opts['elder'] as Map).cast<String, dynamic>());
    final dash = (await _db.rpc('foundation_dashboard')) as Map<String, dynamic>;
    final team = {for (final v in (dash['volunteers'] as List).cast<Map>()) v['id'] as String: v};

    final history = (await _db.from('proposals').select().eq('elder_id', widget.elderId).order('attempt'))
        .map(Proposal.fromMap)
        .toList();
    final options = (opts['volunteers'] as List)
        .map((m) => (m as Map).cast<String, dynamic>())
        .map((m) => (
              v: Volunteer.fromMap(m),
              name: (m['full_name'] as String?) ?? 'Relawan',
              load: (m['load'] as num?)?.toInt() ?? 0,
              km: (m['km'] as num?)?.toDouble(),
            ))
        .toList()
      ..sort((a, b) => (a.km ?? double.infinity).compareTo(b.km ?? double.infinity));

    return (
      elder: elder,
      hasChronic: opts['has_chronic'] == true,
      history: history,
      names: {for (final e in team.entries) e.key: (e.value['full_name'] as String?) ?? 'Relawan'},
      options: options,
    );
  }

  Future<void> _pair(Elder elder, _Option o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pasangkan relawan?'),
        content: Text('${o.name} akan mendampingi ${elder.fullName}. Pastikan sudah dibicarakan dengan keluarga.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Pasangkan')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await _db.functions.invoke('pairing', body: {'action': 'manual', 'elder_id': elder.id, 'volunteer_id': o.v.id});
      messenger.showSnackBar(SnackBar(content: Text('${elder.fullName} kini didampingi ${o.name}.')));
      nav.pop(true);
    } on FunctionException catch (e) {
      final msg = (e.details is Map ? (e.details as Map)['error'] : null) ?? 'Gagal memasangkan, coba lagi.';
      messenger.showSnackBar(SnackBar(content: Text('$msg')));
      setState(() {
        _busy = false;
        _data = _load(); // status lansia mungkin sudah berubah
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pasang manual')),
      body: FutureBuilder(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Gagal memuat data: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!;
          final e = d.elder;
          final title = Theme.of(context).textTheme.titleMedium;
          final canPair = e.pairingState == 'perlu_yayasan' && !_busy;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(e.fullName, style: Theme.of(context).textTheme.titleLarge),
              Text(e.address),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                Chip(label: Text(d.hasChronic ? 'Ada kondisi kronis' : 'Tidak ada kondisi kronis tercatat')),
                if (e.hasDementia) const Chip(label: Text('Demensia')),
                if (e.hasMobilityIssue) const Chip(label: Text('Mobilitas sulit')),
              ]),
              if (e.pairingState != 'perlu_yayasan')
                Card(child: ListTile(title: Text('Status pemasangan: ${e.pairingState}'))),
              const SizedBox(height: 16),
              Text('Riwayat usulan', style: title),
              if (d.history.isEmpty) const Text('Belum ada usulan.'),
              for (final p in d.history)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(child: Text('${p.attempt}')),
                  title: Text('${d.names[p.volunteerId] ?? 'Relawan'} · ${p.distanceKm?.toStringAsFixed(1) ?? '-'} km'),
                  subtitle: Text(switch (p.state) {
                    'rejected' => 'Ditolak: ${rejectReasons[p.rejectReason] ?? p.rejectReason}'
                        '${p.rejectNote == null ? '' : ' — "${p.rejectNote}"'}',
                    'accepted' => 'Diterima',
                    'manual' => 'Dipasangkan manual',
                    _ => 'Menunggu jawaban keluarga',
                  }),
                ),
              const SizedBox(height: 16),
              Text('Relawan aktif (terdekat di atas)', style: title),
              if (d.options.isEmpty) const Text('Belum ada relawan aktif.'),
              for (final o in d.options)
                Card(
                  child: ListTile(
                    title: Text(o.name),
                    subtitle: Text([
                      o.km == null ? 'Jarak tidak diketahui' : '${o.km!.toStringAsFixed(1)} km',
                      'beban ${o.load}/${o.v.maxLoad}',
                      if (o.v.areaLabel != null) o.v.areaLabel!,
                      if (e.hasDementia && !o.v.canDementia) '⚠ belum berpengalaman demensia',
                      if (e.hasMobilityIssue && !o.v.canMobility) '⚠ belum berpengalaman mobilitas sulit',
                      if (o.load >= o.v.maxLoad) '⚠ beban penuh',
                      if (d.history.any((p) => p.volunteerId == o.v.id && p.state == 'rejected')) 'pernah ditolak keluarga',
                    ].join(' · ')),
                    trailing: FilledButton(
                      onPressed: canPair ? () => _pair(e, o) : null,
                      child: const Text('Pilih'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
