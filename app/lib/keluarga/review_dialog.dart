import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kategori masukan: (judul, siapa yang membaca). Bukan bintang; kategori menentukan ke mana masukan dikirim.
const reviewKinds = {
  'apresiasi': ('Terima kasih / apresiasi', 'Dibaca relawan dan yayasan.'),
  'perbaikan': ('Ada yang perlu diperbaiki', 'Hanya dibaca yayasan, yang akan membina relawan.'),
  'serius': (
    'Ada masalah serius',
    'Mis. keselamatan, kasar, atau meminta uang. Langsung ke yayasan dan tidak dibaca relawan.'
  ),
};

/// Dialog masukan; mengembalikan (kategori, isi) atau null bila batal.
class ReviewDialog extends StatefulWidget {
  const ReviewDialog({super.key, this.intro, this.initialKind});

  final String? intro;
  final String? initialKind;

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  late String? _kind = widget.initialKind;
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _kind != null && _text.text.trim().length >= 3;
    return AlertDialog(
      title: const Text('Masukan tentang relawan'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(shrinkWrap: true, children: [
          if (widget.intro != null) Text(widget.intro!),
          RadioGroup<String>(
            groupValue: _kind,
            onChanged: (v) => setState(() => _kind = v),
            child: Column(children: [
              for (final e in reviewKinds.entries)
                RadioListTile<String>(
                  key: Key('jenis-${e.key}'),
                  contentPadding: EdgeInsets.zero,
                  value: e.key,
                  title: Text(e.value.$1),
                  subtitle: Text(e.value.$2),
                ),
            ]),
          ),
          TextField(
            key: const Key('isi-masukan'),
            controller: _text,
            maxLength: 500,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Ceritakan singkat'),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: ok ? () => Navigator.pop(context, (_kind!, _text.text.trim())) : null,
          child: const Text('Kirim'),
        ),
      ],
    );
  }
}

/// Buka dialog lalu kirim ke Edge Function `review`. true bila terkirim.
Future<bool> askReview(BuildContext context, String elderId, {String? intro, String? initialKind}) async {
  final messenger = ScaffoldMessenger.of(context);
  final r = await showDialog<(String, String)>(context: context, builder: (_) => ReviewDialog(intro: intro, initialKind: initialKind));
  if (r == null) return false;
  try {
    await Supabase.instance.client.functions.invoke('review', body: {'elder_id': elderId, 'kind': r.$1, 'body': r.$2});
    messenger.showSnackBar(SnackBar(
      content: Text(r.$1 == 'serius'
          ? 'Laporan dikirim ke yayasan. Bila perlu, pilih "Minta ganti pendamping" di menu.'
          : 'Terima kasih, masukan terkirim.'),
    ));
    return true;
  } on FunctionException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('${(e.details as Map?)?['error'] ?? 'Gagal mengirim, coba lagi'}')));
    return false;
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
String reviewDate(DateTime t) => '${_two(t.toLocal().day)}/${_two(t.toLocal().month)}/${t.toLocal().year}';

/// Ajakan memberi masukan sekitar sebulan sekali: sudah 30 hari sejak masukan terakhir saya
/// (atau sejak kunjungan pertama bila belum pernah).
bool reviewDue({required DateTime? firstVisitAt, required DateTime? lastMine, DateTime? now}) {
  final from = lastMine ?? firstVisitAt;
  return from != null && (now ?? DateTime.now()).difference(from).inDays >= 30;
}
