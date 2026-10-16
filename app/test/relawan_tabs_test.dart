import 'package:app/relawan/home_screen.dart';
import 'package:app/relawan/profile_tab.dart';
import 'package:app/relawan/ui.dart';
import 'package:app/shared/models.dart';
import 'package:app/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RelawanData fakeData({DateTime? resignAt}) {
  final elder = Elder.fromMap({
    'id': 'e1',
    'family_id': 'f1',
    'full_name': 'Ibu Sri Gunawan',
    'address': 'Jl. Taman Palem Raya',
    'pairing_state': 'berpasangan',
    'status': 'stabil',
    'verify_state': 'terverifikasi',
    'paid_until': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    'first_visit_at': '2026-09-01T03:00:00Z',
    'schedule_weekday': 5,
    'schedule_time': '10:00:00',
    'schedule_status': 'disetujui',
  });
  Visit visit(String id, String at, {bool flag = false}) => Visit.fromMap({
        'id': id,
        'elder_id': 'e1',
        'volunteer_id': 'v1',
        'visited_at': at,
        'answers': {'makan': 'Hanya makan tiga suap bubur'},
        'final_result': {
          'makan': {'level': 2, 'evidence': 'hanya makan tiga suap bubur'},
          'red_flags': [if (flag) {'flag': 'jatuh', 'evidence': 'terpeleset'}],
        },
        'confirmed_at': at,
      });
  return RelawanData(
    volunteer: Volunteer.fromMap({
      'id': 'v1',
      'foundation_id': 'y1',
      'status': 'aktif',
      'area_label': 'Kotabaru',
      'available_days': ['senin', 'rabu'],
      'languages': ['jawa'],
      'can_dementia': true,
      'resign_reason': resignAt == null ? null : 'Pindah kota',
      'resign_requested_at': resignAt?.toIso8601String(),
    }),
    name: 'John Thor',
    foundation: 'Yayasan Sinar Senja',
    elders: [elder],
    contacts: {'e1': (name: 'Dev Fedorian', phone: '081288374736')},
    health: {'e1': HealthProfile.fromMap({'elder_id': 'e1', 'conditions': 'Hipertensi'})},
    visits: {
      'e1': [visit('k2', '2026-10-03T03:00:00Z', flag: true), visit('k1', '2026-09-26T03:00:00Z')],
    },
  );
}

Future<void> tab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(NavigationDestination, label));
  await tester.pumpAndSettle();
}

void main() {

  testWidgets('Beranda → Lansia → Riwayat → Profil sesuai Figma', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: RelawanHomeScreen(load: () async => fakeData())));
    await tester.pumpAndSettle();

    // Beranda
    expect(find.text('John Thor'), findsOneWidget);
    expect(find.text('Terverifikasi · Aktif'), findsOneWidget);
    expect(find.text('Yayasan Sinar Senja'), findsOneWidget);
    expect(find.text('Ibu Sri Gunawan'), findsOneWidget);
    expect(find.text('Rekap Kunjungan'), findsOneWidget);
    expect(find.text('3 Okt 2026 · Ada tanda bahaya'), findsOneWidget);
    expect(find.text('26 Sep 2026 · Tanpa tanda bahaya'), findsOneWidget);
    expect(find.text('Darurat'), findsOneWidget);

    // Lansia: profil kesehatan dengan disclaimer, bagian kosong diberi keterangan
    await tab(tester, 'Lansia');
    expect(find.text('081288374736'), findsOneWidget);
    expect(find.text('Info Keluarga'), findsOneWidget);
    expect(find.byType(DisclaimerLabel), findsOneWidget);
    await tester.tap(find.text('Kondisi / Penyakit'));
    await tester.pumpAndSettle();
    expect(find.text('Hipertensi'), findsOneWidget);
    await tester.tap(find.text('Dokter atau rumah sakit langganan'));
    await tester.pumpAndSettle();
    expect(find.text('Belum diisi oleh keluarga.'), findsOneWidget);

    // Riwayat: daftar → detail; hanya kunjungan terakhir yang bisa dikoreksi
    await tab(tester, 'Riwayat');
    await tester.tap(find.text('26 Sep 2026 · Tanpa tanda bahaya'));
    await tester.pumpAndSettle();
    expect(find.text('Cerita asli Anda'), findsOneWidget);
    expect(find.text('Sangat sedikit'), findsOneWidget);
    expect(find.text('Koreksi kunjungan ini'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 Okt 2026 · Ada tanda bahaya'));
    await tester.pumpAndSettle();
    expect(find.text('Tanda bahaya ditemukan'), findsOneWidget);
    expect(find.text('Koreksi kunjungan ini'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Profil
    await tab(tester, 'Profil');
    expect(find.text('Kotabaru'), findsWidgets);
    expect(find.text('Senin, Rabu'), findsOneWidget);
    expect(find.text('Ajukan berhenti'), findsOneWidget);
    expect(find.text('Ajukan Pengunduran Diri'), findsOneWidget);
  });

  testWidgets('pengunduran diri yang menunggu yayasan: tombol hilang, alasan tampil', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: RelawanHomeScreen(load: () async => fakeData(resignAt: DateTime(2026, 10, 16)))));
    await tester.pumpAndSettle();
    await tab(tester, 'Profil');
    expect(find.text('Ajukan Pengunduran Diri'), findsNothing);
    expect(find.textContaining('Alasan: Pindah kota'), findsOneWidget);
  });

  testWidgets('form pengunduran diri: alasan wajib, lalu dikirim', (tester) async {
    String? sent;
    await tester.pumpWidget(MaterialApp(
      home: ResignScreen(foundation: 'Yayasan Sinar Senja', submit: (r) async => sent = r),
    ));
    expect(find.textContaining('dikirim ke Yayasan Sinar Senja'), findsOneWidget);
    final send = find.widgetWithText(FilledButton, 'Kirim');
    expect(tester.widget<FilledButton>(send).onPressed, isNull, reason: 'alasan kosong');
    await tester.enterText(find.byKey(const Key('alasan-mundur')), 'Pindah kota');
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(sent, 'Pindah kota');
  });
}
