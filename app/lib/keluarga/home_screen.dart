import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../relawan/home_screen.dart' show greeting;
import '../shared/models.dart';
import '../shared/notifications.dart';
import '../shared/theme.dart';
import 'elder_list.dart';
import 'history_tab.dart';
import '../shared/account_profile.dart';
import 'register_elder_screen.dart';

/// Beranda keluarga. Tiga tab sesuai Figma: Beranda · Riwayat · Profil.
class KeluargaHomeScreen extends StatefulWidget {
  const KeluargaHomeScreen({super.key});

  @override
  State<KeluargaHomeScreen> createState() => _KeluargaHomeScreenState();
}

class _KeluargaHomeScreenState extends State<KeluargaHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_tab) {
          1 => const HistoryTab(),
          2 => const FamilyProfileTab(),
          _ => const _Beranda(),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.schedule), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.account_circle_outlined), label: 'Profil'),
        ],
      ),
    );
  }
}

/// Lansia yang didaftarkan sendiri atau diikuti sebagai anggota keluarga (RLS), berubah langsung lewat Realtime.
// async*: Supabase baru diakses saat stream didengarkan, jadi error (mis. di test) menjadi pesan, bukan crash.
Stream<List<Elder>> watchElders() async* {
  final db = Supabase.instance.client;
  yield* db.from('elders').stream(primaryKey: ['id']).order('created_at').map((rows) => rows.map(Elder.fromMap).toList());
}

/// Nama akun yang login (sapaan "Keluarga [nama]").
Future<String?> myName() async {
  final db = Supabase.instance.client;
  return (await db.from('profiles').select('full_name').eq('id', db.auth.currentUser!.id).single())['full_name']
      as String?;
}

/// Logo, sapaan, "Keluarga [nama akun]", lonceng kotak masuk notifikasi.
class FamilyHeader extends StatefulWidget {
  const FamilyHeader({super.key});

  @override
  State<FamilyHeader> createState() => _FamilyHeaderState();
}

class _FamilyHeaderState extends State<FamilyHeader> {
  late final Future<String?> _name = myName().catchError((_) => null);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      ClipOval(child: Image.asset('assets/rela-logo.png', width: 64, height: 64, fit: BoxFit.cover)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(greeting(DateTime.now()), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          FutureBuilder<String?>(
            future: _name,
            builder: (context, snap) =>
                Text('Keluarga ${snap.data ?? ''}'.trim(), style: const TextStyle(color: RelaColors.muted)),
          ),
        ]),
      ),
      const NotificationBell(),
    ]);
  }
}

class _Beranda extends StatefulWidget {
  const _Beranda();

  @override
  State<_Beranda> createState() => _BerandaState();
}

class _BerandaState extends State<_Beranda> {
  // Dibuat per tab: stream Realtime hanya boleh didengarkan sekali.
  late Stream<List<Elder>> _elders = watchElders();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const FamilyHeader(),
          const SizedBox(height: 20),
          // Hak baca berubah setelah undangan diterima: buka ulang langganan supaya lansianya ikut tampil.
          FamilyInvites(onChanged: () => setState(() { _elders = watchElders(); })),
          StreamBuilder<List<Elder>>(
            stream: _elders,
            builder: (context, snap) {
              if (snap.hasError) return const ListTile(title: Text('Gagal memuat daftar lansia'));
              if (!snap.hasData) return const LinearProgressIndicator();
              if (snap.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('Belum ada lansia. Tekan "Daftar Lansia" untuk mulai.', textAlign: TextAlign.center),
                );
              }
              return Column(children: [
                for (final e in snap.data!)
                  ElderHomeCard(key: ValueKey(e.id), elder: e, onTap: () => openElder(context, e)),
              ]);
            },
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: FilledButton.icon(
          style: bigFilled,
          icon: const Icon(Icons.add_circle),
          label: const Text('Daftar Lansia'),
          onPressed: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterElderScreen())),
        ),
      ),
    ]);
  }
}
