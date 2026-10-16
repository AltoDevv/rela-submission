import 'package:app/shared/models.dart';
import 'package:app/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, Widget w) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));

void main() {
  group('StatusBadge', () {
    const cases = {
      'stabil': 'Stabil',
      'perlu_perhatian': 'Perlu perhatian',
      'segera_dikabari': 'Segera dikabari',
    };
    for (final MapEntry(key: status, value: label) in cases.entries) {
      testWidgets('$status → "$label"', (tester) async {
        await pump(tester, StatusBadge(status: status));
        expect(find.text(label), findsOneWidget);
      });
    }

    testWidgets('ketiga status punya warna berbeda', (tester) async {
      final colors = cases.keys.map(StatusBadge.colorFor).toSet();
      expect(colors.length, 3);
    });
  });

  testWidgets('DisclaimerLabel memakai teks persis dari PRD F1', (tester) async {
    await pump(tester, const DisclaimerLabel());
    expect(
      find.text('Diisi oleh keluarga. Bukan diagnosis medis dan bukan rekam medis resmi.'),
      findsOneWidget,
    );
  });

  group('models.fromMap', () {
    test('Volunteer: kolom array dan kolom kosong', () {
      final v = Volunteer.fromMap({
        'id': 'v1',
        'foundation_id': 'f1',
        'status': 'aktif',
        'available_days': ['selasa', 'jumat'],
        'languages': null,
        'can_dementia': true,
        'can_mobility': false,
        'max_load': 3,
        'lat': -7.78,
        'lng': 110,
      });
      expect(v.availableDays, ['selasa', 'jumat']);
      expect(v.languages, isEmpty);
      expect(v.lng, 110.0);
      expect(v.idCheckedAt, isNull);
    });

    test('Visit: jsonb dan tanggal, final_result boleh null', () {
      final v = Visit.fromMap({
        'id': 'k1',
        'elder_id': 'e1',
        'volunteer_id': 'v1',
        'visited_at': '2026-10-14T09:00:00+07:00',
        'answers': {'makan': 'cuma setengah piring'},
        'ai_result': {
          'makan': {'level': 1, 'evidence': 'cuma setengah piring'},
        },
        'final_result': null,
        'confirmed_at': null,
      });
      expect(v.answers['makan'], 'cuma setengah piring');
      expect(v.aiResult?['makan']['level'], 1);
      expect(v.finalResult, isNull);
      expect(v.visitedAt.toUtc().hour, 2);
    });
  });

  group('LastVisitBadge', () {
    final now = DateTime(2026, 10, 15, 10);
    test('teks: hari ini, X hari lalu, belum pernah', () {
      expect(lastVisitText(DateTime(2026, 10, 15, 8), now: now), 'Kunjungan terakhir: hari ini');
      expect(lastVisitText(DateTime(2026, 10, 12, 10), now: now), 'Kunjungan terakhir: 3 hari lalu');
      expect(lastVisitText(null, now: now), 'Belum pernah dikunjungi');
    });
    test('basi bila lebih dari 7 hari atau belum pernah', () {
      expect(isVisitStale(DateTime(2026, 10, 8, 10), now: now), isFalse); // tepat 7 hari
      expect(isVisitStale(DateTime(2026, 10, 7, 10), now: now), isTrue);
      expect(isVisitStale(null, now: now), isTrue);
    });
    testWidgets('kunjungan lama tampil sebagai peringatan', (tester) async {
      await pump(tester, LastVisitBadge(last: DateTime(2026, 10, 1), now: now));
      expect(find.textContaining('14 hari lalu, belum ada kunjungan baru'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });
  });

  testWidgets('hapus akun hanya bisa dikonfirmasi setelah mengetik HAPUS', (tester) async {
    await pump(tester, const DeleteAccountDialog());
    FilledButton hapus() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Hapus akun'));
    expect(hapus().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'hapus');
    await tester.pump();
    expect(hapus().onPressed, isNull, reason: 'harus persis HAPUS');
    await tester.enterText(find.byType(TextField), 'HAPUS');
    await tester.pump();
    expect(hapus().onPressed, isNotNull);
  });
}

