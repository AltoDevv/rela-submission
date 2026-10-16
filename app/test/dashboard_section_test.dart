import 'package:app/yayasan/dashboard_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> elder(String id, String name, String status, {String pairing = 'berpasangan', bool chronic = false}) =>
    {'id': id, 'full_name': name, 'status': status, 'status_reason': 'alasan $name', 'pairing_state': pairing, 'has_chronic': chronic};

/// Bentuk sama dengan hasil RPC foundation_dashboard().
Map<String, dynamic> dashboard() => {
      'elders': [
        elder('e1', 'Ani', 'stabil'),
        elder('e2', 'Budi', 'segera_dikabari', chronic: true),
        elder('e3', 'Citra', 'perlu_perhatian'),
        elder('e4', 'Dodi', 'stabil', pairing: 'perlu_yayasan'),
        elder('e5', 'Ari', 'segera_dikabari'),
      ],
      'counts': {'didampingi': 3, 'tanpa_pendamping': 0, 'perlu_yayasan': 1},
      'volunteers': [
        {'id': 'v1', 'full_name': 'Rina', 'status': 'aktif', 'load': 1, 'max_load': 3},
      ],
    };

void main() {
  test('sortByUrgency: Segera dikabari → Perlu perhatian → Stabil, lalu nama', () {
    final sorted = sortByUrgency(dashboard()['elders'] as List).map((e) => e['full_name']).toList();
    expect(sorted, ['Ari', 'Budi', 'Citra', 'Ani', 'Dodi']);
  });

  testWidgets('menampilkan hitungan, daftar berurutan, beban relawan, tanpa detail kesehatan', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [DashboardSection(load: () async => dashboard())]))));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget); // didampingi
    expect(find.textContaining('Rina'), findsOneWidget);
    expect(find.textContaining('1/3'), findsOneWidget);
    expect(find.textContaining('Ada kondisi kronis'), findsOneWidget);

    final ari = tester.getTopLeft(find.text('Ari')).dy;
    final citra = tester.getTopLeft(find.text('Citra')).dy;
    final ani = tester.getTopLeft(find.text('Ani')).dy;
    expect(ari < citra && citra < ani, isTrue, reason: 'urutan tampil mengikuti tingkat kedaruratan');
  });

  testWidgets('koreksi relawan atas penilaian AI tetap tampil walau status Stabil (E1)', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final d = dashboard();
    (d['elders'] as List)[0]['status_reason'] = 'Koreksi relawan atas penilaian AI: mencabut tanda bahaya Jatuh.\nBukan diagnosis.';

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [DashboardSection(load: () async => d)]))));
    await tester.pumpAndSettle();

    expect(find.textContaining('mencabut tanda bahaya Jatuh'), findsOneWidget);
    expect(find.textContaining('alasan Dodi'), findsNothing, reason: 'alasan biasa status Stabil tetap disembunyikan');
  });

  testWidgets('lansia perlu_yayasan membuka pemasangan manual', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    String? opened;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          DashboardSection(load: () async => dashboard(), onManualPair: (_, id) => opened = id),
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dodi'));
    expect(opened, 'e4');
    opened = null;
    await tester.tap(find.text('Ani')); // berpasangan: tidak membuka pemasangan manual
    expect(opened, isNull);
  });

  testWidgets('lansia berpasangan: lepas pendamping perlu konfirmasi', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final released = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          DashboardSection(load: () async => dashboard(), onRelease: (id) async {
            released.add(id);
            return 'ok';
          }),
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ani'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(released, isEmpty, reason: 'Batal tidak melepas');

    await tester.tap(find.text('Ani'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, lepas'));
    await tester.pumpAndSettle();
    expect(released, ['e1']);
  });

  test('sortByUrgency: yang sudah ditangani turun ke bawah dalam kelompok statusnya', () {
    final list = [
      {...elder('a', 'Ani', 'segera_dikabari'), 'status_ack_at': '2026-10-15T01:00:00Z'},
      elder('b', 'Budi', 'segera_dikabari'),
      elder('c', 'Citra', 'perlu_perhatian'),
    ];
    expect(sortByUrgency(list).map((e) => e['full_name']), ['Budi', 'Ani', 'Citra']);
  });
}

