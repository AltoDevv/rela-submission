import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/widgets.dart';
import 'manual_pair_screen.dart';
import 'verify_family_screen.dart';

const _urgency = {'segera_dikabari': 0, 'perlu_perhatian': 1, 'stabil': 2};

const _pairingLabels = {
  'berpasangan': 'Didampingi relawan · ketuk untuk melepas',
  'tanpa_pendamping': 'Belum ada relawan yang cocok · ketuk untuk memasangkan',
  'perlu_yayasan': 'Menunggu pencocokan ulang · ketuk untuk memasangkan',
  'menunggu_keluarga': 'Menunggu keputusan keluarga',
  'mencari': 'Mencari relawan',
  'selesai': 'Pendampingan selesai',
};

/// Urutan dashboard (PRD F9): Segera dikabari → Perlu perhatian → Stabil, lalu nama.
List<Map<String, dynamic>> sortByUrgency(List elders) {
  final list = elders.map((e) => (e as Map).cast<String, dynamic>()).toList();
  list.sort((a, b) {
    // Yang sudah ditangani turun ke bawah dalam kelompok statusnya, supaya yang belum disentuh terlihat dulu.
    int rank(Map e) => (_urgency[e['status']] ?? 3) * 2 + (e['status_ack_at'] != null ? 1 : 0);
    final byStatus = rank(a).compareTo(rank(b));
    return byStatus != 0 ? byStatus : (a['full_name'] as String).compareTo(b['full_name'] as String);
  });
  return list;
}

Future<Map<String, dynamic>> loadDashboard() async =>
    ((await Supabase.instance.client.rpc('foundation_dashboard')) as Map).cast<String, dynamic>();

void _openManualPair(BuildContext context, String elderId) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManualPairScreen(elderId: elderId)));

/// F9: dashboard yayasan dalam satu layar (bagian dari beranda yayasan).
class DashboardSection extends StatefulWidget {
  const DashboardSection({super.key, this.load, this.onManualPair, this.onRelease, this.onVerify, this.onApproveStop});

  // Bisa diganti di test. Default: RPC foundation_dashboard dan navigasi ke ManualPairScreen.
  final Future<Map<String, dynamic>> Function()? load;
  final void Function(BuildContext context, String elderId)? onManualPair;
  final Future<String> Function(String elderId)? onRelease;
  final void Function(String elderId, String name)? onVerify;
  final Future<void> Function(String requestId)? onApproveStop;

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection> {
  late Future<Map<String, dynamic>> _data = (widget.load ?? loadDashboard)();

  void _reload() => setState(() { _data = (widget.load ?? loadDashboard)(); });

  Future<void> _release(String elderId, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(context,
        title: 'Lepas pendamping $name?',
        body: 'Sistem langsung mengusulkan relawan pengganti ke keluarga (bisa dari yayasan lain).',
        okLabel: 'Ya, lepas');
    if (!ok) return;
    messenger.showSnackBar(SnackBar(content: Text(await (widget.onRelease ?? releasePairing)(elderId))));
    _reload();
  }

  Future<void> _verify(String elderId, String name) async {
    if (widget.onVerify != null) return widget.onVerify!(elderId, name);
    final done = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => VerifyFamilyScreen(elderId: elderId, elderName: name)));
    if (done == true) _reload();
  }

  /// Permintaan berhenti relawan: yayasan menerima (tidak bisa menolak; otomatis setelah 7 hari), lalu sistem
  /// langsung mengusulkan pengganti ke keluarga (bisa dari yayasan lain).
  Future<void> _approveStop(Map e) async {
    final messenger = ScaffoldMessenger.of(context);
    final req = (e['stop_request'] as Map).cast<String, dynamic>();
    final ok = await confirmAction(context,
        title: 'Terima permintaan berhenti?',
        body: 'Alasan relawan: ${req['reason']}\n\nSistem langsung mengusulkan relawan pengganti untuk '
            '${e['full_name']} ke keluarga. Bila tidak ditanggapi, permintaan diterima otomatis setelah 7 hari.',
        okLabel: 'Terima & cari pengganti');
    if (!ok) return;
    try {
      await (widget.onApproveStop ??
          (id) => Supabase.instance.client.functions.invoke('pairing', body: {'action': 'approve_stop', 'request_id': id}))(
          req['id'] as String);
      _reload();
      messenger.showSnackBar(const SnackBar(content: Text('Diterima. Usulan relawan pengganti dikirim ke keluarga.')));
    } on FunctionException catch (err) {
      messenger.showSnackBar(SnackBar(content: Text('${(err.details as Map?)?['error'] ?? 'Gagal, coba lagi'}')));
    }
  }

  Future<void> _manualPair(String elderId) async {
    (widget.onManualPair ?? _openManualPair)(context, elderId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snap) {
        if (snap.hasError) {
          return ListTile(
            title: const Text('Gagal memuat dashboard'),
            trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
          );
        }
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
        final d = snap.data!;
        final counts = (d['counts'] as Map).cast<String, dynamic>();
        final elders = sortByUrgency(d['elders'] as List);
        final volunteers = (d['volunteers'] as List).cast<Map>();
        final theme = Theme.of(context).textTheme;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Dashboard', style: theme.titleLarge)),
              IconButton(tooltip: 'Muat ulang', icon: const Icon(Icons.refresh), onPressed: _reload),
            ]),
            Row(children: [
              _Count(label: 'Didampingi', value: counts['didampingi']),
              _Count(label: 'Belum ada relawan', value: counts['tanpa_pendamping']),
              _Count(label: 'Dicocokkan ulang', value: counts['perlu_yayasan']),
            ]),
            const SizedBox(height: 12),
            Text('Lansia (paling mendesak di atas)', style: theme.titleMedium),
            if (elders.isEmpty) const Text('Belum ada lansia.'),
            for (final e in elders)
              Card(
                child: ListTile(
                  title: Text(e['full_name'] as String),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text([
                      _pairingLabels[e['pairing_state']] ?? e['pairing_state'],
                      if (e['has_chronic'] == true) 'Ada kondisi kronis',
                      // Koreksi relawan atas penilaian AI selalu terlihat, juga saat hasilnya "Stabil" (E1).
                      if (e['status_reason'] != null &&
                          (e['status'] != 'stabil' || (e['status_reason'] as String).startsWith('Koreksi relawan')))
                        (e['status_reason'] as String).split('\n').first,
                    ].join('\n')),
                    if (e['stop_request'] != null)
                      Text('Relawan mengajukan berhenti: ${(e['stop_request'] as Map)['reason']} · ketuk untuk menerima',
                          style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                    if (e['verify_state'] == 'menunggu' && e['pairing_state'] == 'berpasangan')
                      Text('Dokumen keluarga perlu diperiksa · ketuk untuk memverifikasi',
                          style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                    if (e['status_ack_at'] != null)
                      Text('Sudah ditangani oleh ${e['status_ack_by'] ?? '-'}', style: TextStyle(color: Colors.green.shade800)),
                    if (e['pairing_state'] == 'berpasangan')
                      LastVisitBadge(
                        last: e['last_visit_at'] == null ? null : DateTime.parse(e['last_visit_at'] as String),
                      ),
                  ]),
                  isThreeLine: true,
                  trailing: StatusBadge(status: e['status'] as String),
                  onTap: switch (e['pairing_state']) {
                    'berpasangan' when e['stop_request'] != null => () => _approveStop(e),
                    'berpasangan' when e['verify_state'] == 'menunggu' =>
                      () => _verify(e['id'] as String, e['full_name'] as String),
                    'perlu_yayasan' || 'tanpa_pendamping' => () => _manualPair(e['id'] as String),
                    'berpasangan' => () => _release(e['id'] as String, e['full_name'] as String),
                    _ => null,
                  },
                ),
              ),
            const SizedBox(height: 12),
            Text('Beban relawan', style: theme.titleMedium),
            for (final v in volunteers)
              ListTile(
                dense: true,
                leading: Icon(v['status'] == 'aktif' ? Icons.person : Icons.hourglass_empty),
                title: Text('${v['full_name']} · ${v['load']}/${v['max_load']} lansia'),
                subtitle: v['status'] == 'aktif' ? null : const Text('Belum diverifikasi'),
              ),
          ]),
        );
      },
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            Text(label, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
