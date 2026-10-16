import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';

/// Kotak masuk akun yang login (tabel notifications, diisi Edge Function lewat notify). Terbaru dulu, maks. 50.
// async*: Supabase baru diakses saat stream didengarkan, jadi error (mis. di test) menjadi stream kosong, bukan crash.
Stream<List<Map<String, dynamic>>> watchNotifications() async* {
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) return;
  yield* db
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('profile_id', uid)
      .order('created_at', ascending: false)
      .limit(50);
}

Future<void> markAllRead() async {
  final db = Supabase.instance.client;
  await db
      .from('notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('profile_id', db.auth.currentUser!.id)
      .isFilter('read_at', null);
}

String _ago(DateTime t, DateTime now) {
  final d = now.difference(t.toLocal());
  if (d.inMinutes < 1) return 'Baru saja';
  if (d.inHours < 1) return '${d.inMinutes} menit lalu';
  if (d.inDays < 1) return '${d.inHours} jam lalu';
  return d.inDays == 1 ? 'Kemarin' : '${d.inDays} hari lalu';
}

IconData _icon(String? type) => switch (type) {
      'darurat' => Icons.emergency,
      'segera_dikabari' => Icons.priority_high,
      'jadwal' || 'pengingat_kunjungan' => Icons.event,
      'langganan' => Icons.receipt_long,
      'usulan' || 'pendamping_dilepas' || 'ganti_pendamping' => Icons.volunteer_activism,
      'verifikasi' => Icons.verified_user,
      'apresiasi' || 'masukan' || 'masukan_serius' => Icons.forum_outlined,
      _ => Icons.notifications_none,
    };

/// Lonceng di header ketiga peran: titik merah berisi jumlah belum dibaca; ditekan → panel dari atas halaman.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, this.stream, this.onOpened});

  /// Diganti di test. Default: [watchNotifications].
  final Stream<List<Map<String, dynamic>>>? stream;
  final Future<void> Function()? onOpened; // default: tandai semua dibaca

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late final Stream<List<Map<String, dynamic>>> _stream = (widget.stream ?? watchNotifications()).asBroadcastStream();
  List<Map<String, dynamic>> _items = const [];

  Future<void> _open() async {
    final items = _items;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup notifikasi',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (context, anim, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
      pageBuilder: (context, _, _) => _Panel(items: items),
    );
    try {
      await (widget.onOpened ?? markAllRead)();
    } catch (_) {
      // gagal menandai dibaca tidak mengganggu tampilan
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        _items = snap.data ?? const [];
        final unread = _items.where((n) => n['read_at'] == null).length;
        return Badge(
          isLabelVisible: unread > 0,
          label: Text(unread > 9 ? '9+' : '$unread'),
          offset: const Offset(-4, 4),
          child: IconButton.filled(
            key: const Key('lonceng'),
            tooltip: 'Notifikasi',
            style: IconButton.styleFrom(backgroundColor: RelaColors.cream, foregroundColor: RelaColors.ink),
            icon: const Icon(Icons.notifications_none),
            onPressed: _open,
          ),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Material(
          color: Colors.white,
          elevation: 8,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                title: const Text('Notifikasi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                trailing: IconButton(
                  tooltip: 'Tutup',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const Divider(height: 1),
              if (items.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Text('Belum ada notifikasi.'))
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final n = items[i];
                      final unread = n['read_at'] == null;
                      return ListTile(
                        tileColor: unread ? RelaColors.paper : null,
                        leading: CircleAvatar(
                          backgroundColor: n['data']?['type'] == 'darurat' ? const Color(0xFFF6DADA) : RelaColors.cream,
                          child: Icon(_icon(n['data']?['type'] as String?), color: RelaColors.ink),
                        ),
                        title: Text('${n['title']}', style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
                        subtitle: Text('${n['body']}\n${_ago(DateTime.parse(n['created_at'] as String), now)}'),
                        isThreeLine: true,
                      );
                    },
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
