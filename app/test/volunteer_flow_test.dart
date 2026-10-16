import 'package:app/keluarga/elder_detail_screen.dart' show ChangeDialog;
import 'package:app/relawan/verification_card.dart';
import 'package:app/yayasan/dashboard_section.dart';
import 'package:app/yayasan/verify_volunteers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('relawan Terdaftar: kode salah → pesan; kode benar → aktif', (tester) async {
    var status = 'terdaftar';
    var activated = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VerificationCard(
          load: () async => (status: status, note: 'Dinonaktifkan yayasan: uji'),
          redeem: (c) async {
            if (c != '123456') return 'salah';
            status = 'aktif';
            return 'aktif';
          },
          onActivated: () => activated++,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Menunggu verifikasi tatap muka'), findsOneWidget);
    expect(find.textContaining('Dinonaktifkan yayasan'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('kode-verifikasi')), '000000');
    await tester.pump();
    await tester.tap(find.text('Verifikasi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kode salah'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('kode-verifikasi')), '123456');
    await tester.pump();
    await tester.tap(find.text('Verifikasi'));
    await tester.pumpAndSettle();
    expect(activated, 1);
    expect(find.text('Menunggu verifikasi tatap muka'), findsNothing);
  });

  testWidgets('pengurus: kode tampil dan dialog tertutup saat relawan sudah aktif', (tester) async {
    var active = false;
    bool? closed;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => closed = await showDialog<bool>(
            context: context,
            builder: (_) => VerificationCodeDialog(
              volunteerName: 'Maria',
              issue: () async => (code: '482913', expiresAt: DateTime.now().add(const Duration(minutes: 2))),
              isActive: () async => active,
            ),
          ),
          child: const Text('buka'),
        ),
      ),
    ));
    await tester.tap(find.text('buka'));
    await tester.pump();
    await tester.pump();
    expect(find.text('482 913'), findsOneWidget);
    active = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
  });

  testWidgets('dashboard: permintaan berhenti → terima → sistem mengusulkan pengganti (tanpa pasang manual)', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    String? approved, paired;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          DashboardSection(
            load: () async => {
              'elders': [
                {'id': 'e1', 'full_name': 'Ibu Sri', 'status': 'stabil', 'pairing_state': 'berpasangan',
                 'stop_request': {'id': 's1', 'reason': 'Pindah kota', 'created_at': '2026-10-15'}},
              ],
              'counts': {'didampingi': 1, 'tanpa_pendamping': 0, 'perlu_yayasan': 0},
              'volunteers': [],
            },
            onApproveStop: (id) async => approved = id,
            onManualPair: (_, id) => paired = id,
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Relawan mengajukan berhenti: Pindah kota'), findsOneWidget);
    await tester.tap(find.text('Ibu Sri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terima & cari pengganti'));
    await tester.pumpAndSettle();
    expect((approved, paired), ('s1', null));
    expect(find.textContaining('Usulan relawan pengganti dikirim'), findsOneWidget);
  });

  testWidgets('minta ganti: alasan wajib; "masalah serius" wajib cerita', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    (String, String)? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked = await showDialog(context: context, builder: (_) => const ChangeDialog(name: 'Ibu Sri')),
          child: const Text('buka'),
        ),
      ),
    ));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    final go = find.widgetWithText(FilledButton, 'Kirim');
    expect(tester.widget<FilledButton>(go).onPressed, isNull, reason: 'belum pilih alasan');
    await tester.tap(find.byKey(const Key('ganti-serius')));
    await tester.pump();
    expect(tester.widget<FilledButton>(go).onPressed, isNull, reason: 'serius wajib diceritakan');
    await tester.enterText(find.byKey(const Key('catatan-ganti')), 'Relawan meminta uang');
    await tester.pump();
    await tester.tap(go);
    await tester.pumpAndSettle();
    expect(picked, ('serius', 'Relawan meminta uang'));
  });
}
