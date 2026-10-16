import 'package:app/keluarga/home_screen.dart';
import 'package:app/keluarga/register_elder_screen.dart';
import 'package:app/main.dart';
import 'package:app/relawan/home_screen.dart';
import 'package:app/relawan/join_screen.dart';
import 'package:app/yayasan/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpHome(WidgetTester tester, String role, {bool volunteerJoined = true}) {
  return tester.pumpWidget(MaterialApp(home: homeFor(role, volunteerJoined: volunteerJoined)));
}

/// Ketuk tombol berlabel [label], pastikan layar stub terbuka, lalu kembali.
Future<void> opensStub(WidgetTester tester, String label, String title) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  expect(find.text(title), findsOneWidget, reason: '$label → $title');
  expect(find.text('Belum dibuat'), findsWidgets);
}

Future<void> back(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}

void main() {
  group('beranda sesuai profiles.role', () {
    testWidgets('keluarga → beranda keluarga', (tester) async {
      await pumpHome(tester, 'keluarga');
      expect(find.byType(KeluargaHomeScreen), findsOneWidget);
    });

    testWidgets('relawan yang sudah bergabung → beranda relawan', (tester) async {
      await pumpHome(tester, 'relawan');
      expect(find.byType(RelawanHomeScreen), findsOneWidget);
    });

    testWidgets('relawan yang belum bergabung ke yayasan → JoinScreen', (tester) async {
      await pumpHome(tester, 'relawan', volunteerJoined: false);
      expect(find.byType(JoinScreen), findsOneWidget);
      expect(find.byType(RelawanHomeScreen), findsNothing);
    });

    testWidgets('yayasan → beranda yayasan', (tester) async {
      await pumpHome(tester, 'yayasan');
      expect(find.byType(YayasanHomeScreen), findsOneWidget);
    });

    testWidgets('peran tidak dikenal → pesan, bukan beranda mana pun', (tester) async {
      await pumpHome(tester, 'admin');
      expect(find.textContaining('Peran tidak dikenal'), findsOneWidget);
    });
  });

  group('semua stub bisa dibuka dari beranda', () {
    testWidgets('keluarga', (tester) async {
      // Daftar lansia dimuat Realtime dari Supabase (tidak ada di test): beranda tidak crash, navbar 3 tab tampil,
      // dan tombol Daftar Lansia membuka form.
      await pumpHome(tester, 'keluarga');
      await tester.pumpAndSettle();
      expect(find.text('Gagal memuat daftar lansia'), findsOneWidget);
      for (final tab in ['Beranda', 'Riwayat', 'Profil']) {
        expect(find.text(tab), findsOneWidget);
      }
      await tester.tap(find.text('Daftar Lansia'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterElderScreen), findsOneWidget);
    });

    testWidgets('relawan', (tester) async {
      // Data relawan dimuat dari Supabase (tidak ada di test) → pesan gagal, navbar 4 tab tetap tampil.
      // Isi tiap tab diuji di relawan_tabs_test.dart.
      await pumpHome(tester, 'relawan');
      await tester.pumpAndSettle();
      expect(find.textContaining('Gagal memuat data relawan'), findsOneWidget);
      for (final tab in ['Beranda', 'Lansia', 'Riwayat', 'Profil']) {
        expect(find.text(tab), findsOneWidget);
      }
    });

    testWidgets('yayasan', (tester) async {
      // Data yayasan dimuat dari Supabase (tidak ada di test) → pesan gagal, navbar 4 tab tetap tampil.
      // Isi tiap tab diuji di yayasan_tabs_test.dart.
      await pumpHome(tester, 'yayasan');
      await tester.pumpAndSettle();
      expect(find.textContaining('Gagal memuat data yayasan'), findsOneWidget);
      for (final tab in ['Beranda', 'Relawan', 'Ulasan', 'Profil']) {
        expect(find.text(tab), findsOneWidget);
      }
    });

    testWidgets('JoinScreen menampilkan kode undangan dari tautan', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: JoinScreen(code: 'SENJA1')));
      expect(find.textContaining('SENJA1'), findsOneWidget);
    });
  });
}
