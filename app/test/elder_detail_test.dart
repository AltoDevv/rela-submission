import 'dart:convert';
import 'dart:io';

import 'package:app/keluarga/elder_detail_screen.dart';
import 'package:app/keluarga/history_tab.dart';
import 'package:app/shared/models.dart';
import 'package:app/shared/rubric.dart';
import 'package:app/shared/widgets.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Data 6 kunjungan Ibu Sri dari T-009 (cwd saat `flutter test` adalah app/).
final seed = jsonDecode(File('../supabase/seeds/ibu_sri.json').readAsStringSync()) as Map<String, dynamic>;

List<Visit> seedVisits() => [
      for (final v in seed['visits'] as List)
        Visit.fromMap({...v as Map<String, dynamic>, 'elder_id': seed['elder_id'], 'volunteer_id': seed['volunteer_id'],
          'confirmed_at': v['visited_at']}),
    ];

final elder = Elder.fromMap({
  'id': seed['elder_id'],
  'family_id': 'b0000000-0000-0000-0000-000000000001',
  'full_name': 'Ibu Sri Wahyuni',
  'address': 'Jl. Cik Di Tiro No. 12',
  'pairing_state': 'berpasangan',
  'status': 'perlu_perhatian',
  'status_reason': 'Nafsu makan: Berkurang (biasanya Baik), memburuk 3 kunjungan berturut-turut. '
      'Kata relawan: "cuma habis setengah"\nSaran: Telepon lansia untuk menanyakan kabarnya.\n'
      'Ini bukan diagnosis. Status ini hanya ringkasan dari cerita relawan untuk membantu keluarga dan yayasan.',
});

final health = HealthProfile.fromMap({
  'elder_id': seed['elder_id'],
  'conditions': 'Hipertensi, diabetes tipe 2',
  'medications': [
    {'name': 'Amlodipin 5 mg', 'times': ['07.00']},
  ],
  'has_chronic': true,
});

Future<void> pump(WidgetTester tester, List<Visit> visits) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: ElderDetailView(elder: elder, visits: visits, health: health)),
  ));
}

void main() {
  Future<void> pumpHistory(WidgetTester tester, List<Visit> visits) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [HistoryView(elder: elder, visits: visits)]))));
  }

  testWidgets('Riwayat: 6 kunjungan, grafik satu kategori yang bisa diganti', (tester) async {
    await pumpHistory(tester, seedVisits());
    expect(find.byIcon(Icons.calendar_today_outlined), findsNWidgets(6));
    expect(find.byType(LineChart), findsOneWidget);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.first.spots.length, 6);
    // Sumbu Y memakai label rubrik.
    expect(find.text('Baik'), findsWidgets);
    expect(find.text('Tidak makan'), findsWidgets);
    // Kategori lain lewat dropdown (7 kategori rubrik).
    await tester.tap(find.byKey(const Key('kategori')));
    await tester.pumpAndSettle();
    for (final d in rubricDomains) {
      expect(find.text(d.name), findsWidgets);
    }
    await tester.tap(find.text('Daya ingat').last);
    await tester.pumpAndSettle();
    expect(find.text('Bingung mendadak'), findsWidgets);
  });

  testWidgets('domain null tampil sebagai titik kosong, bukan dianggap baik', (tester) async {
    final visits = seedVisits();
    final raw = (seed['visits'] as List).last as Map<String, dynamic>;
    final result = Map<String, dynamic>.from(raw['final_result'] as Map)..['ingatan'] = {'level': null, 'evidence': ''};
    visits[5] = Visit.fromMap({...raw, 'final_result': result, 'elder_id': seed['elder_id'], 'volunteer_id': seed['volunteer_id']});

    expect(levelSeries(visits, 'ingatan').last, isNull);
    final d = rubricDomains.firstWhere((d) => d.key == 'ingatan');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DomainChart(domain: d, levels: levelSeries(visits, 'ingatan'), visits: visits)),
    ));
    final ingatan = tester.widget<LineChart>(find.byType(LineChart));
    final line = ingatan.data.lineBarsData[0].spots;
    final empty = ingatan.data.lineBarsData[1].spots;
    expect(line.last.isNull(), isTrue); // garis terputus
    expect(empty.single.y, -1); // titik kosong di baris "Tidak disebut"
    expect(find.text('Tidak disebut'), findsWidgets);
  });

  testWidgets('tab Lansia: status, alasan, saran, bukan diagnosis, kunjungan terakhir, dan profil kesehatan', (tester) async {
    await pump(tester, seedVisits());
    expect(find.text('Perlu Perhatian'), findsOneWidget);
    expect(find.textContaining('memburuk 3 kunjungan'), findsOneWidget);
    expect(find.textContaining('Saran:'), findsOneWidget);
    expect(find.textContaining('bukan diagnosis'), findsOneWidget);
    expect(find.text('Kunjungan Terakhir'), findsOneWidget);
    expect(find.textContaining('Hipertensi, diabetes tipe 2'), findsOneWidget);
    expect(find.textContaining('Amlodipin 5 mg (07.00)'), findsOneWidget);
    expect(find.byType(DisclaimerLabel), findsOneWidget);
  });

  testWidgets('detail kunjungan: cerita relawan, tanda bahaya yang dicabut beserta alasannya', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final raw = (seed['visits'] as List).last as Map<String, dynamic>;
    final visit = Visit.fromMap({...raw, 'elder_id': seed['elder_id'], 'volunteer_id': seed['volunteer_id'],
      'status_after': 'perlu_perhatian', 'overrides': {
      'removed_flags': [{'flag': 'jatuh', 'evidence': 'terpeleset', 'reason': 'Itu kejadian tahun lalu'}],
      'softened': [],
    }});
    await tester.pumpWidget(MaterialApp(home: FamilyVisitDetailScreen(elder: elder, visit: visit, companion: 'Pendamping: Maria')));
    await tester.pumpAndSettle();
    expect(find.text('Rekap kunjungan'), findsOneWidget);
    expect(find.text('Makan'), findsOneWidget);
    expect(find.text('Perlu Perhatian'), findsOneWidget);
    expect(find.textContaining('Dicabut relawan: Jatuh'), findsOneWidget);
    expect(find.textContaining('alasan: Itu kejadian tahun lalu'), findsOneWidget);
  });

  testWidgets('kunjungan belum dikonfirmasi tidak ikut riwayat dan grafik', (tester) async {
    final visits = seedVisits()
      ..add(Visit.fromMap({
        'id': 'baru',
        'elder_id': seed['elder_id'],
        'volunteer_id': seed['volunteer_id'],
        'visited_at': '2026-10-13T10:00:00+07:00',
        'answers': {},
      }));
    await pumpHistory(tester, visits);
    expect(find.byIcon(Icons.calendar_today_outlined), findsNWidgets(6));
    expect(tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData.first.spots.length, 6);
  });

  testWidgets('status tanpa alasan tetap menampilkan pernyataan bukan diagnosis', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final stabil = Elder.fromMap({
      'id': 'x', 'family_id': 'y', 'full_name': 'Uji', 'address': 'z', 'pairing_state': 'berpasangan', 'status': 'stabil',
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ElderDetailView(elder: stabil, visits: const [], health: null))));
    expect(find.text('Stabil'), findsOneWidget);
    expect(find.textContaining('bukan diagnosis'), findsOneWidget);
    expect(find.byType(DisclaimerLabel), findsOneWidget);
  });

  testWidgets('dialog akhiri pendampingan: alasan wajib, "lainnya" wajib teks', (tester) async {
    (String, String)? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => picked = await showDialog<(String, String)>(
            context: context, builder: (_) => const EndDialog(name: 'Ibu Sri')),
          child: const Text('buka'),
        ),
      )),
    ));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    FilledButton akhiri() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Akhiri'));
    expect(akhiri().onPressed, isNull, reason: 'belum memilih alasan');
    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();
    expect(akhiri().onPressed, isNull, reason: 'lainnya tanpa teks');
    await tester.enterText(find.byType(TextField), 'Dirawat di panti');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Akhiri'));
    await tester.pumpAndSettle();
    expect(picked, ('lainnya', 'Dirawat di panti'));
  });

  testWidgets('lansia selesai menampilkan alasan', (tester) async {
    final elder = Elder.fromMap({
      'id': 'e1', 'family_id': 'k1', 'full_name': 'Ibu Sri', 'address': 'Jl. X', 'pairing_state': 'selesai',
      'status': 'stabil', 'ended_reason': 'Lansia pindah: ikut anak ke Jakarta', 'ended_at': '2026-10-15T01:00:00Z',
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ElderDetailView(elder: elder, visits: const [], health: null))));
    expect(find.text('Pendampingan selesai: Lansia pindah: ikut anak ke Jakarta'), findsOneWidget);
  });

  testWidgets('tombol "Tandai sudah ditangani" hanya untuk status tidak stabil', (tester) async {
    Elder mk(String status, {String? ackBy}) => Elder.fromMap({
          'id': 'e1', 'family_id': 'k1', 'full_name': 'Ibu Sri', 'address': 'Jl. X', 'pairing_state': 'berpasangan',
          'status': status, if (ackBy != null) 'status_ack_at': '2026-10-15T01:00:00Z', 'status_ack_by': ackBy,
          'status_ack_note': ackBy == null ? null : 'Sudah ditelepon',
        });
    var tapped = 0;
    Future<void> show(Elder e) => tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ElderDetailView(elder: e, visits: const [], health: null, onAcknowledge: () => tapped++))));

    await show(mk('stabil'));
    expect(find.text('Tandai sudah ditangani'), findsNothing);
    await show(mk('segera_dikabari'));
    await tester.tap(find.text('Tandai sudah ditangani'));
    expect(tapped, 1);
    await show(mk('segera_dikabari', ackBy: 'Budi'));
    expect(find.text('Sudah ditangani oleh Budi: Sudah ditelepon'), findsOneWidget);
    expect(find.text('Tandai sudah ditangani'), findsNothing);
  });

  testWidgets('catatan "sudah ditangani" wajib diisi', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AckDialog())));
    FilledButton simpan() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Simpan'));
    expect(simpan().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Sudah ditelepon');
    await tester.pump();
    expect(simpan().onPressed, isNotNull);
  });
}

