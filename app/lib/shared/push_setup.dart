import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../keluarga/elder_detail_screen.dart';
import '../main.dart' show navigatorKey;

StreamSubscription<String>? _tokenSub;
bool _listening = false;

/// Dipanggil setelah login (main.dart): minta izin notifikasi (Android 13+), daftarkan token FCM perangkat ini
/// ke push_tokens (satu akun bisa punya banyak perangkat), perbarui saat token berganti, dan buka layar yang
/// sesuai saat notifikasi diketuk. Token perangkat ini dihapus saat Keluar (LogoutButton).
Future<void> registerPush() async {
  try {
    final fm = FirebaseMessaging.instance;
    await fm.requestPermission();

    final db = Supabase.instance.client;
    Future<void> save(String token) async {
      if (db.auth.currentUser != null) await db.rpc('register_push_token', params: {'p_token': token});
    }

    final token = await fm.getToken();
    if (token != null) await save(token);
    await _tokenSub?.cancel();
    _tokenSub = fm.onTokenRefresh.listen(save);

    if (_listening) return;
    _listening = true;
    FirebaseMessaging.onMessageOpenedApp.listen(openFromNotification); // aplikasi di latar belakang
    FirebaseMessaging.onMessage.listen(_showInApp); // aplikasi terbuka: Android tidak menampilkan notifikasi
    final initial = await fm.getInitialMessage(); // aplikasi dibuka dari keadaan tertutup
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => openFromNotification(initial));
    }
  } catch (e) {
    debugPrint('registerPush gagal: $e'); // tanpa notifikasi aplikasi tetap jalan
  }
}

/// Keluarga → detail lansia di notifikasi. Yayasan → beranda (dashboard).
Future<void> openFromNotification(RemoteMessage message) async {
  final nav = navigatorKey.currentState;
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (nav == null || uid == null) return;
  final profile = await db.from('profiles').select('role').eq('id', uid).single();
  final elderId = message.data['elder_id'] as String?;
  nav.popUntil((r) => r.isFirst);
  if (profile['role'] == 'keluarga' && elderId != null) {
    nav.push(MaterialPageRoute(builder: (_) => ElderDetailScreen(elderId: elderId)));
  }
}

void _showInApp(RemoteMessage message) {
  final context = navigatorKey.currentContext;
  final n = message.notification;
  if (context == null || n == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 10),
      content: Text('${n.title}\n${n.body ?? ''}'),
      action: SnackBarAction(label: 'Lihat', onPressed: () => openFromNotification(message)),
    ),
  );
}
