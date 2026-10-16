import 'package:app/keluarga/register_elder_screen.dart';
import 'package:app/shared/location_picker.dart';
import 'package:app/shared/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layar dibuat tinggi supaya semua field form ter-render tanpa perlu scroll.
Future<void> pumpForm(WidgetTester tester, {PickLocation? geocode}) async {
  tester.view.physicalSize = const Size(1080, 8000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: RegisterElderScreen(pickLocation: geocode ?? (_, _, _) async => null)));
}

Future<void> fillRequired(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('nama')), 'Ibu Tini');
  await tester.enterText(find.byKey(const Key('alamat')), 'Jl. Malioboro No. 1, Yogyakarta');
  await tester.enterText(find.byKey(const Key('kontak_nama')), 'Budi (anak)');
  await tester.enterText(find.byKey(const Key('kontak_hp')), '081234567890');
}

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('lanjut')));
  await tester.pumpAndSettle();
}

/// Isi langkah 1 lalu maju sampai langkah 5.
Future<void> toLastStep(WidgetTester tester) async {
  await fillRequired(tester);
  for (var i = 0; i < 4; i++) {
    await next(tester);
  }
}

void main() {
  testWidgets('5 langkah berisi field F1 dan profil kesehatan, ya/tidak demensia & mobilitas, tanpa hari/bahasa', (
    tester,
  ) async {
    await pumpForm(tester);
    final steps = {
      'Informasi Dasar': ['Nama lansia', 'Usia / tanggal lahir', 'Alamat', 'Kontak keluarga', 'Foto lansia'],
      'Kebutuhan Pendampingan': ['Kebutuhan pendampingan', 'Kondisi atau penyakit yang dimiliki', 'Demensia', 'Kesulitan mobilitas'],
      'Alergi dan Obat': ['Alergi', 'Obat rutin', 'Jadwal konsumsi', 'Pantangan makanan'],
      'Mobilitas dan Dokter': ['Kemampuan bergerak', 'Alat bantu', 'Dokter atau rumah sakit langganan'],
      'Instruksi Darurat': ['Instruksi darurat', 'Ringkasan', 'Persetujuan lansia'],
    };
    var n = 1;
    for (final e in steps.entries) {
      expect(find.text('Registrasi Lansia · Langkah $n dari 5'), findsOneWidget);
      expect(find.text(e.key), findsOneWidget);
      for (final label in e.value) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      if (n > 1) expect(find.text('Diisi oleh keluarga. Bukan diagnosis medis dan bukan rekam medis resmi.'), findsOneWidget);
      expect(find.textContaining('Hari'), findsNothing);
      expect(find.textContaining('Bahasa'), findsNothing);
      if (n == 1) await fillRequired(tester);
      if (n < 5) await next(tester);
      n++;
    }
    expect(find.text('Simpan dan Lihat Rekomendasi'), findsOneWidget);
  });

  testWidgets('langkah 1: field wajib kosong → pesan error, tidak lanjut, alamat tidak di-geocode', (tester) async {
    var geocoded = false;
    await pumpForm(
      tester,
      geocode: (_, _, _) async {
        geocoded = true;
        return null;
      },
    );
    await next(tester);
    expect(find.text('Wajib diisi'), findsNWidgets(3)); // nama, alamat, nama kontak
    expect(find.textContaining('Nomor HP tidak valid'), findsOneWidget);
    expect(find.text('Informasi Dasar'), findsOneWidget);
    expect(geocoded, isFalse);
  });

  testWidgets('nama lebih dari 100 karakter ditolak', (tester) async {
    await pumpForm(tester, geocode: (_, _, _) async => null);
    await fillRequired(tester);
    await tester.enterText(find.byKey(const Key('nama')), 'a' * 101);
    await next(tester);
    expect(find.text('Maksimal 100 karakter'), findsOneWidget);
  });

  testWidgets('tambah obat → baris obat kedua', (tester) async {
    await pumpForm(tester);
    await fillRequired(tester);
    await next(tester);
    await next(tester);
    expect(find.byKey(const Key('obat-1')), findsNothing);
    await tester.tap(find.byKey(const Key('tambah-obat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('obat-1')), findsOneWidget);
    expect(find.text('Obat rutin 2'), findsOneWidget);
  });

  testWidgets('titik lokasi tidak dipilih → peta dibuka dengan alamat, pesan muncul, form tidak tersimpan', (tester) async {
    String? asked;
    await pumpForm(
      tester,
      geocode: (_, address, _) async {
        asked = address;
        return null;
      },
    );
    await toLastStep(tester);
    await tester.tap(find.text('Lansia sudah saya jelaskan tentang layanan ini dan ia setuju'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan dan Lihat Rekomendasi'));
    await tester.pumpAndSettle();
    expect(asked, 'Jl. Malioboro No. 1, Yogyakarta');
    expect(find.textContaining('Titik lokasi rumah belum dipilih'), findsOneWidget);
    // Tetap di form (tidak pindah layar). Supabase tidak diinisialisasi di test,
    // jadi bila kode mencoba menyimpan, test ini akan gagal dengan exception.
    expect(find.byType(RegisterElderScreen), findsOneWidget);
  });

  test('parseMedications memisahkan nama obat dan jam per baris', () {
    expect(parseMedications('Amlodipin 5 mg - 07.00\nMetformin 500 mg 07.00, 19:00\n\nVitamin D'), [
      {
        'name': 'Amlodipin 5 mg',
        'times': ['07.00'],
      },
      {
        'name': 'Metformin 500 mg',
        'times': ['07.00', '19.00'],
      },
      {'name': 'Vitamin D', 'times': <String>[]},
    ]);
  });

  test('baris obat: jam diambil dari jadwal; jadwal tanpa jam disimpan apa adanya; baris kosong dilewati', () {
    expect(medicationsFromRows([('Amlodipin 5 mg', 'Setiap pagi pukul 08.00'), ('Vitamin D', 'setiap pagi'), ('', 'x')]), [
      {'name': 'Amlodipin 5 mg', 'times': ['08.00']},
      {'name': 'Vitamin D', 'times': ['setiap pagi']},
    ]);
  });

  group('mode ubah', () {
    test('obat: teks → data → teks kembali sama', () {
      const text = 'Amlodipin 5 mg 07.00\nMetformin 500 mg 07.00 19.00';
      expect(medicationsToText(parseMedications(text)), text);
    });

    test('kontak keluarga dipisah dari instruksi darurat', () {
      expect(splitContact('Kontak keluarga: Budi Santoso 081234567890. Jangan beri obat tidur.'),
          ('Budi Santoso', '081234567890', 'Jangan beri obat tidur.'));
      expect(splitContact('Kontak keluarga: Budi 0812345678.'), ('Budi', '0812345678', ''));
      expect(splitContact('Tanpa kontak'), ('', '', 'Tanpa kontak'));
    });

    testWidgets('form terisi data lama dan tombol terakhir menjadi "Simpan perubahan"', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final elder = Elder.fromMap({
        'id': 'e1', 'family_id': 'k1', 'full_name': 'Ibu Sri Wahyuni', 'address': 'Jl. Cik Di Tiro No. 12',
        'needs': 'Teman ngobrol', 'has_dementia': true, 'has_mobility_issue': false,
        'pairing_state': 'berpasangan', 'status': 'stabil', 'birth_date': '1948-05-04',
      });
      final health = HealthProfile.fromMap({
        'elder_id': 'e1', 'conditions': 'Hipertensi', 'allergies': 'Tidak ada',
        'medications': [{'name': 'Amlodipin 5 mg', 'times': ['07.00']}],
        'emergency_instructions': 'Kontak keluarga: Budi 081234567890. Telepon dulu sebelum ke RS.',
        'mobility': 'Berjalan pelan', 'mobility_aids': 'Tongkat',
        'has_chronic': true,
      });
      await tester.pumpWidget(MaterialApp(home: RegisterElderScreen(elder: elder, health: health)));
      expect(find.text('Ubah Data Lansia · Langkah 1 dari 5'), findsOneWidget);
      expect(find.text('Ibu Sri Wahyuni'), findsOneWidget);
      expect(find.textContaining('4 Mei 1948'), findsOneWidget);
      expect(find.text('081234567890'), findsOneWidget);
      await next(tester);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('demensia-ya'))).selected, isTrue);
      await next(tester);
      expect(find.text('Amlodipin 5 mg'), findsWidgets);
      expect(find.text('07.00'), findsOneWidget);
      await next(tester);
      expect(find.text('Berjalan pelan'), findsOneWidget);
      expect(find.text('Tongkat'), findsWidgets);
      await next(tester);
      expect(find.text('Telepon dulu sebelum ke RS.'), findsOneWidget);
      expect(find.text('Simpan perubahan'), findsOneWidget);
    });
  });

  testWidgets('tanpa persetujuan lansia → pesan muncul dan alamat tidak di-geocode', (tester) async {
    var geocoded = false;
    await pumpForm(tester, geocode: (_, _, _) async {
      geocoded = true;
      return (-7.78, 110.37);
    });
    await toLastStep(tester);
    await tester.tap(find.text('Simpan dan Lihat Rekomendasi'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih persetujuan lansia terlebih dahulu.'), findsOneWidget);
    expect(geocoded, isFalse);
  });
}
