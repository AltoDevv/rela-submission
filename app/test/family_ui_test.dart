import 'package:app/keluarga/elder_detail_screen.dart';
import 'package:app/shared/account_profile.dart';
import 'package:app/keluarga/ui.dart';
import 'package:app/shared/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Visit visit(String at, {String vol = 'v1', bool confirmed = true}) => Visit.fromMap({
      'id': at, 'elder_id': 'e1', 'volunteer_id': vol, 'visited_at': at, 'answers': {},
      if (confirmed) 'confirmed_at': at,
    });

void main() {
  test('usia dihitung dari tanggal lahir (belum ulang tahun → kurang satu)', () {
    expect(ageFrom(DateTime(1948, 5, 4), now: DateTime(2026, 5, 3)), 77);
    expect(ageFrom(DateTime(1948, 5, 4), now: DateTime(2026, 5, 4)), 78);
  });

  test('kehadiran: persen minggu (sejak pasangan dimulai) dengan kunjungan relawan ini', () {
    final now = DateTime(2026, 10, 16);
    final paired = now.subtract(const Duration(days: 27)); // 4 minggu
    final visits = [
      visit('2026-10-15T10:00:00'), // minggu ini
      visit('2026-10-14T10:00:00'), // minggu yang sama → tetap 1
      visit('2026-10-01T10:00:00'), // 2 minggu lalu
      visit('2026-10-08T10:00:00', vol: 'lama'), // relawan lain tidak dihitung
      visit('2026-09-25T10:00:00', confirmed: false), // belum dikonfirmasi
    ];
    expect(attendanceForElder(visits, 'v1', paired, now: now), 50);
    expect(attendanceForElder(visits, 'v1', null, now: now), isNull);
  });

  test('ringkasan kunjungan dari kategori yang disebut, maksimal 3', () {
    expect(
      visitSummary({
        'makan': {'level': 0, 'evidence': ''},
        'obat': {'level': null, 'evidence': ''},
        'gerak': {'level': 1, 'evidence': ''},
        'harian': {'level': 0, 'evidence': ''},
        'hati': {'level': 2, 'evidence': ''},
      }),
      'Nafsu makan: Baik · Mobilitas: Pelan atau perlu pegangan · Kemandirian harian: Mandiri',
    );
  });

  testWidgets('pengaturan notifikasi: darurat terkunci, kategori lain bisa dimatikan', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final saved = <Map<String, dynamic>>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FamilyProfileTab(
          load: () async => {'full_name': 'Andi', 'phone': '081234567890', 'notify_off': <String>[]},
          save: (f) async => saved.add(f),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Keluarga Andi'), findsOneWidget);
    await tester.tap(find.text('Pengaturan Notifikasi'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Darurat')).onChanged, isNull);
    await tester.tap(find.byKey(const Key('notif-pengingat')));
    await tester.pumpAndSettle();
    expect(saved.last, {'notify_off': ['pengingat']});
  });

  testWidgets('ulasan relawan: pilih Masalah Serius lalu Kirim', (tester) async {
    final sent = <(String, String)>[];
    var done = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReviewComposer(elderId: 'e1', onSent: () => done++, send: (k, b) async => sent.add((k, b))),
      ),
    ));
    final kirim = find.widgetWithText(FilledButton, 'Kirim');
    expect(tester.widget<FilledButton>(kirim).onPressed, isNull, reason: 'isi kosong');
    await tester.tap(find.text('Masalah Serius'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('isi-ulasan')), 'Relawan meminta uang');
    await tester.pump();
    await tester.tap(kirim);
    await tester.pumpAndSettle();
    expect(sent, [('serius', 'Relawan meminta uang')]);
    expect(done, 1);
  });
}
