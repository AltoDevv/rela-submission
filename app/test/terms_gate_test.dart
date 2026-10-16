import 'package:app/shared/terms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('akun tanpa persetujuan syarat: beranda baru terbuka setelah Saya setuju', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var called = 0;
    await tester.pumpWidget(MaterialApp(
      home: TermsGate(onAccept: () async => called++, child: const Text('BERANDA')),
    ));
    expect(find.text('BERANDA'), findsNothing);
    expect(find.text('Persetujuan lansia'), findsOneWidget);

    await tester.tap(find.text('Saya setuju'));
    await tester.pumpAndSettle();
    expect(called, 1);
    expect(find.text('BERANDA'), findsOneWidget);
  });
}
