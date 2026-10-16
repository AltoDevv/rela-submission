import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:image_picker/image_picker.dart';

import '../auth/signup_screen.dart' show validatePhone;
import '../keluarga/register_elder_screen.dart' show pickElderPhoto;
import '../keluarga/ui.dart' show ElderAvatar;
import '../shared/theme.dart';
import '../shared/widgets.dart';

/// Kategori notifikasi yang bisa dimatikan (profiles.notify_off; disaring di Edge Function lewat recipientTokens).
const notifyCategories = {
  'kondisi': ('Kondisi lansia', 'Saat status lansia menjadi "Segera dikabari" setelah kunjungan.'),
  'pendamping': ('Pendamping & usulan relawan', 'Usulan relawan baru, pergantian pendamping, hasil verifikasi dokumen.'),
  'pengingat': ('Pengingat', 'Lansia lama tidak dikunjungi dan langganan yang akan berakhir.'),
};

/// Tab Profil keluarga (Figma "Profile").
class FamilyProfileTab extends StatelessWidget {
  const FamilyProfileTab({super.key, this.load, this.save});

  final Future<Map<String, dynamic>> Function()? load;
  final Future<void> Function(Map<String, dynamic> fields)? save;

  @override
  Widget build(BuildContext context) =>
      AccountProfileTab(subtitle: (name) => 'Keluarga $name', load: load, save: save);
}

/// Tab Profil akun (keluarga & yayasan): foto profil, Kelola Akun, Pengaturan Notifikasi, Keluar dari Akun.
class AccountProfileTab extends StatefulWidget {
  const AccountProfileTab({
    super.key,
    required this.subtitle,
    this.canDelete = true,
    this.extra = const [],
    this.load,
    this.save,
    this.pickPhoto = pickElderPhoto,
  });

  final String Function(String name) subtitle;
  final bool canDelete; // akun yayasan dihapus lewat pengelola platform
  final List<Widget> extra; // mis. Tambah pengurus yayasan

  /// Diganti di test. Default: baris profiles akun yang login.
  final Future<Map<String, dynamic>> Function()? load;
  final Future<void> Function(Map<String, dynamic> fields)? save;
  final Future<XFile?> Function(BuildContext context) pickPhoto;

  @override
  State<AccountProfileTab> createState() => _AccountProfileTabState();
}

class _AccountProfileTabState extends State<AccountProfileTab> {
  late final Future<Map<String, dynamic>> _me = _load();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _form = GlobalKey<FormState>();
  Set<String> _off = {};
  String? _avatar;
  bool _busy = false;

  Future<Map<String, dynamic>> _load() async {
    final me = await (widget.load ??
        () async {
          final db = Supabase.instance.client;
          return await db
              .from('profiles')
              .select('full_name, phone, notify_off, avatar_path')
              .eq('id', db.auth.currentUser!.id)
              .single();
        })();
    _name.text = me['full_name'] as String? ?? '';
    _phone.text = me['phone'] as String? ?? '';
    _off = {...((me['notify_off'] as List?) ?? const []).cast<String>()};
    _avatar = me['avatar_path'] as String?;
    return me;
  }

  /// Foto profil ke bucket privat `avatars/<id akun>/foto.jpg`.
  Future<void> _changePhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final photo = await widget.pickPhoto(context);
    if (photo == null) return;
    setState(() => _busy = true);
    try {
      final db = Supabase.instance.client;
      final path = '${db.auth.currentUser!.id}/foto-${DateTime.now().millisecondsSinceEpoch}.jpg';
      await db.storage.from('avatars').uploadBinary(path, await photo.readAsBytes(),
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
      await db.from('profiles').update({'avatar_path': path}).eq('id', db.auth.currentUser!.id);
      if (mounted) setState(() => _avatar = path);
      messenger.showSnackBar(const SnackBar(content: Text('Foto profil diperbarui.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal mengunggah foto: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _update(Map<String, dynamic> fields, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await (widget.save ??
          (f) async {
            final db = Supabase.instance.client;
            await db.from('profiles').update(f).eq('id', db.auth.currentUser!.id);
          })(fields);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal: ${e.message}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
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
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Widget _section({required IconData icon, required String title, required String subtitle, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: RelaColors.muted),
        title: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        shape: const Border(),
        childrenPadding: const EdgeInsets.all(20),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _me,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Gagal memuat profil: ${snap.error}', textAlign: TextAlign.center),
              const LogoutButton(),
            ]),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(20), children: [
              const SizedBox(height: 12),
              Center(
                child: InkWell(
                  key: const Key('foto-profil'),
                  customBorder: const CircleBorder(),
                  onTap: _busy ? null : _changePhoto,
                  child: Stack(children: [
                    _avatar == null
                        ? CircleAvatar(
                            radius: 52,
                            backgroundColor: Colors.grey.shade300,
                            child: const Icon(Icons.person_outline, size: 52, color: RelaColors.primary),
                          )
                        : ElderAvatar(name: _name.text, photoPath: _avatar, bucket: 'avatars', radius: 52),
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: RelaColors.primary,
                        child: Icon(Icons.photo_camera, size: 16, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Text(_name.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              Text(widget.subtitle(_name.text), textAlign: TextAlign.center, style: const TextStyle(color: RelaColors.muted)),
              const SizedBox(height: 24),
              _section(
                icon: Icons.person_outline,
                title: 'Kelola Akun',
                subtitle: 'Ubah Informasi Akun.',
                children: [
                  Form(
                    key: _form,
                    child: Column(children: [
                      TextFormField(
                        key: const Key('akun-nama'),
                        controller: _name,
                        maxLength: 100,
                        decoration: const InputDecoration(labelText: 'Nama'),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('akun-hp'),
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Nomor HP'),
                        validator: validatePhone,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () {
                            if (!_form.currentState!.validate()) return;
                            _update({'full_name': _name.text.trim(), 'phone': _phone.text.trim()}, 'Akun diperbarui.');
                          },
                    child: const Text('Simpan'),
                  ),
                  if (widget.canDelete)
                    TextButton(
                      onPressed: _deleteAccount,
                      child: Text('Hapus akun', style: TextStyle(color: Colors.red.shade700)),
                    ),
                ],
              ),
              _section(
                icon: Icons.notifications_none,
                title: 'Pengaturan Notifikasi',
                subtitle: 'Atur Pemberitahuan Aplikasi.',
                children: [
                  const SwitchListTile(
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    value: true,
                    onChanged: null,
                    title: Text('Darurat'),
                    subtitle: Text('Selalu aktif: tombol Darurat relawan tidak bisa dimatikan.'),
                  ),
                  for (final c in notifyCategories.entries)
                    SwitchListTile(
                      key: Key('notif-${c.key}'),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      value: !_off.contains(c.key),
                      title: Text(c.value.$1),
                      subtitle: Text(c.value.$2),
                      onChanged: _busy
                          ? null
                          : (on) {
                              setState(() => on ? _off.remove(c.key) : _off.add(c.key));
                              _update({'notify_off': _off.toList()}, on ? 'Notifikasi diaktifkan.' : 'Notifikasi dimatikan.');
                            },
                    ),
                ],
              ),
              ...widget.extra,
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: FilledButton.icon(
              style: bigDanger,
              icon: const Icon(Icons.logout),
              label: const Text('Keluar dari Akun'),
              onPressed: LogoutButton.signOut,
            ),
          ),
        ]);
      },
    );
  }
}
