import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Anggota keluarga yang memantau satu lansia (mis. beberapa anak di kota berbeda). Semua anggota melihat data
/// yang sama dan menerima notifikasi. Hanya pendaftar yang menambah/menghapus; anggota boleh keluar sendiri.
class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key, required this.elderId, required this.elderName});

  final String elderId;
  final String elderName;

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  final _db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _members = _load();

  Future<List<Map<String, dynamic>>> _load() async =>
      ((await _db.rpc('family_member_list', params: {'p_elder_id': widget.elderId})) as List)
          .map((m) => (m as Map).cast<String, dynamic>())
          .toList();

  void _say(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _run(Future<dynamic> Function() action, String success) async {
    try {
      await action();
      _say(success);
    } on PostgrestException catch (e) {
      _say(e.message);
    }
    setState(() { _members = _load(); });
  }

  Future<void> _add() async {
    final email = await showDialog<String>(context: context, builder: (_) => const _AddMemberDialog());
    if (email == null) return;
    await _run(() => _db.rpc('add_family_member', params: {'p_elder_id': widget.elderId, 'p_email': email}),
        'Undangan dikirim bila email itu milik akun Keluarga ReLa. Ia perlu menerimanya dulu.');
  }

  Future<void> _remove(String profileId, {required bool self}) async {
    await _run(() => _db.rpc('remove_family_member', params: {'p_elder_id': widget.elderId, 'p_profile_id': profileId}),
        self ? 'Anda keluar dari keluarga ini.' : 'Anggota dihapus.');
    if (self && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final me = _db.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(title: Text('Keluarga ${widget.elderName}')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _members,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Gagal memuat: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final members = snap.data!;
          final iAmOwner = members.any((m) => m['is_owner'] == true && m['profile_id'] == me);
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Semua anggota melihat data, status, dan riwayat yang sama, serta menerima notifikasi. '
                'Keputusan menerima atau menolak usulan relawan tetap di tangan pendaftar.'),
            const SizedBox(height: 12),
            for (final m in members)
              ListTile(
                leading: Icon(m['is_owner'] == true ? Icons.star : Icons.person),
                title: Text('${m['full_name'] ?? '-'}${m['profile_id'] == me ? ' (Anda)' : ''}'),
                subtitle: Text(m['is_owner'] == true
                    ? 'Pendaftar'
                    : m['accepted'] == true
                        ? 'Anggota keluarga'
                        : 'Menunggu undangan diterima'),
                trailing: m['is_owner'] == true
                    ? null
                    : m['profile_id'] == me
                        ? TextButton(onPressed: () => _remove(m['profile_id'], self: true), child: const Text('Keluar'))
                        : iAmOwner
                            ? IconButton(
                                tooltip: 'Hapus anggota',
                                icon: const Icon(Icons.person_remove),
                                onPressed: () => _remove(m['profile_id'], self: false),
                              )
                            : null,
              ),
            if (iAmOwner)
              FilledButton.icon(icon: const Icon(Icons.person_add), label: const Text('Tambah anggota keluarga'), onPressed: _add),
          ]);
        },
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());
    return AlertDialog(
      title: const Text('Tambah anggota keluarga'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Masukkan email akun ReLa miliknya. Ia harus sudah mendaftar sebagai Keluarga.'),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
          onChanged: (_) => setState(() {}),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: valid ? () => Navigator.pop(context, _email.text.trim()) : null, child: const Text('Tambah')),
      ],
    );
  }
}
