import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'elder_list.dart' show proposeAndOpen;

/// Dokumen verifikasi keluarga/lansia: kunci = nama file di `elder-docs/<elder_id>/<kunci>.jpg`.
const verifyDocs = {
  'ktp_keluarga': 'KTP Anda',
  'ktp_lansia': 'KTP lansia',
  'kk': 'Kartu Keluarga (atau surat keterangan RT/RW)',
};

/// Langkah sebelum relawan dicarikan (K1/K5): berlangganan, lalu unggah dokumen yang diperiksa online oleh
/// pengurus yayasan relawan yang Anda terima. Fungsi Supabase bisa diganti di test.
class VerifyElderScreen extends StatefulWidget {
  const VerifyElderScreen({
    super.key,
    required this.elderId,
    required this.elderName,
    this.paid = false,
    this.rejectedNote,
    this.needDocs = true,
    this.pay,
    this.pick,
    this.upload,
    this.submit,
    this.onDone,
  });

  final String elderId, elderName;
  final bool paid;
  final String? rejectedNote; // dokumen sebelumnya ditolak yayasan
  final bool needDocs; // false: dokumen sudah dikirim/terverifikasi, cukup perpanjang langganan
  final Future<void> Function()? pay;
  final Future<XFile?> Function(String doc)? pick;
  final Future<void> Function(String doc, XFile file)? upload;
  final Future<void> Function()? submit;
  final Future<void> Function(BuildContext context)? onDone; // default: tutup layar lalu cari relawan

  @override
  State<VerifyElderScreen> createState() => _VerifyElderScreenState();
}

class _VerifyElderScreenState extends State<VerifyElderScreen> {
  SupabaseClient get _db => Supabase.instance.client; // getter: test tanpa Supabase tetap jalan
  late bool _paid = widget.paid;
  final _uploaded = <String>{};
  bool _busy = false;

  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } on PostgrestException catch (e) {
      _say(e.message);
    } on StorageException catch (e) {
      _say('Gagal mengunggah: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() => _run(() async {
    await (widget.pay ?? () => _db.rpc('simulate_payment', params: {'p_elder_id': widget.elderId}))();
    setState(() => _paid = true);
    if (!widget.needDocs && mounted) {
      await (widget.onDone ??
          (ctx) async {
            final nav = Navigator.of(ctx);
            final home = nav.context;
            nav.pop();
            if (home.mounted) await proposeAndOpen(home, widget.elderId);
          })(context);
    }
  });

  Future<void> _take(String doc) async {
    final file =
        await (widget.pick ??
            (_) => ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80))(doc);
    if (file == null) return;
    await _run(() async {
      await (widget.upload ??
          (d, f) async => _db.storage
              .from('elder-docs')
              .uploadBinary(
                '${widget.elderId}/$d.jpg',
                await f.readAsBytes(),
                fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
              ))(doc, file);
      setState(() => _uploaded.add(doc));
    });
  }

  Future<void> _submit() => _run(() async {
    await (widget.submit ?? () => _db.rpc('submit_verification', params: {'p_elder_id': widget.elderId}))();
    if (!mounted) return;
    await (widget.onDone ??
        (ctx) async {
          final nav = Navigator.of(ctx);
          final home = nav.context;
          nav.pop();
          if (home.mounted) await proposeAndOpen(home, widget.elderId);
        })(context);
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final allDocs = _uploaded.length == verifyDocs.length;
    return Scaffold(
      appBar: AppBar(title: Text('Lanjutkan pendaftaran ${widget.elderName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('1. Langganan', style: t.titleMedium),
          Card(
            child: ListTile(
              leading: Icon(_paid ? Icons.check_circle : Icons.payments_outlined, color: _paid ? Colors.green : null),
              title: Text(_paid ? 'Langganan aktif' : 'Langganan Rp200.000 per bulan per lansia'),
              subtitle: const Text(
                'Pembayaran disimulasikan untuk demo. Relawan baru dicarikan setelah langganan aktif.',
              ),
              trailing: _paid
                  ? null
                  : FilledButton(
                      key: const Key('bayar'),
                      onPressed: _busy ? null : _pay,
                      child: const Text('Bayar (simulasi)'),
                    ),
            ),
          ),
          if (widget.needDocs) ...[
            const SizedBox(height: 16),
            Text('2. Dokumen verifikasi', style: t.titleMedium),
            if (widget.rejectedNote != null)
              Card(
                color: Colors.orange.shade50,
                child: ListTile(title: const Text('Dokumen sebelumnya ditolak'), subtitle: Text(widget.rejectedNote!)),
              ),
            const Text(
              'Untuk keamanan relawan yang datang ke rumah dan untuk memastikan Anda keluarga lansia ini. '
              'Dokumen hanya dilihat pengurus yayasan relawan yang Anda terima, lalu dihapus setelah diperiksa.',
            ),
            for (final e in verifyDocs.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _uploaded.contains(e.key) ? Icons.check_circle : Icons.photo_camera_outlined,
                  color: _uploaded.contains(e.key) ? Colors.green : null,
                ),
                title: Text(e.value),
                trailing: TextButton(
                  key: Key('doc-${e.key}'),
                  onPressed: !_paid || _busy ? null : () => _take(e.key),
                  child: Text(_uploaded.contains(e.key) ? 'Ulangi' : 'Ambil foto'),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('kirim-dokumen'),
              onPressed: _paid && allDocs && !_busy ? _submit : null,
              child: const Text('Kirim dan cari relawan'),
            ),
          ],
        ],
      ),
    );
  }
}
