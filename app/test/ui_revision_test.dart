import 'package:app/auth/login_screen.dart';
import 'package:app/auth/signup_screen.dart';
import 'package:app/keluarga/history_tab.dart' show DomainChart;
import 'package:app/relawan/home_screen.dart';
import 'package:app/relawan/history_tab.dart';
import 'package:app/relawan/schedule_board.dart';
import 'package:app/relawan/ui.dart';
import 'package:app/shared/models.dart';
import 'package:app/shared/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'relawan_tabs_test.dart' show fakeData, tab;

Elder elder(
  String id,
  String name, {
  String? time,
  DateTime? shift,
  String status = 'disetujui',
  String verifyState = 'terverifikasi',
}) => Elder.fromMap({
  'id': id,
  'family_id': 'f1',
  'full_name': name,
  'address': 'Alamat $name',
  'status': 'stabil',
  'pairing_state': 'berpasangan',
  'verify_state': verifyState,
  if (time != null) ...{
    'schedule_weekday': 5,
    'schedule_time': time,
    'schedule_status': status,
  },
  'schedule_shift_at': shift?.toIso8601String(),
});

Visit visit(
  String id,
  String eid,
  String date,
  int? level, {
  bool confirmed = true,
}) => Visit.fromMap({
  'id': id,
  'elder_id': eid,
  'volunteer_id': 'v1',
  'visited_at': date,
  'answers': {},
  if (confirmed) ...{
    'confirmed_at': date,
    'final_result': {
      'makan': {'level': level, 'evidence': ''},
      'red_flags': [],
    },
  },
});

void main() {
  testWidgets('login baru: validasi, lihat password, dan navigasi daftar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: relaTheme, home: const LoginScreen()),
    );
    expect(
      find.text('Selamat datang kembali. Masuk untuk melanjutkan.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Email tidak valid'), findsOneWidget);
    expect(find.text('Minimal 6 karakter'), findsOneWidget);
    final password = find.byKey(const Key('password'));
    final passwordInput = find.descendant(
      of: password,
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(passwordInput).obscureText, isTrue);
    await tester.tap(find.byTooltip('Tampilkan password'));
    await tester.pump();
    expect(tester.widget<TextField>(passwordInput).obscureText, isFalse);
    await tester.ensureVisible(find.text('Daftar'));
    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();
    expect(find.byType(SignupScreen), findsOneWidget);
    expect(
      find.text(
        'Buat akun untuk mulai mendampingi atau memantau orang tersayang.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'daftar: peran relawan, syarat wajib, dan form bisa digulir di HP kecil',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: relaTheme, home: const SignupScreen()),
      );
      await tester.tap(find.text('Relawan'));
      await tester.pump();
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('peran-relawan')))
            .properties
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('peran-keluarga')))
            .properties
            .selected,
        isFalse,
      );
      await tester.enterText(find.byKey(const Key('nama')), 'Budi');
      await tester.ensureVisible(find.byKey(const Key('telepon')));
      await tester.enterText(find.byKey(const Key('telepon')), '081234567890');
      await tester.ensureVisible(find.byKey(const Key('email')));
      await tester.enterText(
        find.byKey(const Key('email')),
        'budi@example.com',
      );
      await tester.ensureVisible(find.byKey(const Key('password')));
      await tester.enterText(find.byKey(const Key('password')), 'demo1234');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Daftar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Daftar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Setujui Syarat & Persetujuan terlebih dahulu.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'jadwal hari ini: jam urut, usulan diabaikan, geseran mengganti slot',
    () {
      final now = DateTime(2026, 10, 16, 11);
      final entries = todaySchedule([
        elder('b', 'Pak B', time: '15:30:00'),
        elder('a', 'Ibu A', time: '10:00:00'),
        elder('c', 'Usulan', time: '09:00:00', status: 'diusulkan'),
        elder('d', 'Tanpa jadwal'),
        elder(
          'e',
          'Digeser besok',
          time: '12:00:00',
          shift: DateTime(2026, 10, 17, 12),
        ),
        elder(
          'f',
          'Digeser hari ini',
          time: '13:00:00',
          shift: DateTime(2026, 10, 16, 8),
        ),
      ], now);
      expect(entries.map((s) => s.elder.id), ['f', 'a', 'b']);
      expect(entries.map((s) => s.at.hour), [8, 10, 15]);
    },
  );

  testWidgets(
    'dropdown Lansia/Riwayat tetap memilih lansia yang sama; grafik sesuai pilihannya',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final d = fakeData();
      final elders = [elder('e1', 'Ibu Sri'), elder('e2', 'Pak Harto')];
      await tester.pumpWidget(
        MaterialApp(
          theme: relaTheme,
          home: RelawanHomeScreen(
            load: () async => RelawanData(
              volunteer: d.volunteer,
              elders: elders,
              visits: {
                'e1': [visit('a', 'e1', '2026-10-01T10:00:00', 0)],
                'e2': [visit('b', 'e2', '2026-10-02T10:00:00', 3)],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tab(tester, 'Lansia');
      await tester.tap(find.byKey(const Key('pilih-lansia')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pak Harto').last);
      await tester.pumpAndSettle();
      expect(find.text('Alamat Pak Harto'), findsOneWidget);
      await tab(tester, 'Riwayat');
      expect(find.text('2 Okt 2026 · Tanpa tanda bahaya'), findsOneWidget);
      expect(find.text('1 Okt 2026 · Tanpa tanda bahaya'), findsNothing);
      await tester.ensureVisible(find.byType(DomainChart));
      expect(tester.widget<DomainChart>(find.byType(DomainChart)).levels, [3]);
      await tester.tap(find.byKey(const Key('kategori')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobilitas').last);
      await tester.pumpAndSettle();
      expect(tester.widget<DomainChart>(find.byType(DomainChart)).levels, [
        null,
      ]);
    },
  );

  testWidgets(
    'grafik di bawah riwayat: kronologis, null kosong, draf diabaikan',
    (tester) async {
      final d = fakeData();
      final visits = [
        visit('baru', 'e1', '2026-10-03T10:00:00', 2),
        visit('draf', 'e1', '2026-10-04T10:00:00', 0, confirmed: false),
        visit('lama', 'e1', '2026-10-01T10:00:00', 0),
        visit('kosong', 'e1', '2026-10-02T10:00:00', null),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: relaTheme,
          home: Scaffold(
            body: HistoryTab(
              data: RelawanData(
                volunteer: d.volunteer,
                elders: d.elders,
                visits: {'e1': visits},
              ),
              elder: d.elders.first,
              onPick: (_) {},
              onOpen: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byType(DomainChart), 250);
      final chart = tester.widget<DomainChart>(find.byType(DomainChart));
      expect(chart.visits.map((v) => v.id), ['lama', 'kosong', 'baru']);
      expect(chart.levels, [0, null, 2]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'jadwal beranda: progres asli dan aksi tetap mengikuti kunjungan berikutnya',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final d = fakeData();
      await tester.pumpWidget(
        MaterialApp(
          theme: relaTheme,
          home: RelawanHomeScreen(
            now: DateTime(2026, 10, 16, 9),
            load: () async => RelawanData(
              volunteer: d.volunteer,
              elders: [
                elder('e1', 'Ibu Sri', time: '08:00:00'),
                elder(
                  'e2',
                  'Pak Harto',
                  time: '15:30:00',
                  verifyState: 'menunggu',
                ),
              ],
              visits: {
                'e1': [visit('sri', 'e1', '2026-10-16T08:00:00', 0)],
                'e2': [visit('harto', 'e2', '2026-10-12T10:00:00', 2)],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Kunjungan 2 dari 2 · berikutnya pukul 15.30',
          findRichText: true,
        ),
        findsOneWidget,
      );
      final rekap = find.widgetWithText(FilledButton, 'Rekap Kunjungan');
      await tester.ensureVisible(rekap);
      expect(
        tester.widget<FilledButton>(rekap).onPressed,
        isNull,
        reason: 'Pak Harto belum diverifikasi',
      );
      await tester.ensureVisible(find.text('Ibu Sri'));
      await tester.tap(find.text('Ibu Sri'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(rekap);
      expect(tester.widget<FilledButton>(rekap).onPressed, isNull);
      await tester.ensureVisible(find.text('Lihat semua ›'));
      await tester.tap(find.text('Lihat semua ›'));
      await tester.pumpAndSettle();
      expect(find.text('12 Okt 2026 · Tanpa tanda bahaya'), findsOneWidget);
      expect(find.text('16 Okt 2026 · Tanpa tanda bahaya'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tanpa pasangan: pesan kosong dan navbar tetap tersedia', (
    tester,
  ) async {
    final d = fakeData();
    await tester.pumpWidget(
      MaterialApp(
        theme: relaTheme,
        home: RelawanHomeScreen(
          load: () async => RelawanData(volunteer: d.volunteer),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Belum ada jadwal kunjungan hari ini.'), findsOneWidget);
    expect(find.text('Rekap Kunjungan'), findsNothing);
    await tab(tester, 'Riwayat');
    expect(find.text('Belum ada lansia pasangan.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
