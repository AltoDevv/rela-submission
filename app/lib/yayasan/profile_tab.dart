import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/theme.dart';
import '../shared/account_profile.dart';

/// Tab Profil yayasan: sama dengan profil keluarga (foto, Kelola Akun, Pengaturan Notifikasi, Keluar), ditambah
/// Tambah pengurus. Kode undangan bersama dihapus (keputusan pengguna 16 Okt): relawan memilih yayasan saat mendaftar
/// dan diaktifkan dengan kode verifikasi pribadi saat tatap muka.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.foundation});

  final String foundation;

  @override
  Widget build(BuildContext context) {
    return AccountProfileTab(
      subtitle: (_) => 'Pengurus $foundation',
      canDelete: false,
      extra: [
        OutlinedButton.icon(
          style: bigOutlined,
          icon: const Icon(Icons.admin_panel_settings),
          label: const Text('Tambah pengurus yayasan'),
          onPressed: () => _addAdmin(context),
        ),
      ],
    );
  }
}

Future<void> _addAdmin(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final email = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tambah pengurus yayasan'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Ia harus sudah mendaftar sebagai Keluarga dan belum memantau lansia mana pun. '
            'Ia menjadi pengurus setelah menerima undangan di aplikasinya.'),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Undang')),
      ],
    ),
  );
  if (ok != true || email.text.trim().isEmpty) return;
  try {
    final msg = await Supabase.instance.client.rpc('add_foundation_admin', params: {'p_email': email.text.trim()});
    messenger.showSnackBar(SnackBar(content: Text('$msg')));
  } on PostgrestException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}
