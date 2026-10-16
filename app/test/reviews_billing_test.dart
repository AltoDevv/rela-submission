import 'package:app/keluarga/care_cards.dart';
import 'package:app/keluarga/elder_list.dart' show elderListLabel;
import 'package:app/keluarga/review_dialog.dart';
import 'package:app/keluarga/verify_elder_screen.dart';
import 'package:app/shared/models.dart';
import 'package:app/yayasan/reviews_screen.dart' show sortReviews;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Elder elder({DateTime? paidUntil, DateTime? firstVisit, String pairing = 'berpasangan'}) => Elder.fromMap({
      'id': 'e1', 'family_id': 'k1', 'full_name': 'Ibu Tini', 'address': 'x', 'pairing_state': pairing,
      'status': 'stabil', 'verify_state': 'terverifikasi', 'paid_until': paidUntil?.toIso8601String(),
      'first_visit_at': firstVisit?.toIso8601String(),
    });

void main() {
  final now = DateTime.now();

  test('reviewDue: sekitar sebulan sekali sejak masukan terakhir atau kunjungan pertama', () {
    final t = DateTime(2026, 10, 15);
    expect(reviewDue(firstVisitAt: null, lastMine: null, now: t), isFalse);
    expect(reviewDue(firstVisitAt: DateTime(2026, 10, 1), lastMine: null, now: t), isFalse);
    expect(reviewDue(firstVisitAt: DateTime(2026, 9, 10), lastMine: null, now: t), isTrue);
    expect(reviewDue(firstVisitAt: DateTime(2026, 8, 1), lastMine: DateTime(2026, 10, 1), now: t), isFalse);
  });

  test('sortReviews: belum ditangani dulu, serius paling atas', () {
    final rows = [
      {'id': 'a', 'kind': 'apresiasi', 'handled_at': null, 'created_at': '2026-10-14'},
      {'id': 's', 'kind': 'serius', 'handled_at': '2026-10-14', 'created_at': '2026-10-13'},
      {'id': 'p', 'kind': 'perbaikan', 'handled_at': null, 'created_at': '2026-10-12'},
      {'id': 'S', 'kind': 'serius', 'handled_at': null, 'created_at': '2026-10-10'},
    ];
    expect(sortReviews(rows).map((r) => r['id']), ['S', 'p', 'a', 's']);
  });

  test('daftar lansia: didampingi tetapi langganan habis → ajakan perpanjang', () {
    expect(elderListLabel(elder(paidUntil: now.subtract(const Duration(days: 1)))), contains('langganan berakhir'));
    expect(elderListLabel(elder(paidUntil: now.add(const Duration(days: 5)))), 'Didampingi relawan');
  });

  testWidgets('masukan: kategori dan isi wajib', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    (String, String)? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showDialog(context: context, builder: (_) => const ReviewDialog()),
          child: const Text('buka'),
        ),
      ),
    ));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    final send = find.widgetWithText(FilledButton, 'Kirim');
    expect(find.textContaining('tidak dibaca relawan'), findsOneWidget, reason: 'keluarga tahu siapa yang membaca');
    await tester.enterText(find.byKey(const Key('isi-masukan')), 'Relawan meminta uang');
    await tester.pump();
    expect(tester.widget<FilledButton>(send).onPressed, isNull, reason: 'kategori belum dipilih');
    await tester.tap(find.byKey(const Key('jenis-serius')));
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(result, ('serius', 'Relawan meminta uang'));
  });

  testWidgets('ajakan masukan muncul bila sudah sebulan; riwayat menampilkan tanggapan yayasan', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var asked = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReviewsSection(
          elder: elder(paidUntil: now.add(const Duration(days: 5)), firstVisit: now.subtract(const Duration(days: 40))),
          myId: 'k1',
          ask: (_) async => (++asked > 0),
          load: () async => [
            {'author_id': 'k2', 'kind': 'perbaikan', 'body': 'Sering telat', 'created_at': '2026-10-01T10:00:00Z',
             'handled_at': '2026-10-02T10:00:00Z', 'handled_by': 'Pengurus', 'handled_note': 'Sudah dibina'},
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ajakan-masukan')), findsOneWidget);
    expect(find.textContaining('Ditangani Pengurus: Sudah dibina'), findsOneWidget);
    await tester.tap(find.text('Beri masukan'));
    await tester.pumpAndSettle();
    expect(asked, 1);
  });

  testWidgets('langganan: masa tenggang 7 hari ditampilkan, Perpanjang memanggil bayar', (tester) async {
    var paid = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SubscriptionCard(
          elder: elder(paidUntil: now.subtract(const Duration(days: 2))),
          pay: () async => paid++,
          loadPayments: () async => [],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kunjungan tetap berjalan sampai'), findsOneWidget);
    await tester.tap(find.byKey(const Key('perpanjang')));
    await tester.pumpAndSettle();
    expect(paid, 1);
  });

  testWidgets('perpanjang tanpa dokumen ulang (sudah terverifikasi)', (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(
      home: VerifyElderScreen(elderId: 'e1', elderName: 'Ibu Tini', needDocs: false, pay: () async {}, onDone: (_) async => done++),
    ));
    expect(find.text('2. Dokumen verifikasi'), findsNothing);
    await tester.tap(find.byKey(const Key('bayar')));
    await tester.pumpAndSettle();
    expect(done, 1);
  });
}
