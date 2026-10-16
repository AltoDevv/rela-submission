import 'package:app/relawan/home_screen.dart';
import 'package:app/relawan/ui.dart';
import 'package:app/shared/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'relawan_tabs_test.dart' show fakeData, tab;
import 'ui_revision_test.dart' show elder;

void main() {
  testWidgets(
    'titik dan garis vertikal tersambung meski tinggi kartu berbeda',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1500);
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
                elder(
                  'a',
                  'Ibu Sri Gunawan dengan alamat dan nama panjang',
                  time: '10:00:00',
                ),
                elder('b', 'Pak Harto', time: '15:30:00'),
                elder('c', 'Ibu C', time: '16:00:00'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dot = tester.getRect(find.byKey(const Key('timeline-dot-a')));
      final down = tester.getRect(
        find.byKey(const Key('timeline-line-below-a')),
      );
      final up = tester.getRect(find.byKey(const Key('timeline-line-above-b')));
      final second = tester.getRect(find.byKey(const Key('timeline-dot-b')));
      expect(dot.width, 24);
      expect(second.width, 12);
      expect(down.center.dx, closeTo(dot.center.dx, .1));
      expect(up.center.dx, closeTo(second.center.dx, .1));
      expect(down.bottom, closeTo(up.top, .1));
      expect(down.bottom, greaterThan(dot.bottom + 60));
      expect(find.byKey(const Key('timeline-line-above-a')), findsNothing);
      expect(find.byKey(const Key('timeline-line-below-c')), findsNothing);
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Tampilkan melihat lansia lain; target rekap Beranda tetap berikutnya',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1500);
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
              elders: [
                elder('a', 'Ibu Sri', time: '10:00:00'),
                elder('b', 'Pak Harto', time: '15:30:00'),
              ],
            ),
            onStartVisit: (e) async => started.add(e.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tampilkan'));
      await tester.pumpAndSettle();
      expect(find.text('Alamat Pak Harto'), findsOneWidget);
      expect(find.text('Jadwal Kunjungan'), findsOneWidget);
      await tab(tester, 'Beranda');
      final rekap = find.widgetWithText(FilledButton, 'Rekap Kunjungan');
      await tester.ensureVisible(rekap);
      await tester.tap(rekap);
      await tester.pumpAndSettle();
      expect(started, ['a']);
      expect(tester.takeException(), isNull);
    },
  );
}
