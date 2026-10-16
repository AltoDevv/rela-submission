import 'package:app/keluarga/proposal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kartu contoh, bentuknya sama dengan baris `get_proposal_card` (+ `photo_url`).
Map<String, dynamic> card(String id, String name, {int attempt = 1}) => {
      'id': id,
      'attempt': attempt,
      'state': 'pending',
      'rejects_left': 3 - attempt,
      'volunteer_name': name,
      'foundation_name': 'Yayasan Demo',
      'photo_url': null,
      'can_dementia': true,
      'can_mobility': false,
      'available_days': ['selasa', 'jumat'],
      'languages': ['indonesia', 'jawa'],
      'distance_km': 2.2,
      'reason_text': 'Jarak 2,2 km',
      'verification': 'Identitas dicek tatap muka oleh pengurus Yayasan Demo · Sudah mengikuti orientasi',
    };

class Fake {
  final cards = {'p1': card('p1', 'Rina'), 'p2': card('p2', 'Dimas', attempt: 2)};
  Map<String, dynamic> rejectResult = {'pairing_state': 'menunggu_keluarga', 'proposal_id': 'p2'};
  final rejects = <List<String?>>[];
  final accepts = <String>[];

  Widget screen(String id) => MaterialApp(
        home: ProposalScreen(
          proposalId: id,
          loadCard: (pid) async => cards[pid]!,
          onAccept: (pid) async => accepts.add(pid),
          onReject: (pid, reason, note) async {
            rejects.add([pid, reason, note]);
            return rejectResult;
          },
        ),
      );
}

Future<void> openRejectDialog(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Tolak'));
  await tester.tap(find.text('Tolak'));
  await tester.pumpAndSettle();
}

FilledButton sendButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Kirim alasan'));

void main() {
  // Layar setinggi HP supaya seluruh kartu (sampai tombol) dibangun oleh ListView.
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 3200);
    view.devicePixelRatio = 1.0;
  });
  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset());

  testWidgets('kartu menampilkan profil, verifikasi, label keahlian, dan sisa tolak', (tester) async {
    await tester.pumpWidget(Fake().screen('p1'));
    await tester.pumpAndSettle();
    expect(find.text('Rina'), findsOneWidget);
    expect(find.textContaining('Yayasan Demo'), findsWidgets);
    expect(find.textContaining('Identitas dicek tatap muka'), findsOneWidget);
    expect(find.textContaining('diisi sendiri oleh relawan'), findsOneWidget);
    expect(find.textContaining('demensia'), findsOneWidget);
    expect(find.textContaining('2,2 km'), findsWidgets);
    expect(find.text('Sisa 2 kali tolak'), findsOneWidget);
  });

  testWidgets('Kirim nonaktif tanpa alasan; "lainnya" wajib teks', (tester) async {
    await tester.pumpWidget(Fake().screen('p1'));
    await tester.pumpAndSettle();
    await openRejectDialog(tester);

    expect(sendButton(tester).onPressed, isNull, reason: 'belum memilih alasan');
    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();
    expect(sendButton(tester).onPressed, isNull, reason: '"lainnya" tanpa teks');
    await tester.enterText(find.byType(TextField), 'Ibu ingin relawan perempuan');
    await tester.pumpAndSettle();
    expect(sendButton(tester).onPressed, isNotNull);
  });

  testWidgets('tolak dengan alasan → reject dipanggil, kartu berikutnya dimuat', (tester) async {
    final fake = Fake();
    await tester.pumpWidget(fake.screen('p1'));
    await tester.pumpAndSettle();
    await openRejectDialog(tester);
    await tester.tap(find.text('Jarak terlalu jauh'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Kirim alasan'));
    await tester.pumpAndSettle();

    expect(fake.rejects, [
      ['p1', 'jarak', null],
    ]);
    expect(find.text('Dimas'), findsOneWidget);
    expect(find.text('Sisa 1 kali tolak'), findsOneWidget);
  });

  testWidgets('usulan ketiga tidak bisa ditolak: hanya tombol Terima', (tester) async {
    final fake = Fake()..cards['p3'] = card('p3', 'Sari', attempt: 3);
    await tester.pumpWidget(fake.screen('p3'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tidak bisa ditolak'), findsOneWidget);
    expect(find.text('Tolak'), findsNothing);
    expect(find.text('Terima'), findsOneWidget);
  });

  testWidgets('Terima memanggil accept', (tester) async {
    final fake = Fake();
    await tester.pumpWidget(fake.screen('p1'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Terima'));
    await tester.tap(find.text('Terima'));
    await tester.pumpAndSettle();
    expect(fake.accepts, ['p1']);
  });
}
