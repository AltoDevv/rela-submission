# ReLa — Relawan Lansia

Repository pengumpulan prototype ReLa. Source disertai petunjuk menjalankan aplikasi/backend dan contoh
konfigurasi; konfigurasi Firebase asli serta kredensial server tidak disertakan.

Prototype Android untuk Hackathon JOINTS UGM 2026, tema Healthcare. ReLa menghubungkan keluarga yang tinggal
jauh dengan relawan komunitas melalui yayasan, lalu membantu keluarga memantau perubahan kondisi lansia
dari cerita kunjungan yang diperiksa relawan.

## Mencoba aplikasi

Unduh [APK ReLa terbaru](https://github.com/AltoDevv/rela-submission/releases/latest/download/ReLa.apk)
atau buka [rilis terbaru](https://github.com/AltoDevv/rela-submission/releases/latest). Versi pengumpulan saat ini **1.0.1**.
Petunjuk pemasangan dan akun demo ada di
[panduan instalasi](docs/submission/panduan-instalasi.md). Aplikasi membutuhkan koneksi internet dan backend
demo yang aktif. Tidak perlu memasang Flutter untuk memakai APK.

| Peran | Email demo | Password demo |
|---|---|---|
| Keluarga | `keluarga1@demo.id` | `demo1234` |
| Relawan | `relawan1@demo.id` | `demo1234` |
| Pengurus yayasan | `pengurus@demo.id` | `demo1234` |

Akun ini khusus data contoh bersama. Gunakan data fiktif saat mencoba; jangan memasukkan dokumen pribadi.
Untuk mendaftar sendiri, pilih peran Keluarga atau Relawan. Relawan baru perlu memilih yayasan dan menjalani
verifikasi tatap muka sebelum aktif, sehingga akun demo lebih praktis untuk meninjau fitur yang sudah berjalan.

## Alur solusi

1. **Pendampingan:** keluarga mendaftarkan lansia, menyatakan persetujuan lansia/wali, memilih titik rumah,
   melakukan pembayaran simulasi, dan mengirim dokumen verifikasi. Sistem mengusulkan relawan berdasarkan
   kemampuan yang diperlukan, jarak, lalu beban pendampingan. Keluarga meninjau dan menerima usulan; yayasan
   memeriksa dokumen sebelum kunjungan dimulai. Relawan memastikan persetujuan lansia pada kunjungan pertama.
2. **Pemantauan:** relawan menceritakan kunjungan melalui tujuh pertanyaan terbuka (ketik atau dikte). Gemini
   mengekstraksi kategori dengan kalimat bukti. Relawan memeriksa/mengoreksi hasil sebelum menyimpan. Aturan
   membandingkan hasil dengan kebiasaan pribadi lansia, lalu memperbarui status dan grafik keluarga.
3. **Darurat:** relawan mengonfirmasi tindakan Darurat; aplikasi mengirim pemberitahuan kepada keluarga/yayasan
   dan menyertakan lokasi bila tersedia. Panggilan 119 dalam prototype adalah **simulasi**.

Pada akun relawan, tab **Lansia** menyediakan dropdown lansia, jadwal rutin/kunjungan berikutnya, dan tombol
Atur/Ubah jadwal serta Geser kunjungan. Jadwal rutin menunggu persetujuan keluarga. Beranda menampilkan
timeline titik dan garis vertikal; kunjungan berikutnya ditentukan otomatis. **Tampilkan** membuka detail
lansia tanpa mengganti target rekap Beranda. Rekap umum di Riwayat meminta pilihan jika pasangan lebih dari satu.

Untuk mencoba dua HP, masuk sebagai keluarga dan relawan yang terhubung pada lansia yang sama. Keduanya
memakai backend demo bersama melalui internet. Detail lansia keluarga menerima pembaruan Realtime;
beberapa halaman relawan perlu dibuka ulang untuk memuat data terbaru.

Tiga peran memiliki tampilan berbeda. Yayasan mengelola relawan, verifikasi, pemasangan, dan tindak lanjut;
detail cerita/profil kesehatan dibatasi menurut peran melalui RLS di database. Nama dan alamat lansia disaring
dari input ke Gemini. Profil kesehatan berasal dari keluarga dan bukan rekam medis resmi atau diagnosis.

## Teknologi dan penggunaan AI

- Flutter/Dart untuk aplikasi Android, dengan Navigator dan setState bawaan.
- Supabase: Auth, PostgreSQL/RLS, Storage, Realtime, dan Edge Functions TypeScript/Deno.
- Google Gemini untuk ekstraksi narasi; status dihitung dengan aturan, bukan model prediksi klinis.
- Firebase Cloud Messaging untuk push notification.
- OpenStreetMap, Photon, dan Esri untuk pemilih lokasi/peta.
- Codex membantu implementasi, perbaikan antarmuka, pengujian, dan persiapan pengumpulan. Tim tetap meninjau
  keputusan dan hasil. Tools AI lain yang benar-benar dipakai tim harus ditambahkan pada pitch deck.

Evaluasi internal 15 Oktober 2026: 35 cerita buatan tim, 245 kategori, akurasi ekstraksi 217/245 (88,6%), recall
tanda bahaya 18/18 (100%), dengan 10 alarm palsu sebelum pemeriksaan relawan. Label belum ditinjau orang kedua.
Angka ini bukan validasi klinis atau bukti akurasi diagnosis. Detail: [naskah demo](docs/demo-script.md).

## Menjalankan source code aplikasi

Prasyarat: Flutter dengan Dart yang memenuhi `app/pubspec.yaml` (`^3.13.5`), Android SDK/JDK, serta HP Android
dengan USB debugging. Backend Supabase dan proyek Firebase harus sudah dikonfigurasi.

```bash
cp app/env.example.json app/env.json
```

Isi dua field pada `app/env.json`: URL proyek Supabase dan **publishable key**. Unduh konfigurasi Android
dari Firebase Console milik proyek Anda untuk package `id.temansenja.app`, lalu simpan lokal pada
`app/android/app/google-services.json`. Konfigurasi asli tidak disertakan dalam source pengumpulan.
Strukturnya dapat dilihat pada `firebase/google-services.example.json`, yang hanya berisi placeholder.
Jangan memakai key Gemini sebagai key client Firebase; key server Gemini tetap hanya di Supabase secrets.

```bash
cd app
flutter pub get
flutter run --dart-define-from-file=env.json
```

Untuk membuat satu APK rilis yang memuat arsitektur Android yang didukung:

```bash
cd app
flutter build apk --release --dart-define-from-file=env.json
```

Hasil: `app/build/app/outputs/flutter-apk/app-release.apk` (dari root repository).
Konfigurasi signing saat ini memakai kunci debug lokal untuk distribusi prototype; rilis produksi memerlukan
kunci signing milik tim yang dikelola terpisah.

## Menyiapkan backend sendiri

1. Buat proyek Supabase dan Firebase. Aktifkan email/password Auth dan FCM; pertahankan package Android di atas.
2. Dari root repository, jalankan `supabase link --project-ref <project-ref>` dan `supabase db push --yes`
   untuk menerapkan berkas `supabase/migrations/` ke proyek kosong.
3. Atur secret server Gemini (`GEMINI_API_KEY`, `GEMINI_MODEL`), Firebase service account, dan secret pengingat
   pada Supabase. Kredensial admin tetap di server; jangan masukkan ke aplikasi atau repository.
4. Deploy fungsi `pairing`, `visit`, `emergency`, `account`, dan `review` dengan `supabase functions deploy <nama>`.
   Deploy `reminders` dengan `--no-verify-jwt`; pengingat menggunakan secret cron dan Vault seperti dijelaskan
   pada [aturan lingkungan proyek](CLAUDE.md).
5. Untuk data contoh di proyek uji kosong, jalankan seed 01, 02, lalu 03 melalui
   `supabase db query --linked -f supabase/seeds/<nama-file>.sql`. Akun demo dibuat seed 01.
6. Masukkan URL/publishable key proyek tersebut ke `app/env.json`, lalu jalankan aplikasi.

## Pemeriksaan

```bash
cd app
flutter test
flutter analyze
```

Dari root repository:

```bash
deno test supabase/functions/_shared
python3 -m unittest discover -s scripts -p 'test_package_submission.py'
python3 scripts/package_submission.py
```

Skrip pengemas menyalin snapshot source terbaru ke `dist/submission/ReLa-source.zip`, termasuk perubahan yang
belum di-commit. Berkas konfigurasi pribadi, hasil build, catatan progres, dan screenshot uji tidak dimasukkan.
Skrip berhenti bila menemukan materi privat yang diketahui pada source yang akan dibagikan.

## Panduan untuk peninjau

- [Cara memasang dan mencoba APK](docs/submission/panduan-instalasi.md)
- [Naskah demo dan batasan evaluasi](docs/demo-script.md)
- [Kebutuhan produk](docs/prd.md) dan [arsitektur](docs/architecture.md)
- `app/lib/`: UI dan logika client; `supabase/functions/_shared/`: aturan dan test server;
  `supabase/migrations/`: skema/policy; `data/eval/`: dataset evaluasi buatan tim.

Pembayaran dan panggilan 119 disimulasikan. Verifikasi identitas dilakukan pengurus secara manual; aplikasi tidak
memiliki integrasi e-KYC/auto-debit. ReLa membantu pendampingan dan komunikasi, bukan menggantikan tenaga medis.
