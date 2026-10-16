import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/rubric.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'ui.dart';

/// Bukti untuk tanda bahaya yang tidak dideteksi AI tetapi dicentang relawan.
const addedByVolunteer = 'Ditambahkan relawan';

/// Salinan [ai] dengan level dan tanda bahaya hasil koreksi relawan. [ai] tidak diubah, supaya `ai_result`
/// dan `final_result` tersimpan berdampingan sebagai data berlabel (PRD F5). Bila [flags] diisi, tanda bahaya
/// mengikuti pilihan relawan: yang dicabut dibuang (alarm palsu), yang ditambah diberi bukti [addedByVolunteer].
Map<String, dynamic> applyCorrection(Map<String, dynamic> ai, Map<String, int?> levels, {Set<String>? flags}) {
  final fin = jsonDecode(jsonEncode(ai)) as Map<String, dynamic>; // salinan dalam
  levels.forEach((key, level) => (fin[key] as Map<String, dynamic>)['level'] = level);
  if (flags != null) {
    final fromAi = {for (final f in (ai['red_flags'] as List? ?? const [])) (f as Map)['flag']: f['evidence']};
    fin['red_flags'] = [
      for (final key in redFlags.keys)
        if (flags.contains(key)) {'flag': key, 'evidence': fromAi[key] ?? addedByVolunteer},
    ];
  }
  return fin;
}

/// Kirim final_result ke Edge Function `visit` (confirm). [flagReasons]: alasan untuk tiap tanda bahaya AI yang
/// dicabut (wajib; dicatat dan diperlihatkan ke keluarga & yayasan). Mengembalikan hasil computeStatus.
Future<Map<String, dynamic>> confirmVisit(String visitId, Map<String, dynamic> finalResult, Map<String, String> flagReasons) async {
  final res = await Supabase.instance.client.functions.invoke('visit',
      body: {'action': 'confirm', 'visit_id': visitId, 'final_result': finalResult, 'flag_reasons': flagReasons});
  return (res.data as Map).cast<String, dynamic>();
}

/// F5: relawan melihat ringkasan hasil AI, mengoreksi bila perlu, lalu menyimpan.
class VisitConfirmScreen extends StatefulWidget {
  const VisitConfirmScreen({super.key, required this.visitId, this.aiResult, this.answers, this.onConfirm});

  final String visitId;

  /// Hasil `extract`. Bila kosong, diambil dari kolom `visits.ai_result`.
  final Map<String, dynamic>? aiResult;

  /// Cerita relawan untuk kotak "Cerita asli Anda". Bila kosong dan [aiResult] juga kosong, diambil dari `visits`.
  final Map<String, dynamic>? answers;

  /// Diganti di test. Default: [confirmVisit].
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> finalResult, Map<String, String> flagReasons)? onConfirm;

  @override
  State<VisitConfirmScreen> createState() => _VisitConfirmScreenState();
}

class _VisitConfirmScreenState extends State<VisitConfirmScreen> {
  late final Future<Map<String, dynamic>> _ai = _loadAi();
  final Map<String, int?> _levels = {};
  final Set<String> _flags = {};
  final Map<String, String> _reasons = {}; // tanda bahaya AI yang dicabut → alasan relawan
  bool _saving = false;
  bool _editing = false; // false = kartu hasil seperti Figma; true = dropdown & centang tanda bahaya
  Map<String, dynamic> _answers = const {};
  Map<String, dynamic>? _status; // hasil confirm

  Future<Map<String, dynamic>> _loadAi() async {
    _answers = widget.answers ?? const {};
    var ai = widget.aiResult;
    if (ai == null) {
      final row = await Supabase.instance.client.from('visits').select('ai_result, answers').eq('id', widget.visitId).single();
      ai = (row['ai_result'] as Map).cast<String, dynamic>();
      _answers = (row['answers'] as Map?)?.cast<String, dynamic>() ?? const {};
    }
    for (final d in rubricDomains) {
      _levels[d.key] = (ai[d.key] as Map?)?['level'] as int?;
    }
    _flags.addAll([for (final f in (ai['red_flags'] as List? ?? const [])) (f as Map)['flag'] as String]);
    return ai;
  }

  Future<void> _save(Map<String, dynamic> ai) async {
    setState(() => _saving = true);
    try {
      final fin = applyCorrection(ai, _levels, flags: _flags);
      final result = await (widget.onConfirm ?? (f, r) => confirmVisit(widget.visitId, f, r))(fin, Map.of(_reasons));
      setState(() => _status = result);
    } catch (e) {
      if (mounted) {
        final msg = e is FunctionException && e.details is Map ? (e.details as Map)['error'] : null;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${msg ?? 'Gagal menyimpan, coba lagi'}')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_status == null ? 'Periksa ringkasan' : ''), automaticallyImplyLeading: _status == null),
      body: _status != null
          ? _Saved(status: _status!)
          : FutureBuilder<Map<String, dynamic>>(
              future: _ai,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Gagal memuat hasil: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final ai = snap.data!;
                final aiFlags = {
                  for (final f in (ai['red_flags'] as List? ?? const [])) (f as Map)['flag'] as String: f['evidence'],
                };
                return ListView(padding: const EdgeInsets.all(24), children: [
                  if (!_editing)
                    VisitResultView(answers: _answers, result: applyCorrection(ai, _levels, flags: _flags))
                  else ...[
                    Card(
                      color: _flags.isEmpty ? null : Colors.red.shade50,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Text('Tanda bahaya. Cabut centang bila AI keliru, centang bila terlewat.'),
                        ),
                        for (final e in redFlags.entries)
                          CheckboxListTile(
                            key: Key('flag-${e.key}'),
                            value: _flags.contains(e.key),
                            title: Text(e.value),
                            subtitle: aiFlags.containsKey(e.key)
                                ? Text('AI: "${aiFlags[e.key]}"${_reasons[e.key] == null ? '' : '\nDicabut: ${_reasons[e.key]}'}')
                                : null,
                            onChanged: (on) => _toggleFlag(e.key, e.value, on == true, fromAi: aiFlags.containsKey(e.key)),
                          ),
                      ]),
                    ),
                    for (final d in rubricDomains) _domainTile(d, (ai[d.key] as Map?)?['evidence'] as String? ?? ''),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton(
                    style: bigOutlined,
                    onPressed: () => setState(() => _editing = !_editing),
                    child: Text(_editing ? 'Selesai mengedit' : 'Edit'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: bigOutlined,
                    onPressed: _saving ? null : () => _save(ai),
                    child: Text(_saving ? 'Menyimpan…' : 'Konfirmasi dan Simpan'),
                  ),
                ]);
              },
            ),
    );
  }

  /// Mencabut tanda bahaya dari AI wajib beralasan; alasannya ikut terlihat oleh keluarga dan yayasan.
  Future<void> _toggleFlag(String key, String label, bool on, {required bool fromAi}) async {
    if (!on && fromAi) {
      final reason = await _askReason(label);
      if (reason == null) return;
      _reasons[key] = reason;
    } else {
      _reasons.remove(key);
    }
    setState(() { on ? _flags.add(key) : _flags.remove(key); });
  }

  Future<String?> _askReason(String label) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cabut tanda bahaya "$label"?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Alasan Anda dicatat dan dapat dilihat keluarga serta yayasan.'),
          TextField(
            key: const Key('alasan-cabut'),
            controller: c,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Alasan, mis. "Itu kejadian tahun lalu"'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ListenableBuilder(
            listenable: c,
            builder: (context, _) => FilledButton(
              onPressed: c.text.trim().length < 3 ? null : () => Navigator.pop(context, c.text.trim()),
              child: const Text('Cabut'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _domainTile(RubricDomain d, String evidence) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(d.name),
      subtitle: Text(evidence.isEmpty ? 'Tidak disebut dalam cerita' : '"$evidence"'),
      trailing: DropdownButton<int?>(
        key: Key('level-${d.key}'),
        value: _levels[d.key],
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('Tidak disebut')),
          for (var i = 0; i < d.labels.length; i++) DropdownMenuItem<int?>(value: i, child: Text(d.labels[i])),
        ],
        onChanged: (v) => setState(() => _levels[d.key] = v),
      ),
    );
  }
}

class _Saved extends StatelessWidget {
  const _Saved({required this.status});

  final Map<String, dynamic> status;

  @override
  Widget build(BuildContext context) {
    final reasons = (status['reasons'] as List? ?? const []).cast<Map>();
    const muted = TextStyle(color: RelaColors.muted);
    return ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 48),
      const Center(
        child: CircleAvatar(
          radius: 44,
          backgroundColor: RelaColors.primary,
          child: Icon(Icons.check, color: Colors.white, size: 52),
        ),
      ),
      const SizedBox(height: 24),
      const Text('Rekap masuk ke riwayat kunjungan.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('Dashboard keluarga diperbarui. Status terbaru:', textAlign: TextAlign.center, style: muted),
      Center(child: StatusBadge(status: status['status'] as String? ?? '')),
      for (final r in reasons) Text('• ${r['text']} "${r['quote']}"', style: muted),
      if (status['disclaimer'] != null)
        Text(status['disclaimer'] as String, textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic)),
      const SizedBox(height: 24),
      OutlinedButton(
        style: bigOutlined,
        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        child: const Text('Kembali ke Beranda'),
      ),
    ]);
  }
}
