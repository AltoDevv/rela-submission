import 'package:app/keluarga/elder_detail_screen.dart' show VolunteerContactCard;
import 'package:app/keluarga/elder_list.dart' show elderListLabel;
import 'package:app/keluarga/verify_elder_screen.dart';
import 'package:app/shared/models.dart';
import 'package:app/yayasan/verify_family_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

Elder elder({String pairing = 'mencari', String verify = 'belum', bool paid = true, String? note}) => Elder.fromMap({
      'id': 'e1', 'family_id': 'k1', 'full_name': 'Ibu Tini', 'address': 'Jl. Uji', 'pairing_state': pairing,
      'status': 'stabil', 'verify_state': verify, 'verify_note': note,
      'paid_until': paid ? DateTime.now().add(const Duration(days: 10)).toIso8601String() : null,
    });

void main() {
  test('elderListLabel: langganan & dokumen didahulukan, lalu status pemasangan', () {
    expect(elderListLabel(elder(paid: false)), startsWith('Langganan belum aktif'));
    expect(elderListLabel(elder()), startsWith('Lengkapi dokumen'));
    expect(elderListLabel(elder(verify: 'ditolak')), startsWith('Dokumen ditolak'));
    expect(elderListLabel(elder(pairing: 'berpasangan', verify: 'menunggu')), endsWith('dokumen sedang diperiksa yayasan'));
    expect(elderListLabel(elder(pairing: 'berpasangan', verify: 'terverifikasi')), 'Didampingi relawan');
    expect(elder(paid: false).needsSetup, isTrue);
    expect(elder(verify: 'menunggu').needsSetup, isFalse);
  });

  testWidgets('bayar dulu → 3 dokumen → baru bisa kirim', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final uploaded = <String>[];
    var paid = 0, submitted = 0, done = 0;
    await tester.pumpWidget(MaterialApp(
      home: VerifyElderScreen(
        elderId: 'e1',
        elderName: 'Ibu Tini',
        pay: () async => paid++,
        pick: (_) async => XFile('/tmp/x.jpg'),
        upload: (doc, _) async => uploaded.add(doc),
        submit: () async => submitted++,
        onDone: (_) async => done++,
      ),
    ));
    FilledButton btn(String k) => tester.widget<FilledButton>(find.byKey(Key(k)));
    expect(tester.widget<TextButton>(find.byKey(const Key('doc-kk'))).onPressed, isNull, reason: 'belum bayar');
    expect(btn('kirim-dokumen').onPressed, isNull);

    await tester.tap(find.byKey(const Key('bayar')));
    await tester.pumpAndSettle();
    expect(paid, 1);
    expect(find.text('Langganan aktif'), findsOneWidget);

    for (final k in verifyDocs.keys.take(2)) {
      await tester.tap(find.byKey(Key('doc-$k')));
      await tester.pumpAndSettle();
    }
    expect(btn('kirim-dokumen').onPressed, isNull, reason: 'dokumen belum lengkap');
    await tester.tap(find.byKey(const Key('doc-kk')));
    await tester.pumpAndSettle();
    expect(uploaded, verifyDocs.keys.toList());

    await tester.tap(find.byKey(const Key('kirim-dokumen')));
    await tester.pumpAndSettle();
    expect((submitted, done), (1, 1));
  });

  testWidgets('kontak relawan: tersembunyi sebelum verifikasi, lengkap sesudahnya', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: VolunteerContactCard(elder: elder(pairing: 'berpasangan', verify: 'menunggu'), load: () async => {})),
    ));
    expect(find.textContaining('muncul setelah yayasan memeriksa'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          VolunteerContactCard(
            elder: elder(pairing: 'berpasangan', verify: 'terverifikasi'),
            load: () async => {
              'full_name': 'Maria Ulfa', 'phone': '08123', 'foundation_name': 'Yayasan Demo', 'nickname': 'Kak Maria',
              'birth_date': '2001-08-17', 'can_dementia': true, 'available_days': ['rabu'],
            },
            attendance: 75,
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Relawan: Maria Ulfa'), findsOneWidget);
    expect(find.textContaining('08123'), findsOneWidget);
    expect(find.textContaining('Kak Maria'), findsOneWidget);
    expect(find.textContaining('tahun'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
  });

  testWidgets('yayasan: tolak wajib alasan, setujui mengirim keputusan', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final calls = <(bool, String)>[];
    Widget screen([String key = 'a']) => MaterialApp(
          home: VerifyFamilyScreen(
            key: ValueKey(key),
            elderId: 'e1',
            elderName: 'Ibu Tini',
            loadUrls: () async => {for (final k in verifyDocs.keys) k: null},
            decide: (a, n) async => calls.add((a, n)),
          ),
        );
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tolak'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Tolak')); // alasan kosong → tidak terkirim
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Tolak'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('alasan-tolak')), 'KK tidak terbaca');
    await tester.tap(find.widgetWithText(FilledButton, 'Tolak'));
    await tester.pumpAndSettle();
    expect(calls, [(false, 'KK tidak terbaca')]);

    await tester.pumpWidget(screen('b')); // layar baru (state lama sudah selesai memutuskan)
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setujui'));
    await tester.pumpAndSettle();
    expect(calls.last, (true, ''));
  });
}
