import 'dart:async';

import 'package:app/main.dart';
import 'package:app/relawan/home_screen.dart';
import 'package:app/relawan/join_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// JoinScreen dengan OTP tetap, kamera palsu, dan submit yang mencatat data (tidak pernah selesai,
/// supaya layar tidak berpindah ke beranda yang butuh Supabase).
Future<List<JoinData>> pumpJoin(WidgetTester tester, {String? code, Object? submitError}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  pendingInviteCode = null; // global: jangan bocor dari test sebelumnya
  final sent = <JoinData>[];
  await tester.pumpWidget(MaterialApp(
    home: JoinScreen(
      code: code,
      otp: '123456',
      takePhoto: () async => XFile('/tmp/wajah.jpg'),
      pickLocation: (_, _, _) async => (-7.78, 110.37),
      search: (_) async => [(id: 'f1', name: 'Yayasan Demo')],
      resolveCode: (c) async => c.toUpperCase() == 'SENJA1' ? (id: 'f1', name: 'Yayasan Demo') : (id: 'fx', name: 'Yayasan X'),
      submit: (d) {
        sent.add(d);
        if (submitError != null) throw submitError;
        return Completer<void>().future;
      },
    ),
  ));
  return sent;
}

Future<void> passOtp(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('otp')), '123456');
  await tester.tap(find.text('Verifikasi'));
  await tester.pump();
}

Future<void> fillForm(WidgetTester tester, {bool photo = true}) async {
  await tester.enterText(find.byKey(const Key('nama')), 'Rina Relawan');
  await tester.enterText(find.byKey(const Key('tanggal-lahir')), '17/08/2001');
  await tester.enterText(find.byKey(const Key('area')), 'Kotabaru, Yogyakarta');
  await tester.tap(find.text('Selasa'));
  await tester.tap(find.text('Jawa'));
  await tester.tap(find.text('Mendampingi lansia dengan demensia'));
  if (photo) await tester.tap(find.text('Ambil foto wajah (kamera)'));
  await tester.pump();
}

void main() {
  testWidgets('relawan yang belum bergabung selalu mendapat JoinScreen, bukan beranda', (tester) async {
    await tester.pumpWidget(MaterialApp(home: homeFor('relawan', volunteerJoined: false)));
    expect(find.byType(JoinScreen), findsOneWidget);
    expect(find.byType(RelawanHomeScreen), findsNothing);
    // Tidak ada jalan ke fitur lain selain keluar.
    expect(find.byType(BackButton), findsNothing);
  });

  group('OTP simulasi', () {
    testWidgets('kode 6 digit tampil di layar', (tester) async {
      await pumpJoin(tester);
      expect(find.textContaining('123456'), findsOneWidget);
      expect(find.byKey(const Key('nama')), findsNothing); // form belum terbuka
    });

    testWidgets('kode salah ditolak, form tidak terbuka', (tester) async {
      await pumpJoin(tester);
      await tester.enterText(find.byKey(const Key('otp')), '654321');
      await tester.tap(find.text('Verifikasi'));
      await tester.pump();
      expect(find.text('Kode OTP salah'), findsOneWidget);
      expect(find.byKey(const Key('nama')), findsNothing);
    });

    testWidgets('kode benar membuka form', (tester) async {
      await pumpJoin(tester);
      await passOtp(tester);
      expect(find.byKey(const Key('nama')), findsOneWidget);
    });

    test('OTP acak selalu 6 digit', () {
      for (var i = 0; i < 50; i++) {
        expect(generateOtp(), matches(RegExp(r'^\d{6}$')));
      }
    });
  });

  group('form profil', () {
    testWidgets('kosong → semua pesan wajib muncul, tidak dikirim', (tester) async {
      final sent = await pumpJoin(tester);
      await passOtp(tester);
      await tester.tap(find.text('Gabung'));
      await tester.pump();
      expect(find.text('Wajib diisi'), findsNWidgets(2)); // nama, area
      expect(find.text('Pilih yayasan dulu'), findsOneWidget);
      expect(find.text('Pilih minimal satu hari'), findsOneWidget);
      expect(find.text('Pilih minimal satu bahasa'), findsOneWidget);
      expect(find.text('Foto wajah wajib diambil dari kamera'), findsOneWidget);
      expect(sent, isEmpty);
    });

    testWidgets('yayasan dari tautan terpilih otomatis dan data lengkap terkirim', (tester) async {
      final sent = await pumpJoin(tester, code: 'senja1');
      await passOtp(tester);
      await fillForm(tester);
      await tester.tap(find.text('Gabung'));
      await tester.pump();
      expect(sent, hasLength(1));
      final d = sent.single;
      expect(d.foundationId, 'f1', reason: 'tautan undangan memilihkan yayasannya');
      expect(d.fullName, 'Rina Relawan');
      expect(d.area, 'Kotabaru, Yogyakarta');
      expect((d.lat, d.lng), (-7.78, 110.37));
      expect(d.days, ['selasa']);
      expect(d.languages, ['jawa']);
      expect(d.canDementia, isTrue);
      expect(d.canMobility, isFalse);
      expect(d.photo.path, '/tmp/wajah.jpg');
    });

    testWidgets('tanpa tautan: relawan memilih yayasan dari daftar', (tester) async {
      final sent = await pumpJoin(tester);
      await passOtp(tester);
      await fillForm(tester);
      await tester.tap(find.text('Pilih'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yayasan Demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gabung'));
      await tester.pump();
      expect(sent.single.foundationId, 'f1');
    });

    testWidgets('tanpa foto tidak dikirim', (tester) async {
      final sent = await pumpJoin(tester, code: 'SENJA1');
      await passOtp(tester);
      await fillForm(tester, photo: false);
      await tester.tap(find.text('Gabung'));
      await tester.pump();
      expect(find.text('Foto wajah wajib diambil dari kamera'), findsOneWidget);
      expect(sent, isEmpty);
    });

    testWidgets('error dari server (kode tidak dikenal) ditampilkan', (tester) async {
      await pumpJoin(tester, code: 'XXXXXX', submitError: const PostgrestException(message: 'Kode undangan tidak dikenal'));
      await passOtp(tester);
      await fillForm(tester);
      await tester.tap(find.text('Gabung'));
      await tester.pump();
      expect(find.text('Kode undangan tidak dikenal'), findsOneWidget);
    });
  });
}
