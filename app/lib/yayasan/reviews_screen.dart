import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data.dart';
import 'ui.dart';

const _kindRank = {'serius': 0, 'perbaikan': 1, 'apresiasi': 2};

/// Belum ditangani dulu (laporan serius paling atas), lalu yang terbaru. Fungsi murni supaya bisa dites.
List<Map<String, dynamic>> sortReviews(List<Map<String, dynamic>> rows) => [...rows]
  ..sort((a, b) {
    final h = (a['handled_at'] == null ? 0 : 1).compareTo(b['handled_at'] == null ? 0 : 1);
    if (h != 0) return h;
    final k = (_kindRank[a['kind']] ?? 3).compareTo(_kindRank[b['kind']] ?? 3);
    return k != 0 ? k : (b['created_at'] as String).compareTo(a['created_at'] as String);
  });

/// Tangani laporan serius (RPC handle_review); catatannya terlihat oleh keluarga.
Future<void> handleReview(String reviewId, String note) =>
    Supabase.instance.client.rpc('handle_review', params: {'p_review_id': reviewId, 'p_note': note});

/// Tab Ulasan: masukan keluarga untuk relawan yayasan ini (RLS: hanya relawannya). Hanya Masalah Serius yang
/// ditangani di sini (keputusan pengguna 16 Okt); ringkasan per relawan ada di profil relawan.
class ReviewsTab extends StatefulWidget {
  const ReviewsTab({super.key, required this.data, required this.header, required this.onChanged, this.handle});

  final YayasanData data;
  final Widget header;
  final VoidCallback onChanged;

  /// Diganti di test. Default: [handleReview].
  final Future<void> Function(String reviewId, String note)? handle;

  @override
  State<ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<ReviewsTab> {
  int _filter = 0; // Semua · Apresiasi · Kritik & Saran · Masalah Serius

  Future<void> _handle(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final c = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tangani laporan'),
        content: TextField(
          key: const Key('catatan-tindak-lanjut'),
          controller: c,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'Tindak lanjut, mis. "Sudah dibina, kunjungan didampingi"'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Simpan')),
        ],
      ),
    );
    if (note == null || note.isEmpty) return;
    try {
      await (widget.handle ?? handleReview)(id, note);
      widget.onChanged();
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = sortReviews(widget.data.reviews);
    const kinds = [null, 'apresiasi', 'perbaikan', 'serius'];
    int count(String? k) => all.where((r) => k == null || r['kind'] == k).length;
    final shown = all.where((r) => kinds[_filter] == null || r['kind'] == kinds[_filter]).toList();
    return ListView(padding: const EdgeInsets.all(20), children: [
      widget.header,
      const SizedBox(height: 20),
      SegmentTabs(
        labels: [
          'Semua (${count(null)})',
          'Apresiasi (${count('apresiasi')})',
          'Kritik & Saran (${count('perbaikan')})',
          'Masalah Serius (${count('serius')})',
        ],
        selected: _filter,
        onChanged: (i) => setState(() => _filter = i),
      ),
      const SizedBox(height: 16),
      if (shown.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Belum ada masukan dari keluarga.')),
      for (final r in shown)
        ReviewCard(
          review: r,
          data: widget.data,
          onHandle: r['kind'] == 'serius' ? () => _handle(r['id'] as String) : null,
        ),
    ]);
  }
}
