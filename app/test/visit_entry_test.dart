import 'package:app/relawan/home_screen.dart';
import 'package:app/relawan/ui.dart';
import 'package:app/relawan/visit_entry.dart';
import 'package:app/relawan/visit_story_screen.dart';
import 'package:app/shared/account_profile.dart';
import 'package:app/shared/models.dart';
import 'package:app/shared/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'relawan_tabs_test.dart' show fakeData, tab;

Elder paired(String id, {bool verified = true, bool scheduled = false}) =>
    Elder.fromMap({
      'id': id,
      'family_id': 'f1',
      'full_name': 'Lansia $id',
      'address': 'Alamat $id',
      'status': 'stabil',
      'pairing_state': 'berpasangan',
      'verify_state': verified ? 'terverifikasi' : 'menunggu',
      'first_visit_at': '2026-10-01T08:00:00',
      if (scheduled) ...{
        'schedule_weekday': 5,
        'schedule_time': '10:00:00',
        'schedule_status': 'disetujui',
      },
    });

void main() {
  testWidgets(
    'jalur langsung membuka form dengan ID dan nama lansia yang benar',
    (tester) async {
      final a = paired('a');
      final b = paired('b');
      await tester.pumpWidget(
        MaterialApp(
          theme: relaTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    startVisitEntry(context, elders: [a, b], current: b),
                child: const Text('Rekap'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Rekap'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<VisitStoryScreen>(find.byType(VisitStoryScreen)).elderId,
        'b',
      );
      expect(find.text('Kunjungan untuk Lansia b'), findsOneWidget);
      expect(find.text('Rekap kunjungan untuk siapa?'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profil keluarga terbuka: jarak form cukup dan Simpan tetap bekerja',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saved = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: relaTheme,
          home: Scaffold(
            body: FamilyProfileTab(
              load: () async => {'full_name': 'Andi', 'phone': '081234567890'},
              save: (f) async => saved.add(f),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kelola Akun'));
      await tester.pumpAndSettle();
      final header = find
          .descendant(
            of: find.widgetWithText(ExpansionTile, 'Kelola Akun'),
            matching: find.byType(ListTile),
          )
          .first;
      final name = find.byKey(const Key('akun-nama'));
      final phone = find.byKey(const Key('akun-hp'));
      expect(
        tester.getTopLeft(name).dy - tester.getBottomLeft(header).dy,
        greaterThanOrEqualTo(16),
      );
      expect(
        tester.getTopLeft(phone).dy - tester.getBottomLeft(name).dy,
        greaterThanOrEqualTo(12),
      );
      await tester.enterText(name, 'Andi Baru');
      await tester.enterText(phone, '081234567891');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Simpan'));
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(saved.single, {'full_name': 'Andi Baru', 'phone': '081234567891'});
      expect(tester.takeException(), isNull);
    },
  );

  Future<void> pumpEntry(
    WidgetTester tester,
    List<Elder> elders,
    List<String> started, {
    Elder? current,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: relaTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => startVisitEntry(
                context,
                elders: elders,
                current: current,
                onStart: (e) async => started.add(e.id),
              ),
              child: const Text('Rekap'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Rekap'));
    await tester.pumpAndSettle();
  }

  testWidgets('rekap umum memilih lansia sebelum membuka form', (tester) async {
    final started = <String>[];
    await pumpEntry(tester, [paired('a'), paired('b')], started);
    expect(find.text('Rekap kunjungan untuk siapa?'), findsOneWidget);
    expect(started, isEmpty);
    await tester.tap(find.text('Lansia b'));
    await tester.pumpAndSettle();
    expect(started, ['b']);
    expect(find.text('Rekap kunjungan untuk siapa?'), findsNothing);
  });

  testWidgets('batal dan lansia belum diverifikasi tidak memulai rekap', (
    tester,
  ) async {
    final started = <String>[];
    await pumpEntry(tester, [
      paired('a'),
      paired('b', verified: false),
    ], started);
    await tester.tap(find.text('Lansia b'));
    await tester.pumpAndSettle();
    expect(started, isEmpty);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(started, isEmpty);
    expect(find.text('Rekap kunjungan untuk siapa?'), findsNothing);
  });

  testWidgets('satu pasangan langsung membuka rekap', (tester) async {
    final started = <String>[];
    await pumpEntry(tester, [paired('a')], started);
    expect(started, ['a']);
    expect(find.text('Rekap kunjungan untuk siapa?'), findsNothing);
  });

  testWidgets('satu pasangan belum diverifikasi tidak membuka rekap', (
    tester,
  ) async {
    final started = <String>[];
    await pumpEntry(tester, [paired('a', verified: false)], started);
    expect(started, isEmpty);
    expect(
      find.text(
        'Tunggu verifikasi keluarga oleh yayasan sebelum mencatat kunjungan.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'tombol rekap Riwayat membuka pemilih walau sudah ada lansia terpilih',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final d = fakeData();
      final started = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: relaTheme,
          home: RelawanHomeScreen(
            load: () async => RelawanData(
              volunteer: d.volunteer,
              elders: [paired('a'), paired('b')],
            ),
            onStartVisit: (e) async => started.add(e.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tab(tester, 'Riwayat');
      await tester.tap(find.widgetWithText(FilledButton, 'Rekap Kunjungan'));
      await tester.pumpAndSettle();
      expect(find.text('Rekap kunjungan untuk siapa?'), findsOneWidget);
      expect(started, isEmpty);
      final sheet = find.byType(BottomSheet);
      await tester.tap(
        find.descendant(of: sheet, matching: find.text('Lansia b')),
      );
      await tester.pumpAndSettle();
      expect(started, ['b']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rekap Beranda langsung memakai kartu aktif walau tab lain memilih lansia lain',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final d = fakeData();
      final started = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: relaTheme,
          home: RelawanHomeScreen(
            now: DateTime(2026, 10, 16, 9),
            load: () async => RelawanData(
              volunteer: d.volunteer,
              elders: [paired('a', scheduled: true), paired('b')],
            ),
            onStartVisit: (e) async => started.add(e.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tab(tester, 'Lansia');
      await tester.tap(find.byKey(const Key('pilih-lansia')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lansia b').last);
      await tester.pumpAndSettle();
      await tab(tester, 'Beranda');
      final rekap = find.widgetWithText(FilledButton, 'Rekap Kunjungan');
      await tester.ensureVisible(rekap);
      await tester.tap(rekap);
      await tester.pumpAndSettle();
      expect(started, ['a']);
      expect(find.text('Rekap kunjungan untuk siapa?'), findsNothing);
    },
  );
}
