import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Relawan yang belum aktif: datang ke yayasan, pengurus memeriksa lalu menampilkan kode 6 digit (berlaku 2 menit),
/// relawan memasukkannya di sini. Kode membuktikan keduanya bertemu tatap muka.
class VerificationCard extends StatefulWidget {
  const VerificationCard({super.key, this.load, this.redeem, this.onActivated});

  /// (status, catatan yayasan) relawan yang login.
  final Future<({String status, String? note})> Function()? load;
  final Future<String> Function(String code)? redeem; // 'aktif' | 'salah'; error bila kode tidak berlaku
  final VoidCallback? onActivated;

  @override
  State<VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends State<VerificationCard> {
  SupabaseClient get _db => Supabase.instance.client;
  late var _me = (widget.load ?? _load)();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<({String status, String? note})> _load() async {
    final v = await _db.from('volunteers').select('status, status_note').eq('id', _db.auth.currentUser!.id).single();
    return (status: v['status'] as String, note: v['status_note'] as String?);
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await (widget.redeem ??
          (c) async => (await _db.rpc('redeem_verification_code', params: {'p_code': c})) as String)(_code.text.trim());
      if (r == 'aktif') {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Terverifikasi! Anda sekarang relawan aktif.')));
        }
        widget.onActivated?.call();
        setState(() { _me = (widget.load ?? _load)(); });
      } else {
        setState(() => _error = 'Kode salah. Periksa lagi layar pengurus.');
      }
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String status, String? note})>(
      future: _me,
      builder: (context, snap) {
        final me = snap.data;
        if (me == null || me.status == 'aktif') return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Menunggu verifikasi tatap muka', style: Theme.of(context).textTheme.titleMedium),
              if (me.note != null) Text(me.note!, style: TextStyle(color: Colors.orange.shade900)),
              const Text('Datang ke yayasan dengan membawa KTP asli. Setelah pemeriksaan, pengurus menampilkan kode '
                  '6 digit di HP-nya. Masukkan kode itu di sini sebelum waktunya habis.'),
              TextField(
                key: const Key('kode-verifikasi'),
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: 'Kode dari pengurus', errorText: _error),
              ),
              FilledButton(
                onPressed: _busy || _code.text.trim().length != 6 ? null : _submit,
                child: const Text('Verifikasi'),
              ),
            ]),
          ),
        );
      },
    );
  }
}
