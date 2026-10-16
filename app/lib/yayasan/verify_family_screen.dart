import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../keluarga/verify_elder_screen.dart' show verifyDocs;

/// Verifikasi online keluarga/lansia oleh pengurus yayasan relawan yang diterima keluarga. Dokumen dihapus server
/// setelah keputusan; yang tersimpan hanya siapa dan kapan.
class VerifyFamilyScreen extends StatefulWidget {
  const VerifyFamilyScreen({super.key, required this.elderId, required this.elderName, this.loadUrls, this.decide});

  final String elderId, elderName;
  final Future<Map<String, String?>> Function()? loadUrls; // jenis dokumen → URL gambar
  final Future<void> Function(bool approve, String note)? decide;

  @override
  State<VerifyFamilyScreen> createState() => _VerifyFamilyScreenState();
}

class _VerifyFamilyScreenState extends State<VerifyFamilyScreen> {
  late final Future<Map<String, String?>> _urls = (widget.loadUrls ?? _signedUrls)();
  bool _busy = false;

  Future<Map<String, String?>> _signedUrls() async {
    final bucket = Supabase.instance.client.storage.from('elder-docs');
    return {
      for (final k in verifyDocs.keys)
        k: await bucket.createSignedUrl('${widget.elderId}/$k.jpg', 600).then<String?>((u) => u, onError: (_) => null),
    };
  }

  Future<void> _decide(bool approve) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    var note = '';
    if (!approve) {
      final c = TextEditingController();
      final r = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tolak dokumen'),
          content: TextField(
            key: const Key('alasan-tolak'),
            controller: c,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'Alasan untuk keluarga, mis. "KK tidak terbaca"'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Tolak')),
          ],
        ),
      );
      if (r == null || r.isEmpty) return;
      note = r;
    }
    setState(() => _busy = true);
    try {
      await (widget.decide ??
          (a, n) => Supabase.instance.client.functions
              .invoke('pairing', body: {'action': 'verify', 'elder_id': widget.elderId, 'approve': a, 'note': n}))(
          approve, note);
      messenger.showSnackBar(SnackBar(
          content: Text(approve ? 'Keluarga ${widget.elderName} terverifikasi.' : 'Dokumen ditolak; keluarga diberi tahu.')));
      nav.maybePop(true);
    } on FunctionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal: ${(e.details as Map?)?['error'] ?? 'coba lagi'}')));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verifikasi keluarga ${widget.elderName}')),
      body: FutureBuilder<Map<String, String?>>(
        future: _urls,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Periksa: nama di KTP keluarga dan KTP lansia tercantum di Kartu Keluarga (atau surat RT/RW '
                'menyatakan hubungannya), dan alamatnya sesuai. Dokumen dihapus setelah Anda memutuskan.'),
            for (final e in verifyDocs.entries) ...[
              const SizedBox(height: 12),
              Text(e.value, style: Theme.of(context).textTheme.titleSmall),
              snap.data![e.key] == null
                  ? const Text('Tidak ada / gagal dimuat', style: TextStyle(color: Colors.red))
                  : Image.network(snap.data![e.key]!, height: 220, fit: BoxFit.contain),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(onPressed: _busy ? null : () => _decide(false), child: const Text('Tolak')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: _busy ? null : () => _decide(true), child: const Text('Setujui')),
              ),
            ]),
          ]);
        },
      ),
    );
  }
}
