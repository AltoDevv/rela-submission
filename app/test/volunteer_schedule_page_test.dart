import 'package:app/relawan/home_screen.dart';
import 'package:app/relawan/schedule_board.dart';
import 'package:app/relawan/ui.dart';
import 'package:app/shared/schedule_widgets.dart';
import 'package:app/shared/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'relawan_tabs_test.dart' show fakeData, tab;
import 'ui_revision_test.dart' show elder, visit;

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  test('kunjungan selesai lebih awal dilewati, draf dan keterlambatan tetap menunggu', () {
    final d = fakeData();
    final now = DateTime(2026, 10, 16, 9);
    RelawanData data({bool draft = false}) => RelawanData(
      volunteer: d.volunteer,
      elders: [
        elder('a', 'Sudah selesai', time: '10:00:00'),
        elder('b', 'Besok', time: '08:00:00', shift: DateTime(2026, 10, 17, 8)),
      ],
      visits: {
        'a': [visit('v', 'a', '2026-10-16T08:00:00', 0, confirmed: !draft)],
      },
    );
    expect(nextScheduledVisit(data(), now)?.elder.id, 'b');
    expect(nextScheduledVisit(data(draft: true), now)?.elder.id, 'a');
    expect(
      nextScheduledVisit(
        data(draft: true),
        DateTime(2026, 10, 16, 12),
      )?.elder.id,
      'a',
    );
    final allDone = RelawanData(
      volunteer: d.volunteer,
      elders: [elder('a', 'Selesai', time: '10:00:00')],
      visits: data().visits,
    );
    expect(nextScheduledVisit(allDone, now)?.at, DateTime(2026, 10, 23, 10));
  });

  testWidgets('Atur dan Geser mengirim lansia pilihan lalu jadwal diperbarui', (
    tester,
  ) async {
    phone(tester);
    final d = fakeData();
    var b = elder('b', 'Pak B');
    var loads = 0;
    final sent = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: relaTheme,
        home: RelawanHomeScreen(
          now: DateTime(2026, 10, 16, 9),
          load: () async {
            loads++;
            return RelawanData(
              volunteer: d.volunteer,
              elders: [
                elder('a', 'Ibu A', time: '12:00:00'),
                b,
              ],
            );
          },
          scheduleSubmit: (body, done) async {
            sent.add(body);
            b = elder(
              'b',
              'Pak B',
              time: '10:00:00',
              shift: body['action'] == 'schedule_shift'
                  ? DateTime.parse(body['at']).toLocal()
                  : null,
            );
            return done;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tab(tester, 'Lansia');
    await tester.tap(find.byKey(const Key('pilih-lansia')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pak B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atur jadwal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hari-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim usulan'));
    await tester.pumpAndSettle();
    expect(sent.single, {
      'action': 'schedule_propose',
      'elder_id': 'b',
      'weekday': 5,
      'time': '10:00',
    });
    expect(loads, 2);
    expect(find.textContaining('Jadwal: tiap Jumat 10.00'), findsOneWidget);
    expect(
      tester
          .widget<VolunteerScheduleRow>(find.byType(VolunteerScheduleRow))
          .elder
          .id,
      'b',
    );
    await tester.tap(find.text('Geser kunjungan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('17').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(sent.last['action'], 'schedule_shift');
    expect(sent.last['elder_id'], 'b');
    expect(
      DateTime.parse(sent.last['at']).toLocal(),
      DateTime(2026, 10, 17, 10),
    );
    expect(loads, 3);
    expect(
      find.textContaining('Berikutnya: Sab 17 Okt 2026 · 10.00'),
      findsOneWidget,
    );
    expect(
      find.text('Kunjungan berikutnya mengikuti jadwal yang digeser.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('jadwal dipindahkan ke Lansia dan mengikuti dropdown', (
    tester,
  ) async {
    phone(tester);
    tester.view.physicalSize = const Size(360, 640);
    final d = fakeData();
    await tester.pumpWidget(
      MaterialApp(
        theme: relaTheme,
        home: RelawanHomeScreen(
          now: DateTime(2026, 10, 16, 9),
          load: () async => RelawanData(
            volunteer: d.volunteer,
            elders: [
              elder('a', 'Ibu A', time: '10:00:00'),
              elder('b', 'Pak B'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VolunteerScheduleRow), findsNothing);
    expect(find.text('Ubah jadwal'), findsNothing);
    expect(find.text('Geser kunjungan'), findsNothing);
    await tab(tester, 'Lansia');
    expect(find.text('Jadwal Kunjungan'), findsOneWidget);
    expect(find.textContaining('Jadwal: tiap Jumat 10.00'), findsOneWidget);
    expect(
      find.textContaining('Berikutnya: Jum 16 Okt 2026 · 10.00'),
      findsOneWidget,
    );
    expect(find.text('Ubah jadwal'), findsOneWidget);
    expect(find.text('Geser kunjungan'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pilih-lansia')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pak B').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<VolunteerScheduleRow>(find.byType(VolunteerScheduleRow))
          .elder
          .id,
      'b',
    );
    expect(find.text('Belum ada jadwal kunjungan rutin.'), findsOneWidget);
    expect(find.text('Atur jadwal'), findsOneWidget);
    expect(find.text('Geser kunjungan'), findsNothing);
    await tester.ensureVisible(find.text('Atur jadwal'));
    await tester.tap(find.text('Atur jadwal'));
    await tester.pumpAndSettle();
    expect(find.text('Untuk Pak B'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Beranda tidak memilih kartu; rekap tetap untuk kunjungan berikutnya',
    (tester) async {
      phone(tester);
      final d = fakeData();
      final started = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: relaTheme,
          home: RelawanHomeScreen(
            now: DateTime(2026, 10, 16, 9),
            load: () async => RelawanData(
              volunteer: d.volunteer,
              elders: [
                elder('a', 'Ibu A', time: '08:00:00'),
                elder('b', 'Pak B', time: '10:00:00'),
              ],
              visits: {
                'a': [visit('v', 'a', '2026-10-16T08:00:00', 0)],
              },
            ),
            onStartVisit: (e) async => started.add(e.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
      await tester.tap(find.text('Ibu A'));
      await tester.pumpAndSettle();
      final rekap = find.widgetWithText(FilledButton, 'Rekap Kunjungan');
      await tester.ensureVisible(rekap);
      await tester.tap(rekap);
      await tester.pumpAndSettle();
      expect(started, ['b']);
      expect(find.text('Rekap kunjungan untuk siapa?'), findsNothing);
      await tab(tester, 'Lansia');
      await tester.tap(find.byKey(const Key('pilih-lansia')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ibu A').last);
      await tester.pumpAndSettle();
      await tab(tester, 'Beranda');
      await tester.ensureVisible(rekap);
      await tester.tap(rekap);
      await tester.pumpAndSettle();
      expect(started, ['b', 'b']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tanpa jadwal hari ini Beranda menampilkan jadwal terdekat besok',
    (tester) async {
      phone(tester);
      final d = fakeData();
      final started = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: relaTheme,
          home: RelawanHomeScreen(
            now: DateTime(2026, 10, 16, 9),
            load: () async => RelawanData(
              volunteer: d.volunteer,
              elders: [
                elder('a', 'Belum terjadwal'),
                elder(
                  'b',
                  'Besok',
                  time: '10:00:00',
                  shift: DateTime(2026, 10, 17, 10),
                ),
              ],
            ),
            onStartVisit: (e) async => started.add(e.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Belum ada jadwal kunjungan hari ini.'), findsOneWidget);
      expect(find.text('Besok'), findsOneWidget);
      expect(find.text('Sab 17 Okt 2026 · 10.00'), findsOneWidget);
      expect(find.text('Belum terjadwal'), findsNothing);
      final rekap = find.widgetWithText(FilledButton, 'Rekap Kunjungan');
      await tester.ensureVisible(rekap);
      await tester.tap(rekap);
      await tester.pumpAndSettle();
      expect(started, ['b']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('usulan belum disetujui tidak menjadi kunjungan aktif Beranda', (
    tester,
  ) async {
    phone(tester);
    final d = fakeData();
    await tester.pumpWidget(
      MaterialApp(
        theme: relaTheme,
        home: RelawanHomeScreen(
          load: () async => RelawanData(
            volunteer: d.volunteer,
            elders: [
              elder('a', 'Ibu A', time: '10:00:00', status: 'diusulkan'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rekap Kunjungan'), findsNothing);
    await tab(tester, 'Lansia');
    expect(
      find.text('Usulan: tiap Jumat 10.00 · menunggu persetujuan keluarga'),
      findsOneWidget,
    );
    expect(find.text('Ubah jadwal'), findsOneWidget);
    expect(find.text('Geser kunjungan'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
