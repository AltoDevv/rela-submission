import 'dart:async';

import 'package:app/shared/location_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contoh jawaban Photon (GeoJSON, koordinat [lon, lat]).
final photon = {
  'features': [
    {
      'geometry': {'coordinates': [110.3672, -7.7829]},
      'properties': {'name': 'Masjid Syuhada', 'street': 'Jalan I Dewa Nyoman Oka', 'city': 'Yogyakarta', 'state': 'DI Yogyakarta'},
    },
    {
      'geometry': {'coordinates': [110.37, -7.78]},
      'properties': {'street': 'Jalan Malioboro', 'housenumber': '12', 'city': 'Yogyakarta'},
    },
    {'geometry': {'coordinates': []}, 'properties': {'name': 'rusak'}},
  ],
};

(double, double)? near_;

void main() {
  test('parsePhoton: nama, detail, lat/lng tertukar dari [lon, lat]; fitur rusak dilewati', () {
    final p = parsePhoton(photon);
    expect(p, hasLength(2));
    expect(p[0].name, 'Masjid Syuhada');
    expect(p[0].detail, 'Jalan I Dewa Nyoman Oka, Yogyakarta, DI Yogyakarta');
    expect((p[0].lat, p[0].lng), (-7.7829, 110.3672));
    expect(p[1].name, 'Jalan Malioboro 12');
    expect(p[1].detail, 'Yogyakarta');
  });

  test('normalizeQuery & dedupePlaces', () {
    expect(normalizeQuery('Jl. Kaliurang  km 5, gg Mawar'), 'jalan Kaliurang km 5, gang Mawar');
    expect(normalizeQuery('Jln Malioboro'), 'jalan Malioboro');
    expect(normalizeQuery('Gejayan'), 'Gejayan', reason: 'kata yang diawali jl/gg tidak diubah');
    const a = (name: 'RS Sardjito', detail: 'Depok', lat: -7.7677, lng: 110.3742);
    const b = (name: 'RS Sardjito', detail: 'Depok', lat: -7.7679, lng: 110.3734);
    const far = (name: 'RS Sardjito', detail: 'Depok', lat: -7.80, lng: 110.3742);
    expect(dedupePlaces([a, b, far]), [a, far]);
  });

  test('searchQueries: alamat lengkap → tanpa nomor/RT/RW, lalu mundur ke wilayah', () {
    expect(searchQueries('Jl. Kaliurang Km 5 Gg. Mawar No 12 RT 03 RW 05, Kel. Caturtunggal, Depok, Sleman'), [
      'jalan Kaliurang Km 5 gang Mawar, Caturtunggal, Depok, Sleman',
      'Caturtunggal, Depok, Sleman',
      'Depok, Sleman',
    ]);
    expect(searchQueries('Jl. Malioboro No. 1, Yogyakarta'), ['jalan Malioboro, Yogyakarta', 'Yogyakarta']);
    expect(searchQueries('masjid syuhada'), ['masjid syuhada']);
    expect(searchQueries('Perum Griya 03/05'), ['Perum Griya']);
  });

  testWidgets('saat mencari ada indikator; server lambat → pesan untuk geser peta', (tester) async {
    final pending = Completer<List<Place>>();
    await tester.pumpWidget(MaterialApp(
      home: LocationPickerScreen(
        showTiles: false,
        locate: () async => null,
        search: (q, {near}) => pending.future,
        reverse: (_) async => null,
      ),
    ));
    await tester.enterText(find.byKey(const Key('cari-lokasi')), 'malioboro');
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    pending.completeError(TimeoutException('lambat'));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('Pencarian sedang lambat'), findsOneWidget);
  });

  testWidgets('posisi HP: peta langsung ke sana dan pencarian diberi bias', (tester) async {
    (double, double)? near;
    await tester.pumpWidget(MaterialApp(
      home: LocationPickerScreen(
        showTiles: false,
        query: 'masjid syuhada',
        locate: () async => (-7.78, 110.37),
        search: (q, {near}) async {
          near_ = near;
          return [];
        },
        reverse: (_) async => 'Kotabaru',
      ),
    ));
    await tester.pumpAndSettle();
    near = near_;
    expect(near, (-7.78, 110.37));
  });

  testWidgets('ketik → saran muncul → pilih → Pilih lokasi ini mengembalikan titiknya', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    String? asked;
    (double, double)? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked = await Navigator.of(context).push<(double, double)>(MaterialPageRoute(
            builder: (_) => LocationPickerScreen(
              showTiles: false,
              locate: () async => null,
              search: (q, {near}) async {
                asked = q;
                return parsePhoton(photon);
              },
              reverse: (_) async => 'Masjid Syuhada, Yogyakarta',
            ),
          )),
          child: const Text('buka'),
        ),
      ),
    ));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    final choose = find.byKey(const Key('pilih-lokasi'));
    expect(tester.widget<FilledButton>(choose).onPressed, isNull, reason: 'belum ada titik');

    await tester.enterText(find.byKey(const Key('cari-lokasi')), 'masjid syuhada');
    await tester.pump(const Duration(milliseconds: 500)); // jeda ketik
    await tester.pumpAndSettle();
    expect(asked, 'masjid syuhada');
    await tester.tap(find.text('Masjid Syuhada'));
    await tester.pumpAndSettle();
    expect(find.text('Dekat: Masjid Syuhada, Yogyakarta'), findsOneWidget);

    await tester.tap(choose);
    await tester.pumpAndSettle();
    expect(picked, (-7.7829, 110.3672));
  });
}
