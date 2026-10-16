import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Status kondisi lansia (PRD F6): stabil · perlu_perhatian · segera_dikabari.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  static const _labels = {
    'stabil': 'Stabil',
    'perlu_perhatian': 'Perlu perhatian',
    'segera_dikabari': 'Segera dikabari',
  };

  static Color colorFor(String status) => switch (status) {
        'stabil' => Colors.green.shade700,
        'perlu_perhatian' => Colors.amber.shade800,
        'segera_dikabari' => Colors.red.shade700,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(_labels[status] ?? status, style: const TextStyle(color: Colors.white)),
      backgroundColor: colorFor(status),
      side: BorderSide.none,
    );
  }
}

/// Wajib tampil bersama Profil Kesehatan Ringkas (PRD F1).
class DisclaimerLabel extends StatelessWidget {
  const DisclaimerLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Diisi oleh keluarga. Bukan diagnosis medis dan bukan rekam medis resmi.',
      style: TextStyle(fontStyle: FontStyle.italic),
    );
  }
}

/// Menu akun di AppBar: Keluar, atau Hapus akun (hak penghapusan data, UU PDP).
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  static Future<void> signOut() async {
    final db = Supabase.instance.client;
    final uid = db.auth.currentUser?.id;
    // Hapus token push akun ini dulu: HP yang dipakai bergantian akun tidak boleh menerima
    // notifikasi kesehatan/darurat milik akun sebelumnya. Gagal (mis. offline) tidak menahan logout.
    if (uid != null) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await db.rpc('unregister_push_token', params: {'p_token': token});
        await db.from('profiles').update({'fcm_token': null}).eq('id', uid); // kolom lama
      } catch (_) {}
    }
    await db.auth.signOut();
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(context: context, builder: (_) => const DeleteAccountDialog());
    if (ok != true) return;
    try {
      await Supabase.instance.client.functions.invoke('account', body: {'action': 'delete', 'confirm': 'HAPUS'});
      await Supabase.instance.client.auth.signOut();
      messenger.showSnackBar(const SnackBar(content: Text('Akun dan data Anda sudah dihapus.')));
    } on FunctionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal: ${(e.details as Map?)?['error'] ?? 'coba lagi'}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Akun',
      icon: const Icon(Icons.account_circle),
      onSelected: (v) => v == 'hapus' ? _deleteAccount(context) : signOut(),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'keluar', child: Text('Keluar')),
        PopupMenuItem(value: 'hapus', child: Text('Hapus akun')),
      ],
    );
  }
}

/// Konfirmasi hapus akun: pengguna harus mengetik HAPUS. true bila dikonfirmasi.
/// Konfirmasi penghapusan dengan mengetik HAPUS. Default: hapus akun; dipakai juga untuk hapus data lansia.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({
    super.key,
    this.title = 'Hapus akun?',
    this.body = 'Tindakan ini tidak bisa dibatalkan.\n'
        '• Keluarga: data lansia yang Anda daftarkan, termasuk profil kesehatan dan riwayat kunjungan, ikut terhapus, '
        'kecuali ada anggota keluarga lain: lansia dipindahkan ke anggota yang paling lama bergabung.\n'
        '• Relawan: lansia pasangan Anda diteruskan ke yayasan; riwayat kunjungan tetap tersimpan untuk keluarga.',
    this.okLabel = 'Hapus akun',
  });

  final String title, body, okLabel;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.body),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          decoration: const InputDecoration(labelText: 'Ketik HAPUS untuk melanjutkan'),
          onChanged: (_) => setState(() {}),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: _text.text.trim() == 'HAPUS' ? () => Navigator.pop(context, true) : null,
          child: Text(widget.okLabel),
        ),
      ],
    );
  }
}

/// Kerangka sementara untuk layar yang belum dibuat. Diganti oleh tugas pemiliknya.
class StubScreen extends StatelessWidget {
  const StubScreen({super.key, required this.title, this.children = const []});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [const Text('Belum dibuat'), ...children],
        ),
      ),
    );
  }
}

/// Bagian (bukan layar penuh) yang belum dibuat, misalnya daftar di beranda.
class StubSection extends StatelessWidget {
  const StubSection({super.key, required this.title, this.children = const []});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Text('Belum dibuat'),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Tombol di stub untuk membuka layar anak dengan ID contoh. Hilang saat stub diganti.
Widget stubLink(BuildContext context, String label, Widget Function() screen) {
  return TextButton(
    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen())),
    child: Text(label),
  );
}

/// Lebih dari ini tanpa kunjungan → peringatan (status bisa basi karena hanya dihitung ulang saat kunjungan).
const staleAfterDays = 7;

/// Teks "Kunjungan terakhir" dari tanggal kunjungan terkonfirmasi terakhir (null = belum pernah).
String lastVisitText(DateTime? last, {DateTime? now}) {
  if (last == null) return 'Belum pernah dikunjungi';
  final days = (now ?? DateTime.now()).difference(last).inDays;
  return 'Kunjungan terakhir: ${days <= 0 ? 'hari ini' : '$days hari lalu'}';
}

bool isVisitStale(DateTime? last, {DateTime? now}) =>
    last == null || (now ?? DateTime.now()).difference(last).inDays > staleAfterDays;

/// Badge kunjungan terakhir. Kuning bila lebih dari [staleAfterDays] hari atau belum pernah.
class LastVisitBadge extends StatelessWidget {
  const LastVisitBadge({super.key, required this.last, this.now});

  final DateTime? last;
  final DateTime? now; // diisi di test

  @override
  Widget build(BuildContext context) {
    final stale = isVisitStale(last, now: now);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(stale ? Icons.warning_amber : Icons.event_available,
          size: 18, color: stale ? Colors.amber.shade800 : Colors.green.shade700),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          stale && last != null ? '${lastVisitText(last, now: now)}, belum ada kunjungan baru' : lastVisitText(last, now: now),
          style: TextStyle(color: stale ? Colors.amber.shade900 : null),
        ),
      ),
    ]);
  }
}

/// Dialog konfirmasi umum. true bila pengguna menekan [okLabel].
Future<bool> confirmAction(BuildContext context, {required String title, required String body, required String okLabel}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(okLabel)),
      ],
    ),
  );
  return ok == true;
}

/// Mengakhiri pasangan lewat Edge Function `pairing` (relawan berhenti, keluarga minta ganti, yayasan melepas).
/// Lansia langsung dicocokkan ulang otomatis (bisa ke yayasan lain). Mengembalikan pesan untuk ditampilkan.
Future<String> releasePairing(String elderId) async {
  try {
    await Supabase.instance.client.functions.invoke('pairing', body: {'action': 'release', 'elder_id': elderId});
    return 'Pendamping dilepas. Sistem mengusulkan relawan pengganti ke keluarga.';
  } on FunctionException catch (e) {
    return 'Gagal: ${(e.details as Map?)?['error'] ?? 'coba lagi'}';
  }
}

/// Chip bertitik berwarna dari desain Figma (status relawan, jenis masukan, dsb.).
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.fg, required this.bg});

  final String label;
  final Color fg, bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 8, color: fg),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
