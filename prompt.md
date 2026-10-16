# Prompt — TemanSenja

Cara pakai: baca "Langkah demi langkah" dari atas. Di setiap langkah, buka sesi Claude
sebanyak yang disebut, lalu tempel prompt yang sesuai ke masing-masing sesi. Semua sesi
bekerja **di folder yang sama** (`/Users/altodev/hackathon`), tanpa worktree atau branch tambahan.

Saran: jalankan Langkah 1–2 dengan satu sesi sampai alurnya terasa natural (baca rencana →
setujui → test → todo → progress → commit). Setelah itu baru mulai langkah paralel.

---

## Langkah demi langkah

| Langkah | Mode | Target | Sesi → prompt |
|---|---|---|---|
| 1 | **SENDIRIAN** | 14 Okt, sore | T-001 Akun, alat, keputusan PRD (bersama manusia) |
| 2 | **SENDIRIAN** | 14 Okt, malam | T-002 Kerangka proyek |
| 3 | **PARALEL, 3 sesi** | 14 Okt, malam | A: T-003 · B: T-004 · C: T-005, lalu Cek gabungan 3 |
| 4 | **PARALEL, 3 sesi** | 15 Okt, 08.00 | A: T-006 · B: T-007 · C: T-008, lalu Cek gabungan 4 |
| 5 | **PARALEL, 3 sesi** | 15 Okt, 10.00 | A: T-010 · B: T-011 · C: T-009, lalu Cek gabungan 5 |
| 6 | **PARALEL, 3 sesi** | 15 Okt, 12.00 | A: T-012 · B: T-013 · C: T-014, lalu Cek gabungan 6 |
| 7 | **PARALEL, 3 sesi** | 15 Okt, 14.00 | A: T-015 · B: T-016 · C: T-023, lalu Cek gabungan 7 |
| 8 | **PARALEL, 3 sesi** | 15 Okt, 16.00 | A: T-018 · B: T-019 · C: T-020, lalu Cek gabungan 8 |
| 9 | **PARALEL, 3 sesi** | 15 Okt, 18.00 | A: T-021 · B: T-022 · C: T-017, lalu Cek gabungan 9 |
| 10 | **SENDIRIAN** | 15 Okt, 19.00 | T-024 Skrip akurasi |
| 11 | **SENDIRIAN** | 15 Okt, 20.00–22.00 | T-025 Gladi demo (sisa waktu sampai 23.50 untuk perbaikan dan pitch) |

**Kenapa beberapa langkah tidak bisa paralel:**
- **Langkah 1** butuh kamu sendiri: membuat akun, menyalin API key, dan mengambil keputusan. Claude tidak bisa melakukannya untukmu.
- **Langkah 2** membuat `pubspec.yaml`, `pubspec.lock`, `AndroidManifest.xml`, dan `supabase/config.toml`. Semua tugas lain bergantung pada file-file ini, dan lockfile pasti bentrok bila dua sesi menginstal package bersamaan.
- **Langkah 10** butuh dataset dari T-023 (Langkah 7) dan memakai kuota Gemini gratis. Bila dijalankan bersamaan dengan uji lain, mudah terkena batas jumlah panggilan.
- **Langkah 11** adalah gladi seluruh aplikasi, sehingga tidak boleh ada yang sedang mengubah kode.

**Aturan yang menjaga langkah paralel tetap aman:**
- Setiap langkah paralel paling banyak berisi **satu** migration baru, sehingga `supabase db push` tidak pernah berjalan dari dua sesi sekaligus.
- Semua package sudah dipasang di T-002, dan semua file bersama Flutter (`main.dart`, beranda, `models.dart`, `widgets.dart`) dibuat di T-006. Tugas lain hanya mengisi file stub miliknya sendiri.

**Bila waktu mepet:** lewati T-022 (Langkah 9 Sesi B), lalu sederhanakan animasi grafik, lalu batas 3 usulan, sesuai PRD.

---

## Prompt

### Langkah 1 · SENDIRIAN · T-001 Siapkan akun, alat, dan keputusan PRD

```
/next-task T-001

Ini tugas bersama manusia. Kamu menuntun saya, dan saya yang membuat akun serta mengambil keputusan.
Baca: CLAUDE.md, todo.md (blok T-001), docs/architecture.md bagian 8 dan 9.

Cara kerja: wawancara, SATU pertanyaan atau SATU instruksi per giliran. Tunggu jawaban saya.
Jangan mengarang nilai key, token, atau keputusan. Kalau saya belum tahu, tulis "BELUM" lalu lanjut.
Urutan:
1. Jalankan `git init` dan buat .gitignore (.env.local, app/env.json, build/, .dart_tool/, .DS_Store).
2. Cek alat dengan `flutter doctor`, `supabase --version`, `deno --version`.
   Untuk yang belum ada, beri cara pasang yang tepat (Homebrew tidak tersedia di laptop ini) lalu tunggu saya memasangnya.
3. Tuntun saya membuat proyek Supabase (region Singapore), API key Gemini (aistudio.google.com),
   dan proyek Firebase (aplikasi Android id.temansenja.app, google-services.json, kunci service account
   ke folder firebase/). Untuk tiap layanan, beri tahu persis di menu mana nilainya diambil.
4. Buat .env.local dari nilai yang saya tempel. Jangan pernah menampilkan ulang isi secret di chat.
5. Untuk keempat usulan di architecture.md bagian 9, tanyakan satu per satu: setuju, ubah, atau tolak.
   Yang disetujui ditulis ke docs/prd.md (F1, F6, F8) beserta baris baru di Riwayat Perubahan.

File yang boleh diubah: .gitignore, .env.local, firebase/google-services.json, firebase/service-account.json,
docs/prd.md, todo.md (blok T-001 saja).
Mode: SENDIRIAN, tidak ada sesi lain.
Test: semua perintah versi di langkah 2 berjalan, dan `flutter devices` menampilkan HP Android.
Penutup: perbarui blok T-001 di todo.md, tambahkan entri di paling bawah progress.md (format "Alur kerja"
di CLAUDE.md, pakai `cat >>`, jangan baca isinya), lalu commit hanya .gitignore dan docs/prd.md.
```

### Langkah 2 · SENDIRIAN · T-002 Kerangka proyek Flutter + Supabase

```
/next-task T-002

Baca: CLAUDE.md, todo.md (blok T-002), docs/architecture.md bagian 2 dan 3.
Buat:
- `flutter create --platforms=android --org id.temansenja app`, lalu `flutter pub add` untuk semua package
  di kriteria T-002 (jangan menambah yang lain).
- android/app/src/main/AndroidManifest.xml: izin INTERNET, CAMERA, RECORD_AUDIO, ACCESS_FINE_LOCATION,
  ACCESS_COARSE_LOCATION, POST_NOTIFICATIONS, `<queries>` untuk speech recognition, dan intent-filter skema
  temansenja host join. Salin firebase/google-services.json ke android/app/ dan pasang plugin Gradle
  com.google.gms.google-services (package id: id.temansenja.app).
- app/env.example.json (SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY kosong) dan app/env.json dari .env.local.
- app/lib/main.dart minimal yang memanggil Supabase.initialize dari --dart-define, dan app/test/smoke_test.dart.
- `supabase init`, `supabase link --project-ref` (dari .env.local), folder supabase/seeds/ dengan .gitkeep,
  supabase/functions/_shared/smoke_test.ts, dan `supabase secrets set` untuk GEMINI_API_KEY dan GEMINI_MODEL dari .env.local, serta
  FIREBASE_SERVICE_ACCOUNT dari isi firebase/service-account.json.

File yang boleh diubah: app/** (proyek baru), supabase/** (hasil init), todo.md (blok T-002), CLAUDE.md
(hanya bila perintah di "Perintah proyek" ternyata salah).
Mode: SENDIRIAN, tidak ada sesi lain. Ini satu-satunya tugas yang boleh menginstal package.
Test: `cd app && flutter test && flutter analyze` dan `deno test supabase/functions/_shared`.
Penutup: perbarui blok T-002 di todo.md, tambahkan entri progress.md (`cat >>`, jangan dibaca),
commit file baru di app/ dan supabase/ (pastikan app/env.json TIDAK ikut ter-commit).
```

### Langkah 3 · Sesi A · T-003 Database akun

```
/next-task T-003

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-003), docs/architecture.md bagian 4
(profiles, foundations) dan 6 (Autentikasi).
Buat:
- supabase/migrations/20261014000100_profiles.sql: tabel foundations dan profiles, trigger on auth.users
  insert yang membuat profiles dan menolak role selain keluarga/relawan, RLS profiles (hanya baris sendiri),
  dan pencegahan perubahan role/foundation_id oleh pemiliknya. Push dengan `supabase db push`.
- supabase/seeds/01_accounts.sql (idempoten, `on conflict do nothing`): Yayasan Demo (verified, kode SENJA1),
  akun pengurus@demo.id (role yayasan, di-set langsung oleh seed), keluarga1@ dan keluarga2@,
  relawan1@ sampai relawan5@demo.id, semuanya dengan password demo1234. Jalankan dengan
  `supabase db query --linked -f`.
- scripts/check_auth.ts (supabase-js lewat npm: specifier): sign-up dengan role yayasan gagal, sign-up dengan
  role keluarga berhasil, user tidak bisa membaca profil orang lain, dan update role milik sendiri gagal.

File yang boleh diubah: supabase/migrations/20261014000100_profiles.sql, supabase/seeds/01_accounts.sql,
scripts/check_auth.ts, todo.md (blok T-003 saja).
Mode paralel: kamu Sesi A di Langkah 3. Sesi B mengerjakan T-004 (rubrik/status) dan Sesi C mengerjakan
T-005 (matching) di folder yang sama. Ikuti "Sesi paralel" di CLAUDE.md. Jangan instal library.
Test: `deno run -A scripts/check_auth.ts`.
Penutup: perbarui hanya blok T-003 di todo.md, tambahkan entri progress.md (`cat >>`, jangan dibaca),
lalu commit hanya file di daftar di atas (`git add <file>` satu per satu).
```

### Langkah 3 · Sesi B · T-004 Rubrik dan aturan status F6

```
/next-task T-004

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-004), docs/prd.md F4 dan F6,
docs/architecture.md bagian 5 "Aturan status".
Buat:
- supabase/functions/_shared/rubric.ts: 7 domain (key: makan, obat, gerak, harian, ingatan, hati, umum),
  4 label per domain sesuai tabel F4 (index 0 = terbaik), dan RED_FLAGS (jatuh, bingung_mendadak,
  sesak_nyeri_dada, tidak_makan, obat_habis, keluhan_baru).
- supabase/functions/_shared/status.ts: computeStatus(visits) sebagai fungsi murni. Input berupa kunjungan
  terkonfirmasi, terurut lama ke baru, dengan final_result {domain: {level|null, evidence}} dan red_flags.
- supabase/functions/_shared/status_test.ts: satu test untuk setiap kasus di kriteria T-004. Tulis test dulu.
- app/lib/shared/rubric.dart (salinan rubrik) dan app/test/rubric_test.dart.

File yang boleh diubah: keempat file di atas ditambah app/test/rubric_test.dart, dan todo.md (blok T-004 saja).
Mode paralel: kamu Sesi B di Langkah 3. Sesi A mengerjakan T-003 (DB akun) dan Sesi C mengerjakan
T-005 (matching). Ikuti "Sesi paralel" di CLAUDE.md, dan jangan ubah status [~] di awal.
Test: `deno test supabase/functions/_shared/status_test.ts` dan `cd app && flutter test test/rubric_test.dart`.
Penutup: perbarui hanya blok T-004, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Langkah 3 · Sesi C · T-005 Algoritma pemasangan

```
/next-task T-005

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-005), docs/prd.md F2 dan F2a,
docs/architecture.md bagian 5 Alur A langkah 2.
Buat:
- supabase/functions/_shared/matching.ts: haversineKm dan pickVolunteer(elder, candidates, excludedIds)
  sebagai fungsi murni tanpa database. Tipe hanya memakai kolom dari architecture.md bagian 4.
- supabase/functions/_shared/matching_test.ts: satu test untuk setiap kasus di kriteria T-005. Tulis test dulu.
  Jarak diformat dengan koma desimal (1,2 km).

File yang boleh diubah: dua file di atas dan todo.md (blok T-005 saja).
Mode paralel: kamu Sesi C di Langkah 3. Sesi A mengerjakan T-003 dan Sesi B mengerjakan T-004.
Ikuti "Sesi paralel" di CLAUDE.md, dan jangan ubah status [~] di awal.
Test: `deno test supabase/functions/_shared/matching_test.ts`.
Penutup: perbarui hanya blok T-005, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Cek gabungan · Langkah 3

```
Tiga sesi baru saja selesai mengerjakan T-003, T-004, dan T-005 di folder ini. Jangan menulis fitur baru.
1. Jalankan `deno test supabase/functions/_shared`, `deno run -A scripts/check_auth.ts`,
   dan `cd app && flutter test && flutter analyze`.
2. Cek di todo.md bahwa blok T-003, T-004, dan T-005 berstatus [x] dengan kriteria tercentang,
   atau [!] beserta penyebabnya.
3. Jalankan `git status`. Seharusnya tidak ada file yang tidak ter-commit, kecuali .env.local dan app/env.json.
4. Bila ada yang gagal, jelaskan penyebab dan perbaikan paling kecil, lalu tunggu persetujuan saya.
5. Tambahkan satu entri "Cek gabungan Langkah 3" di progress.md (`cat >>`).
```

### Langkah 4 · Sesi A · T-006 Kerangka aplikasi

```
/next-task T-006

Baca: CLAUDE.md (termasuk "Sesi paralel" dan Konvensi Flutter), todo.md (blok T-006),
docs/architecture.md bagian 3 dan 4.
Buat:
- app/lib/main.dart: init Supabase dan Firebase, cek sesi, baca profiles.role, panggil registerPush() setelah
  login, buka beranda sesuai peran, dan
  tangani app_links `temansenja://join?code=` dengan membuka JoinScreen(code).
- app/lib/auth/login_screen.dart dan signup_screen.dart (email, password, nama, HP, peran keluarga/relawan,
  dikirim lewat metadata). Sertakan validator.
- Beranda: app/lib/keluarga/home_screen.dart (ElderList + tombol Daftarkan lansia),
  app/lib/relawan/home_screen.dart (bila belum punya baris volunteers → JoinScreen, selain itu PairedElders),
  app/lib/yayasan/home_screen.dart (DashboardSection + tombol Verifikasi relawan + InviteSection).
- Stub, berupa layar atau widget berisi "Belum dibuat" dengan constructor yang sudah benar:
  keluarga/elder_list.dart, keluarga/register_elder_screen.dart, keluarga/proposal_screen.dart (proposalId),
  keluarga/elder_detail_screen.dart (elderId), relawan/join_screen.dart (code?), relawan/paired_elders.dart,
  relawan/visit_story_screen.dart (elderId), relawan/visit_confirm_screen.dart (visitId),
  relawan/emergency_screen.dart (elderId), yayasan/dashboard_section.dart,
  yayasan/verify_volunteers_screen.dart, yayasan/invite_section.dart, yayasan/manual_pair_screen.dart (elderId),
  shared/push_setup.dart (fungsi registerPush() yang belum melakukan apa-apa).
- app/lib/shared/models.dart (kelas data + fromMap untuk setiap tabel) dan app/lib/shared/widgets.dart
  (StatusBadge, DisclaimerLabel).
- app/test/router_test.dart dan app/test/widgets_test.dart.

File yang boleh diubah: semua file di atas dan todo.md (blok T-006 saja). JANGAN sentuh app/lib/shared/rubric.dart.
Mode paralel: kamu Sesi A di Langkah 4. Sesi B mengerjakan T-007 (skema DB) dan Sesi C mengerjakan
T-008 (ekstraksi). Ikuti "Sesi paralel" di CLAUDE.md. Jangan instal library.
Test: `cd app && flutter test test/router_test.dart test/widgets_test.dart && flutter analyze`.
Penutup: perbarui hanya blok T-006, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Langkah 4 · Sesi B · T-007 Skema inti, RLS, dan data demo dasar

```
/next-task T-007

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-007), docs/architecture.md bagian 4 dan 6
(seluruh tabel RLS), supabase/migrations/20261014000100_profiles.sql.
Buat:
- supabase/migrations/20261014000200_core.sql: semua tabel di kriteria, CHECK untuk semua enum,
  index unik parsial proposals(volunteer_id) where state='pending', trigger dua centang → aktif,
  bucket volunteer-photos (privat) beserta policy-nya, RLS untuk setiap baris tabel di architecture.md
  bagian 6, dan `alter publication supabase_realtime add table elders, visits`. Push dengan `supabase db push`.
- supabase/seeds/02_demo_core.sql (idempoten) sesuai kriteria. Pakai koordinat sungguhan di Yogyakarta
  dan buat relawan dengan kombinasi keahlian berbeda supaya pemasangan punya pilihan.
- scripts/check_rls.ts: login sebagai akun seed, lalu cek setiap aturan dan constraint di kriteria.

File yang boleh diubah: tiga file di atas dan todo.md (blok T-007 saja).
Mode paralel: kamu Sesi B di Langkah 4. Sesi A mengerjakan T-006 (Flutter) dan Sesi C mengerjakan T-008.
Kamu satu-satunya sesi yang menjalankan `supabase db push` di langkah ini. Ikuti "Sesi paralel" di CLAUDE.md.
Test: `supabase db query --linked -f supabase/seeds/02_demo_core.sql` lalu `deno run -A scripts/check_rls.ts`.
Penutup: perbarui hanya blok T-007, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Langkah 4 · Sesi C · T-008 Ekstraksi cerita via Gemini

```
/next-task T-008

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-008), docs/prd.md F4,
docs/architecture.md bagian 5 Alur B dan bagian 6 "Validasi input" serta "Data kesehatan",
supabase/functions/_shared/rubric.ts.
Buat:
- supabase/functions/_shared/gemini.ts: generateJson(request, fetchFn = fetch) memakai GEMINI_API_KEY
  dan GEMINI_MODEL dari env, dengan timeout 15 detik.
- supabase/functions/_shared/extract.ts: stripPII, buildRequest (rubrik di system instruction, cerita sebagai
  data yang dibatasi tag, dan responseSchema), serta validateResult. Kalimat bukti dicocokkan setelah
  normalisasi spasi dan huruf kecil.
- supabase/functions/_shared/extract_test.ts (pakai fetch palsu, tidak memanggil API sungguhan).
- scripts/try_extract.ts: satu panggilan sungguhan, dengan key dari .env.local.

File yang boleh diubah: empat file di atas dan todo.md (blok T-008 saja).
Mode paralel: kamu Sesi C di Langkah 4. Sesi A mengerjakan T-006 dan Sesi B mengerjakan T-007.
Ikuti "Sesi paralel" di CLAUDE.md, dan jangan ubah status [~] di awal.
Test: `deno test supabase/functions/_shared/extract_test.ts` dan `deno run -A scripts/try_extract.ts`.
Penutup: perbarui hanya blok T-008, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Cek gabungan · Langkah 4

```
Tiga sesi baru saja selesai mengerjakan T-006, T-007, dan T-008 di folder ini. Jangan menulis fitur baru.
1. Jalankan `deno test supabase/functions/_shared`, `deno run -A scripts/check_auth.ts`,
   `deno run -A scripts/check_rls.ts`, dan `cd app && flutter test && flutter analyze`.
2. Jalankan aplikasi (`cd app && flutter run --dart-define-from-file=env.json`) lalu login sebagai keluarga1,
   relawan1, dan pengurus. Pastikan ketiga beranda terbuka dan semua stub bisa diklik.
   Pastikan juga models.dart cocok dengan kolom di migration core (nama dan tipe).
3. Cek blok T-006, T-007, dan T-008 di todo.md, lalu jalankan `git status`.
4. Bila ada yang gagal, jelaskan penyebab dan perbaikan paling kecil, lalu tunggu persetujuan saya.
5. Tambahkan entri "Cek gabungan Langkah 4" di progress.md (`cat >>`).
```

### Langkah 5 · Sesi A · T-010 Edge Function `visit`

```
/next-task T-010

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-010), docs/architecture.md bagian 5 Alur B
dan bagian 6, supabase/functions/_shared/{status,extract,gemini,rubric}.ts.
Buat:
- supabase/functions/visit/index.ts: cek JWT pemanggil, pastikan dia relawan pasangan lansia, validasi body,
  lalu aksi extract (ambil answers, stripPII dengan nama dan alamat lansia, panggil Gemini, validateResult,
  simpan ai_result) atau confirm (simpan final_result dan confirmed_at, ambil semua kunjungan terkonfirmasi,
  jalankan computeStatus, perbarui elders). Kolom terlindung ditulis dengan service_role.
  Deploy dengan `supabase functions deploy visit`.
- scripts/try_visit.ts sesuai kriteria.

File yang boleh diubah: dua file di atas dan todo.md (blok T-010 saja). Jangan ubah file di _shared/.
Bila ada bug di sana, catat di Catatan lalu tanya saya.
Mode paralel: kamu Sesi A di Langkah 5. Sesi B mengerjakan T-011 (pairing) dan Sesi C mengerjakan
T-009 (cerita demo). Ikuti "Sesi paralel" di CLAUDE.md.
Test: `deno run -A scripts/try_visit.ts`.
Penutup: perbarui hanya blok T-010, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Langkah 5 · Sesi B · T-011 Edge Function `pairing` dan kartu usulan

```
/next-task T-011

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-011), docs/prd.md F2 dan F2a,
docs/architecture.md bagian 4 (proposals, elders) dan 5 Alur A, supabase/functions/_shared/matching.ts.
Buat:
- supabase/migrations/20261014000300_pairing.sql: RPC get_proposal_card(proposal_id) dengan security definer
  yang mengecek pemanggil adalah keluarga pemilik lansia. Push dengan `supabase db push`.
- supabase/functions/pairing/index.ts: aksi propose, accept, reject, dan manual sesuai kriteria. Kandidat diambil
  dengan query (status aktif, bukan rejected atau pending untuk lansia ini, hitung beban), lalu dipilih dengan
  pickVolunteer. Bila insert pending melanggar index unik (bentrok), coba kandidat berikutnya.
  Deploy dengan `supabase functions deploy pairing`.
- scripts/try_pairing.ts sesuai kriteria. Pakai lansia milik keluarga2 dari seed, dan kembalikan datanya
  ke kondisi awal di akhir skrip, kecuali bila dijalankan dengan `--keep` (dipakai T-019 untuk menyisakan
  lansia perlu_yayasan).

File yang boleh diubah: tiga file di atas dan todo.md (blok T-011 saja).
Mode paralel: kamu Sesi B di Langkah 5. Sesi A mengerjakan T-010 dan Sesi C mengerjakan T-009.
Kamu satu-satunya sesi yang menjalankan `supabase db push` di langkah ini. Ikuti "Sesi paralel" di CLAUDE.md.
Test: `deno run -A scripts/try_pairing.ts` dan `deno test supabase/functions/_shared/matching_test.ts`.
Penutup: perbarui hanya blok T-011, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Langkah 5 · Sesi C · T-009 Data demo: 6 cerita Ibu Sri (bersama manusia)

```
/next-task T-009

Ini tugas bersama manusia. Isi cerita harus disetujui tim, jadi jangan menganggapnya fakta sebelum saya setuju.
Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-009), docs/prd.md F3, F4, F6 dan
"Skenario demo Alur B", supabase/functions/_shared/{rubric,status}.ts, supabase/seeds/02_demo_core.sql.
Cara kerja: wawancara, satu pertanyaan per giliran.
1. Tanyakan gambaran Ibu Sri yang kami inginkan (usia, kebiasaan, gaya bicara relawan, apakah ada campuran
   bahasa Jawa). Jangan mengarang detail yang belum saya jawab.
2. Usulkan kunjungan 1. Tunjukkan 7 jawaban beserta level dan kalimat buktinya, lalu tunggu "setuju" atau
   koreksi. Ulangi untuk kunjungan 2–6, dengan penurunan perlahan yang TIDAK memicu Perlu perhatian.
3. Usulkan dua cerita ke-7 (versi Perlu perhatian dan versi terpeleset), lalu tunggu persetujuan.
4. Tulis supabase/seeds/ibu_sri.json, supabase/seeds/03_visits_ibu_sri.sql (sekaligus skrip reset demo:
   hapus kunjungan dan kejadian darurat Ibu Sri selain 6 ini, lalu kembalikan status ke stabil),
   docs/demo-script.md, dan test
   "demo Ibu Sri" di status_test.ts yang membaca ibu_sri.json (cerita ke-7 versi 1 → perlu_perhatian,
   versi 2 → segera_dikabari).

File yang boleh diubah: supabase/seeds/ibu_sri.json, supabase/seeds/03_visits_ibu_sri.sql, docs/demo-script.md,
supabase/functions/_shared/status_test.ts (hanya menambah test), dan todo.md (blok T-009 saja).
Mode paralel: kamu Sesi C di Langkah 5. Sesi A mengerjakan T-010 dan Sesi B mengerjakan T-011.
Ikuti "Sesi paralel" di CLAUDE.md, dan jangan ubah status [~] di awal.
Test: `deno test supabase/functions/_shared/status_test.ts` dan
`supabase db query --linked -f supabase/seeds/03_visits_ibu_sri.sql` (jalankan dua kali untuk membuktikan idempoten).
Penutup: perbarui hanya blok T-009, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Cek gabungan · Langkah 5

```
Tiga sesi baru saja selesai mengerjakan T-009, T-010, dan T-011 di folder ini. Jangan menulis fitur baru.
1. Jalankan `deno test supabase/functions/_shared`, `deno run -A scripts/check_rls.ts`,
   `deno run -A scripts/try_visit.ts`, dan `deno run -A scripts/try_pairing.ts`.
2. Pastikan elders.status Ibu Sri setelah seed 03 adalah stabil. Bila try_visit mengubahnya,
   muat ulang seed 03 dan pastikan statusnya kembali.
3. Cek blok T-009, T-010, dan T-011 di todo.md, lalu jalankan `git status`.
4. Bila ada yang gagal, jelaskan penyebab dan perbaikan paling kecil, lalu tunggu persetujuan saya.
5. Tambahkan entri "Cek gabungan Langkah 5" di progress.md (`cat >>`).
```

### Langkah 6 · Sesi A · T-012 Layar relawan: pasangan, cerita, konfirmasi

```
/next-task T-012

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-012), docs/prd.md F3 dan F5,
app/lib/shared/{models,widgets,rubric}.dart, supabase/functions/visit/index.ts (bentuk request dan response).
Isi stub:
- app/lib/relawan/paired_elders.dart, visit_story_screen.dart, dan visit_confirm_screen.dart sesuai kriteria.
  Mengetik saja; tombol mikrofon dibuat di T-022. Panggil fungsi dengan `supabase.functions.invoke('visit', ...)`.
- app/test/visit_confirm_test.dart.

File yang boleh diubah: empat file di atas dan todo.md (blok T-012 saja).
Mode paralel: kamu Sesi A di Langkah 6. Sesi B mengerjakan T-013 (detail keluarga) dan Sesi C mengerjakan
T-014 (daftar lansia). Ikuti "Sesi paralel" di CLAUDE.md. Jangan instal library, dan jangan ubah models.dart
atau widgets.dart (bila perlu, tanya saya).
Test: `cd app && flutter test test/visit_confirm_test.dart`, lalu uji manual login relawan1 → cerita untuk Ibu Sri.
Penutup: perbarui hanya blok T-012, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Langkah 6 · Sesi B · T-013 Layar keluarga: rekap, status, tren

```
/next-task T-013

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-013), docs/prd.md F6 dan F7,
app/lib/shared/{models,widgets,rubric}.dart, supabase/seeds/ibu_sri.json.
Isi stub:
- app/lib/keluarga/elder_detail_screen.dart sesuai kriteria (StreamBuilder dengan supabase.from(...).stream,
  fl_chart LineChart per domain).
- app/test/elder_detail_test.dart yang memakai data dari ibu_sri.json.

File yang boleh diubah: dua file di atas dan todo.md (blok T-013 saja).
Mode paralel: kamu Sesi B di Langkah 6. Sesi A mengerjakan T-012 dan Sesi C mengerjakan T-014.
Ikuti "Sesi paralel" di CLAUDE.md, dan jangan ubah status [~] di awal.
Test: `cd app && flutter test test/elder_detail_test.dart`, lalu uji manual login keluarga1 → Ibu Sri.
Penutup: perbarui hanya blok T-013, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Langkah 6 · Sesi C · T-014 Keluarga mendaftarkan lansia

```
/next-task T-014

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-014), docs/prd.md F1 (dan keputusan T-001),
docs/architecture.md bagian 4 (elders, health_profiles), app/lib/shared/{models,widgets}.dart,
supabase/functions/pairing/index.ts (aksi propose).
Isi stub:
- app/lib/keluarga/register_elder_screen.dart dan app/lib/keluarga/elder_list.dart sesuai kriteria.
  Setelah lansia tersimpan, buka ProposalScreen bila ada usulan pending.
- app/test/register_elder_test.dart.

File yang boleh diubah: tiga file di atas dan todo.md (blok T-014 saja).
Mode paralel: kamu Sesi C di Langkah 6. Sesi A mengerjakan T-012 dan Sesi B mengerjakan T-013.
Ikuti "Sesi paralel" di CLAUDE.md, dan jangan ubah status [~] di awal.
Test: `cd app && flutter test test/register_elder_test.dart`, lalu uji manual login keluarga2 → daftarkan lansia baru.
Penutup: perbarui hanya blok T-014, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Cek gabungan · Langkah 6

```
Tiga sesi baru saja selesai mengerjakan T-012, T-013, dan T-014 di folder ini. Jangan menulis fitur baru.
1. Jalankan `cd app && flutter test && flutter analyze` dan `deno test supabase/functions/_shared`.
2. Uji manual dengan dua HP atau emulator: relawan1 mengirim cerita ke-7 versi "Perlu perhatian" dari
   docs/demo-script.md, lalu pastikan halaman keluarga1 berubah tanpa refresh. Setelah itu muat ulang seed 03.
3. Cek blok T-012, T-013, dan T-014 di todo.md, lalu jalankan `git status`.
4. Bila ada yang gagal, jelaskan penyebab dan perbaikan paling kecil, lalu tunggu persetujuan saya.
5. Tambahkan entri "Cek gabungan Langkah 6" di progress.md (`cat >>`).
```

### Langkah 7 · Sesi A · T-015 Keluarga meninjau usulan

```
/next-task T-015

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-015), docs/prd.md F2a,
supabase/migrations/20261014000300_pairing.sql (get_proposal_card), supabase/functions/pairing/index.ts.
Isi stub:
- app/lib/keluarga/proposal_screen.dart sesuai kriteria.
- app/test/proposal_screen_test.dart.

File yang boleh diubah: dua file di atas dan todo.md (blok T-015 saja).
Mode paralel: kamu Sesi A di Langkah 7. Sesi B mengerjakan T-016 (relawan bergabung) dan Sesi C mengerjakan
T-023 (dataset evaluasi). Ikuti "Sesi paralel" di CLAUDE.md.
Test: `cd app && flutter test test/proposal_screen_test.dart`, lalu uji manual keluarga2: tolak 2×, lalu terima.
Penutup: perbarui hanya blok T-015, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Langkah 7 · Sesi B · T-016 Relawan bergabung lewat undangan

```
/next-task T-016

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-016), docs/prd.md F1a,
docs/architecture.md bagian 4 (volunteers) dan 6, supabase/migrations/20261014000200_core.sql.
Buat:
- supabase/migrations/20261014000400_join.sql: RPC join_foundation (security definer, cek foundations.verified).
  Push dengan `supabase db push`.
- Isi stub app/lib/relawan/join_screen.dart sesuai kriteria. OTP simulasi dibuat di sisi aplikasi; setelah cocok,
  set profiles.phone_verified lewat RPC yang sama.
- app/test/join_screen_test.dart.

File yang boleh diubah: tiga file di atas dan todo.md (blok T-016 saja).
Mode paralel: kamu Sesi B di Langkah 7. Sesi A mengerjakan T-015 dan Sesi C mengerjakan T-023.
Kamu satu-satunya sesi yang menjalankan `supabase db push` di langkah ini. Ikuti "Sesi paralel" di CLAUDE.md.
Test: `cd app && flutter test test/join_screen_test.dart`, lalu uji manual: daftar akun relawan baru →
buka temansenja://join?code=SENJA1 lewat `adb shell am start -d` → status terdaftar.
Penutup: perbarui hanya blok T-016, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Langkah 7 · Sesi C · T-023 Dataset evaluasi (bersama manusia)

```
/next-task T-023

Ini tugas bersama manusia. Label adalah keputusan manusia, jadi jangan mengisi label final tanpa persetujuan.
Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-023), docs/prd.md F4 dan Metrik Sukses,
supabase/functions/_shared/rubric.ts.
Cara kerja: wawancara, satu pertanyaan per giliran.
1. Tanyakan apakah tim punya contoh cerita nyata (misalnya dari yayasan). Bila ada, saya tempel dan kamu
   memformatnya. Bila tidak, usulkan cerita dalam kelompok berisi 5, dengan variasi bahasa santai, campuran
   bahasa Jawa, domain yang tidak disebut, dan tanda bahaya.
2. Untuk setiap kelompok, tampilkan usulan label lalu tunggu koreksi saya. Label adalah keputusan saya.
3. Tulis ke data/eval/stories.jsonl setelah setiap kelompok disetujui, supaya pekerjaan tidak hilang.
4. Di akhir, tanyakan siapa yang memeriksa label sebagai orang kedua, lalu catat namanya.

File yang boleh diubah: data/eval/stories.jsonl dan todo.md (blok T-023 saja).
Mode paralel: kamu Sesi C di Langkah 7. Sesi A mengerjakan T-015 dan Sesi B mengerjakan T-016.
Ikuti "Sesi paralel" di CLAUDE.md, dan jangan ubah status [~] di awal.
Test: `deno eval` singkat untuk memastikan setiap baris JSON valid dan menghitung jumlah cerita bahasa Jawa
dan cerita bertanda bahaya sesuai kriteria.
Penutup: perbarui hanya blok T-023, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Cek gabungan · Langkah 7

```
Tiga sesi baru saja selesai mengerjakan T-015, T-016, dan T-023 di folder ini. Jangan menulis fitur baru.
1. Jalankan `cd app && flutter test && flutter analyze`, `deno test supabase/functions/_shared`,
   dan `deno run -A scripts/check_rls.ts`.
2. Uji manual Alur A: keluarga2 mendaftarkan lansia → usulan → tolak → usulan berikutnya → terima →
   relawan tersebut melihat lansianya.
3. Cek blok T-015, T-016, dan T-023 di todo.md, lalu jalankan `git status`.
4. Bila ada yang gagal, jelaskan penyebab dan perbaikan paling kecil, lalu tunggu persetujuan saya.
5. Tambahkan entri "Cek gabungan Langkah 7" di progress.md (`cat >>`).
```

### Langkah 8 · Sesi A · T-018 Dashboard yayasan

```
/next-task T-018

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-018), docs/prd.md F9 dan F2 (ringkasan kondisi),
docs/architecture.md bagian 6, app/lib/shared/{models,widgets}.dart.
Buat:
- supabase/migrations/20261014000500_dashboard.sql: RPC foundation_dashboard() (security definer, cek role
  yayasan, filter foundation_id). Push dengan `supabase db push`.
- Isi stub app/lib/yayasan/dashboard_section.dart. Lansia perlu_yayasan membuka ManualPairScreen(elderId).
- app/test/dashboard_section_test.dart.

File yang boleh diubah: tiga file di atas dan todo.md (blok T-018 saja).
Mode paralel: kamu Sesi A di Langkah 8. Sesi B mengerjakan T-019 (pasang manual) dan Sesi C mengerjakan
T-020 (push notification). Kamu satu-satunya sesi yang menjalankan `supabase db push` di langkah ini.
Ikuti "Sesi paralel" di CLAUDE.md.
Test: `cd app && flutter test test/dashboard_section_test.dart`, lalu uji manual login pengurus.
Penutup: perbarui hanya blok T-018, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Langkah 8 · Sesi B · T-019 Pasang manual oleh yayasan

```
/next-task T-019

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-019), docs/prd.md F2a,
supabase/functions/pairing/index.ts (aksi manual), app/lib/shared/models.dart.
Isi stub:
- app/lib/yayasan/manual_pair_screen.dart sesuai kriteria. Jarak dihitung di aplikasi dengan rumus haversine
  yang sama seperti matching.ts (cukup satu fungsi kecil di file ini).

File yang boleh diubah: app/lib/yayasan/manual_pair_screen.dart dan todo.md (blok T-019 saja).
Mode paralel: kamu Sesi B di Langkah 8. Sesi A mengerjakan T-018 dan Sesi C mengerjakan T-020.
Ikuti "Sesi paralel" di CLAUDE.md, dan jangan ubah status [~] di awal.
Test: `cd app && flutter analyze`, lalu uji manual: `deno run -A scripts/try_pairing.ts --keep`,
lalu login pengurus → pasangkan → status berpasangan.
Penutup: perbarui hanya blok T-019, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Langkah 8 · Sesi C · T-020 Push notification (FCM)

```
/next-task T-020

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-020), docs/architecture.md bagian 5 Alur C
("Mendaftarkan HP untuk notifikasi") dan bagian 6 (Menyimpan rahasia), supabase/functions/visit/index.ts,
app/lib/main.dart (tempat registerPush() dipanggil).
Buat:
- supabase/functions/_shared/push.ts: buat JWT RS256 dari service account (scope
  https://www.googleapis.com/auth/firebase.messaging) dengan WebCrypto atau npm:jose, tukar menjadi access token,
  lalu POST ke https://fcm.googleapis.com/v1/projects/<project_id>/messages:send untuk setiap token.
  Token yang dibalas UNREGISTERED cukup dilewati.
- supabase/functions/_shared/push_test.ts dengan fetch palsu (tidak memanggil Google sungguhan).
- Isi stub app/lib/shared/push_setup.dart (firebase_messaging sudah terpasang di T-002).
- Di supabase/functions/visit/index.ts, kirim push ke keluarga dan pengurus yayasan saat status berubah menjadi
  segera_dikabari, lalu deploy ulang.

File yang boleh diubah: empat file di atas dan todo.md (blok T-020 saja).
Mode paralel: kamu Sesi C di Langkah 8. Sesi A mengerjakan T-018 dan Sesi B mengerjakan T-019.
Ikuti "Sesi paralel" di CLAUDE.md, dan jangan ubah status [~] di awal.
Test: `deno test supabase/functions/_shared/push_test.ts`. Uji manual dengan 2 HP: keluarga1 login di HP 1 lalu
tutup aplikasinya, relawan1 di HP 2 mengirim cerita "terpeleset", lalu notifikasi muncul di HP 1 dan membuka
detail Ibu Sri saat diketuk. Muat ulang seed 03 setelahnya.
Penutup: perbarui hanya blok T-020, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Cek gabungan · Langkah 8

```
Tiga sesi baru saja selesai mengerjakan T-018, T-019, dan T-020 di folder ini. Jangan menulis fitur baru.
1. Jalankan `cd app && flutter test && flutter analyze`, `deno test supabase/functions/_shared`,
   `deno run -A scripts/check_rls.ts`, dan `deno run -A scripts/try_visit.ts`.
2. Pastikan dashboard pengurus menampilkan Ibu Sri dengan urutan status yang benar, dan bahwa RPC
   foundation_dashboard tidak mengembalikan kolom profil kesehatan.
3. Cek blok T-018, T-019, dan T-020 di todo.md, lalu jalankan `git status`.
4. Bila ada yang gagal, jelaskan penyebab dan perbaikan paling kecil, lalu tunggu persetujuan saya.
5. Tambahkan entri "Cek gabungan Langkah 8" di progress.md (`cat >>`).
```

### Langkah 9 · Sesi A · T-021 Tombol Darurat

```
/next-task T-021

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-021), docs/prd.md F8, docs/architecture.md
bagian 5 Alur C, supabase/functions/_shared/push.ts, app/lib/keluarga/elder_detail_screen.dart.
Buat:
- supabase/functions/emergency/index.ts. Deploy dengan `supabase functions deploy emergency`.
- Isi stub app/lib/relawan/emergency_screen.dart (geolocator, layar simulasi 119, profil + DisclaimerLabel).
- Tambahkan bagian "Riwayat darurat" di app/lib/keluarga/elder_detail_screen.dart.
- app/test/emergency_screen_test.dart.

File yang boleh diubah: empat file di atas dan todo.md (blok T-021 saja).
Mode paralel: kamu Sesi A di Langkah 9. Sesi B mengerjakan T-022 (rekam suara) dan Sesi C mengerjakan
T-017 (verifikasi relawan). Ikuti "Sesi paralel" di CLAUDE.md.
Test: `cd app && flutter test test/emergency_screen_test.dart`, lalu uji manual di HP sungguhan
(GPS + push notification muncul di HP keluarga1 dan pengurus).
Penutup: perbarui hanya blok T-021, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Langkah 9 · Sesi B · T-022 Rekam suara (opsional, dipangkas pertama)

```
/next-task T-022

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-022), docs/prd.md F3,
app/lib/relawan/visit_story_screen.dart.
Buat: tombol mikrofon per pertanyaan dengan package speech_to_text (sudah terpasang), localeId id_ID.
Teks dikte ditambahkan ke controller, dan tombol disembunyikan bila izin ditolak atau STT tidak tersedia.

File yang boleh diubah: app/lib/relawan/visit_story_screen.dart dan todo.md (blok T-022 saja).
Mode paralel: kamu Sesi B di Langkah 9. Sesi A mengerjakan T-021 dan Sesi C mengerjakan T-017.
Ikuti "Sesi paralel" di CLAUDE.md, dan jangan ubah status [~] di awal.
Test: `cd app && flutter analyze && flutter test test/visit_confirm_test.dart`, lalu uji manual di HP sungguhan.
Penutup: perbarui hanya blok T-022, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Langkah 9 · Sesi C · T-017 Verifikasi relawan dan undangan

```
/next-task T-017

Baca: CLAUDE.md (termasuk "Sesi paralel"), todo.md (blok T-017), docs/prd.md F1a dan F1b,
supabase/migrations/20261014000200_core.sql (trigger dua centang, policy foto), app/lib/shared/models.dart.
Isi stub:
- app/lib/yayasan/verify_volunteers_screen.dart dan app/lib/yayasan/invite_section.dart sesuai kriteria.
- app/test/invite_section_test.dart.

File yang boleh diubah: tiga file di atas dan todo.md (blok T-017 saja).
Mode paralel: kamu Sesi C di Langkah 9. Sesi A mengerjakan T-021 dan Sesi B mengerjakan T-022.
Ikuti "Sesi paralel" di CLAUDE.md, dan jangan ubah status [~] di awal.
Test: `cd app && flutter test test/invite_section_test.dart`, lalu uji manual: login pengurus → centang dua
untuk relawan5 → status aktif, lalu nama pengurus dan waktunya tampil.
Penutup: perbarui hanya blok T-017, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Cek gabungan · Langkah 9

```
Tiga sesi baru saja selesai mengerjakan T-017, T-021, dan T-022 di folder ini. Jangan menulis fitur baru.
1. Jalankan `cd app && flutter test && flutter analyze`, `deno test supabase/functions/_shared`,
   dan `deno run -A scripts/check_rls.ts`.
2. Uji manual Alur C dari awal sampai akhir dan alur relawan baru (undangan → verifikasi → aktif).
3. Cek blok T-017, T-021, dan T-022 di todo.md, lalu jalankan `git status`.
4. Bila ada yang gagal, jelaskan penyebab dan perbaikan paling kecil, lalu tunggu persetujuan saya.
5. Tambahkan entri "Cek gabungan Langkah 9" di progress.md (`cat >>`).
```

### Langkah 10 · SENDIRIAN · T-024 Skrip akurasi ekstraksi

```
/next-task T-024

Baca: CLAUDE.md, todo.md (blok T-024), docs/prd.md Metrik Sukses, supabase/functions/_shared/{extract,gemini}.ts,
data/eval/stories.jsonl.
Buat scripts/eval_extraction.ts sesuai kriteria, dengan jeda antar panggilan supaya tidak terkena batas free tier.
Bila mendapat 429, tunggu lalu ulangi. Jalankan, lalu salin hasilnya ke docs/demo-script.md bagian "Angka untuk pitch".
Jangan mengubah prompt ekstraksi di tugas ini. Bila akurasi rendah, catat domain terlemah di "Usulan" di todo.md.

File yang boleh diubah: scripts/eval_extraction.ts, docs/demo-script.md, dan todo.md (blok T-024 dan bagian Usulan).
Mode: SENDIRIAN, tidak ada sesi lain (kuota Gemini dipakai penuh).
Test: `deno run -A scripts/eval_extraction.ts`.
Penutup: perbarui blok T-024, tambahkan entri progress.md (`cat >>`), dan commit hanya file di atas.
```

### Langkah 11 · SENDIRIAN · T-025 Gladi demo end-to-end

```
/next-task T-025

Baca: CLAUDE.md, todo.md (semua blok, termasuk tugas yang dipangkas), docs/demo-script.md, docs/prd.md
"Skenario demo Alur B" dan Metrik Sukses.
Cara kerja: kamu memandu gladi, sedangkan saya yang memegang HP.
1. Muat ulang seed (01, 02, 03 dengan `supabase db query --linked -f`), lalu jalankan check_auth.ts, check_rls.ts, semua deno test,
   flutter test, dan flutter analyze.
2. `cd app && flutter build apk --dart-define-from-file=env.json`, lalu pasang di HP demo.
3. Bacakan langkah demo-script.md satu per satu, lalu tanyakan hasilnya setelah setiap langkah.
   Catat setiap hal yang meleset.
4. Perbaiki hanya bug kecil (≤ 10 baris), satu per satu dengan persetujuan saya. Bug yang lebih besar dicatat
   di Catatan T-025 sebagai risiko pitch.
5. Ulangi gladi sampai berhasil dua kali berturut-turut.

File yang boleh diubah: file yang perlu diperbaiki (sebutkan dulu sebelum mengubah), docs/demo-script.md,
dan todo.md.
Mode: SENDIRIAN, tidak ada sesi lain (tidak boleh ada perubahan kode selama gladi).
Test: semua perintah di langkah 1.
Penutup: perbarui blok T-025, tambahkan entri progress.md (`cat >>`), lalu commit. Sarankan /handoff.
```

---

## Langkah lanjutan (setelah 15 Okt)

Tugas T-001–T-024 dan fitur tambahan F10–F17 sudah selesai (lihat "Catatan sesi terakhir" di `todo.md`).
Langkah berikut dikerjakan **sendirian** (satu sesi), karena menyentuh banyak layar bersama.

### Langkah 12 · SENDIRIAN · Menyesuaikan desain Figma (3 navbar per peran)
```
Baca CLAUDE.md, "Catatan sesi terakhir" di todo.md, tabel F10–F17 di docs/prd.md, dan semua gambar di docs/figma/.
Jangan menulis kode dulu. Buat tabel pemetaan: untuk setiap peran (keluarga, relawan, yayasan), tab mana di navbar
Figma berisi fitur dan layar apa yang sudah ada di app/lib/. Tandai fitur yang tidak punya tempat di Figma dan
layar Figma yang belum punya fitur. Tunggu persetujuan saya. Setelah disetujui: pakai NavigationBar bawaan
Flutter (tanpa package navigasi baru), sesuaikan warna/huruf/jarak dari Figma, jangan menghapus fitur, perbarui
test yang terdampak, jalankan flutter test dan flutter analyze, lalu perbarui todo.md dan progress.md.
```

### Langkah 13 · SENDIRIAN · Gladi demo (T-025)
```
Baca CLAUDE.md, docs/demo-script.md, dan daftar "Uji di HP saat gladi" di bagian Usulan todo.md. Jalankan reset demo,
pasang aplikasi di HP (flutter run --dart-define-from-file=env.json), lalu pandu saya satu per satu melalui setiap
daftar uji. Catat yang gagal di blok T-025, perbaiki satu per satu dengan test, dan perbarui progress.md.
```

### Langkah 14 · SENDIRIAN · Keamanan lanjutan
```
Baca CLAUDE.md dan bagian Usulan todo.md. Kerjakan: (1) K4 — isi notifikasi di layar kunci dibuat umum ("Ada kabar
penting tentang <nama>, buka aplikasi"), detail hanya di dalam aplikasi; (2) tombol "Saya merasa tidak aman" untuk
relawan yang mengirim lokasinya ke yayasan. Tambahkan serangannya ke scripts/check_security.ts, jalankan semua test
dan skrip uji (reset demo di antara skrip), lalu perbarui todo.md, progress.md, dan Log keputusan.
```

### Sebelum produksi (bukan untuk demo)
K2 konfirmasi email (butuh SMTP sendiri), K3 aturan kata sandi, payment gateway sungguhan (webhook mengisi
`paid_until`), lisensi citra satelit, server pencarian peta sendiri, nomor HP relawan disamarkan.

