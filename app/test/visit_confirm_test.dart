import 'dart:convert';

import 'package:app/relawan/visit_confirm_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hasil AI contoh, bentuknya sama dengan `ai_result` dari Edge Function `visit` (T-010).
Map<String, dynamic> aiResult() => {
      'makan': {'level': 1, 'evidence': 'cuma makan setengah piring'},
      'obat': {'level': 0, 'evidence': 'kotaknya kosong sesuai hari'},
      'gerak': {'level': 1, 'evidence': 'sambil pegangan meja'},
      'harian': {'level': 0, 'evidence': 'masih sendiri'},
      'ingatan': {'level': null, 'evidence': ''},
      'hati': {'level': 1, 'evidence': 'nggak banyak cerita'},
      'umum': {'level': 1, 'evidence': 'lagi kurang fit'},
      'red_flags': [
        {'flag': 'jatuh', 'evidence': 'terpeleset di kamar mandi'},
      ],
    };

void main() {
  group('applyCorrection', () {
    test('koreksi relawan mengubah final_result, ai_result tetap', () {
      final ai = aiResult();
      final before = jsonEncode(ai);
      final fin = applyCorrection(ai, {'makan': 2, 'ingatan': 1});

      expect(fin['makan'], {'level': 2, 'evidence': 'cuma makan setengah piring'});
      expect(fin['ingatan']['level'], 1);
      expect(fin['obat'], ai['obat']);
      expect(fin['red_flags'], ai['red_flags']);
      expect(jsonEncode(ai), before, reason: 'ai_result tidak boleh ikut berubah');
    });

    test('pilihan "Tidak disebut" menjadi level null', () {
      final fin = applyCorrection(aiResult(), {'gerak': null});
      expect(fin['gerak']['level'], isNull);
    });
  });

  testWidgets('ringkasan, bukti, koreksi dropdown, lalu Simpan memanggil confirm', (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ai = aiResult();
    Map<String, dynamic>? sent;

    await tester.pumpWidget(MaterialApp(
      home: VisitConfirmScreen(
        visitId: 'v1',
        aiResult: ai,
        onConfirm: (finalResult, _) async {
          sent = finalResult;
          return {'status': 'segera_dikabari', 'reasons': [], 'advice': [], 'disclaimer': 'Ini bukan diagnosis.'};
        },
      ),
    ));
    await tester.pumpAndSettle();

    // Kartu hasil: label tingkat, kalimat bukti, tanda bahaya
    expect(find.text('Berkurang'), findsOneWidget);
    expect(find.textContaining('cuma makan setengah piring'), findsOneWidget);
    expect(find.textContaining('Jatuh'), findsWidgets);

    // Koreksi lewat Edit: nafsu makan Berkurang → Sangat sedikit
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('level-makan')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sangat sedikit').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selesai mengedit'));
    await tester.pumpAndSettle();
    expect(find.text('Sangat sedikit'), findsOneWidget);

    // ListView hanya membangun item yang terlihat: gulir dulu sampai tombol dibangun, lalu tampil penuh.
    await tester.scrollUntilVisible(find.text('Konfirmasi dan Simpan'), 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Konfirmasi dan Simpan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konfirmasi dan Simpan'));
    await tester.pumpAndSettle();

    expect(sent?['makan']['level'], 2);
    expect(ai['makan']['level'], 1, reason: 'ai_result asli tetap');
    expect(find.text('Rekap masuk ke riwayat kunjungan.'), findsOneWidget);
    expect(find.text('Segera dikabari'), findsOneWidget);
  });

  group('tanda bahaya dikoreksi relawan', () {
    test('mencabut alarm palsu dan menambah yang terlewat; ai_result tetap', () {
      final ai = aiResult();
      final fin = applyCorrection(ai, {}, flags: {'obat_habis'});
      expect(fin['red_flags'], [
        {'flag': 'obat_habis', 'evidence': addedByVolunteer},
      ]);
      expect((ai['red_flags'] as List).single['flag'], 'jatuh', reason: 'ai_result asli tetap');
    });

    test('yang tetap dicentang memakai bukti dari AI', () {
      final fin = applyCorrection(aiResult(), {}, flags: {'jatuh'});
      expect(fin['red_flags'], [
        {'flag': 'jatuh', 'evidence': 'terpeleset di kamar mandi'},
      ]);
    });
  });

  testWidgets('relawan mencabut tanda bahaya lalu Simpan → final_result tanpa tanda bahaya', (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    Map<String, dynamic>? sent;
    Map<String, String>? reasons;
    await tester.pumpWidget(MaterialApp(
      home: VisitConfirmScreen(visitId: 'v1', aiResult: aiResult(), onConfirm: (f, r) async {
        sent = f;
        reasons = r;
        return {'status': 'stabil', 'reasons': [], 'advice': [], 'disclaimer': ''};
      }),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('flag-jatuh'))).value, isTrue);
    // Mencabut tanda bahaya AI meminta alasan; Batal = tetap dicentang.
    await tester.tap(find.byKey(const Key('flag-jatuh')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('flag-jatuh'))).value, isTrue);

    await tester.tap(find.byKey(const Key('flag-jatuh')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Cabut')).onPressed, isNull,
        reason: 'alasan kosong tidak boleh');
    await tester.enterText(find.byKey(const Key('alasan-cabut')), 'Itu kejadian tahun lalu');
    await tester.pump();
    await tester.tap(find.text('Cabut'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('flag-jatuh'))).value, isFalse);
    expect(find.textContaining('Dicabut: Itu kejadian tahun lalu'), findsOneWidget);

    await tester.ensureVisible(find.text('Konfirmasi dan Simpan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konfirmasi dan Simpan'));
    await tester.pumpAndSettle();
    expect(sent?['red_flags'], isEmpty);
    expect(reasons, {'jatuh': 'Itu kejadian tahun lalu'});
  });
}

