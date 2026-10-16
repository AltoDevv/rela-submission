import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../keluarga/review_dialog.dart' show reviewDate;

/// Ucapan terima kasih dari keluarga. RLS hanya memberi relawan masukan kategori "apresiasi" tentang dirinya;
/// masukan perbaikan dan laporan serius dibaca yayasan.
class AppreciationSection extends StatelessWidget {
  const AppreciationSection({super.key, this.load});

  final Future<List<Map<String, dynamic>>> Function()? load;

  Future<List<Map<String, dynamic>>> _load() async {
    final db = Supabase.instance.client;
    return (await db.from('reviews').select('body, created_at').eq('volunteer_id', db.auth.currentUser!.id)
            .order('created_at', ascending: false).limit(20))
        .cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: (load ?? _load)(),
      builder: (context, snap) {
        final rows = snap.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ucapan terima kasih dari keluarga', style: Theme.of(context).textTheme.titleLarge),
            for (final r in rows)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.favorite, color: Colors.pink),
                  title: Text(r['body'] as String),
                  subtitle: Text(reviewDate(DateTime.parse(r['created_at'] as String))),
                ),
              ),
          ]),
        );
      },
    );
  }
}
