import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/login_screen.dart';
import 'keluarga/home_screen.dart';
import 'relawan/home_screen.dart';
import 'relawan/join_screen.dart';
import 'shared/push_setup.dart';
import 'shared/terms_screen.dart';
import 'shared/theme.dart';
import 'shared/widgets.dart';
import 'yayasan/home_screen.dart';

// Diisi saat build: flutter run --dart-define-from-file=env.json
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    throw StateError('SUPABASE_URL/SUPABASE_PUBLISHABLE_KEY kosong. Jalankan dengan --dart-define-from-file=env.json');
  }
  await Firebase.initializeApp(); // konfigurasi dari android/app/google-services.json
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  runApp(const ReLaApp());
}

/// Beranda untuk setiap peran. Fungsi murni supaya bisa dites tanpa Supabase.
Widget homeFor(String role, {required bool volunteerJoined}) {
  return switch (role) {
    'keluarga' => const KeluargaHomeScreen(),
    'relawan' => volunteerJoined ? const RelawanHomeScreen() : const JoinScreen(),
    'yayasan' => const YayasanHomeScreen(),
    _ => Scaffold(
        appBar: AppBar(actions: const [LogoutButton()]),
        body: Center(child: Text('Peran tidak dikenal: $role')),
      ),
  };
}

class ReLaApp extends StatefulWidget {
  const ReLaApp({super.key});

  @override
  State<ReLaApp> createState() => _ReLaAppState();
}

class _ReLaAppState extends State<ReLaApp> {
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    // uriLinkStream juga mengirim tautan yang membuka aplikasi dari keadaan tertutup.
    _links = AppLinks().uriLinkStream.listen(_openLink);
  }

  void _openLink(Uri uri) {
    if (uri.scheme != 'temansenja' || uri.host != 'join') return;
    final code = uri.queryParameters['code'];
    // Tunggu frame pertama supaya Navigator sudah siap saat aplikasi dibuka dari tautan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => JoinScreen(code: code)));
    });
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReLa',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: relaTheme,
      home: const AuthGate(),
    );
  }
}

/// Belum login → LoginScreen. Sudah login → baca peran dari profiles, lalu buka beranda.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        final user = auth.currentUser;
        if (user == null) return const LoginScreen();
        return FutureBuilder<Widget>(
          key: ValueKey(user.id), // muat ulang bila akun berganti
          future: _loadHome(user.id),
          builder: (context, snap) {
            if (snap.hasError) {
              return Scaffold(
                appBar: AppBar(actions: const [LogoutButton()]),
                body: Center(child: Text('Gagal memuat profil: ${snap.error}')),
              );
            }
            return snap.data ?? const Scaffold(body: Center(child: CircularProgressIndicator()));
          },
        );
      },
    );
  }

  Future<Widget> _loadHome(String userId) async {
    final db = Supabase.instance.client;
    final profile = await db.from('profiles').select('role, terms_accepted_at').eq('id', userId).single();
    final role = profile['role'] as String;

    var joined = false;
    if (role == 'relawan') {
      try {
        joined = await db.from('volunteers').select('id').eq('id', userId).maybeSingle() != null;
      } on PostgrestException {
        joined = false; // tabel volunteers belum ada (sebelum T-007) → anggap belum bergabung
      }
    }

    unawaited(registerPush());
    final home = homeFor(role, volunteerJoined: joined);
    return profile['terms_accepted_at'] == null ? TermsGate(child: home) : home;
  }
}
