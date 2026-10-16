import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/models.dart';
import 'review_dialog.dart';

/// Langganan lansia (hanya pendaftar): sampai kapan aktif, masa tenggang 7 hari, perpanjang, dan riwayat bayar.
class SubscriptionCard extends StatefulWidget {
  const SubscriptionCard({super.key, required this.elder, this.pay, this.loadPayments});

  final Elder elder;
  final Future<void> Function()? pay;
  final Future<List<Map<String, dynamic>>> Function()? loadPayments;

  @override
  State<SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<SubscriptionCard> {
  SupabaseClient get _db => Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _payments = _load();
  bool _busy = false;

  Future<List<Map<String, dynamic>>> _load() => (widget.loadPayments ??
      () async => (await _db.from('payments').select().eq('elder_id', widget.elder.id).order('created_at', ascending: false))
          .cast<Map<String, dynamic>>())();

  Future<void> _pay() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await (widget.pay ?? () => _db.rpc('simulate_payment', params: {'p_elder_id': widget.elder.id}))();
      messenger.showSnackBar(const SnackBar(content: Text('Langganan diperpanjang 30 hari (simulasi).')));
      setState(() { _payments = _load(); });
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final until = widget.elder.paidUntil;
    final now = DateTime.now();
    final expired = until == null || until.isBefore(now);
    final graceEnd = until?.add(const Duration(days: 7));
    final text = until == null
        ? 'Belum berlangganan.'
        : !expired
            ? 'Aktif sampai ${reviewDate(until)}.'
            : graceEnd!.isAfter(now)
                ? 'Berakhir ${reviewDate(until)}. Kunjungan tetap berjalan sampai ${reviewDate(graceEnd)}, setelah itu '
                    'relawan tidak bisa mencatat kunjungan.'
                : 'Berakhir ${reviewDate(until)}. Kunjungan dihentikan sampai langganan diperpanjang.';
    return Card(
      color: expired ? Colors.orange.shade50 : null,
      child: ExpansionTile(
        leading: Icon(expired ? Icons.warning_amber : Icons.payments_outlined),
        title: const Text('Langganan'),
        subtitle: Text(text),
        trailing: FilledButton(
          key: const Key('perpanjang'),
          onPressed: _busy ? null : _pay,
          child: Text(expired ? 'Perpanjang' : 'Tambah 30 hari'),
        ),
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _payments,
            builder: (context, snap) => Column(children: [
              if ((snap.data ?? const []).isEmpty) const ListTile(dense: true, title: Text('Belum ada riwayat pembayaran.')),
              for (final p in snap.data ?? const <Map<String, dynamic>>[])
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.receipt_long),
                  title: Text('Dibayar ${reviewDate(DateTime.parse(p['created_at'] as String))}'
                      '${p['provider'] == 'simulasi' ? ' (simulasi)' : ''}'),
                  subtitle: Text('Aktif sampai ${reviewDate(DateTime.parse(p['period_end'] as String))}'),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Masukan keluarga untuk relawan: ajakan sekitar sebulan sekali, dan riwayat masukan beserta tanggapan yayasan.
class ReviewsSection extends StatefulWidget {
  const ReviewsSection({super.key, required this.elder, this.load, this.ask, this.myId});

  final Elder elder;
  final Future<List<Map<String, dynamic>>> Function()? load;
  final Future<bool> Function(BuildContext context)? ask;
  final String? myId; // diisi di test; default akun yang login

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  late Future<List<Map<String, dynamic>>> _reviews = _load();
  bool _dismissed = false;

  Future<List<Map<String, dynamic>>> _load() => (widget.load ??
      () async => (await Supabase.instance.client
              .from('reviews')
              .select()
              .eq('elder_id', widget.elder.id)
              .order('created_at', ascending: false))
          .cast<Map<String, dynamic>>())();

  Future<void> _ask() async {
    final sent = await (widget.ask ?? (ctx) => askReview(ctx, widget.elder.id))(context);
    if (sent && mounted) setState(() { _reviews = _load(); });
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.myId ?? Supabase.instance.client.auth.currentUser?.id;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reviews,
      builder: (context, snap) {
        final all = snap.data ?? const <Map<String, dynamic>>[];
        final mine = all.where((r) => r['author_id'] == me).toList();
        final due = !_dismissed &&
            widget.elder.pairingState == 'berpasangan' &&
            reviewDue(
              firstVisitAt: widget.elder.firstVisitAt,
              lastMine: mine.isEmpty ? null : DateTime.parse(mine.first['created_at'] as String),
            );
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (due)
            Card(
              key: const Key('ajakan-masukan'),
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                title: const Text('Bagaimana pendampingan bulan ini?'),
                subtitle: const Text('Masukan Anda membantu yayasan membina relawan.'),
                trailing: Wrap(children: [
                  TextButton(onPressed: () => setState(() => _dismissed = true), child: const Text('Nanti')),
                  FilledButton(onPressed: _ask, child: const Text('Beri masukan')),
                ]),
                isThreeLine: true,
              ),
            ),
          if (all.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Masukan untuk relawan', style: Theme.of(context).textTheme.titleMedium),
            for (final r in all)
              Card(
                child: ListTile(
                  title: Text('${reviewKinds[r['kind']]?.$1 ?? r['kind']} · ${reviewDate(DateTime.parse(r['created_at'] as String))}'),
                  subtitle: Text([
                    r['body'] as String,
                    r['handled_at'] == null
                        ? (r['kind'] == 'apresiasi' ? 'Terkirim ke relawan.' : 'Belum ditanggapi yayasan.')
                        : 'Ditangani ${r['handled_by'] ?? 'yayasan'}: ${r['handled_note'] ?? '-'}',
                  ].join('\n')),
                ),
              ),
          ],
        ]);
      },
    );
  }
}
