import 'package:app/shared/models.dart';
import 'package:app/yayasan/data.dart';
import 'package:app/yayasan/home_screen.dart';
import 'package:app/yayasan/reviews_screen.dart';
import 'package:app/yayasan/volunteer_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.now();
String ago(int days) => now.subtract(Duration(days: days)).toUtc().toIso8601String();

Elder elder(String id, String vol, {int pairedDaysAgo = 30}) => Elder.fromMap({
      'id': id, 'family_id': 'k', 'full_name': id == 'e1' ? 'Ibu Sri' : 'Pak Harto', 'address': 'Kalideres',
      'pairing_state': 'berpasangan', 'status': 'stabil', 'volunteer_id': vol, 'has_dementia': true,
      'paired_at': ago(pairedDaysAgo),
    });

Volunteer vol(String id, {String status = 'aktif', String? note, DateTime? resign}) => Volunteer.fromMap({
      'id': id, 'foundation_id': 'y1', 'status': status, 'area_label': 'Depok', 'available_days': ['rabu', 'sabtu'],
      'can_dementia': true, 'max_load': 2, 'status_note': note, 'oriented_at': status == 'aktif' ? ago(60) : null,
      'resign_reason': resign == null ? null : 'Kesibukan baru', 'resign_requested_at': resign?.toIso8601String(),
    });

YayasanData fake() => YayasanData(
      foundation: 'Sinar Sejahtera',
      dash: {
        'elders': [
          {'id': 'e1', 'full_name': 'Ibu Sri', 'status': 'stabil', 'pairing_state': 'berpasangan', 'last_visit_at': ago(2)},
          {'id': 'e2', 'full_name': 'Pak Harto', 'status': 'stabil', 'pairing_state': 'berpasangan', 'last_visit_at': ago(10),
           'stop_request': {'id': 's1', 'reason': 'Mengundurkan diri: Kesibukan baru'}},
          {'id': 'e3', 'full_name': 'Mbah Darmi', 'status': 'stabil', 'pairing_state': 'perlu_yayasan'},
        ],
        'counts': {},
        'volunteers': [
          {'id': 'v1', 'full_name': 'Budi Santoso', 'status': 'aktif', 'max_load': 2, 'load': 1},
          {'id': 'v2', 'full_name': 'Rini Kusuma', 'status': 'aktif', 'max_load': 2, 'load': 1},
          {'id': 'v3', 'full_name': 'Agus Prasetyo', 'status': 'terdaftar', 'max_load': 2, 'load': 0},
        ],
      },
      volunteers: [vol('v1'), vol('v2', resign: DateTime(2026, 10, 15)), vol('v3', status: 'terdaftar')],
      elders: [elder('e1', 'v1'), elder('e2', 'v2')],
      weekVisits: [now],
      reviews: [
        {'id': 'r1', 'volunteer_id': 'v1', 'elder_id': 'e1', 'kind': 'serius', 'body': 'Kasar', 'created_at': ago(1)},
        {'id': 'r2', 'volunteer_id': 'v1', 'elder_id': 'e1', 'kind': 'apresiasi', 'body': 'Sabar sekali', 'created_at': ago(2)},
      ],
      authors: {'r1': 'Rina', 'r2': 'Dedi Kurnia'},
    );

Future<void> tall(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('aturan ringkasan', () {
    test('terlewat: >7 hari sejak kunjungan terakhir, atau sejak mulai didampingi bila belum pernah', () {
      final e = elder('e1', 'v1', pairedDaysAgo: 30);
      expect(isMissed(e, now.subtract(const Duration(days: 2)), now), isFalse);
      expect(isMissed(e, now.subtract(const Duration(days: 10)), now), isTrue);
      expect(isMissed(e, null, now), isTrue);
      expect(isMissed(elder('e1', 'v1', pairedDaysAgo: 3), null, now), isFalse, reason: 'baru dipasangkan');
    });

    test('terlewat dengan jadwal rutin: slot yang lewat tanpa kunjungan', () {
      final now = DateTime(2026, 10, 16, 9); // Jumat
      Elder sched(String? shift) => Elder.fromMap({
            'id': 'e1', 'family_id': 'k', 'full_name': 'Ibu Sri', 'address': 'x', 'pairing_state': 'berpasangan',
            'status': 'stabil', 'volunteer_id': 'v1', 'paired_at': '2026-09-01T00:00:00Z',
            'schedule_weekday': 3, 'schedule_time': '10:00:00', 'schedule_status': 'disetujui', 'schedule_shift_at': shift,
          });
      expect(isMissed(sched(null), DateTime(2026, 10, 14, 11), now), isFalse, reason: 'dikunjungi Rabu');
      expect(isMissed(sched(null), DateTime(2026, 10, 13, 11), now), isFalse, reason: 'sehari lebih awal boleh');
      expect(isMissed(sched(null), DateTime(2026, 10, 8, 11), now), isTrue, reason: 'Rabu 14 terlewat');
      expect(isMissed(sched('2026-10-15T08:00:00Z'), DateTime(2026, 10, 8, 11), now), isFalse,
          reason: 'digeser ke Kamis sore, belum lewat sehari');
    });

    test('persen terlaksana dan kunjungan per hari Senin–Minggu', () {
      final elders = [elder('e1', 'v1'), elder('e2', 'v1')];
      final last = {'e1': now.subtract(const Duration(days: 1)), 'e2': now.subtract(const Duration(days: 9))};
      expect(visitedPercent(elders, (id) => last[id], now), 50);
      expect(visitedPercent(const [], (_) => null, now), isNull);
      final monday = weekStart(now);
      expect(visitsPerDay([monday, monday.add(const Duration(hours: 3)), monday.add(const Duration(days: 6))], now),
          [2, 0, 0, 0, 0, 0, 1]);
    });

    test('status relawan: pengunduran > nonaktif > belum verifikasi > penuh/tersedia', () {
      expect(volunteerState(vol('a', resign: now), 0), VolunteerState.mundur);
      expect(volunteerState(vol('a', status: 'terdaftar', note: 'Dinonaktifkan yayasan: x'), 0), VolunteerState.nonaktif);
      expect(volunteerState(vol('a', status: 'terdaftar'), 0), VolunteerState.belum);
      expect(volunteerState(vol('a'), 2), VolunteerState.penuh);
      expect(volunteerState(vol('a'), 1), VolunteerState.tersedia);
    });
  });

  testWidgets('Beranda → Relawan → Ulasan sesuai Figma', (tester) async {
    await tall(tester);
    await tester.pumpWidget(MaterialApp(home: YayasanHomeScreen(load: () async => fake())));
    await tester.pumpAndSettle();
    expect(find.text('Sinar Sejahtera'), findsOneWidget);
    expect(find.text('1 lansia terkunjungi · 1 terlewat'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('aktif dari 3 terdaftar'), findsOneWidget);
    expect(find.text('Relawan menunggu verifikasi'), findsOneWidget);
    expect(find.text('Relawan mengundurkan diri'), findsOneWidget);
    expect(find.text('Lansia perlu dipasangkan'), findsOneWidget);
    expect(find.text('Lansia · Pak Harto'), findsOneWidget, reason: 'kunjungan terlewat');

    // Perlu Perhatian → tab Relawan dengan filter Undur Diri
    await tester.tap(find.text('Relawan mengundurkan diri'));
    await tester.pumpAndSettle();
    expect(find.text('Rini Kusuma'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsNothing);
    expect(find.text('Pengunduran'), findsOneWidget);

    await tester.tap(find.text('Semua (3)'));
    await tester.pumpAndSettle();
    expect(find.text('Belum verifikasi'), findsOneWidget);
    expect(find.text('Tersedia'), findsOneWidget);

    // Ulasan: Tangani hanya untuk masalah serius
    await tester.tap(find.widgetWithText(NavigationDestination, 'Ulasan'));
    await tester.pumpAndSettle();
    expect(find.text('Rina'), findsOneWidget);
    expect(find.text('Tangani'), findsOneWidget);
  });

  testWidgets('Tangani masalah serius mengirim catatan', (tester) async {
    await tall(tester);
    final handled = <(String, String)>[];
    var reloaded = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReviewsTab(data: fake(), header: const SizedBox(), onChanged: () => reloaded++,
            handle: (i, n) async => handled.add((i, n))),
      ),
    ));
    await tester.tap(find.text('Tangani'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('catatan-tindak-lanjut')), 'Relawan dinonaktifkan');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(handled, [('r1', 'Relawan dinonaktifkan')]);
    expect(reloaded, 1);
  });

  testWidgets('pengunduran diri: popup alasan, Terima menonaktifkan (tanpa Tolak)', (tester) async {
    await tall(tester);
    final calls = <(String, String)>[];
    await tester.pumpWidget(MaterialApp(
      home: VolunteerProfileScreen(data: fake(), volunteerId: 'v2', deactivate: (id, r) async => calls.add((id, r))),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Berhenti mendampingi: Mengundurkan diri'), findsOneWidget);
    await tester.tap(find.text('Rini Kusuma mengajukan pengunduran diri'));
    await tester.pumpAndSettle();
    expect(find.text('Kesibukan baru'), findsOneWidget);
    expect(find.text('Tolak'), findsNothing);
    await tester.tap(find.text('Terima'));
    await tester.pumpAndSettle();
    expect(calls, [('v2', 'Pengunduran diri diterima: Kesibukan baru')]);
  });

  testWidgets('relawan belum terverifikasi: Verifikasi aktif setelah identitas & orientasi dicentang', (tester) async {
    await tall(tester);
    await tester.pumpWidget(MaterialApp(home: VolunteerProfileScreen(data: fake(), volunteerId: 'v3')));
    await tester.pumpAndSettle();
    final verify = find.widgetWithText(FilledButton, 'Verifikasi');
    expect(tester.widget<FilledButton>(verify).onPressed, isNull);
    for (final key in ['cek-identitas', 'cek-orientasi']) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      var i = 0;
      while (find.byKey(Key('butir-$i')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(Key('butir-$i')));
        i++;
      }
      await tester.pump();
      await tester.tap(find.text('Simpan centang'));
      await tester.pumpAndSettle();
    }
    expect(tester.widget<FilledButton>(verify).onPressed, isNotNull);
  });
}
