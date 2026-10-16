# Todo — TemanSenja

Status: `[ ]` belum · `[~]` sedang dikerjakan · `[x]` selesai (semua kriteria terbukti) · `[!]` macet (lihat Catatan)

Urutan pengerjaan dan prompt siap pakai ada di `prompt.md`. Tugas bertanda **(bisa paralel)** dikerjakan
bersamaan dengan tugas lain dalam satu langkah, di folder yang sama.

Deadline: **15 Oktober 2026 pukul 23.50.** Bila waktu mepet, pangkas sesuai PRD dengan urutan
T-022 (rekam suara), lalu animasi grafik, lalu batas 3 usulan.

---

## Catatan sesi terakhir

- **Tanggal:** 2026-10-16
- **KEAMANAN — JANGAN PUBLIKASIKAN ULANG TANPA IZIN BARU:** T-033 selesai menangani pembatasan key Firebase: Android package/sertifikat APK cocok, allowlist 25 → 4 API, 6 uji langsung lulus. Repository AltoDevv/rela tetap private (diperiksa ulang API); riwayat/ZIP lama tetap private sebagai bukti. Key client dipertahankan dengan pembatasan yang sudah diuji, bukan dirotasi. Jangan cetak key atau unggah arsip lama. Laporan: `dist/security/SECURITY-REVIEW.md`.
- **Selesai sebelumnya (T-032):** source perubahan T-030–031 sudah dipush ke AltoDevv/rela, commit `0e5c15b`; rilis **v1.0.1 (build 2)** menjadi latest dengan APK/source ZIP/checksum/panduan. Keempat lampiran berhasil diunduh tanpa login (HTTP 200) dan checksum cocok. Repository yang sempat private dipulihkan public sesuai persetujuan pengguna. **Posisi sebelum T-033: 30/32**; tersisa T-023 `[!]` dan T-025 `[ ]`.
- **Selesai sebelumnya (T-031):** timeline Beranda mengikuti Home.png dengan titik aktif berlingkar, garis vertikal tersambung sesuai tinggi kartu, kartu krem, tombol Tampilkan ke tab Lansia, serta tombol garis putus-putus. Proporsi header dan riwayat dirapikan. **Posisi sebelum T-032: 29/31**; tersisa T-023 `[!]` dan T-025 `[ ]`.
- **Selesai sebelumnya (T-030):** Atur/Ubah jadwal dan Geser kunjungan pindah dari Beranda ke tab Lansia dan mengikuti dropdown; tab Lansia menampilkan jadwal rutin, waktu berikutnya, status usulan, dan geseran. Beranda menjadi ringkasan tanpa pemilih kartu; target rekap/riwayat/darurat otomatis dari kunjungan belum dicatat hari ini lalu jadwal terdekat. Dialog jadwal bisa digulir di HP kecil. **Posisi sebelum T-031: 28/30**; tersisa T-023 `[!]` dan T-025 `[ ]`.
- **Selesai sebelumnya (T-029):** APK rilis universal dibangun; source dan APK dipublikasikan dengan persetujuan pengguna di https://github.com/AltoDevv/rela (release v1.0.0, commit snapshot fc5f46a). Unduhan tanpa login dan checksum cocok, pemasangan ke emulator kosong berhasil, serta login server ketiga akun demo berhasil. Proposal Google Docs berhasil dibaca dan direview. PDF pitch deck 11 slide dari pengguna sudah dibaca dan diperiksa visual; review dan teks pengganti disimpan di `dist/submission/review-pitch-deck.md`. Dokumen asli belum diubah; proposal dan deck masih perlu direvisi sesuai catatan. Sebelumnya T-026–028 menyelesaikan desain baru, perbaikan alur rekap, dan menghilangkan banner DEBUG. Pekerjaan sebelumnya yang sudah tersedia:
  1. **Figma tiga peran:**
     - Relawan: 4 tab Beranda · Lansia · Riwayat · Profil + pengunduran diri.
     - Yayasan: 4 tab Beranda · Relawan · Ulasan · Profil.
     - Keluarga: 3 tab Beranda · Riwayat · Profil, detail lansia bertab Lansia/Relawan, daftar lansia 5 langkah.
  2. **Pencocokan ulang otomatis lintas yayasan** saat relawan lepas (`_shared/propose.ts`). Usulan ke-3 tidak bisa ditolak; minta ganti 1× per lansia.
  3. **Kotak masuk notifikasi:** tabel `notifications`, helper `notify`, lonceng.
  4. **Foto profil** keluarga & yayasan.
  5. **Alamat terisi dari titik peta.**
  6. **Kode undangan bersama dihapus dari UI.**
  7. **Jadwal kunjungan rutin:** relawan usul, keluarga setuju, bisa digeser, pengingat H-1.
  8. **Pengaturan notifikasi per kategori.**
  9. **Data baru:** nama panggilan/tanggal lahir relawan dan lansia, status per kunjungan.

  Migration 20261016000100–000600 **sudah di-push**. Function pairing, visit, account, emergency, review, dan reminders **sudah di-deploy**.
- **Selesai terbaru:** T-033 `[x]`: setelah izin JavaScript Chrome diaktifkan pengguna, pembatasan Cloud key Android temansenja disimpan/dibaca ulang dan 6/6 uji langsung lulus. Hanya 4 API pendukung FCM, dibatasi package serta SHA-1 APK. Kedua proyek Firebase/Gemini saat ini tanpa linked billing account; metrik agregat 30 hari ditinjau (bukan bukti atribusi pemakaian atau riwayat tagihan). Pengemas 9/9 test lulus. **31/33** tugas selesai; T-023/T-025 masih tersisa. Tidak ada key server Gemini/private key ditemukan pada materi publik yang diaudit sebelumnya.
- **Proyek Cloud teridentifikasi:** Firebase `temansenja` (nomor `1026966001643`), berbeda dari Default Gemini Project (`gen-lang-client-0924688717`). Firebase Android app metadata HTTP 200 mengonfirmasi UID key di halaman Cloud cocok dengan aplikasi. Pembatasan Android: `id.temansenja.app`, SHA-1 `C1:E6:B7:90:BD:4B:25:90:17:ED:34:80:F5:19:78:E5:11:78:7A:9E`. Allowlist: Firebase Management, Cloud Logging, Firebase Installations, FCM Registration. Tiga key proyek Gemini tetap dibatasi Gemini API dan tidak diubah.
- **Akses Chrome:** penolakan awal JavaScript/assistive access sudah diatasi pengguna dengan mengaktifkan View → Developer → Allow JavaScript from Apple Events. Otomasi JavaScript kemudian berhasil; tidak membuka Show key atau membaca nilai key dari Chrome. Tidak mengaktifkan API Cloud/IAM atau mengubah service account.
- **GitHub & commit:** snapshot terakhir tetap 0e5c15b, repository sekarang PRIVATE karena insiden; jangan mengandalkan izin publikasi lama untuk membukanya lagi. Riwayat/source rilis lama memuat konfigurasi client Firebase dan dipertahankan private sebagai bukti; belum dilakukan rewrite/force-push atau commit perbaikan baru. Perubahan pengemas, ignore, contoh Firebase, README, dan arsitektur ada di workspace untuk ditinjau.
- **Berkas pengumpulan:** paket dist/submission ditandai security_hold; tautan aplikasi/source bukan untuk distribusi publik saat ini. ZIP source baru tanpa konfigurasi asli: `dist/security/ReLa-source-sanitized.zip` (238 file), belum diunggah. Jangan menganggap arsip/APK lama bersih hanya karena repository kini private. Laporan dan bukti audit disimpan di dist/security (diabaikan Git).
- **Kondisi test:** T-033: 9 test pengemas lulus (regresi membuktikan filter lama gagal), 28 pemeriksaan API read-only lulus; 17 tabel public Supabase RLS aktif, 4 bucket Supabase private, tidak ada CREATE schema untuk anon/authenticated atau definer tanpa search_path. Tidak ada perubahan data demo atau generasi Gemini. Cloud awal: Firebase Rules API 200 dengan 0 release, daftar layanan 403 AUTH_PERMISSION_DENIED, Key Management 403 SERVICE_DISABLED. Cloud terbaru: sesi Chrome pemilik berhasil menyimpan/membaca ulang Android restrictions + 4 API; 6 uji langsung lulus, instalasi Firebase uji dihapus, kedua proyek saat ini tanpa linked billing account, metrik agregat 30 hari ditinjau. Key client tidak dirotasi. HP tidak terhubung, uji push menyeluruh belum diulang. T-032: 145 test Flutter lengkap, 52 unit test server, 7 test pengemas lulus; analisis statis bersih. APK internal 1.0.1/build 2, signature valid. APK/source/panduan/checksum publik HTTP 200 tanpa login dan cocok SHA256; README publik sesuai source. Tidak menjalankan test mutasi cloud/Gemini. T-031: 32 test terarah lulus (2 baru) ditambah satu render visual sementara; analisis statis bersih. Pratinjau dibandingkan dengan Home.png, build rilis berhasil, install Success dan launch Status ok pada HP. File test render sementara sudah dihapus. HP terkunci, uji visual fisik menunggu pengguna. T-030: 30 test terarah lulus (6 test baru), termasuk kirim usulan/geser sesuai ID dropdown, reload, jadwal besok, kunjungan selesai lebih awal, draf, kartu tanpa pilihan, dan dialog pada 360×640. Analisis statis bersih, build APK rilis berhasil. Tidak mengubah data cloud. T-029: 7 test pengemas dan 52 test server lulus. APK signature valid, min SDK 24 (Android 7), ABI arm64/armv7/x86_64, izin INTERNET ada. Unduhan APK/source dan README diuji tanpa login; checksum cocok. Pemasangan APK publik ke emulator Android 16 yang kosong berhasil. Buka aplikasi/screenshot emulator kemudian timeout, sehingga UI rilis belum terverifikasi. HP fisik tidak tersambung. Suite Flutter lengkap terakhir T-027: 137 lulus; analisis statis bersih pada T-028.
- **Masalah yang belum terpecahkan:**
  1. Emulator Mac ini crash di `glInvalidateFramebuffer` (gfxstream) baik dengan `-gpu host` maupun `swiftshader_indirect`; uji di HP Xiaomi lewat USB (tekan "Install" di HP saat pasang). Belum dicoba: `-gpu guest`.
  2. `check_security` P2a kadang gagal karena token push keluarga1 di HP uji (data, bukan kode).
  3. Seed demo belum berisi kolom baru (tanggal lahir Ibu Sri, nama panggilan/usia relawan, `status_after` kunjungan lama, jadwal), sehingga tampil "Belum diisi".
  4. Reset demo tidak menghapus kunjungan draf yang dibuat saat uji di HP; bila ada, `check_security` S8 macet (aturan 1 kunjungan per hari).
  5. Relawan lama belum bisa mengubah nama panggilan sendiri.
  6. APK rilis sudah dibangun dan dipublikasikan; uji visual di HP fisik masih perlu dilakukan.
  7. T-023: label orang kedua belum dicek.
  8. Tombol Lupa password pada desain login baru membuka petunjuk bantuan pengelola; alur pemulihan email mandiri belum tersedia.
- **Keputusan penting (16 Okt, juga di Log keputusan `docs/architecture.md` dan PRD F2a/F19):**
  - **Pencocokan & pendamping:** pencocokan tetap aturan (syarat → jarak → beban), bukan ML. Relawan lepas → putaran baru 3 usulan lintas yayasan; tidak ada kandidat → lansia tanpa yayasan, terlihat semua yayasan. Pengunduran diri relawan hanya bisa diterima (tanpa Tolak).
  - **Terlewat & kehadiran:** "terlewat" = slot jadwal yang lewat > 1 hari tanpa kunjungan (tanpa jadwal: > 7 hari). Kehadiran keluarga = persen minggu berkunjung untuk lansia itu.
  - **Akses data:** yayasan tetap tidak membaca tabel `visits`; waktu kunjungan lewat RPC `foundation_week_visits`.
  - **Notifikasi:** dicatat per akun (bukan per token); kategori kondisi/pendamping/pengingat bisa dimatikan; Darurat tidak.
  - **Foto & kode:** foto relawan tidak bisa diganti sendiri. Relawan memilih yayasan saat daftar; satu-satunya kode adalah kode verifikasi 6 angka per relawan.
  - **Label:** `perbaikan` ditampilkan "Kritik & Saran"; Tangani hanya untuk Masalah Serius.
- **Langkah berikutnya:**
  1. Uji push menyeluruh di HP saat tersambung; saat ini adb kosong. Perubahan pembatasan Cloud memakai key/sertifikat lama yang sama, sehingga tidak memerlukan APK baru. Jika teks peringatan Google terpisah menyatakan compromised atau meminta pencabutan, ikuti rotasi terkait; jangan kirim key ke chat.
  2. Pembatasan Cloud sudah diverifikasi; tinjau pembersihan riwayat/rilis dan ZIP source sanitasi sebelum publikasi berikutnya. Repository harus tetap private sampai ada persetujuan baru pengguna. Tidak ada commit/push/unggahan rilis baru pada sesi keamanan.
  3. Revisi proposal/deck, video, gladi T-025, serta pemeriksaan label T-023 tetap belum selesai; distribusi publik menunggu tinjauan paket/riwayat dan persetujuan baru.

---

## Tahap 0: Fondasi

### [x] T-001 · Siapkan akun, alat, dan keputusan PRD (bersama manusia)
- **Bergantung pada:** —
- **Deskripsi:** Semua tugas berikutnya butuh akun layanan dan alat di laptop. Tugas ini juga menyetujui 4 usulan tambahan PRD (architecture.md bagian 9), karena beberapa tugas bergantung padanya.
- **Kriteria selesai:**
  - [x] `git init` sudah dijalankan, dan `.gitignore` berisi `.env.local`, `app/env.json`, `firebase/service-account.json`, `build/`, `.dart_tool/`.
  - [x] `.env.local` (tidak di-commit) berisi `SUPABASE_PROJECT_REF`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `GEMINI_API_KEY`, `GEMINI_MODEL`, dan semuanya terisi. Firebase: `firebase/google-services.json` (aplikasi Android `id.temansenja.app`) dan `firebase/service-account.json` sudah diunduh.
  - [x] `flutter doctor` tanpa error untuk Android. `supabase --version` dan `deno --version` berjalan (psql tidak dipakai; SQL dijalankan dengan `supabase db query --linked -f`). HP Android atau emulator muncul di `flutter devices`.
  - [x] Keempat usulan di architecture.md bagian 9 diputuskan dan, bila disetujui, ditulis ke `docs/prd.md` (F1, F6, F8, Riwayat Perubahan).
- **Catatan:**
  - Homebrew tidak dipakai. Flutter 3.47.7 dipasang di `~/development/flutter`, Deno 2.9.7 di `~/.deno`, Supabase CLI 2.120.0 di `~/.local/bin`. PATH dan `ANDROID_HOME` ditambahkan ke `~/.zshrc`. Android Studio, SDK, dan Java sudah ada sebelumnya; cmdline-tools dipasang lewat Android Studio, dan lisensi sudah disetujui.
  - psql tidak dipasang, karena `supabase db query --linked -f <file>` bisa menjalankan SQL ke proyek cloud. Semua rujukan psql di prompt sudah diganti, dan `SUPABASE_DB_URL` tidak diperlukan.
  - Tidak memakai HP fisik. Emulator `Medium_Phone_2` (Android 16, Google Play) untuk relawan, dan `TemanSenja_Keluarga` (dibuat dari image yang sama) untuk demo notifikasi di sisi keluarga.
  - Proyek Supabase: ref `zysrjsbykllpjemvbbuf`, region Singapore. Key diambil lewat `supabase projects api-keys`, jadi tidak pernah ditempel di chat.
  - Gemini: `gemini-3.5-flash` (4,5 detik, JSON schema berjalan, paham "ora doyan mangan"). Model 3.7 dan 3.8 timeout karena beban tinggi, dan 2.5 sudah tidak tersedia untuk pengguna baru. Model bisa diganti lewat secret `GEMINI_MODEL`.
  - **Perubahan rencana:** notifikasi beralih dari Telegram ke push notification FCM (keputusan pengguna). Arsitektur, PRD, todo (T-001, T-002, T-006, T-020, T-021), prompt, dan CLAUDE.md sudah diperbarui. Service account sudah diuji dan berhasil mendapat access token FCM.
  - Keputusan 4 usulan: (1) hari dan bahasa lansia **ditolak**, sehingga F2 hanya memakai jarak lalu beban; (2) izin notifikasi **disetujui** (F8); (3) baseline 3 kunjungan pertama **disetujui** (F6); (4) push saat Segera dikabari **disetujui** (F6).
  - Risiko: Flutter memperingatkan bahwa dukungan Mac Intel akan dihentikan di versi mendatang. Versi 3.47.7 masih berjalan, jadi jangan menjalankan `flutter upgrade` sebelum hackathon selesai.

### [x] T-002 · Kerangka proyek Flutter + Supabase dengan test yang lulus
- **Bergantung pada:** T-001
- **Deskripsi:** Menyiapkan semua yang dipakai bersama supaya tugas paralel tidak pernah mengedit file yang sama: proyek Flutter dengan **semua** package dari arsitektur, izin Android, folder Supabase, dan satu test di tiap bahasa.
- **Kriteria selesai:**
  - [x] `app/` dibuat (Android saja) dengan package `supabase_flutter`, `speech_to_text`, `geolocator`, `geocoding`, `image_picker`, `app_links`, `fl_chart`, `url_launcher`, `firebase_core`, `firebase_messaging`. `google-services.json` ada di `android/app/` dengan plugin Gradle `com.google.gms.google-services`. `AndroidManifest.xml` sudah berisi izin INTERNET, CAMERA, RECORD_AUDIO, ACCESS_FINE_LOCATION, POST_NOTIFICATIONS, serta intent-filter skema `temansenja://join`.
  - [x] `cd app && flutter test` lulus (minimal satu test contoh) dan `flutter analyze` tanpa issue.
  - [x] `supabase/` sudah di-`init` dan di-`link` ke proyek cloud. Folder `supabase/seeds/` ada. `deno test supabase/functions/_shared` lulus dengan `smoke_test.ts`.
  - [x] Secret `GEMINI_API_KEY`, `GEMINI_MODEL`, dan `FIREBASE_SERVICE_ACCOUNT` muncul di `supabase secrets list`. `app/env.example.json` di-commit dan `app/env.json` tidak.
- **Catatan:**
  - Versi: Flutter 3.47.7, AGP 9.1, Kotlin 2.4, plugin google-services **4.5.0** (dicek di Maven Google). Package: supabase_flutter 2.18, firebase_core 4.15, firebase_messaging 16.7, dan lainnya ada di `pubspec.yaml`.
  - **Publishable key** menggantikan anon key, karena `anonKey` sudah deprecated di supabase_flutter 2.18. Nama variabel diganti menjadi `SUPABASE_PUBLISHABLE_KEY` di `.env.local`, `env.json`, `env.example.json`, `main.dart`, CLAUDE.md, architecture.md, prompt.md, dan kriteria T-001. Ini di luar daftar file T-002, tapi diubah supaya dokumen konsisten (sesi berjalan sendirian).
  - `supabase init` sempat berjalan di `app/` karena cwd tertinggal. `config.toml` dan `.gitignore` sudah dipindah ke `supabase/`, dan `project_id` diganti menjadi `temansenja`. `supabase link` tidak meminta password DB, dan `supabase db query --linked` sudah terbukti berjalan.
  - Secret di-set lewat file env sementara yang langsung dihapus. JSON service account diringkas menjadi satu baris.
  - Verifikasi tambahan: `flutter build apk --debug` berhasil (sekitar 18,6 menit untuk build pertama), lalu APK terpasang dan proses aplikasi berjalan di emulator `TemanSenja_Keluarga` tanpa crash di logcat.
  - Emulator `Medium_Phone_2` hanya tersisa 346 MB, karena penuh aplikasi tugas kuliah. APK debug (155 MB) gagal dipasang di sana. Pakai `TemanSenja_Keluarga`, atau kosongkan ruang sendiri.
  - Di laptop ini `head` adalah tool HTTP Perl, jadi pakai `sed -n`. Di zsh, tulis `${VAR}` di dalam URL.

### [x] T-003 · Database akun: yayasan, profil, peran (bisa paralel)
- **Bergantung pada:** T-002
- **Deskripsi:** Tabel `foundations` dan `profiles` beserta trigger sign-up, supaya setiap akun punya peran. Akun demo dibuat lewat seed, karena akun yayasan tidak boleh mendaftar sendiri (F0 P3).
- **Kriteria selesai:**
  - [x] Migration `supabase/migrations/20261014000100_profiles.sql` sudah ter-push: `foundations(name, verified, invite_code unique)` dan `profiles` (kolom sesuai architecture.md bagian 4) dengan CHECK pada `role`.
  - [x] Trigger sign-up membuat baris `profiles`. Peran dari metadata hanya boleh `keluarga` atau `relawan`; nilai lain, termasuk `yayasan`, ditolak dengan error. Ini dibuktikan dengan dua percobaan sign-up di `scripts/check_auth.ts`.
  - [x] RLS `profiles`: pengguna hanya bisa membaca dan mengubah barisnya sendiri, dan tidak bisa mengubah `role` atau `foundation_id`. Ini dibuktikan di `scripts/check_auth.ts`.
  - [x] `supabase/seeds/01_accounts.sql` (idempoten) membuat Yayasan Demo (terverifikasi, kode `SENJA1`), 1 pengurus yayasan, 2 keluarga, 5 relawan, semuanya dengan password `demo1234`. `deno run -A scripts/check_auth.ts` lulus.
- **Catatan:**
  - `role`/`foundation_id` dikunci dengan **column grant** (`authenticated` hanya boleh update `full_name, phone, phone_verified, fcm_token`), bukan trigger. Update kolom terlarang mengembalikan `permission denied`. RPC/seed (security definer/postgres) tetap bisa mengubahnya.
  - `foundations` diberi RLS: hanya anggota (`profiles.foundation_id`) yang bisa membaca yayasannya. Lookup kode undangan untuk relawan baru perlu RPC security definer di T-016.
  - Seed menulis langsung ke `auth.users` + `auth.identities` dengan UUID tetap: yayasan `f0000000-…-001`, pengurus `a0000000-…-001`, keluarga `b0000000-…-001/002`, relawan `c0000000-…-001..005`. Pengurus dibuat dengan metadata `relawan` (trigger menolak `yayasan`) lalu di-update menjadi `yayasan` oleh seed. Relawan dan pengurus sudah ber-`foundation_id` Yayasan Demo.
  - **Konfirmasi email di proyek cloud tadinya aktif** (`config.toml` hanya berlaku lokal) sehingga sign-up kena "email rate limit exceeded". Sudah dimatikan pengguna di dashboard (Authentication → Email → Confirm email).
  - T-002 masih `[~]` saat tugas ini dikerjakan, tetapi Supabase sudah ter-link dan secret sudah ada, jadi T-003 tidak terhambat.

### [x] T-006 · Kerangka aplikasi: login, navigasi per peran, layar stub (bisa paralel)
- **Bergantung pada:** T-002, T-003
- **Deskripsi:** Membuat semua file bersama di Flutter sekali saja: `main.dart`, login dan daftar, beranda tiap peran, model data, widget bersama, penanganan tautan undangan, serta **file stub untuk setiap layar fitur**. Tugas berikutnya cukup mengisi file stubnya masing-masing.
- **Kriteria selesai:**
  - [x] Login dan daftar (email, password, nama, HP, pilih peran keluarga/relawan) berjalan, dan setelah login aplikasi membuka beranda sesuai `profiles.role`. Dibuktikan dengan `test/router_test.dart` untuk ketiga peran.
  - [x] Stub (layar berisi teks "Belum dibuat" dan sudah bisa dibuka dari beranda) ada untuk semua file di daftar "Stub" pada prompt T-006.
  - [x] `shared/models.dart` berisi kelas data untuk semua tabel di architecture.md bagian 4. `shared/widgets.dart` berisi `StatusBadge` (3 status) dan `DisclaimerLabel` dengan teks persis dari PRD F1. Keduanya dites di `test/widgets_test.dart`.
  - [x] Membuka `temansenja://join?code=SENJA1` di HP membuka `JoinScreen` dengan kode terisi.
- **Catatan:**
  - Test: `flutter test test/router_test.dart test/widgets_test.dart` → 16 lulus, dan `flutter analyze` bersih. `test/smoke_test.dart` (T-002) dihapus atas izin pengguna, karena `TemanSenjaApp` kini butuh Supabase dan app_links.
  - `homeFor(role, volunteerJoined:)` di `main.dart` adalah fungsi murni yang menentukan beranda, dan itulah yang dites. `AuthGate` membaca `profiles.role`; untuk relawan, `AuthGate` juga mengecek baris `volunteers`. Bila tabel atau query gagal, relawan dianggap belum bergabung dan diarahkan ke JoinScreen.
  - Stub yang butuh ID dibuka dari stub induknya lewat tombol "Contoh … (stub)" dengan ID `contoh`. Tombol-tombol ini otomatis hilang saat tugas pemiliknya mengganti stub, jadi file beranda tidak perlu diubah lagi.
  - Uji di emulator (TemanSenja_Keluarga): login keluarga1, relawan1, dan pengurus masing-masing membuka beranda yang benar. `adb shell am start -d "temansenja://join?code=SENJA1"` membuka JoinScreen dengan "Kode undangan: SENJA1". Validator form daftar muncul di perangkat.
  - **Belum dilihat langsung di emulator:** menekan "Daftar" sampai berhasil, karena `adb input text` kehilangan ketikan di emulator yang lambat. Jalur yang sama (`signUp` + metadata role/full_name/phone) sudah terbukti lewat panggilan langsung ke Supabase dan `check_auth.ts`. Sebaiknya dicoba manual sekali di emulator.
  - Untuk tugas berikutnya: model di `shared/models.dart` mengikuti architecture.md bagian 4. Bila T-007 memakai nama kolom berbeda, sesuaikan saat Cek gabungan Langkah 4. `LogoutButton`, `StubScreen`/`StubSection`, dan `stubLink` ada di `shared/widgets.dart`.

### [x] T-007 · Skema inti, RLS, dan data demo dasar (bisa paralel)
- **Bergantung pada:** T-003
- **Deskripsi:** Semua tabel MVP lainnya beserta RLS dibuat sekaligus, karena aturan privasi lintas tabel (architecture.md bagian 6) harus konsisten, dan supaya tiga alur bisa dikerjakan paralel setelah ini.
- **Kriteria selesai:**
  - [x] Migration `20261014000200_core.sql` sudah ter-push: `volunteers`, `elders`, `health_profiles`, `proposals` (dengan index unik parsial `pending`), `visits`, `emergencies`, bucket privat `volunteer-photos`, trigger "dua centang → `aktif`", dan Realtime aktif untuk `elders` dan `visits`.
  - [x] `seeds/02_demo_core.sql` (idempoten): 4 relawan aktif dengan lokasi dan keahlian berbeda di Yogyakarta, 1 relawan `terdaftar`, Ibu Sri (keluarga 1, demensia: tidak) sudah berpasangan dengan relawan 1 beserta profil kesehatannya, dan 1 lansia milik keluarga 2 yang belum berpasangan.
  - [x] `deno run -A scripts/check_rls.ts` lulus untuk setiap baris tabel RLS di architecture.md bagian 6, minimal: yayasan membaca `health_profiles` → 0 baris; relawan 2 tidak melihat Ibu Sri; relawan membaca `proposals` → 0 baris; keluarga 2 tidak melihat Ibu Sri.
  - [x] `check_rls.ts` juga membuktikan bahwa constraint bekerja: `status` di luar enum ditolak, dan dua proposal `pending` untuk relawan yang sama ditolak.
- **Catatan:**
  - `scripts/check_rls.ts` berisi 51 cek (semua sel tabel RLS bagian 6, constraint, storage, Realtime). Data uji (proposal, darurat, kunjungan, foto, lansia baru) dibuat lalu dihapus lagi, jadi data demo tetap bersih.
  - Policy yayasan memakai fungsi `security definer` `my_admin_foundation()` (null bila bukan pengurus) supaya policy antar tabel tidak saling memicu RLS (rekursi).
  - Kolom yang dilindungi memakai column grant: keluarga hanya bisa menulis data lansia (bukan `volunteer_id`, `foundation_id`, `pairing_state`, `status`), dan relawan tidak bisa mengubah `status`/`foundation_id`. `proposals` dan `emergencies` tidak punya policy tulis, karena keduanya ditulis Edge Function dengan service_role.
  - Trigger `volunteers_checks`: relawan tidak bisa mencentang dirinya sendiri, yayasan hanya boleh mengubah kolom centang, `*_at` terisi otomatis, dan status menjadi `aktif` begitu kedua centang terisi. Relawan baru belum punya policy INSERT ke `volunteers`; bergabung lewat kode (T-016) perlu RPC.
  - Keluarga membaca semua proposal lansianya, termasuk `reject_*`. Alasan tolak itu ditulis keluarga sendiri, jadi tidak ada data relawan lain yang bocor.
  - Bug yang ketemu lewat test: CHECK `reject_note` wajib untuk `lainnya` lolos bila note `NULL` (CHECK bernilai NULL = lolos). File migration diperbaiki dengan `coalesce`, dan constraint yang sama diterapkan ke cloud lewat `supabase db query` (migration baru dipakai sesi ini, jadi isi file dan DB tetap sama).
  - UUID seed: lansia Ibu Sri `e0000000-…-001` (berpasangan dengan relawan1), Bapak Harjo `e0000000-…-002` (keluarga2, demensia, `mencari`). Relawan1 bisa demensia+mobilitas, relawan2 mobilitas saja, relawan3 demensia saja, relawan4 tidak keduanya, relawan5 `terdaftar`.

## Tahap 1: Alur B — Rekap cerita dan deteksi penurunan (P1, inti pitch)

### [x] T-004 · Rubrik dan aturan status F6 (bisa paralel)
- **Bergantung pada:** T-002
- **Deskripsi:** Logika murni yang menentukan Stabil, Perlu perhatian, atau Segera dikabari. Ini inti pitch, jadi dikerjakan dan dites paling awal, tanpa database.
- **Kriteria selesai:**
  - [x] `_shared/rubric.ts` berisi 7 domain, label 4 level (0 = terbaik), dan daftar tanda bahaya. `app/lib/shared/rubric.dart` berisi salinan yang sama, dan `app/test/rubric_test.dart` mengecek jumlah domain dan label.
  - [x] `_shared/status.ts` mengekspor `computeStatus(visits)` yang mengembalikan `{status, reasons[]}`, dengan setiap alasan mengutip kalimat bukti relawan, ditambah saran umum dan pernyataan bukan diagnosis.
  - [x] `status_test.ts` punya test untuk: tanda bahaya; turun ≥2 level dari baseline; turun 3 kunjungan berturut-turut; obat terlewat 2 dari 3; kemandirian hilang; **baseline buruk tidak memicu**; domain `null` dilewati; kurang dari 3 kunjungan dianggap baseline belum sah. Semua lulus.
- **Catatan:** `red_flags` di `final_result` berbentuk `[{flag, evidence}]` (bukan string) supaya alasan "Segera dikabari" ikut mengutip kalimat relawan; T-008 perlu memakai bentuk ini. `computeStatus` juga mengembalikan `advice[]` dan `disclaimer`. Baseline seri (mis. 0,1,null) memakai level yang lebih buruk. Aturan obat dan "3 kunjungan berturut" hanya memicu bila kunjungan terbaru lebih buruk dari baseline. Deno ada di `~/.deno/bin/deno` (tidak ada di PATH shell non-interaktif).

### [x] T-008 · Ekstraksi cerita ke kategori via Gemini (bisa paralel)
- **Bergantung pada:** T-004
- **Deskripsi:** Mengubah 7 jawaban cerita menjadi level per domain dengan kalimat bukti (F4). Keluaran Gemini diperlakukan sebagai input yang tidak dipercaya.
- **Kriteria selesai:**
  - [x] `_shared/extract.ts` mengekspor `stripPII(text, {name, address})`, `buildRequest(answers)` (Gemini dengan `responseSchema`), dan `validateResult(raw, answers)`. `_shared/gemini.ts` memanggil API dengan `fetch` yang bisa diganti saat test.
  - [x] Test `extract_test.ts` membuktikan: nama dan alamat lansia tidak ada di body request; kalimat bukti yang tidak ada di cerita membuat domain itu `null`; level di luar 0–3 dibuang; domain yang tidak disebut menjadi `null`.
  - [x] Satu panggilan sungguhan (`deno run -A scripts/try_extract.ts`) untuk cerita contoh "terpeleset di kamar mandi" menghasilkan tanda bahaya `jatuh`.
- **Catatan:** Ditambah `extractVisit(answers, elder, generate)` (samarkan → panggil → validasi) untuk dipakai Edge Function `visit`. `stripPII` menyamarkan per kata (nama ≥3 huruf, alamat ≥4 huruf kecuali kata umum seperti "jalan"/"desa") menjadi `[nama]`/`[alamat]`; julukan seperti "Mbah Uti" tidak tertangkap. Kalimat bukti mengutip cerita yang sudah disamarkan. `generateJson` menerima `{apiKey, model}` opsional supaya test tidak butuh izin env. Panggilan sungguhan 14 Okt: percobaan pertama Gemini membalas **503 (high demand)**, percobaan kedua berhasil dalam 8,1 detik dengan `jatuh` + `keluhan_baru`. Belum ada retry otomatis: pertimbangkan 1x retry untuk 503/429 di Edge Function `visit` supaya demo tidak gagal.

### [x] T-009 · Data demo: 6 cerita kunjungan Ibu Sri (bersama manusia, bisa paralel)
- **Bergantung pada:** T-004, T-007
- **Deskripsi:** Skenario demo Alur B butuh 6 cerita yang perlahan menurun. Isinya harus terdengar seperti relawan sungguhan, sehingga ditulis bersama tim.
- **Kriteria selesai:**
  - [x] `supabase/seeds/03_visits_ibu_sri.sql` (idempoten) berisi 6 kunjungan dengan `answers` (7 jawaban dalam bahasa santai), `ai_result`, dan `final_result` yang sudah dikonfirmasi, setiap kategori didukung kalimat bukti yang benar-benar ada di cerita.
  - [x] `computeStatus` atas 6 kunjungan itu menghasilkan **Stabil**, dibuktikan dengan test `status_test.ts` "demo Ibu Sri" yang memakai data yang sama dari `supabase/seeds/ibu_sri.json`.
  - [x] Teks cerita ke-7 untuk demo langsung (versi "Perlu perhatian" dan versi "terpeleset di kamar mandi") disimpan di `docs/demo-script.md`, dan tim sudah menyetujuinya.
- **Catatan:**
  - Disetujui pengguna satu per satu (kunjungan 1–6 dan dua versi cerita ke-7). Ibu Sri berusia 60 tahun, suka merawat tanaman, menonton TV, dan memasak. Gaya cerita relawan santai sehari-hari, tanpa bahasa Jawa.
  - Level per domain (kunjungan 1→6): makan 0,0,0,0,1,1 · obat 0,0,0,0,0,1 · gerak 0,0,0,0,1,1 · harian 0 semua · ingatan 0 semua · hati 0,0,1,1,1,1 · umum 0,0,0,0,1,1. Baseline = kunjungan 1–3.
  - Cerita 7A → perlu_perhatian (makan turun 2 tingkat, dan obat terlewat 2 dari 3). Cerita 7B → segera_dikabari (tanda bahaya jatuh, "terpeleset di kamar mandi").
  - `ai_result` di seed = `final_result`, karena AI dianggap benar dan relawan tidak mengoreksi.
  - `03_visits_ibu_sri.sql` sekaligus **reset demo**: menghapus kunjungan dan kejadian darurat Ibu Sri selain 6 seed, lalu mengembalikan status ke stabil. Sudah diuji: dijalankan 2×, hasilnya tetap 6 kunjungan; sisa demo palsu (7 kunjungan, 1 darurat, status segera_dikabari) kembali menjadi 6/0/stabil.
  - `status_test.ts` mendapat 4 test baru (test lama tidak diubah), termasuk "setiap bukti ada di cerita". Data dibaca lewat JSON import, sehingga tidak perlu `--allow-read`. Total 16 lulus.
  - Teks cerita ke-7 ada di dua tempat: `docs/demo-script.md` dan `ibu_sri.json` (`story7`). Keduanya sudah dicek sama persis.

### [x] T-010 · Edge Function `visit`: extract dan confirm (bisa paralel)
- **Bergantung pada:** T-007, T-008
- **Deskripsi:** Server untuk Alur B: memanggil Gemini, lalu setelah relawan mengonfirmasi, menghitung status lansia.
- **Kriteria selesai:**
  - [x] `functions/visit/index.ts` sudah di-deploy. `{action:"extract", visit_id}` menyimpan dan mengembalikan `ai_result`. `{action:"confirm", visit_id, final_result}` menyimpan `final_result`, menjalankan `computeStatus`, lalu memperbarui `elders.status` dan `status_reason`.
  - [x] Body yang tidak valid dibalas `400`. Pemanggil yang bukan relawan pasangan lansia itu dibalas `403`, dibuktikan di `scripts/try_visit.ts` dengan login sebagai relawan 2.
  - [x] `deno run -A scripts/try_visit.ts` (login relawan 1, kunjungan baru Ibu Sri): extract selesai dalam < 10 detik dan mengembalikan 7 domain, lalu confirm mengubah `elders.status`.
- **Catatan:**
  - **Ditutup di Cek gabungan Langkah 5:** `GEMINI_MODEL` diganti menjadi `gemini-3.5-flash-lite` (keputusan pengguna, lihat Log keputusan). Dua cek di `try_visit.ts` diperbaiki, karena perbandingan `JSON.stringify` gagal akibat jsonb mengubah urutan kunci; sekarang memakai `equal` dari `jsr:@std/assert`. `try_visit.ts` lulus 16/16 (extract 4,8 detik, tanda bahaya jatuh terdeteksi), lalu seed 03 dimuat ulang.
  - (Riwayat) **Macet karena kuota Gemini, bukan kode.** Free tier = **20 request/hari per model** (`GenerateRequestsPerDayPerProjectPerModel-FreeTier`, model terbaca `gemini-3.6-flash`). Kuota habis pukul 19.34 WIB 14 Okt dan pulih sekitar 06.20 WIB 15 Okt. Sebelumnya model juga sering membalas 503 "high demand". Loop retry otomatis sesi ini ikut menghabiskan kuota, jadi lain kali cek kode error dulu sebelum mengulang.
  - Sudah terbukti (`try_visit.ts`): 400 untuk 4 jenis body salah, 403 untuk relawan 2, 401 tanpa login. Fungsi sudah di-deploy dan tipe aman (`deno check`). Kriteria 1 dan 3 tinggal dibuktikan dengan `deno run -A scripts/try_visit.ts` setelah kuota pulih (sekitar 1 panggilan Gemini per run).
  - Desain: identitas lewat `admin.auth.getUser(jwt)`; otorisasi = `elders.volunteer_id` dari kunjungan harus sama dengan pemanggil; semua tulisan memakai service_role. `final_result` dicek strukturnya saja (7 domain, level 0–3/null, red_flags valid), bukan dengan `validateResult`, karena koreksi relawan boleh mengubah level tanpa kutipan baru. `status_reason` = alasan + kutipan + saran + disclaimer, dipotong supaya muat CHECK 1000 karakter. Gemini gagal → 502. Push `segera_dikabari` ditinggalkan untuk T-020.
  - **Usulan (butuh keputusan pengguna):** (1) aktifkan billing atau pakai API key/proyek Google lain sebelum demo, karena 20 request/hari tidak cukup untuk T-023/T-024 dan gladi; (2) retry 1–2x untuk 503 di `_shared/gemini.ts` setelah langkah paralel selesai.

### [x] T-012 · Layar relawan: daftar pasangan, cerita kunjungan, konfirmasi (bisa paralel)
- **Bergantung pada:** T-006, T-010
- **Deskripsi:** F3 (input dengan mengetik) dan F5 di sisi relawan.
- **Kriteria selesai:**
  - [x] `paired_elders.dart` menampilkan lansia pasangan relawan yang login (lewat RLS), dengan tombol "Cerita kunjungan" dan "Darurat".
  - [x] `visit_story_screen.dart` menampilkan 7 pertanyaan terbuka sesuai PRD F3, menyimpan `visits.answers`, lalu memanggil `extract` dan menampilkan indikator loading.
  - [x] `visit_confirm_screen.dart` menampilkan ringkasan (misalnya "Nafsu makan: Berkurang · …") beserta kalimat bukti, setiap domain bisa diubah lewat dropdown, dan Simpan memanggil `confirm`. Ini dibuktikan dengan `test/visit_confirm_test.dart` (koreksi dropdown → `final_result` berubah, `ai_result` tetap).
- **Catatan:**
  - `visit_confirm_test.dart` 3/3 lulus. `applyCorrection(ai, levels)` adalah fungsi murni yang membuat salinan dalam, sehingga `ai_result` tidak berubah. Pemanggilan `confirm` bisa diganti lewat parameter `onConfirm` untuk test. `flutter analyze` file T-012 bersih.
  - Uji di **HP Samsung A54** (emulator di Mac Intel crash, lihat di bawah): relawan1 → kartu Ibu Sri → 7 pertanyaan → Kirim → "Membaca cerita…" → Konfirmasi → koreksi dropdown → Simpan → Tersimpan. Hasil di DB: kunjungan terkonfirmasi, `final_result` ≠ `ai_result` pada domain hati, status perlu_perhatian. Seed 03 dimuat ulang setelahnya.
  - Jalur RLS dicek dengan skrip sementara: relawan1 hanya melihat Ibu Sri dan bisa insert kunjungan, sedangkan relawan2 ditolak (42501).
  - `VisitStoryScreen` menyimpan `visit_id`, sehingga "Coba lagi" setelah Gemini gagal tidak membuat kunjungan dobel. Constructor `VisitConfirmScreen` menjadi `(visitId, aiResult?, onConfirm?)`; bila `aiResult` kosong, data diambil dari DB.
  - `router_test.dart` bagian relawan diubah atas izin pengguna (stub hilang → cek "Lansia pasangan"). Test bagian **keluarga** gagal karena T-014 mengganti stub `ElderList`; ini dibereskan di Cek gabungan Langkah 6.
  - **Emulator:** Android 16 di Mac Intel crash di `glInvalidateFramebuffer` (gfxstream), bahkan dipicu System UI sendiri. Gunakan HP fisik untuk uji dan demo.

### [x] T-013 · Layar keluarga: rekap, status, dan grafik tren (bisa paralel)
- **Bergantung pada:** T-006, T-004, T-009
- **Deskripsi:** F7. Rekap, status, dan tren langsung terlihat oleh keluarga begitu relawan menyimpan.
- **Kriteria selesai:**
  - [x] `elder_detail_screen.dart` menampilkan `StatusBadge` dan alasannya (beserta saran dan pernyataan bukan diagnosis), daftar rekap per kunjungan, dan profil kesehatan dengan `DisclaimerLabel`.
  - [x] Grafik `fl_chart` per domain dari seluruh kunjungan, dengan sumbu Y memakai label rubrik dan domain `null` tampil sebagai titik kosong. Ini dibuktikan dengan `test/elder_detail_test.dart` (7 grafik dari data 6 kunjungan).
  - [x] Layar memakai `stream()` Supabase pada `elders` dan `visits`, sehingga perubahan status dari HP relawan muncul tanpa refresh (dicek manual dengan 2 HP/emulator).
- **Catatan:**
  - Layar dipecah menjadi `ElderDetailScreen` (stream Supabase) dan `ElderDetailView` (murni data), sehingga test cukup memakai `ibu_sri.json` tanpa Supabase. `test/elder_detail_test.dart`: 5 test lulus, dan `flutter analyze` kedua file bersih.
  - Grafik: sumbu Y dibalik (`y = 3 − level`) supaya garis turun saat kondisi memburuk. Level `null` membuat garis terputus (`FlSpot.nullSpot`) dan digambar sebagai titik berongga di baris "Tidak disebut" (y = −1). Hanya kunjungan ber-`final_result` yang masuk grafik dan rekap.
  - Bila `status_reason` kosong atau tidak memuat "bukan diagnosis", layar menambahkan kalimat disclaimer yang sama dengan `DISCLAIMER` di `status.ts`.
  - Realtime: uji manual di HP (keluarga1 → Ibu Sri, `update elders` dari terminal) → badge berubah sendiri. Uji pertama di emulator gagal karena emulator hang (`adb shell` tidak merespons). Skrip Dart dengan `stream()` yang sama menerima perubahan dalam ±1 detik, jadi server dan RLS terbukti benar.
  - Profil kesehatan dimuat sekali (`FutureBuilder`), tidak lewat Realtime, karena `health_profiles` tidak ada di publikasi Realtime.

### [x] T-022 · Rekam suara di form cerita (bisa paralel, P1 opsional)
- **Bergantung pada:** T-012
- **Deskripsi:** F3 rekam suara dengan STT bawaan HP. Ini fitur pertama yang dipangkas bila waktu mepet.
- **Kriteria selesai:**
  - [x] Setiap pertanyaan di `visit_story_screen.dart` punya tombol mikrofon. Hasil dikte (`id_ID`) ditambahkan ke kolom teks dan tetap bisa disunting sebelum dikirim.
  - [x] Bila izin mikrofon ditolak atau STT tidak tersedia, tombol disembunyikan dan form ketik tetap berjalan.
  - [x] `flutter analyze` tanpa issue, dan uji manual di HP sungguhan berhasil (dicatat di Catatan).
- **Catatan:**
  - `speech_to_text` 7.5: `initialize()` dipanggil sekali saat form dibuka (sekaligus meminta izin mikrofon). Hasil `false` atau error → `_sttReady = false` → `suffixIcon` mikrofon tidak dirender. `listen()` memakai `SpeechListenOptions(localeId: 'id_ID', partialResults: false, listenMode: dictation, pauseFor: 5 dtk)`. Hanya hasil final yang ditambahkan ke akhir teks (`appendDictation`, tidak menimpa), dan kursor pindah ke akhir. Satu kolom merekam dalam satu waktu.
  - Manifest sudah berisi `RECORD_AUDIO` dan `<queries>` RecognitionService sejak T-002, jadi tidak ada perubahan Android.
  - Bukti: `flutter analyze` bersih, `visit_confirm_test` lulus. Test sementara (tidak di-commit) membuktikan STT tidak tersedia → tanpa ikon mikrofon dan form ketik tetap jalan, serta `appendDictation` menambahkan, bukan menimpa.
  - **Uji manual di HP Samsung (15 Okt):** izin diizinkan → dikte bahasa Indonesia berhasil, teks ditambahkan dan bisa disunting. Izin "Don't allow" → ikon mikrofon langsung hilang, dan form tetap bisa diketik.

### [!] T-023 · Dataset evaluasi: 30–50 cerita berlabel (bersama manusia, bisa paralel)
- **Bergantung pada:** T-004
- **Deskripsi:** Metrik sukses PRD: akurasi ekstraksi diukur dengan cerita berlabel manual, termasuk bahasa santai dan bahasa daerah.
- **Kriteria selesai:**
  - [x] `data/eval/stories.jsonl` berisi ≥30 baris `{answers, expected: {domain: level|null}, expected_red_flags}`.
  - [x] Minimal 8 cerita memakai bahasa Jawa atau campuran (misalnya "ora doyan mangan"), dan minimal 6 cerita memuat tanda bahaya.
  - [ ] Label diperiksa oleh orang kedua di tim (namanya dicatat di Catatan).
- **Catatan:**
  - **Macet hanya di kriteria 3:** label belum diperiksa orang kedua. Dataset dan cek sudah selesai. Untuk menutup: minta satu anggota tim membaca 35 baris, catat namanya di sini, lalu ubah status ke `[x]`.
  - 35 cerita (S01–S35), disusun dalam 7 kelompok berisi 5 dan **setiap label disetujui pengguna** per kelompok. Bahasa: 14 Jawa/campuran (termasuk krama), 1 Sunda, sisanya Indonesia (termasuk slang/singkatan dan campuran Inggris). 15 cerita bertanda bahaya, dan keenam jenis tanda bahaya muncul.
  - Format per baris: `{id, bahasa, answers: {makan, obat, gerak, harian, ingatan, hati, lain}, expected: {makan..umum: 0–3|null}, expected_red_flags: []}`. `id` dan `bahasa` adalah tambahan untuk penghitungan.
  - Cerita jebakan untuk T-024: jatuh setahun lalu (S12), demensia sebagai baseline (S13, S33), menyangkal sesak (S15), semua info ditulis di kolom "lain" (S19), "takut jatuh" (S24), prompt injection (S26), lumpuh lama (S30), "biasa" di semua kolom (S35).
  - Keputusan label yang disepakati: batuk seminggu = `keluhan_baru` (S20); obat terlewat hari itu saja = 2 (S14); "kondisi seperti biasa" untuk umum = null (S30); obrolan non-kesehatan di "lain" = umum null (S04, S28).
  - Cek: skrip Deno sementara membaca setiap baris dengan `JSON.parse`, memvalidasi key/level/nama tanda bahaya terhadap `rubric.ts`, lalu menghitung → `{cerita: 35, jawa_campuran: 14, bertanda_bahaya: 15, rusak: 0}` LULUS.

### [x] T-024 · Skrip pengukur akurasi ekstraksi
- **Bergantung pada:** T-008, T-023
- **Deskripsi:** Menghasilkan angka akurasi untuk pitch.
- **Kriteria selesai:**
  - [x] `scripts/eval_extraction.ts` menjalankan semua cerita lewat `extract.ts`, dengan jeda antar panggilan supaya tidak terkena batas free tier.
  - [x] Hasil cetak: akurasi per domain, akurasi keseluruhan, recall tanda bahaya, dan daftar cerita yang salah.
  - [x] Hasil terakhir disalin ke `docs/demo-script.md` bagian "Angka untuk pitch", lengkap dengan tanggal dan nama model.
- **Catatan:**
  - Hasil 15 Okt 2026, `gemini-3.5-flash-lite`, 35/35 cerita: akurasi **88,6%** (217/245), recall tanda bahaya **100%** (18/18), 10 alarm palsu. Indonesia 92,9%, Jawa/campuran 82,7%. Hasil disalin ke `docs/demo-script.md` bagian "Angka untuk pitch" beserta batasannya.
  - **Dijalankan sebelum T-023 selesai** (keputusan pengguna): label belum diperiksa orang kedua. Bila label dikoreksi, jalankan ulang skrip.
  - Skrip **hanya** memakai `GEMINI_EVAL_API_KEY` (API key di proyek Google terpisah), supaya kuota key demo tidak tersentuh. Jeda 5 detik antar cerita; 429/503 per menit → tunggu dan ulangi (sekali kena 503 dan berhasil diulang); 429 harian → berhenti dan laporkan hasil sebagian.
  - `--self-check` (tanpa Gemini) menghasilkan 100%. Diuji dengan mutasi (semua jawaban makan diganti null, 1 tanda bahaya dibuang): makan turun ke 2,9% dan recall ke 3/18, jadi penghitungnya terbukti menangkap kesalahan.

## Tahap 2: Alur A — Pendaftaran dan pemasangan otomatis

### [x] T-005 · Algoritma pemasangan relawan (bisa paralel)
- **Bergantung pada:** T-002
- **Deskripsi:** Logika murni F2: syarat wajib, lalu jarak terdekat, lalu pemecah seri. Dites tanpa database.
- **Kriteria selesai:**
  - [x] `_shared/matching.ts` mengekspor `pickVolunteer(elder, candidates, excludedIds)` yang mengembalikan `{volunteer, distanceKm, reasonText} | null`, plus `haversineKm`.
  - [x] `matching_test.ts` membuktikan: syarat demensia, mobilitas, dan keduanya wajib; yang terdekat dipilih; seri dipecah dengan beban terendah; hari dan bahasa **tidak** memengaruhi pilihan; relawan di `excludedIds` dan relawan yang mencapai `max_load` dilewati; hanya status `aktif`; tidak ada kandidat → `null`.
  - [x] `reasonText` berformat "Jarak 1,2 km · berpengalaman mendampingi lansia dengan demensia" (dites), dan tidak ada kolom agama di tipe mana pun.
- **Catatan:**
  - 13 test di `matching_test.ts` lulus (`deno test supabase/functions/_shared/matching_test.ts`), dan `deno check` serta `deno lint` bersih.
  - "Jarak sama" berarti sama setelah dibulatkan ke 0,1 km (angka yang dilihat keluarga). Seri terakhir dipecah dengan `id` supaya hasilnya deterministik.
  - `Candidate.load` bukan kolom tabel, melainkan jumlah lansia `berpasangan` milik relawan itu. Query di T-011 wajib menghitungnya, dan relawan yang sedang `pending` dimasukkan ke `excludedIds`.
  - `reasonText` hanya menyebut keahlian yang memang dibutuhkan lansia. Lansia tanpa demensia/mobilitas → hanya "Jarak X km".
  - Diuji dengan mutasi: menghapus aturan beban, status aktif, max_load, syarat mobilitas, atau excludedIds masing-masing membuat test gagal. Mutasi ini sempat menemukan test beban yang lolos karena kebetulan urutan abjad, lalu diperbaiki.

### [x] T-011 · Edge Function `pairing` dan kartu usulan (bisa paralel)
- **Bergantung pada:** T-005, T-007
- **Deskripsi:** Server Alur A: propose, accept, reject (maksimal 3 usulan), manual, ditambah RPC yang hanya mengembalikan data relawan yang aman untuk keluarga.
- **Kriteria selesai:**
  - [x] `functions/pairing/index.ts` sudah di-deploy dengan aksi `propose`, `accept`, `reject` (alasan wajib, `lainnya` wajib disertai teks), dan `manual` (khusus pengurus yayasan, hanya untuk `perlu_yayasan`). `pairing_state` berpindah sesuai architecture.md Alur A.
  - [x] Migration `20261014000300_pairing.sql` berisi RPC `get_proposal_card(id)` yang mengembalikan foto (signed URL), nama, yayasan, keahlian, hari, bahasa, jarak, alasan, dan keterangan verifikasi, **tanpa** HP dan lat/lng relawan.
  - [x] `deno run -A scripts/try_pairing.ts` membuktikan: tolak 3× → `perlu_yayasan` dan tidak ada usulan ke-4; relawan yang ditolak tidak diusulkan lagi; keluarga 2 memanggil `accept` untuk lansia keluarga 1 → `403`; setelah accept, relawan melihat lansia tersebut.
- **Catatan:** Signed URL tidak bisa dibuat dari SQL, jadi `get_proposal_card` mengembalikan `photo_path` dan migration menambah policy Storage "keluarga: baca foto relawan yang diusulkan". **T-015 perlu memanggil `storage.from('volunteer-photos').createSignedUrl(photo_path, 3600)`** dengan sesi keluarga. Kartu juga berisi `rejects_left` (3 − attempt) untuk teks "Sisa n kali tolak". Kode balasan fungsi: 400 body salah, 401 belum login, 403 bukan pemilik/bukan yayasan, 404 tidak ada, 409 state tidak cocok (sudah dijawab, propose saat bukan `mencari`/`tanpa_pendamping`, manual saat bukan `perlu_yayasan`). Pak Harjo (seed) punya demensia, padahal hanya 2 relawan aktif yang mampu, jadi `try_pairing.ts` mematikan `has_dementia` sementara lalu selalu mengembalikannya. Usulan `manual` memakai `attempt = 3` karena kolomnya wajib 1..3, dan bila relawan itu pernah ditolak, barisnya ditimpa (upsert). Skrip juga mengecek aksi `manual` (keluarga → 403, lansia bukan perlu_yayasan → 409, pengurus → berpasangan).

### [x] T-014 · Keluarga mendaftarkan lansia (bisa paralel)
- **Bergantung pada:** T-006, T-011
- **Deskripsi:** F1 dengan form ringkas, lalu langsung memicu usulan relawan.
- **Kriteria selesai:**
  - [x] `register_elder_screen.dart` berisi semua field F1 dan Profil Kesehatan Ringkas, dan ya/tidak untuk demensia dan mobilitas sulit (tanpa hari dan bahasa, sesuai keputusan T-001). Field wajib divalidasi, dibuktikan dengan `test/register_elder_test.dart`.
  - [x] Saat disimpan: alamat diubah ke lat/lng dengan `geocoding` (bila gagal, muncul pesan dan form tidak tersimpan), `elders` dan `health_profiles` disimpan, lalu `pairing` → `propose` dipanggil.
  - [x] `elder_list.dart` di beranda keluarga menampilkan lansia milik keluarga yang login beserta `StatusBadge` dan `pairing_state`, lalu membuka usulan atau detail.
- **Catatan:**
  - **Ditutup di Cek gabungan Langkah 6 (uji di HP Samsung A54):** keluarga2 mendaftarkan "Ibu Uji Coba" (Jl. Kaliurang Km 5). Geocoding menghasilkan −7,7616 / 110,3801, `health_profiles` tersimpan, dan 1 usulan dibuat otomatis ("Jarak 2,2 km", `menunggu_keluarga`). Lansia muncul di beranda. Data uji sudah dihapus.
  - Perbaikan di Cek gabungan: `ElderList` menjadi StatefulWidget dengan stream yang dibuat **sekali** (`late final`, lewat `async*`). Sebelumnya stream Realtime dibuat di `build()`, sehingga langganan bertambah setiap kali widget dibangun ulang dan aplikasi crash di test tanpa Supabase.
  - **Macet hanya di uji manual:** kode selesai, `flutter test test/register_elder_test.dart` lulus 5/5, dan `flutter analyze` bersih. Jalur data kriteria 2–3 sudah dibuktikan dengan skrip sebagai keluarga2: payload `_save()` lolos RLS/grant untuk `elders` dan `health_profiles`, `propose` mengembalikan `proposal_id`, dan keluarga bisa membaca usulan pending (dipakai ElderList). Geocoding gagal → pesan dan tidak tersimpan dibuktikan oleh widget test. **Yang belum dilihat:** geocoding sungguhan di Android dan tampilan daftar di emulator, karena `adb screencap` macet di emulator `TemanSenja_Keluarga`. Untuk menutup: login keluarga2 → Daftarkan lansia → isi alamat Yogyakarta → Simpan; pastikan ProposalScreen terbuka dan lansia muncul di beranda dengan "Ada usulan relawan". Hapus lansia uji lewat SQL Editor setelahnya.
  - Tabel `elders` tidak punya kolom kontak keluarga, jadi kontak disimpan di awal `health_profiles.emergency_instructions` ("Kontak keluarga: Budi 0812…"), sama seperti seed Ibu Sri. Bila perlu kolom sendiri, buat migration baru.
  - `has_chronic` diisi lewat switch "Ada penyakit kronis?" (satu-satunya data kesehatan yang dilihat yayasan). Obat ditulis satu per baris dan diubah oleh `parseMedications` menjadi `[{name, times}]`.
  - `geocoding` 5.0 memakai `Geocoding().locationFromAddress()` (instance), bukan fungsi top-level.
  - Ketuk lansia di beranda: `menunggu_keluarga` → buka usulan pending; `mencari`/`tanpa_pendamping` → `propose` diulang (kalau pencarian sebelumnya gagal atau ada relawan baru); status lain → detail.
  - Bila insert `health_profiles` gagal setelah `elders` tersimpan, lansia tetap ada tanpa profil kesehatan (keluarga tidak punya izin hapus). Risiko kecil, belum ditangani.

### [x] T-015 · Keluarga meninjau usulan: terima atau tolak (bisa paralel)
- **Bergantung pada:** T-011, T-014
- **Deskripsi:** F2a di sisi keluarga.
- **Kriteria selesai:**
  - [x] `proposal_screen.dart` menampilkan kartu dari `get_proposal_card`, termasuk foto, keterangan verifikasi, label keahlian "Diisi sendiri oleh relawan", dan "Sisa N kali tolak".
  - [x] Tolak membuka pilihan alasan (jarak, jadwal, bahasa, lainnya + teks wajib) lalu memanggil `reject`, dan layar memuat usulan berikutnya atau pesan "Diteruskan ke yayasan". Dibuktikan dengan `test/proposal_screen_test.dart` (tolak tanpa alasan → tombol nonaktif).
  - [x] Terima memanggil `accept` lalu kembali ke daftar dengan status "berpasangan".
- **Catatan:**
  - `test/proposal_screen_test.dart` 5/5 lulus: isi kartu, Kirim nonaktif tanpa alasan dan untuk "lainnya" tanpa teks, tolak → kartu berikutnya, tolak terakhir → "Diteruskan ke yayasan", dan Terima → accept. Test memakai viewport 1080×3200 supaya ListView membangun seluruh kartu. `flutter analyze` bersih.
  - Uji di HP (keluarga2 → Pak Harjo): tolak 1× → kartu relawan kedua → Terima → beranda menampilkan "Didampingi relawan". DB: `1:rejected/jarak, 2:accepted`, berpasangan. Pak Harjo dikembalikan ke `mencari` setelahnya.
  - Uji pertama (tolak 2×) berakhir di `tanpa_pendamping`, bukan usulan ke-3. Ini **benar sesuai F2**, karena hanya ada 2 relawan aktif yang mampu mendampingi demensia (Agus, Maria; Dewi masih terdaftar). Lihat Usulan tentang data demo.
  - Usulan berikutnya dimuat di layar yang sama (state `_id`), tanpa push halaman baru. Foto memakai signed URL 10 menit dari `photo_path`. Fungsi `loadCard`, `onAccept`, dan `onReject` bisa diganti untuk test.

### [x] T-016 · Relawan bergabung lewat undangan (bisa paralel)
- **Bergantung pada:** T-006, T-007
- **Deskripsi:** F1a: kode atau tautan undangan, OTP simulasi, profil, dan foto wajah dari kamera.
- **Kriteria selesai:**
  - [x] Migration `20261014000400_join.sql` berisi RPC `join_foundation(code, profile...)` yang membuat baris `volunteers` berstatus `terdaftar`. Kode tidak dikenal atau yayasan belum terverifikasi menghasilkan error (dicek di SQL atau skrip).
  - [x] `join_screen.dart`: OTP simulasi (kode 6 digit tampil di layar, salah kode = ditolak), lalu form area, hari, keahlian, dan bahasa, lalu foto **hanya** lewat `ImageSource.camera`, diunggah ke `volunteer-photos/<user_id>.jpg`.
  - [x] Relawan yang belum punya baris `volunteers` selalu diarahkan ke `JoinScreen` dan tidak bisa membuka fitur lain. Dibuktikan dengan `test/join_screen_test.dart` (validasi OTP dan form).
- **Catatan:**
  - RPC `join_foundation` (security definer) dicek di SQL sebagai relawan baru dalam transaksi yang di-rollback: kode tidak dikenal, yayasan belum terverifikasi, foto milik orang lain, hari tidak valid, bergabung dua kali, dan akun keluarga semuanya ditolak. Kode ` senja1 ` berhasil → `volunteers.status = terdaftar`, `profiles.foundation_id` terisi, `phone_verified = true`.
  - **Path foto `volunteer-photos/<user_id>/wajah.jpg`**, bukan `<user_id>.jpg` seperti di teks kriteria. Policy storage T-007 (unggah) dan T-011 (keluarga membaca foto usulan) sama-sama memakai `storage.foldername(name)[1]`, sehingga file tanpa folder akan ditolak. RPC juga mewajibkan path diawali `<uid>/`.
  - Routing "belum bergabung → JoinScreen" sudah ada di `homeFor` (main.dart, T-006). `join_screen_test.dart` (9 test) + `router_test.dart` lulus, dan analyze bersih.
  - `JoinScreen` tidak menyentuh Supabase saat build (supaya `router_test` tetap jalan). Login dicek saat menekan Gabung. Kode dari tautan disimpan di `pendingInviteCode`, sehingga tetap terisi bila relawan baru masuk atau mendaftar setelah membuka tautan.
  - Uji manual di HP: daftar `relawanbaru@demo.id` → `adb shell am start -d temansenja://join?code=SENJA1` → OTP → form → foto kamera depan → status `terdaftar`, dan foto ada di storage. Akun ini sengaja dibiarkan karena berguna untuk demo verifikasi yayasan (T-017).

### [x] T-017 · Yayasan memverifikasi relawan dan membagikan undangan (bisa paralel)
- **Bergantung pada:** T-006, T-007
- **Deskripsi:** F1b dengan dua centang, ditambah tombol salin tautan undangan untuk F1a.
- **Kriteria selesai:**
  - [x] `verify_volunteers_screen.dart` menampilkan relawan `terdaftar` di yayasan pengurus yang login, beserta foto (signed URL), profil, dan keahlian berlabel "Diisi sendiri oleh relawan". Tidak ada tempat untuk mengunggah dokumen.
  - [x] Dua centang menyimpan `id_checked_by/at` dan `oriented_by/at`. Setelah keduanya terisi, status menjadi `aktif` (oleh trigger), dan nama pengurus serta waktunya tampil.
  - [x] `invite_section.dart` menampilkan kode undangan dan tombol salin tautan `temansenja://join?code=…`, dibuktikan dengan `test/invite_section_test.dart`.
- **Catatan:**
  - Nama relawan diambil dari RPC `foundation_dashboard()` (T-018), karena RLS `profiles` hanya mengizinkan baris sendiri. Nama pengurus yang mencentang memakai profil pengurus yang login (bila pengurus lain yang mencentang, tampil "pengurus yayasan").
  - Waktu `_at` diisi trigger dari jam server, bukan dari HP. Setelah `aktif`, kedua centang dikunci di UI supaya status tidak berubah tanpa jejak.
  - Layar menampilkan dua bagian: "Menunggu verifikasi" (`terdaftar`) dan "Sudah aktif" (dengan nama dan waktu pencentang).
  - Foto memakai `createSignedUrl` (1 jam) lewat policy Storage "yayasan: baca foto relawannya" (T-007). Relawan seed tidak punya `photo_path`, jadi avatar menampilkan ikon. Foto sungguhan baru terlihat untuk relawan yang bergabung lewat T-016.
  - `InviteSection(code:)` bisa diberi kode saat test; di aplikasi kode dibaca dari `foundations`. `flutter test test/invite_section_test.dart` → 2 lulus. `flutter analyze` bersih untuk file T-017.
  - Bukti: skrip sebagai pengurus → centang 1 mengisi `id_checked_at`, centang 2 membuat status `aktif`. **Uji manual 2026-10-15** di HP Galaxy A54 (login pengurus): kode SENJA1 dan tombol salin berfungsi, centang dua untuk Dewi (relawan5) memindahkannya ke "Sudah aktif" dengan nama dan waktu pengurus (dikonfirmasi pengguna). relawan5 dikembalikan ke `terdaftar` setelahnya.

### [x] T-019 · Yayasan memasangkan relawan secara manual (bisa paralel)
- **Bergantung pada:** T-006, T-011
- **Deskripsi:** F2a: lansia yang 3 kali menolak usulan dipasangkan manual oleh yayasan.
- **Kriteria selesai:**
  - [x] `manual_pair_screen.dart` menampilkan riwayat 3 penolakan beserta alasannya dan daftar relawan aktif (jarak dan beban).
  - [x] Memilih relawan memanggil `pairing` → `manual`, lalu lansia menjadi `berpasangan`. Dicek manual dengan data dari `try_pairing.ts`.
  - [x] Layar hanya menampilkan ringkasan kondisi (`has_chronic`) tanpa detail profil kesehatan.
- **Catatan:**
  - Pengurus tidak bisa membaca `health_profiles` maupun nama relawan (`profiles`) lewat RLS. Keduanya diambil dari RPC `foundation_dashboard()` milik T-018 (`elders[].has_chronic`, `volunteers[].full_name/load`), sesuai keputusan pengguna. Tidak ada migration baru.
  - Data lain lewat RLS yayasan: `elders` (lansia perlu_yayasan), `proposals` (riwayat + alasan tolak), `volunteers` aktif. Jarak dihitung di aplikasi dengan `haversineKm` (salinan matching.ts), lalu diurutkan dari yang terdekat. Peringatan ditampilkan bila relawan belum berpengalaman demensia/mobilitas, bebannya penuh, atau pernah ditolak. Pemilihan tetap diizinkan, karena keputusan ada di yayasan.
  - Uji manual di HP: `try_pairing.ts --keep` → login pengurus → dashboard → Pak Harjo → Pilih → Pasangkan → DB: `berpasangan`, `volunteer_id` relawan1. `flutter analyze` bersih.
  - **Untuk Cek gabungan Langkah 8:** `router_test.dart:81` (`opensStub 'Contoh pasang manual (stub)'`) kini gagal, karena layarnya bukan stub lagi (dan tautan stub itu dihapus T-018). Baris itu perlu dihapus atau diganti di router_test.
  - Pak Harjo di database sekarang `berpasangan` dengan relawan1. Muat ulang seed demo sebelum gladi bila skenario butuh Pak Harjo belum berpasangan.

## Tahap 3: Alur C — Darurat dan notifikasi

### [x] T-020 · Push notification lewat FCM (bisa paralel)
- **Bergantung pada:** T-006, T-010
- **Deskripsi:** Kanal notifikasi untuk F8 dan status "Segera dikabari", muncul langsung dari aplikasi TemanSenja.
- **Kriteria selesai:**
  - [x] `_shared/push.ts` mengekspor `sendPush(tokens, {title, body, data})`: mengambil token OAuth dari secret `FIREBASE_SERVICE_ACCOUNT`, lalu memanggil FCM HTTP v1. `push_test.ts` (dengan fetch palsu) membuktikan format request benar dan token kosong dilewati.
  - [x] `shared/push_setup.dart`: `registerPush()` meminta izin notifikasi (Android 13+), menyimpan token FCM ke `profiles.fcm_token` dan memperbaruinya saat token berganti. Mengetuk notifikasi membuka detail lansia (keluarga) atau beranda (yayasan).
  - [x] `visit` → `confirm` mengirim push ke HP keluarga dan pengurus yayasan saat status berubah menjadi `segera_dikabari`. Diuji manual dengan 2 HP saat aplikasi keluarga ditutup (dicatat di Catatan).
- **Catatan:**
  - `push.ts` membuat JWT RS256 dengan WebCrypto bawaan Deno (tanpa `jose`), menukarnya ke access token (disimpan di memori fungsi sampai 1 menit sebelum kedaluwarsa), lalu POST FCM v1 per token. Token kosong/duplikat dilewati, `UNREGISTERED` → `skipped`, dan gagal lain → `failed` (dicatat di log, tidak melempar error). `push_test.ts` 3/3 lulus, termasuk verifikasi tanda tangan JWT dengan kunci RSA uji.
  - Uji OAuth sungguhan: dengan `firebase/service-account.json`, Google menerima token OAuth dan hanya menolak token HP palsu (`INVALID_ARGUMENT`, bukan 401).
  - `visit` → `confirm` mengirim push hanya saat status **berubah** menjadi `segera_dikabari` (bukan setiap kunjungan selama status itu bertahan), ke `profiles.fcm_token` milik keluarga dan pengurus yayasan lansia. Kegagalan push tidak membatalkan confirm. Sudah di-deploy ulang.
  - **Uji manual 2026-10-14 23.51** (HP fisik Galaxy A54 `RRCX106FAZT` sebagai keluarga1; relawan1 lewat skrip yang memanggil `visit` → `confirm` yang sama dengan aplikasi): aplikasi keluarga ditutup lewat Recent apps, cerita "terpeleset di kamar mandi" dikirim, notifikasi "Segera dikabari: Ibu Sri Wahyuni" muncul di HP (terlihat juga di `dumpsys notification`), dan mengetuknya membuka detail Ibu Sri (dikonfirmasi pengguna). Seed 03 dimuat ulang setelahnya.
  - Saat aplikasi terbuka, Android tidak menampilkan notifikasi sistem, jadi `push_setup.dart` menampilkan SnackBar dengan tombol "Lihat".
  - Batasan: token tidak dihapus saat logout (HP yang bergantian akun bisa menerima notifikasi akun lama). `LogoutButton` ada di `widgets.dart`, di luar file tugas ini. Jangan memakai Force stop saat demo, karena Android memblokir FCM untuk aplikasi yang di-force stop.

### [x] T-021 · Tombol Darurat relawan (bisa paralel)
- **Bergantung pada:** T-020, T-012, T-013
- **Deskripsi:** F8: konfirmasi, simulasi 119, profil kesehatan siap dibacakan, dan notifikasi ke keluarga serta yayasan.
- **Kriteria selesai:**
  - [x] `functions/emergency/index.ts` sudah di-deploy: hanya relawan pasangan lansia itu yang boleh memanggil (selain itu `403`), menyimpan `emergencies`, mengirim push notification berisi ringkasan dan tautan Google Maps, lalu mengembalikan profil kesehatan.
  - [x] `emergency_screen.dart`: dialog konfirmasi (batal = tidak ada panggilan ke server, dibuktikan dengan `test/emergency_screen_test.dart`), lalu GPS, lalu layar "Memanggil 119 (simulasi)" dengan profil kesehatan dan `DisclaimerLabel`.
  - [x] Kejadian muncul di riwayat pada `elder_detail_screen` keluarga (lewat data `emergencies`), dan uji manual end-to-end dengan push notification di HP keluarga berhasil.
- **Catatan:**
  - `functions/emergency` sudah di-deploy. Skrip sementara lulus 12/12: 401 tanpa login, 400 untuk elder_id/lat salah, 403 untuk relawan lain dan keluarga, 200 untuk relawan pasangan (profil kesehatan kembali, tautan Maps benar), tanpa GPS tetap 200, kejadian tersimpan, keluarga1 bisa membaca riwayat (RLS), dan keluarga2 tidak bisa.
  - `emergency_screen_test.dart` 4/4: Batal → tidak ada panggilan, konfirmasi → layar 119 + profil + DisclaimerLabel, GPS gagal → tetap terkirim, dan riwayat darurat tampil di `ElderDetailView`. Test T-013 (`elder_detail_test`) tetap lulus. `flutter analyze` bersih.
  - **Uji di HP Samsung A54:** (1) keluarga1 di latar belakang, skrip relawan1 menekan Darurat → notifikasi "DARURAT: Ibu Sri Wahyuni" muncul → diketuk → detail dengan Riwayat darurat → peta terbuka. (2) Login relawan1 → Batal (tidak ada efek) → Ya, darurat → izin lokasi → "Memanggil 119 (simulasi)" + profil. DB: GPS sungguhan (−6,1331 / 106,7259), `notified: true`. Seed 03 dimuat ulang setelahnya.
  - Lokasi bersifat opsional: GPS gagal atau ditolak tidak menahan keadaan darurat. Push yang gagal tidak membatalkan kejadian. Riwayat dibaca saat layar dibuka, karena tabel `emergencies` tidak masuk publikasi Realtime.

## Tahap 4: Dashboard dan penutup

### [x] T-018 · Dashboard yayasan (bisa paralel)
- **Bergantung pada:** T-006, T-007
- **Deskripsi:** F9: satu layar untuk melihat lansia yang paling perlu perhatian.
- **Kriteria selesai:**
  - [x] Migration `20261014000500_dashboard.sql` berisi RPC `foundation_dashboard()` yang mengembalikan daftar lansia (nama, status, alasan, `has_chronic`, `pairing_state`), jumlah lansia didampingi, jumlah tanpa pendamping, jumlah `perlu_yayasan`, dan beban per relawan, **tanpa** kolom profil kesehatan.
  - [x] `dashboard_section.dart` mengurutkan daftar: Segera dikabari → Perlu perhatian → Stabil. Lansia `perlu_yayasan` membuka `ManualPairScreen`. Dibuktikan dengan `test/dashboard_section_test.dart` (urutan).
  - [x] Pengurus yayasan dari yayasan lain (bila dibuat sementara) tidak melihat lansia Yayasan Demo, kecuali yang `tanpa_pendamping` atau `perlu_yayasan`.
- **Catatan:**
  - RPC `foundation_dashboard()` mengembalikan satu JSON `{elders, counts, volunteers}` (security definer). Bila bukan pengurus, error 42501. Aturan lansia yang terlihat sama dengan RLS elders, dan dari profil kesehatan hanya `has_chronic` yang keluar. Migration sudah di-push.
  - Skrip sementara lulus 9/9: Yayasan Demo melihat lansianya dan Pak Harjo (dibuat `perlu_yayasan` sementara); hitungan dan beban benar; tidak ada kolom kesehatan; **yayasan uji kedua tidak melihat Ibu Sri** tetapi melihat Pak Harjo `perlu_yayasan`, dengan 0 relawan; keluarga ditolak. Data uji dihapus.
  - `dashboard_section_test.dart` 3/3 (urutan `sortByUrgency`, tampilan, `perlu_yayasan` → pasang manual). `router_test.dart` bagian yayasan diperbarui atas izin pengguna. `flutter analyze` bersih.
  - Uji di HP (pengurus): dashboard tampil dengan **Didampingi 2**, karena Pak Harjo baru dipasangkan manual oleh uji T-019 (Maria). Ini cocok dengan DB.
  - Dashboard dimuat sekali dengan tombol muat ulang (bukan Realtime), karena RPC tidak bisa di-stream.

### [ ] T-025 · Gladi demo end-to-end
- **Bergantung pada:** semua tugas lain yang tidak dipangkas
- **Deskripsi:** Menjalankan Alur A, B, dan C di HP sungguhan dengan urutan pitch, lalu memperbaiki hal kecil yang ditemukan.
- **Kriteria selesai:**
  - [ ] Seed dimuat ulang dari awal, dan `check_auth.ts` serta `check_rls.ts` lulus.
  - [ ] Alur A, B, dan C berjalan sesuai `docs/demo-script.md` dua kali berturut-turut tanpa intervensi kode, dengan hanya panggilan 119 yang disimulasikan.
  - [ ] Semua test (`flutter test`, `deno test supabase/functions/_shared`) dan `flutter analyze` lulus. APK rilis dibangun dengan `flutter build apk` dan terpasang di HP demo.
- **Catatan:**

---

### [x] T-026 · Penyegaran login, daftar, dan beranda relawan
- **Bergantung pada:** T-006, T-012, T-013
- **Deskripsi:** Lanjutan desain langkah 12 sesuai permintaan 16 Okt: desain Masuk/Daftar akun/Home relawan terbaru, grafik ringkasan di bawah riwayat, dan dropdown pemilih lansia.
- **Kriteria selesai:**
  - [x] Login dan daftar mengikuti gambar terbaru, dengan validasi, pemilihan peran, persetujuan, dan navigasi tetap bekerja.
  - [x] Beranda menampilkan jadwal hari ini dari data asli, pilihan lansia, akses rekap/riwayat/darurat, dan kondisi tanpa jadwal.
  - [x] Tab Lansia dan Riwayat memakai dropdown; pilihan konsisten dan data tidak tercampur antar lansia.
  - [x] Grafik per kategori muncul di bawah riwayat relawan; urutan kronologis, hanya hasil tersimpan, dan nilai kosong tidak dianggap baik.
  - [x] Test Flutter dan analisis statis lulus.
- **Catatan:** `flutter test --no-pub` 129 lulus (7 test baru di `test/ui_revision_test.dart`), `flutter analyze --no-pub` bersih. Grafik `DomainChart` dan pemilih kategori dipindahkan ke `shared/condition_summary.dart` agar keluarga/relawan memakai aturan yang sama; fixture grafik keluarga diberi `confirmed_at` sesuai data tersimpan. `schedule_board.dart` memakai jadwal disetujui, geseran, dan kunjungan terkonfirmasi untuk progres; aksi beranda mengikuti satu lansia terpilih. Riwayat memakai `status_after` bila ada; data lama tetap berlabel tanda bahaya, tidak ditebak Stabil. Pratinjau widget diperiksa, belum uji HP. Lupa password baru berupa petunjuk bantuan, belum pemulihan email. Tidak mengubah skema/data cloud atau menambah package.

### [x] T-027 · Perbaikan padding profil dan pemilihan lansia saat rekap
- **Bergantung pada:** T-026
- **Deskripsi:** Perbaikan dari uji HP: jarak isi dropdown profil keluarga, pemilih lansia pada akses rekap umum, serta rekap langsung untuk kartu kunjungan aktif di Beranda.
- **Kriteria selesai:**
  - [x] Bagian profil terbuka memiliki jarak isi yang rapi, form tetap bisa disimpan, dan pengaturan notifikasi tetap bekerja.
  - [x] Rekap umum: lebih dari satu pasangan → pilih lansia; satu pasangan → langsung; Batal tidak membuka form; lansia belum terverifikasi tidak bisa direkap.
  - [x] Rekap Beranda langsung memakai kartu aktif; pilihan pada tab lain tidak mengubah target kunjungan aktif.
  - [x] Test yang relevan dan analisis statis lulus; aplikasi terbaru terpasang kembali di HP bila masih terhubung.
- **Catatan:** 137 test Flutter lulus, analisis statis bersih. Delapan test baru di `visit_entry_test.dart` menguji jarak dan penyimpanan profil, pemilih rekap umum, Batal, satu pasangan, larangan rekap sebelum verifikasi, jalur Riwayat, isolasi pilihan Beranda, serta ID/nama pada form sesungguhnya. Profil bersama keluarga/yayasan memakai padding isi 20 dan jarak field 12. Rekap umum ditaruh di tab Riwayat; `visit_entry.dart` tetap meneruskan ke `startStory` untuk persetujuan kunjungan pertama. `_homeElderId` menyimpan kartu aktif, `_elderId` untuk tab Lansia/Riwayat. APK debug berhasil dibangun/dipasang/dibuka di HP 25080RABDG; menunggu penilaian visual pengguna. Tanpa perubahan skema/data cloud.

### [x] T-028 · Hilangkan banner DEBUG di semua tampilan
- **Bergantung pada:** T-006
- **Kriteria selesai:**
  - [x] Banner dimatikan pada MaterialApp induk sehingga berlaku untuk semua peran dan halaman.
  - [x] Test navigasi dan analisis statis lulus; versi terbaru terpasang di HP.
- **Catatan:** `debugShowCheckedModeBanner: false` di `app/lib/main.dart`; hanya satu MaterialApp dalam aplikasi sehingga semua halaman/peran memakai pengaturan yang sama. 9 test navigasi lulus, analisis statis bersih, APK debug terbaru berhasil dipasang di HP 25080RABDG. Tanpa perubahan backend.

### [x] T-029 · Siapkan paket pengumpulan dan tinjau proposal/pitch deck
- **Bergantung pada:** T-028
- **Deskripsi:** APK rilis untuk pengguna baru, README dan arsip source code siap GitHub, serta pemeriksaan dokumen pengumpulan terhadap PPT TM dan implementasi ReLa.
- **Kriteria selesai:**
  - [x] APK rilis dibangun, konfigurasi publik diverifikasi, dan petunjuk pemasangan/akun demo tersedia.
  - [x] Tautan unduh APK bisa diakses tanpa login dan pemasangan diuji di perangkat.
  - [x] README proyek dan arsip source code siap dibagikan tanpa berkas rahasia atau hasil build.
  - [x] Proposal ditinjau (format, klaim fitur, data uji, model bisnis, dan referensi); temuan ditulis.
  - [x] Pitch deck dapat dibaca dan ditinjau, termasuk pengungkapan tools AI.
- **Catatan:** APK/source sudah publik di AltoDevv/rela atas persetujuan eksplisit pengguna, release v1.0.0 dan snapshot commit fc5f46a. Unduhan anonim APK/source diverifikasi cocok checksum; pemasangan pada emulator kosong Success. UI emulator timeout dan HP belum tersambung, jadi uji visual rilis belum selesai. Ketiga akun demo dapat login melalui koneksi baru ke server; sesi uji ditutup lokal tanpa mengeluarkan perangkat lain. 7 test pengemas dan 52 test server lulus. Proposal A4 5 halaman berhasil direview; klaim prediksi, 119, auto-debit, privasi, dan konteks evaluasi perlu diperbaiki. Catatan lengkap pada dist/submission/review-proposal.md. PDF pitch deck 11 slide yang dikirim pengguna sudah dibaca dan diperiksa visual. Review lengkap dan teks pengganti ada di dist/submission/review-pitch-deck.md: perlu label simulasi 119/pembayaran, tiga peran dan konfirmasi relawan, pengungkapan Codex/tools AI yang benar dipakai, penghapusan klaim kepatuhan mutlak, bukti demo/evaluasi, dan sumber/asumsi biaya/pasar. Tugas review/paket selesai; dokumen asli belum diubah dan gladi/uji visual tetap T-025.

### [x] T-030 · Jadwal per lansia dan Beranda kunjungan berikutnya
- **Bergantung pada:** T-026, T-027
- **Deskripsi:** Pindahkan Atur/Ubah jadwal dan Geser kunjungan dari Beranda relawan ke tab Lansia; Beranda menjadi ringkasan jadwal tanpa pemilih kartu.
- **Kriteria selesai:**
  - [x] Tab Lansia menampilkan jadwal rutin, waktu kunjungan berikutnya/geseran, atau status belum ada/usulan, mengikuti dropdown lansia.
  - [x] Atur/Ubah jadwal dan Geser kunjungan mengirim ID lansia terpilih dan memuat ulang data setelah perubahan.
  - [x] Kartu Beranda tidak dapat dipilih; kunjungan berikutnya dan aksi rekap/riwayat mengikuti jadwal otomatis, termasuk kunjungan selesai dan jadwal hari berikutnya.
  - [x] Test terarah dan analisis statis lulus; APK terbaru dibangun dan dipasang bila HP tersambung.
- **Catatan:** 30 test terarah lulus, termasuk 6 test baru di volunteer_schedule_page_test.dart; analisis statis bersih dan APK rilis berhasil. Jadwal di elder_tab.dart memakai VolunteerScheduleRow; aksi pairing tetap sama dan refresh setelah kirim. home_screen.dart dan schedule_board.dart menentukan target otomatis melalui nextScheduledVisit, tanpa state/pilihan kartu Beranda. Slot selesai lebih awal dilewati, draf tidak dianggap selesai, jadwal berikutnya dapat lintas hari. Dialog jadwal scrollable setelah test 360×640 menemukan overflow. PRD/arsitektur diperbarui. APK lokal: dist/updates/jadwal-relawan/ReLa-jadwal-relawan.apk beserta checksum dan verification.json; belum dipublikasikan ke GitHub. Pembaruan APK berhasil dipasang di HP 25080RABDG lewat adb install -r (Success); data aplikasi dipertahankan. Penilaian visual pengguna masih menunggu. Tanpa perubahan skema/backend/data cloud atau package.

### [x] T-031 · Timeline Beranda relawan sesuai Home.png
- **Bergantung pada:** T-030
- **Deskripsi:** Sesuaikan titik dan garis vertikal, kartu kunjungan berikutnya, serta tombol pada Beranda dengan docs/figma/Relawan/Home.png tanpa mengembalikan pemilih kartu.
- **Kriteria selesai:**
  - [x] Titik tersambung garis vertikal yang mengikuti tinggi kartu; kartu berikutnya memakai titik penuh dengan lingkar luar.
  - [x] Kartu dan tombol mendekati proporsi/warna Home.png; Tampilkan membuka tab Lansia tanpa mengganti target otomatis Beranda.
  - [x] Test terarah dan analisis statis lulus; pratinjau visual dibandingkan dengan referensi.
  - [x] APK terbaru dibangun dan dipasang/dibuka di HP bila tersambung.
- **Catatan:** schedule_board.dart memakai baris dengan titik dan segmen garis yang mengikuti tinggi kartu, bukan tinggi tetap. Kartu berikutnya krem dengan halo titik; kartu lainnya memiliki Tampilkan yang hanya membuka tab Lansia, target rekap tetap otomatis. Header/status, avatar, badge waktu, tombol putus-putus, dan riwayat ringkas mengikuti proporsi Home.png. Kontak tetap di tab Lansia; jam akhir tidak dibuat-buat karena data hanya berisi waktu mulai. 32 test terarah lulus (2 test baru untuk koneksi garis dan isolasi target), satu render visual data fiktif dibandingkan dengan referensi, analisis statis bersih. APK dist/updates/home-timeline/ReLa-home-timeline.apk berhasil dipasang (Success) dan diluncurkan (Status ok) di HP 25080RABDG. HP terkunci, penilaian visual akhir menunggu pengguna membuka kunci. Tidak mengubah data cloud, skema, atau dependency; GitHub belum diperbarui.

### [x] T-032 · Perbarui rilis dan source pengumpulan ke versi terbaru
- **Bergantung pada:** T-031
- **Deskripsi:** Terbitkan perubahan jadwal/timeline relawan sebagai rilis 1.0.1 dan perbarui source, README, serta panduan pengumpulan.
- **Kriteria selesai:**
  - [x] APK versi 1.0.1+2 dibangun dari source terbaru; arsip source lulus pemeriksaan materi privat.
  - [x] Source publik dan ZIP sama dengan snapshot perubahan terbaru; commit/push bersih ke AltoDevv/rela.
  - [x] Rilis v1.0.1 menjadi latest, dengan APK/source/checksum/panduan dan tautan unduh stabil.
  - [x] Unduhan tanpa login diverifikasi beserta checksum; README/panduan menampilkan alur jadwal yang baru.
- **Catatan:** Versi app/pubspec.yaml menjadi 1.0.1+2. README/panduan memakai tautan latest/download/ReLa.apk dan menjelaskan jadwal di Lansia, target otomatis Beranda, serta dua HP. Snapshot 239 berkas lulus pemindaian materi privat; isi ZIP cocok byte demi byte dengan commit 0e5c15b, staging satu per satu, co-author Codex, push main berhasil. GitHub rilis v1.0.1 terbaru berisi ReLa.apk, ReLa-source.zip, SHA256SUMS.txt, panduan. Repository ternyata private saat cek anonim (404); dipulihkan public berdasarkan izin eksplisit sebelumnya, lalu keempat lampiran HTTP 200 dan SHA256 cocok, README publik sesuai. 145 test Flutter, 52 server, 7 pengemas lulus; analyzer bersih. Root dist/submission berisi paket baru, versi lama dipindah ke archive/v1.0.0, tautan siap salin tersedia di LINK-PENGUMPULAN.md. Proposal/deck asli belum diedit. HP tidak terhubung; build ini hanya menaikkan versi dari UI T-031 yang sebelumnya terpasang. Tidak mengubah skema/data cloud atau memakai kuota Gemini.

### [x] T-033 · Tanggapi laporan kebocoran key GitHub
- **Deskripsi:** Batasi akses repository, audit source/riwayat/artefak tanpa mencetak kredensial, periksa batasan key, dan cegah konfigurasi Firebase asli ikut source pengumpulan berikutnya.
- **Kriteria selesai:**
  - [x] Repository private dan distribusi publik ditahan sampai pengguna menyetujui publikasi ulang.
  - [x] Lokasi key dan kecocokan dengan Gemini/service account diaudit serta dilaporkan tanpa nilai key.
  - [x] Pengemas dan dokumentasi diperbaiki agar konfigurasi client Firebase asli tidak ikut source; test regresi lulus.
  - [x] Pembatasan Cloud lengkap dan status key yang diperingatkan diverifikasi dari akun pemilik; key client dipertahankan dengan API/application restrictions yang sesuai dan lulus uji langsung (tidak dirotasi).
- **Catatan:** Repository private (terverifikasi API dan akses anonim 404). Firebase client key ditemukan pada dua file google-services.json, kedua commit publik, dan kedua ZIP. Tidak ada kecocokan key Gemini demo/eval lokal, service role Supabase, atau private key service account pada source/riwayat/ZIP; APK lama/baru tidak memuat key Gemini lokal. Firebase key ditolak oleh endpoint model Gemini: 403 API_KEY_SERVICE_BLOCKED. 28 uji backend read-only lulus; 17 tabel RLS aktif, 4 bucket private. Pengemas lama keliru mengizinkan konfigurasi Firebase; kini diblokir meski tracked, pola Google key juga diblokir, contoh placeholder dan README diperbarui; 9 test lulus. ZIP sanitasi 238 file diverifikasi tanpa config/key asli. **Review Cloud selesai melalui Chrome pemilik:** UID key cocok dengan metadata aplikasi; Android package/SHA-1 APK dibatasi, allowlist 25 → 4 API pendukung FCM, Save dibaca ulang. 6/6 uji langsung lulus: identitas Android cocok diterima, tanpa/salah identitas ditolak, Gemini/Auth diblokir; instalasi teknis uji dihapus HTTP 200. Kedua proyek saat ini tanpa linked billing account, metrik 30 hari diperiksa (Firebase FCM 58, Gemini 171; angka agregat tidak membuktikan atribusi/riwayat). Tiga key Gemini dibatasi Gemini API. Tidak merotasi key client karena perbaikan terverifikasi berupa pembatasan sesuai penggunaan Firebase; peringatan Google terpisah yang meminta pencabutan tetap harus ditindaklanjuti bila ada. GitHub private, secret scanning API 404 disabled, bukan bukti tiada alert. HP tidak terhubung sehingga push menyeluruh belum diulang. Laporan lengkap dist/security/SECURITY-REVIEW.md. Tidak mengaktifkan layanan baru/IAM, mengubah data Supabase, commit, rewrite Git, atau mempublikasikan ulang.

### [~] T-034 · Siapkan kembali paket teknis pengumpulan setelah audit key
- **Bergantung pada:** T-033
- **Deskripsi:** Siapkan APK, panduan juri, source sanitasi, repository baru tanpa riwayat konfigurasi lama, dan rilis draft. Proposal, pitch deck, serta video dikelola pengguna.
- **Kriteria selesai:**
  - [ ] APK 1.0.1/build 2, panduan akun demo, source ZIP dan checksum disiapkan dalam satu folder pengumpulan yang jelas.
  - [ ] Snapshot baru tidak memuat konfigurasi Firebase asli, env privat, key server, atau riwayat Git lama; pengemas dan pemindaian lulus.
  - [ ] Source dan lampiran diunggah ke repository private baru serta rilis draft; unduhan terautentikasi cocok dengan checksum dan akun demo dapat login.
  - [ ] Pengguna memberikan izin publikasi baru; repository/rilis publik dan tautan juri diuji tanpa login.
- **Catatan:** Pengguna meminta persiapan bagian teknis setelah menyatakan proposal, pitch deck, dan video akan dikumpulkan sendiri. Repository lama AltoDevv/rela tetap private; persiapan baru memakai AltoDevv/rela-submission agar riwayat lama tidak ikut. Publikasi masih menunggu persetujuan baru sesuai penahanan pascainsiden.

## Usulan

- **Uji di HP saat gladi T-025: langganan + verifikasi keluarga (15 Okt)** — ikuti "Alur verifikasi keluarga" di `docs/demo-script.md` dengan 3 HP/akun (keluarga baru, pengurus, relawan yang diusulkan). Cek juga: relawan melihat peringatan oranye dan tombol Cerita kunjungan nonaktif sebelum verifikasi; tolak dokumen → keluarga melihat alasan dan bisa unggah ulang.
- **Uji di HP saat gladi T-025: masukan & langganan (15 Okt)** — keluarga1 → detail Ibu Sri → menu "Beri masukan tentang relawan" (coba ketiga kategori; kedua kalinya dalam seminggu ditolak kecuali "serius"); relawan1 melihat "Ucapan terima kasih" hanya untuk apresiasi; pengurus → "Masukan keluarga" → Tangani; keluarga melihat catatan yayasan. Kartu "Langganan" → Tambah 30 hari → riwayat pembayaran.
- **Uji di HP saat gladi T-025: alur relawan baru (15 Okt)** — ikuti "Alur relawan baru" di `docs/demo-script.md` (2 HP: relawan baru + pengurus). Cek juga: kode salah 5× → harus minta kode baru; permintaan berhenti tampil "menunggu yayasan" di HP relawan.
- **Belum dikerjakan (lanjutan K1/K5):** tombol "Saya merasa tidak aman" + check-in/check-out kunjungan untuk relawan, notifikasi layar kunci yang generik (K4).

- **WAJIB sebelum produksi (ditunda karena mode demo, keputusan pengguna 15 Okt): K2 + K3.** (K2) Nyalakan konfirmasi email di Supabase Auth: saat ini siapa pun bisa mendaftar memakai email orang lain dan langsung masuk, lalu menerima undangan keluarga/pengurus yang ditujukan ke email itu (terbukti lewat API). Butuh SMTP sendiri karena kuota email bawaan Supabase kecil; akun demo sudah terkonfirmasi. (K3) Password minimal 8 karakter berisi huruf dan angka, di pengaturan Supabase Auth dan di validator `signup_screen.dart` (saat ini `123456` diterima).

- **Uji di HP saat gladi T-025: pemilih lokasi peta (15 Okt)**: (1) Daftarkan lansia → isi alamat lengkap → Simpan → peta terbuka dengan saran; pilih saran, geser pin ke atap rumah, "Pilih lokasi ini"; (2) ubin peta tampil dan atribusi "OpenStreetMap contributors" terlihat; (3) tombol lokasi saya meminta izin lalu memindah peta; (4) relawan baru (Gabung) dan Profil saya → "Titik tempat tinggal"; (5) ubah alamat lansia → saat simpan peta terbuka lagi dengan titik lama. Cek juga di sinyal lemah: pencarian gagal → pesan, pin tetap bisa digeser.

- **Uji di HP saat gladi T-025: perbaikan evaluasi E1–E8 (15 Okt)** (backend teruji lewat `check_security.ts`, belum dicoba di layar): (1) relawan mencabut centang tanda bahaya AI → dialog alasan muncul, Batal = tetap tercentang; setelah Simpan baris "Koreksi relawan…" tampil di detail keluarga dan di dashboard walau Stabil; (2) cerita kedua di hari yang sama → pesan "Kunjungan hari ini sudah dicatat"; (3) pengurus → Tambah pengurus → akun keluarga baru melihat kartu undangan, Terima → keluar → masuk lagi sebagai pengurus; (4) akun tanpa persetujuan syarat → layar "Saya setuju" sebelum beranda; (5) Pasang manual Pak Harjo: alamat tersembunyi, jarak relawan tetap tampil. Catatan: pg_cron mengirim pengingat 08.00 WIB; Ibu Sri (kunjungan terakhir 6 Okt) akan memicu push "belum dikunjungi" ke HP demo.

(Ide di luar tugas yang muncul saat bekerja. Dicatat di sini, tidak dikerjakan.)

- **Prompt tanda bahaya versi B** (15 Okt, belum dipasang): definisi per tanda bahaya menurunkan alarm palsu 10 → 3 dan akurasi 88,6% → 89,4%, tetapi S16 ("Katon lara banget, raine pucet") terlewat (recall 17/18). Pertimbangkan bila relawan memang memeriksa tanda bahaya di F5. Teksnya disimpan di laporan sesi; label S16 mungkin lebih tepat sebagai kondisi umum "Tampak sakit berat".

- **Uji di HP saat gladi T-025: fitur siklus hidup 15 Okt** (backend teruji lewat skrip, UI lewat widget test): Berhenti mendampingi (relawan), Minta ganti pendamping / Ubah data & profil kesehatan / Anggota keluarga / Akhiri pendampingan (menu detail lansia), Lepas pendamping (ketuk lansia berpasangan di dashboard), Koreksi kunjungan terakhir (relawan), Hapus akun (menu akun), dan "Kunjungan terakhir". Jalankan skrip reset 04 dan 03 setelahnya. Tambahan dari pengerasan: kartu Undangan di beranda keluarga (Terima/Tolak), Aktifkan kembali, Tandai sudah ditangani, Profil saya (relawan), Tambah pengurus yayasan, Darurat ditekan dua kali, notifikasi di dua perangkat satu akun. Juga: centang Syarat saat daftar akun, pilihan persetujuan lansia di form pendaftaran, dan mencentang/mencabut tanda bahaya di layar konfirmasi relawan.

- **Domain terlemah ekstraksi** (T-024): Kondisi umum 77,1% (sering memberi "Sehat" padahal tidak disebut, dan melebihkan menjadi "Tampak sakit berat") dan Nafsu makan 82,9% (tertukar antara "Sangat sedikit" dan "Tidak makan"). Alarm palsu "keluhan baru" 6×. Bahasa Jawa/campuran 82,7% vs Indonesia 92,9%. Perbaikan prompt dan rubrik di luar T-024; ukur ulang dengan skrip yang sama.

- **Uji di HP saat gladi T-025: relawan baru lewat layar** (Cek gabungan 9). Backend alur undangan → verifikasi → aktif sudah lulus 10/10 lewat skrip, tetapi tampilan JoinScreen (OTP simulasi, kamera depan, unggah foto) dan VerifyVolunteersScreen (foto dan dua centang) belum dicoba di HP karena HP tidak tersedia. Hapus akun ujinya setelah selesai.

- **Skrip reset data demo lengkap** (Cek gabungan 7 dan 8): uji manual berkali-kali meninggalkan data (akun relawan uji, Pak Harjo berpasangan beserta usulannya), sehingga `check_rls` gagal. Usulan: `supabase/seeds/04_reset_demo.sql` yang mengembalikan Pak Harjo ke `mencari` tanpa usulan, menghapus lansia/akun di luar seed, dan dijalankan bersama seed 03 sebelum gladi (T-025). **→ Dikerjakan 15 Okt: `supabase/seeds/04_reset_demo.sql`.**

- **Data demo batas 3 usulan** (T-015): hanya 2 relawan aktif yang mampu mendampingi demensia, sehingga lansia demensia (Pak Harjo) berakhir `tanpa_pendamping` setelah 2 penolakan dan tidak pernah sampai ke "usulan ke-3 → yayasan"-. Kalau alur ini mau diperagakan, tambahkan 1 relawan aktif `can_dementia` di seed 02, atau peragakan dengan lansia tanpa demensia.

- **Kutipan berisi "[nama]" di alasan status** (Cek gabungan Langkah 5): nama lansia disamarkan sebelum dikirim ke Gemini, sehingga kalimat bukti dan `status_reason` bisa berbunyi "Kemarin sore [nama] [nama] jatuh…". Keluarga akan melihatnya. Opsi: kembalikan placeholder ke nama asli setelah respons Gemini divalidasi (di sisi server), atau tampilkan "Ibu/Bapak". Belum dikerjakan.
- **Retry untuk Gemini 503** di `_shared/gemini.ts` (usulan T-010): 1–2 kali dengan jeda, hanya untuk 503 dan bukan untuk 429, karena retry pada 429 justru menghabiskan kuota.
