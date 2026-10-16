import 'package:app/yayasan/verify_volunteers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ketentuan: usia minimal 18, tanpa SKCK', () {
    expect(identityChecklist.any((s) => s.contains('18 tahun')), isTrue);
    expect([...identityChecklist, ...orientationChecklist].any((s) => s.toUpperCase().contains('SKCK')), isFalse);
  });

  testWidgets('Simpan centang baru aktif setelah semua butir dicentang', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showDialog<bool>(
            context: context,
            builder: (_) => const ChecklistDialog(title: 'Cek identitas', volunteerName: 'Maria', items: identityChecklist),
          ),
          child: const Text('buka'),
        ),
      ),
    ));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Simpan centang');
    for (var i = 0; i < identityChecklist.length - 1; i++) {
      await tester.tap(find.byKey(Key('butir-$i')));
    }
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNull, reason: 'masih ada butir kosong');
    await tester.tap(find.byKey(Key('butir-${identityChecklist.length - 1}')));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
