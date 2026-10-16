import 'package:app/shared/models.dart';
import 'package:app/shared/notifications.dart';
import 'package:app/shared/schedule_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Elder elder(String? status, {String? shift}) => Elder.fromMap({
      'id': 'e1', 'family_id': 'k1', 'full_name': 'Ibu Sri', 'address': 'x', 'pairing_state': 'berpasangan',
      'status': 'stabil', 'volunteer_id': 'v1',
      if (status != null) ...{'schedule_weekday': 3, 'schedule_time': '10:00:00', 'schedule_status': status},
      'schedule_shift_at': shift,
    });

void main() {
  testWidgets('lonceng: jumlah belum dibaca, panel dari atas, ditandai dibaca saat dibuka', (tester) async {
    var opened = 0;
    final now = DateTime.now().toUtc().toIso8601String();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: NotificationBell(
            stream: Stream.value([
              {'id': 'n1', 'title': 'Usulan relawan baru untuk Ibu Sri', 'body': 'Buka aplikasi', 'data': {'type': 'usulan'},
               'created_at': now, 'read_at': null},
              {'id': 'n2', 'title': 'Besok kunjungan Ibu Sri', 'body': 'Pukul 10.00', 'data': {'type': 'jadwal'},
               'created_at': now, 'read_at': null},
              {'id': 'n3', 'title': 'Lama', 'body': 'x', 'data': {}, 'created_at': now, 'read_at': now},
            ]),
            onOpened: () async => opened++,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('lonceng')));
    await tester.pumpAndSettle();
    expect(find.text('Notifikasi'), findsOneWidget);
    expect(find.text('Usulan relawan baru untuk Ibu Sri'), findsOneWidget);
    expect(find.text('Besok kunjungan Ibu Sri'), findsOneWidget);
    expect(opened, 1);
  });

  testWidgets('keluarga: usulan jadwal → Setuju mengirim jawaban', (tester) async {
    final answers = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: FamilyScheduleCard(elder: elder('diusulkan'), answer: (a) async {
        answers.add(a);
        return 'ok';
      })),
    ));
    expect(find.text('Relawan mengusulkan kunjungan rutin tiap Rabu 10.00.'), findsOneWidget);
    await tester.tap(find.text('Setuju'));
    await tester.pumpAndSettle();
    expect(answers, [true]);
  });

  testWidgets('keluarga: jadwal disetujui menampilkan kunjungan berikutnya; relawan bisa geser', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [
      FamilyScheduleCard(elder: elder('disetujui')),
      VolunteerScheduleRow(elder: elder('disetujui'), availableDays: const ['rabu'], onDone: () {}),
      VolunteerScheduleRow(elder: elder(null), availableDays: const ['rabu'], onDone: () {}),
    ]))));
    expect(find.text('Tiap Rabu 10.00'), findsOneWidget);
    expect(find.textContaining('Kunjungan berikutnya: Rab'), findsOneWidget);
    expect(find.text('Geser kunjungan'), findsOneWidget);
    expect(find.text('Atur jadwal'), findsOneWidget);
    expect(find.text('Belum ada jadwal kunjungan rutin.'), findsOneWidget);
  });
}
