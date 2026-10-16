import 'package:app/yayasan/invite_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inviteLink membentuk tautan temansenja://join?code=…', () {
    expect(inviteLink('SENJA1'), 'temansenja://join?code=SENJA1');
  });

  testWidgets('menampilkan kode, dan tombol salin menaruh tautan undangan di clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: InviteSection(code: 'SENJA1')),
      ),
    );
    await tester.pump(); // FutureBuilder selesai memuat kode
    expect(find.text('SENJA1'), findsOneWidget);
    expect(find.text('temansenja://join?code=SENJA1'), findsOneWidget);

    await tester.tap(find.text('Salin tautan'));
    await tester.pump();
    expect(copied, 'temansenja://join?code=SENJA1');
    expect(find.text('Tautan undangan disalin. Tempel di grup WhatsApp.'), findsOneWidget);
  });
}
