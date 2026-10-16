import 'package:app/keluarga/elder_detail_screen.dart';
import 'package:app/relawan/emergency_screen.dart';
import 'package:app/shared/models.dart';
import 'package:app/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Respons Edge Function `emergency` contoh.
Map<String, dynamic> response({bool notified = true}) => {
      'emergency_id': 'ev1',
      'notified': notified,
      'maps_url': 'https://maps.google.com/?q=-7.779,110.376',
      'health': {
        'elder_id': 'e1',
        'conditions': 'Hipertensi, diabetes tipe 2',
        'allergies': 'Tidak ada alergi obat',
        'medications': [
          {'name': 'Amlodipin 5 mg', 'times': '07.00'},
        ],
        'emergency_instructions': 'Kontak keluarga: Budi 0812…',
        'has_chronic': true,
      },
    };

class Fake {
  final calls = <List<Object?>>[];
  ({double lat, double lng})? location = (lat: -7.779, lng: 110.376);

  Widget screen() => MaterialApp(
        home: EmergencyScreen(
          elderId: 'e1',
          locate: () async => location,
          trigger: (id, lat, lng) async {
            calls.add([id, lat, lng]);
            return response();
          },
        ),
      );
}

/// Layar Darurat langsung menampilkan dialog konfirmasi saat dibuka (Figma "Emergency Confirm").
Future<void> pressDarurat(WidgetTester tester) => tester.pumpAndSettle();

void main() {
  testWidgets('Batal di dialog konfirmasi → tidak ada panggilan ke server', (tester) async {
    final fake = Fake();
    await tester.pumpWidget(fake.screen());
    await pressDarurat(tester);
    expect(find.text('Aktifkan fitur darurat?'), findsOneWidget);

    await tester.tap(find.text('Batalkan'));
    await tester.pumpAndSettle();
    expect(fake.calls, isEmpty);
    expect(find.textContaining('Memanggil 119'), findsNothing);
  });

  testWidgets('Konfirmasi → GPS dikirim → layar 119 (simulasi) + profil + disclaimer', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fake = Fake();
    await tester.pumpWidget(fake.screen());
    await pressDarurat(tester);
    await tester.tap(find.text('Ya, aktifkan darurat'));
    await tester.pumpAndSettle();

    expect(fake.calls, [
      ['e1', -7.779, 110.376],
    ]);
    expect(find.textContaining('Memanggil 119'), findsOneWidget);
    expect(find.textContaining('Hipertensi'), findsOneWidget);
    expect(find.textContaining('Amlodipin 5 mg'), findsOneWidget);
    expect(find.byType(DisclaimerLabel), findsOneWidget);
    expect(find.textContaining('Keluarga dan yayasan sudah diberi tahu'), findsOneWidget);
  });

  testWidgets('GPS gagal → tetap dikirim tanpa lokasi', (tester) async {
    final fake = Fake()..location = null;
    await tester.pumpWidget(fake.screen());
    await pressDarurat(tester);
    await tester.tap(find.text('Ya, aktifkan darurat'));
    await tester.pumpAndSettle();

    expect(fake.calls, [
      ['e1', null, null],
    ]);
    expect(find.textContaining('Memanggil 119'), findsOneWidget);
  });

  testWidgets('riwayat darurat tampil di halaman keluarga', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final elder = Elder.fromMap({
      'id': 'e1', 'family_id': 'k1', 'full_name': 'Ibu Sri Wahyuni', 'address': 'Jl. Cik Di Tiro',
      'pairing_state': 'berpasangan', 'status': 'stabil',
    });
    final ev = Emergency.fromMap({
      'id': 'ev1', 'elder_id': 'e1', 'volunteer_id': 'v1', 'lat': -7.779, 'lng': 110.376,
      'summary': 'Maria menekan tombol Darurat saat mendampingi Ibu Sri Wahyuni.', 'notified': true,
      'created_at': '2026-10-15T03:05:00Z',
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ElderDetailView(elder: elder, visits: const [], health: null, emergencies: [ev])),
    ));
    expect(find.text('Riwayat darurat'), findsOneWidget);
    expect(find.textContaining('Maria menekan tombol Darurat'), findsOneWidget);
    expect(find.byTooltip('Buka lokasi'), findsOneWidget);
  });
}
