# Arsitektur — ReLa

**Dasar:** `docs/prd.md` (draf 2026-10-14)
**Batasan:** deadline 15 Oktober 2026 pukul 23.50, tim 4 orang, budget Rp0, belum punya akun layanan apa pun.

---

## 1. Gambaran besar

```
 ┌──────────────────────────┐
 │  Aplikasi Flutter (HP)   │  satu aplikasi, tampilan berbeda per peran:
 │  keluarga/relawan/yayasan│  keluarga · relawan · pengurus yayasan
 └────────────┬─────────────┘
              │ supabase_flutter (publishable key + JWT pengguna)
 ┌────────────▼──────────────────────────────────────────────┐
 │ Supabase                                                  │
 │  Auth ─ login email + password                            │
 │  PostgreSQL ─ semua data + Row Level Security (RLS)       │
 │  Storage ─ foto wajah relawan (bucket privat)             │
 │  Realtime ─ status & rekap langsung muncul di HP keluarga │
 │  Edge Functions (TypeScript/Deno) ─ logika server:        │
 │     pairing · visit · emergency                           │
 └──────┬───────────────────────────────┬────────────────────┘
        │                               │
 ┌──────▼──────────┐            ┌───────▼───────────────┐
 │ Gemini API      │            │ FCM (push notif)      │
 │ (free tier)     │            │ notifikasi darurat    │
 │ cerita → JSON   │            │ ke HP keluarga/yayasan│
 └─────────────────┘            └───────────────────────┘
```

Prinsipnya: **aplikasi tidak pernah dipercaya untuk aturan penting.** Siapa boleh melihat
data apa dijaga oleh RLS di database. Pemasangan relawan, ekstraksi AI, perhitungan status,
dan notifikasi berjalan di Edge Function. Aplikasi hanya menampilkan dan mengirim input.

---

## 2. Tech stack

| Lapisan | Pilihan | Alasan |
|---|---|---|
| Aplikasi mobile | **Flutter 3 (Dart)**, target Android | Sudah dikuasai tim. Satu kode untuk semua peran. Demo cukup di HP Android, iOS tidak perlu dibangun dulu. |
| State & navigasi | `setState` + `StreamBuilder`/`FutureBuilder` + `Navigator` bawaan | Tanpa Riverpod/Bloc/go_router. Layarnya sedikit, dan tim tidak perlu belajar library baru dalam 1,5 hari. |
| Backend | **Supabase** (free tier) | Postgres, login, storage, realtime, dan fungsi server ada dalam satu akun gratis tanpa kartu kredit. |
| Database | **PostgreSQL** (dari Supabase) | Datanya relasional (lansia ↔ usulan ↔ relawan ↔ kunjungan). Jarak, syarat, beban, dan tren cukup dengan query SQL. |
| Aturan akses | **Row Level Security** | Aturan privasi PRD (yayasan tidak melihat profil kesehatan, relawan hanya melihat pasangannya) ditegakkan oleh database, jadi tidak bisa terlewat oleh bug di aplikasi. |
| Logika server | **Supabase Edge Functions** (TypeScript, Deno) | Tempat menyimpan API key secara aman. Logika murni (status, pemasangan) bisa dites dengan `deno test`. |
| Model bahasa | **Google Gemini** (model Flash di free tier, nama model disimpan di secret `GEMINI_MODEL`) | Gratis, cukup login akun Google. Mendukung keluaran JSON dengan skema (`responseSchema`) sehingga hasilnya terstruktur. |
| Speech-to-text | Package **`speech_to_text`** (STT bawaan HP) | Gratis, tanpa server, mendukung bahasa Indonesia. Hasilnya masuk ke kolom teks dan bisa disunting (F3). Termasuk P1 opsional. |
| Notifikasi | **Firebase Cloud Messaging (FCM)** + package `firebase_core`, `firebase_messaging` | Notifikasi muncul langsung dari aplikasi ReLa, tanpa aplikasi lain (keputusan pengguna). Gratis di paket Spark tanpa kartu kredit. Firebase **hanya** dipakai untuk push; data tetap di Supabase. |
| Lokasi | `geolocator` (GPS) + `flutter_map`/`latlong2` (peta OpenStreetMap, satelit Esri) + pencarian Photon lewat `http` | Gratis tanpa API key; titik rumah dipilih di peta (pin digeser), bukan ditebak dari teks (15 Okt, menggantikan `geocoding`). |
| Kamera | Package `image_picker` dengan `ImageSource.camera` saja | Memenuhi F1a: foto hanya dari kamera, bukan dari galeri. |
| Tautan undangan | Package `app_links` (skema `temansenja://join?code=XXXX`) | Membuka aplikasi langsung dari tautan. Kode undangan tetap bisa diketik manual sebagai cadangan. |
| Grafik tren | Package `fl_chart` | Library grafik Flutter paling populer dan dokumentasinya banyak. |
| Testing | `flutter test`, `deno test` | Bawaan masing-masing bahasa, tanpa framework tambahan. |

---

## 3. Struktur folder

Diperbarui 15 Okt sesuai kode yang ada (rencana awal memakai `0001_schema.sql`; kenyataannya satu file migration per perubahan).

```
hackathon/
├── CLAUDE.md · AGENTS.md (Codex) · todo.md · progress.md · prompt.md
├── docs/  prd.md · architecture.md · demo-script.md · ringkasan-proyek.md
├── app/                                   # Flutter (Android)
│   ├── env.example.json                   # env.json (rahasia publik: URL + publishable key) di-.gitignore
│   ├── lib/
│   │   ├── main.dart                      # AuthGate: login → TermsGate → beranda per peran
│   │   ├── auth/                          # login, daftar (centang syarat)
│   │   ├── shared/                        # models, rubric, widgets (StatusBadge, menu akun, hapus akun),
│   │   │                                  # push_setup, terms_screen (+TermsGate), location_picker (peta OSM)
│   │   ├── keluarga/                      # elder_list, register_elder (peta), verify_elder (bayar + dokumen),
│   │   │                                  # proposal_screen, elder_detail (status, tren, rekap, darurat,
│   │   │                                  # kontak relawan), care_cards (langganan, masukan), review_dialog,
│   │   │                                  # family_members
│   │   ├── relawan/                       # join (OTP simulasi, foto, peta), paired_elders (kunjungan pertama),
│   │   │                                  # visit_story, visit_confirm (alasan cabut tanda bahaya), emergency,
│   │   │                                  # profile, appreciation_section
│   │   └── yayasan/                       # dashboard_section, verify_volunteers (butir pemeriksaan),
│   │                                      # verify_family (dokumen), manual_pair, reviews_screen, invite_section
│   └── test/                              # widget & unit test per layar (flutter test)
├── supabase/
│   ├── config.toml                        # [functions.reminders] verify_jwt = false
│   ├── migrations/                        # 22 file, 20261014000100_profiles.sql … 20261015002200_reviews_billing.sql
│   ├── seeds/                             # 01_accounts, 02_demo_core, 03_visits_ibu_sri, 04_reset_demo, ibu_sri.json
│   └── functions/
│       ├── _shared/                       # rubric, status, matching, extract, gemini, push, recipients,
│       │                                  # overrides (+ *_test.ts)
│       ├── pairing/      # propose · accept · reject · manual · release · end · reopen · delete · verify
│       ├── visit/        # extract · confirm (alasan wajib bila tanda bahaya AI dicabut)
│       ├── emergency/    # darurat + push + profil kesehatan untuk 119
│       ├── account/      # hapus akun (relawan: lansia ke yayasan; keluarga: pindah ke anggota)
│       ├── reminders/    # dipanggil pg_cron 08.00 WIB: >7 hari tanpa kunjungan, langganan hampir habis
│       └── review/       # masukan keluarga untuk relawan (3 kategori)
├── data/eval/                             # cerita berlabel untuk akurasi ekstraksi
└── scripts/                               # check_rls, check_auth, check_security (49 serangan), try_*, eval_extraction
```

---

## 4. Model data

Hanya entitas yang dibutuhkan fitur MVP. Semua tabel memakai `id uuid` dan `created_at timestamptz`.

### `profiles` (satu baris per akun, `id` = `auth.users.id`)
| Kolom | Tipe | Catatan |
|---|---|---|
| role | text | `keluarga` · `relawan` · `yayasan` |
| full_name | text | |
| phone | text | |
| phone_verified | bool | OTP disimulasikan (P2) |
| foundation_id | uuid → foundations | untuk pengurus yayasan dan relawan |
| fcm_token | text null | token push HP terakhir, diisi aplikasi setelah login (`push_setup.dart`) |

### `foundations`
| Kolom | Tipe | Catatan |
|---|---|---|
| name | text | |
| verified | bool | F0, diisi lewat seed (P3) |
| invite_code | text unique | 6 karakter, untuk tautan dan kode undangan |

### `volunteers` (`id` = `profiles.id`)
| Kolom | Tipe | Catatan |
|---|---|---|
| foundation_id | uuid not null | relawan tanpa yayasan tidak pernah punya baris di sini |
| status | text | `terdaftar` → `aktif` |
| area_label, lat, lng | text, float8, float8 | area relawan |
| available_days | text[] | contoh `{selasa,jumat}` |
| languages | text[] | contoh `{indonesia,jawa}` |
| can_dementia, can_mobility | bool | diisi sendiri oleh relawan |
| photo_path | text | path di bucket privat `volunteer-photos` |
| id_checked_by, id_checked_at | uuid, timestamptz | centang 1 (F1b) |
| oriented_by, oriented_at | uuid, timestamptz | centang 2 (F1b) |
| max_load | int default 3 | [ASUMSI: angka belum ditentukan di PRD] |

Trigger: begitu kedua centang terisi, `status` otomatis menjadi `aktif`.

### `elders`
| Kolom | Tipe | Catatan |
|---|---|---|
| family_id | uuid → profiles | |
| full_name, address | text | **tidak pernah dikirim ke Gemini** |
| lat, lng | float8 | titik dari pemilih peta (wajib lengkap & di Indonesia) |
| needs | text | kebutuhan |
| has_dementia, has_mobility_issue | bool | pilihan ya/tidak di form F1 |
| volunteer_id | uuid null → volunteers | terisi setelah usulan diterima atau dipasang manual |
| foundation_id | uuid null | yayasan relawannya |
| pairing_state | text | `mencari` · `menunggu_keluarga` · `berpasangan` · `tanpa_pendamping` · `perlu_yayasan` |
| status | text | `stabil` · `perlu_perhatian` · `segera_dikabari` |
| status_reason | text | kutipan kalimat relawan, saran, dan pernyataan bukan diagnosis |

### `health_profiles` (`elder_id` sebagai PK)
Dipisah dari `elders` supaya RLS bisa menyembunyikan seluruh tabel ini dari yayasan.
Kolom: `conditions`, `allergies`, `medications` (jsonb `[{name, times}]`), `diet_restrictions`,
`mobility_aids`, `doctor_hospital`, `emergency_instructions`, dan `has_chronic` (bool, satu-satunya
informasi yang boleh dilihat yayasan).

### `proposals`
| Kolom | Tipe | Catatan |
|---|---|---|
| elder_id, volunteer_id | uuid | `unique(elder_id, volunteer_id)`: relawan yang ditolak tidak diusulkan lagi ke lansia yang sama |
| attempt | int check (1..3) | usulan ke-1, ke-2, atau ke-3 |
| distance_km | numeric | |
| reason_text | text | contoh "Jarak 1,2 km · berpengalaman mendampingi lansia dengan demensia" |
| state | text | `pending` · `accepted` · `rejected` · `manual` |
| reject_reason | text null | `jarak` · `jadwal` · `bahasa` · `lainnya` |
| reject_note | text null | wajib bila `lainnya` |

Index unik parsial `on proposals(volunteer_id) where state = 'pending'` membuat relawan yang
sedang "dipesan" tidak bisa diusulkan ke lansia lain. Aturan ini dijaga oleh database, bukan oleh kode.

### `visits`
| Kolom | Tipe | Catatan |
|---|---|---|
| elder_id, volunteer_id | uuid | |
| visited_at | timestamptz | |
| answers | jsonb | 7 jawaban cerita `{makan, obat, gerak, harian, ingatan, hati, lain}` |
| ai_result | jsonb | hasil asli Gemini: `{domain: {level 0–3 \| null, evidence}}` + `red_flags[]` |
| final_result | jsonb null | setelah dikoreksi atau dikonfirmasi relawan (F5). Disimpan berdampingan dengan `ai_result` sebagai data berlabel. |
| confirmed_at | timestamptz null | |

Level 0 berarti kategori terbaik dan 3 terburuk, sesuai urutan di rubrik F4. `null` berarti "tidak disebut".

### `emergencies`
Kolom: `elder_id`, `volunteer_id`, `lat`, `lng`, `summary`, `notified` (bool).

---

### Tambahan setelah MVP (15 Okt)
| Tabel / kolom | Isi | Siapa menulis |
|---|---|---|
| `family_members` (elder_id, profile_id, accepted_at) | anggota keluarga lain; aktif setelah menerima undangan | RPC `add_family_member`, `accept_family_invite` |
| `push_tokens` (token, profile_id) | banyak perangkat per akun | RPC `register_push_token` / `unregister_push_token` |
| `foundation_admin_invites` | undangan menjadi pengurus yayasan | RPC `add_foundation_admin`, `answer_admin_invite` |
| `reviews` (kind apresiasi/perbaikan/serius, body, handled_*) | masukan keluarga untuk relawan | Edge Function `review`; ditangani RPC `handle_review` |
| `payments` (elder_id, paid_by, period_end, provider) | riwayat langganan | RPC `simulate_payment` (produksi: webhook gateway) |
| `elders`: ended_reason/at, status_ack_*, consent_type/by/at, last_reminder_at, paid_until/by, verify_state/note, verified_by/at, first_visit_at | siklus hidup, persetujuan, pengingat, langganan, verifikasi keluarga | trigger/RPC/Edge Function; aplikasi tidak boleh menulis (hak kolom) |
| `visits.overrides` | koreksi relawan yang menurunkan penilaian AI + alasan | Edge Function `visit` |
| `profiles.terms_accepted_at` | persetujuan syarat | trigger `handle_new_user`, RPC `accept_terms` |
| bucket `elder-docs` | KTP keluarga, KTP lansia, KK/surat RT-RW; dihapus setelah diperiksa | keluarga unggah; yayasan lansia itu membaca |

Aturan yang ditegakkan trigger (bukan aplikasi): status relawan dari dua centang, nama relawan terkunci setelah verifikasi, maks. 3 lansia per akun, satu kunjungan terkonfirmasi per hari (maks. 3 cerita), kunjungan hanya setelah keluarga terverifikasi + kunjungan pertama + langganan (tenggang 7 hari), persetujuan lansia wajib.

---

## 5. Alur utama

### Alur A: Pendaftaran → usulan → terima/tolak (F1, F2, F2a)
1. Keluarga mengisi form F1 dan memilih titik rumah di peta, lalu aplikasi menyimpan ke `elders` dan `health_profiles` lewat RLS. Sejak 15 Okt: berlangganan (simulasi) dan mengunggah dokumen dulu sebelum relawan dicarikan.
2. Aplikasi memanggil `pairing` dengan `{action: "propose", elder_id}`. Fungsi ini:
   - mengambil kandidat: relawan `aktif`, memenuhi syarat demensia dan mobilitas, belum pernah ditolak untuk lansia ini, tidak sedang `pending`, dan bebannya di bawah `max_load`;
   - `matching.ts` mengurutkan kandidat berdasarkan jarak (haversine), lalu memakai beban terendah sebagai pemecah seri, kemudian menyusun `reason_text`;
   - menyimpan `proposals` (state `pending`) dan mengubah `pairing_state` menjadi `menunggu_keluarga`. Bila tidak ada kandidat, `pairing_state` menjadi `tanpa_pendamping`.
3. Keluarga membuka kartu usulan lewat RPC `get_proposal_card(id)`. RPC ini hanya mengembalikan field yang aman: foto (signed URL), nama, yayasan, keahlian, hari, bahasa, jarak, alasan, dan keterangan verifikasi. Nomor HP dan lokasi relawan tidak ikut.
4. Bila keluarga menekan **Terima** (`pairing` → `accept`), `elders.volunteer_id` dan `foundation_id` terisi dan `pairing_state` menjadi `berpasangan`. Sejak itu RLS mengizinkan relawan melihat lansia tersebut.
5. Bila keluarga menekan **Tolak** (`pairing` → `reject`, dengan alasan), fungsi langsung menjalankan `propose` lagi. Bila ini usulan ke-3, `pairing_state` menjadi `perlu_yayasan`.
6. Untuk lansia `perlu_yayasan`, yayasan menekan `pairing` → `manual` dengan memilih salah satu relawan aktif.

### Alur B: Cerita → kategori → konfirmasi → status → tren (F3–F7)

Navigasi relawan (16 Okt, T-030): `schedule_board.dart` merangkum jadwal tanpa aksi pilih kartu.
`nextScheduledVisit` mendahulukan slot hari ini yang belum dikonfirmasi, termasuk yang terlambat,
lalu mengambil jadwal terdekat sesudahnya; kunjungan yang selesai lebih awal tidak ditawarkan lagi pada hari
yang sama. `home_screen.dart` memakai target yang sama untuk kartu, rekap, riwayat, dan darurat, terpisah
dari pilihan dropdown Lansia/Riwayat. Tanpa jadwal disetujui, Beranda mengarahkan ke tab Lansia.
`elder_tab.dart` memuat `VolunteerScheduleRow` sesuai ID pilihan; usulan rutin dan geseran tetap dikirim
ke aksi `pairing.schedule_propose`/`schedule_shift`, lalu data dimuat ulang. Tidak mengubah kontrak server.

Penyelarasan Home.png (T-031): timeline memakai titik dan segmen garis vertikal pada tiap baris,
dengan tinggi mengikuti konten kartu. Titik kunjungan berikutnya penuh dengan lingkar luar; kartu tidak
menjadi pemilih. Tombol **Tampilkan** membuka tab Lansia untuk baris tersebut, sementara target Beranda
tetap otomatis. Kontak keluarga tetap tersedia di tab Lansia; kartu Beranda menampilkan nama, usia/alamat,
dan waktu kunjungan mengikuti referensi. Durasi selesai tidak dikarang karena data hanya menyimpan jam mulai.

1. Relawan mengisi 7 pertanyaan dengan mengetik atau dikte, lalu aplikasi menyimpan `visits.answers`.
2. Aplikasi memanggil `visit` → `extract`. `extract.ts`:
   - membuang nama dan alamat lansia dari teks, termasuk bila relawan menulisnya;
   - mengirim jawaban dan rubrik ke Gemini dengan `responseSchema` (level per domain, kalimat bukti, dan tanda bahaya);
   - **memastikan setiap kalimat bukti benar-benar ada di cerita.** Bila tidak ada, domain itu diubah menjadi `null`;
   - menyimpan `ai_result` dan mengembalikannya ke aplikasi dalam beberapa detik.
3. Relawan melihat ringkasan (F5), mengoreksi kategori bila perlu, lalu menekan Simpan (`visit` → `confirm`).
4. `confirm` menyimpan `final_result`, menjalankan `status.ts` atas seluruh kunjungan lansia itu, lalu memperbarui `elders.status` dan `status_reason`. Bila status menjadi `segera_dikabari`, fungsi ini juga mengirim push notification ke HP keluarga dan pengurus yayasan.
5. Halaman keluarga mendengarkan `elders` dan `visits` lewat Realtime, sehingga rekap, status, dan grafik `fl_chart` langsung berubah.

**Aturan status (`status.ts`), sesuai F6:**
- Ada tanda bahaya di kunjungan terbaru → `segera_dikabari`.
- **Baseline** per domain = kategori yang paling sering muncul pada 3 kunjungan terkonfirmasi pertama. Sebelum ada 3 kunjungan, hanya tanda bahaya yang bisa mengubah status (PRD F6).
- `perlu_perhatian` bila salah satu kondisi ini terpenuhi:
  - domain turun ≥2 level dari baseline;
  - domain memburuk 3 kunjungan berturut-turut;
  - obat bernilai level 1–2 pada 2 dari 3 kunjungan terakhir;
  - kemandirian harian lebih buruk dari baseline.
- Karena semua aturan dibandingkan dengan baseline, kondisi buruk yang memang sudah menjadi baseline tidak memicu status.
- Domain `null` dilewati dan tidak dianggap baik.

### Alur C: Darurat (F8)
1. Relawan menekan **Darurat**, lalu muncul dialog konfirmasi. Bila dibatalkan, tidak terjadi apa-apa.
2. Setelah dikonfirmasi, aplikasi mengambil GPS (`geolocator`) dan memanggil `emergency` dengan `{elder_id, lat, lng}`.
3. Fungsi `emergency`:
   - memeriksa bahwa pemanggil adalah relawan pasangan lansia itu;
   - menyimpan `emergencies`;
   - mengirim push notification ke HP keluarga dan pengurus yayasan berisi ringkasan dan tautan `https://maps.google.com/?q=lat,lng`;
   - mengembalikan Profil Kesehatan Ringkas.
4. Aplikasi menampilkan layar "Memanggil 119 (simulasi)" beserta profil kesehatan yang siap dibacakan ke operator.

**Mendaftarkan HP untuk notifikasi:** setelah login, `push_setup.dart` meminta izin notifikasi (Android 13+),
mengambil token FCM, lalu menyimpannya ke `profiles.fcm_token`. Keluarga dan yayasan tidak perlu melakukan langkah
tambahan. Mengetuk notifikasi membuka detail lansia (keluarga) atau beranda (yayasan).

---

## 6. Keamanan

**Penahanan distribusi (16 Okt, T-033):** source pengumpulan tidak lagi menyertakan
`firebase/google-services.json`, `app/android/app/google-services.json`, atau `firebase_options.dart`;
gunakan contoh placeholder dan konfigurasi Firebase lokal. Pengemas menolak pola Google API key meski
tidak sama dengan key server yang diketahui. File yang sudah ada dalam riwayat Git tidak dihapus oleh
`.gitignore`. Review pembatasan key Cloud sudah selesai; repository tetap private sampai paket/riwayat
rilis ditinjau dan ada persetujuan publikasi baru. T-034 menyiapkan repository pengumpulan baru
`AltoDevv/rela-submission` tanpa riwayat konfigurasi lama; repository lama `AltoDevv/rela` dipertahankan private.
Konfigurasi client Firebase di APK tetap membutuhkan API restrictions; key Gemini harus terpisah di server.

**Pembatasan Cloud terverifikasi (16 Okt, T-033):** Android key proyek `temansenja` dibatasi ke
package `id.temansenja.app` dan SHA-1 sertifikat APK prototype yang dipakai tim. Allowlist dipersempit
dari 25 menjadi 4 API: `firebase.googleapis.com`, `logging.googleapis.com`,
`firebaseinstallations.googleapis.com`, dan `fcmregistrations.googleapis.com`, mengikuti kebutuhan FCM
pada https://firebase.google.com/docs/projects/api-keys . Uji pendaftaran instalasi dengan header Android
yang sesuai berhasil lalu instalasi uji dihapus; tanpa header/package/sertifikat yang cocok ditolak 403,
dan Gemini serta Firebase Auth diblokir. Header Android bukan pengganti autentikasi/IAM atau RLS.
Jika sertifikat signing diganti, pembatasan Android juga perlu diperbarui. Key client tidak dirotasi;
perubahan Cloud ini tidak memerlukan APK baru. Uji push menyeluruh di HP belum diulang.

### Autentikasi
- Login memakai Supabase Auth dengan email dan password. Konfirmasi email dimatikan supaya demo cepat. OTP HP relawan disimulasikan, kodenya tampil di layar, sesuai PRD P2. Login dengan OTP SMS sungguhan butuh provider SMS berbayar, jadi ditunda.
- Peran disimpan di `profiles.role`. Trigger saat sign-up hanya mengizinkan peran `keluarga` atau `relawan`. Akun `yayasan` hanya dibuat lewat `seed.sql` (F0 P3), sehingga tidak ada yang bisa mendaftar sendiri sebagai yayasan.
- Kolom `role`, `foundation_id`, dan `status` relawan tidak bisa diubah oleh pemiliknya sendiri. Perubahannya hanya lewat RPC atau trigger.

### Siapa boleh mengakses apa (RLS)
| Data | Keluarga | Relawan | Pengurus yayasan |
|---|---|---|---|
| `elders` | miliknya (`family_id`) | hanya bila `volunteer_id` = dirinya | yang `foundation_id`-nya sama, ditambah `tanpa_pendamping` dan `perlu_yayasan` |
| `health_profiles` | miliknya | lansia pasangannya | **tidak boleh sama sekali**, hanya `has_chronic` lewat RPC dashboard |
| `proposals` | milik lansianya (tanpa `reject_*` relawan lain) | **tidak boleh**, karena relawan tidak tahu dirinya ditolak | semua di yayasannya, termasuk alasan tolak |
| `visits` | baca, lansianya | baca dan tulis, lansia pasangannya | tidak boleh; ringkasan waktu lewat RPC `foundation_week_visits` |
| `volunteers` | hanya lewat `get_proposal_card` | dirinya | relawan di yayasannya, termasuk mengubah dua centang |
| `emergencies` | baca, lansianya | buat lewat fungsi | baca, yayasannya |
| Foto relawan (Storage) | signed URL lewat RPC | unggah miliknya | baca, yayasannya |

Edge Function memakai JWT pemanggil untuk mengecek identitas. Kunci `service_role` dipakai hanya
di dalam fungsi untuk menulis kolom yang dilindungi, dan **tidak pernah** ada di aplikasi.

### Menyimpan rahasia
- Di aplikasi hanya ada `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY`. Keduanya memang publik, karena keamanannya dijaga RLS. Nilainya dimasukkan lewat `--dart-define-from-file=env.json`, dan `env.json` masuk `.gitignore`.
- `GEMINI_API_KEY`, `GEMINI_MODEL`, dan `FIREBASE_SERVICE_ACCOUNT` (isi JSON service account) hanya disimpan di `supabase secrets set ...`. File `firebase/service-account.json` di laptop masuk `.gitignore`.
- Key client dalam `google-services.json` mengidentifikasi proyek Firebase dan tetap ada di APK. Untuk source proyek ini, konfigurasi asli disimpan lokal dan dilarang masuk paket/commit; gunakan contoh placeholder. Keamanan key client tetap bergantung pada pembatasan API/aplikasi yang benar. Private key service account wajib dirahasiakan karena memberikan hak backend sesuai IAM.

### Validasi input
- **Aplikasi:** validator di setiap `TextFormField` (wajib diisi, format HP, panjang maksimal), supaya pengguna langsung mendapat pesan yang jelas.
- **Database:** `CHECK` constraint untuk semua enum (role, status, state, reject_reason), `attempt between 1 and 3`, `not null` pada kolom wajib, dan panjang teks maksimal. Ini menjadi pertahanan terakhir.
- **Edge Function:** setiap body diperiksa (field wajib, tipe, enum) sebelum diproses. Bila tidak sesuai, fungsi membalas `400`.
- **Keluaran Gemini:** diperlakukan sebagai input yang tidak dipercaya. Keluaran divalidasi terhadap skema, level di luar 0–3 dibuang, dan kalimat bukti yang tidak ada di cerita dibuang. Cerita relawan dibungkus sebagai data di prompt, bukan instruksi.

### Data kesehatan dan privasi
- Profil kesehatan selalu ditampilkan bersama label *"Diisi oleh keluarga. Bukan diagnosis medis dan bukan rekam medis resmi."* lewat widget `DisclaimerLabel`.
- Yang dikirim ke Gemini hanya 7 jawaban cerita yang sudah dibersihkan dari nama dan alamat. Free tier Gemini boleh memakai data untuk melatih model, jadi aturan ini wajib.
- Bucket foto bersifat privat dan hanya diakses lewat signed URL yang berlaku singkat.
- Tidak ada tempat untuk mengunggah KTP, SKCK, atau dokumen medis (Non-goals PRD).

---

## 7. Strategi testing

| Jenis | Alat | Yang dites | Perintah |
|---|---|---|---|
| Unit logika server | `deno test` | `status.ts` (semua aturan F6, termasuk baseline buruk yang tidak memicu status), `matching.ts` (syarat wajib, jarak, relawan yang ditolak atau dipesan tidak diusulkan), `extract.ts` (kalimat bukti palsu dibuang, nama dan alamat dibuang) | `deno test supabase/functions/_shared` |
| Unit/widget Flutter | `flutter test` | validator form, pemetaan level ke label rubrik, widget `DisclaimerLabel` selalu tampil | `cd app && flutter test` |
| Akurasi ekstraksi | skrip Deno | 30–50 cerita berlabel di `data/eval/stories.jsonl` dijalankan ke Gemini, lalu dihitung akurasi per domain. Angkanya dipakai di pitch. | `deno run -A scripts/eval_extraction.ts` |
| RLS | manual dengan 3 akun seed | login sebagai yayasan, lalu pastikan `health_profiles` kosong. Login sebagai relawan, lalu pastikan lansia lain tidak terlihat dan `proposals` kosong. | lewat aplikasi atau SQL Editor dengan `set role authenticated` |
| End-to-end | checklist demo | Alur A, B, dan C dijalankan dari awal sampai akhir di HP sungguhan sebelum pitch | — |

Prioritas test mengikuti P1: `status.ts` dan `extract.ts` dites lebih dulu, karena keduanya inti pitch.

---

## 8. Hal yang perlu disiapkan

1. Akun **Supabase** (login dengan GitHub), lalu buat satu proyek di region Singapore.
2. API key **Gemini** dari Google AI Studio (aistudio.google.com).
3. **Proyek Firebase** (paket Spark, gratis): tambahkan aplikasi Android `id.temansenja.app`, unduh `google-services.json`, dan buat kunci service account.
4. Terpasang di laptop: Flutter SDK, Supabase CLI, Deno, dan HP Android dengan USB debugging aktif.

---

## 9. Usulan tambahan ke PRD

Kebutuhan berikut muncul dari desain teknis. Semuanya sudah diputuskan pengguna pada T-001 (2026-10-14):

1. ~~Hari kunjungan dan bahasa lansia di F1~~ **Ditolak.** F2 cukup memakai syarat demensia/mobilitas, jarak, lalu beban.
2. **Izin notifikasi di HP keluarga dan yayasan.** Aplikasi meminta izin ini setelah login. Tanpa izin, notifikasi F8 tidak muncul. **Disetujui**, masuk F8.
3. **Definisi baseline:** modus 3 kunjungan terkonfirmasi pertama (lihat Alur B). **Disetujui**, masuk F6.
4. **Push notification saat status menjadi "Segera dikabari"**, bukan hanya saat tombol darurat ditekan. Ini wajar dari nama statusnya, **Disetujui**, masuk F6.

---

## 10. Log keputusan

| Tanggal | Keputusan | Alternatif yang ditolak | Alasan |
|---|---|---|---|
| 2026-10-14 | **Aplikasi mobile Flutter**, bukan web | Web responsif Next.js (preferensi awal di PRD bagian 7) | Pengguna ingin aplikasi, dan tim menguasai Flutter. Kamera langsung (F1a) dan GPS (F8) lebih wajar di aplikasi. |
| 2026-10-14 | **Supabase** sebagai backend | Firebase: Cloud Functions mewajibkan paket Blaze (kartu kredit), dan Firestore NoSQL menyulitkan query pemasangan dan tren. FastAPI + Postgres di Render: login, izin, dan upload harus ditulis sendiri, server gratis tidur sekitar 50 detik (berisiko saat demo), dan DB gratis kedaluwarsa dalam 30 hari. | Gratis tanpa kartu kredit. SQL cocok dengan data relasional. RLS menegakkan aturan privasi PRD di database. |
| 2026-10-14 | **Gemini free tier** untuk ekstraksi | Claude / OpenAI | Tim belum punya kredit, dan Gemini gratis cukup dengan akun Google. Konsekuensinya, data bisa dipakai Google untuk pelatihan, sehingga nama dan alamat wajib dibuang. |
| 2026-10-14 | **STT bawaan HP** (`speech_to_text`) | Whisper / Google Cloud STT | Gratis, tanpa server, dan hasilnya tetap bisa disunting. Rekam suara memang P1 opsional. |
| 2026-10-14 | **Push notification (FCM)** untuk notifikasi | Telegram Bot (rencana awal PRD); WhatsApp Cloud API; notifikasi hanya di dalam aplikasi | Pengguna ingin notifikasi langsung dari aplikasi tanpa aplikasi lain. WhatsApp butuh persetujuan template berhari-hari. Notifikasi di dalam aplikasi saja tidak memenuhi F8 karena keluarga hanya tahu saat aplikasi dibuka. Konsekuensi: setup Firebase menambah sekitar setengah hari, dan demo butuh 2 HP Android. |
| 2026-10-14 | Tanpa library state management atau router | Riverpod, Bloc, go_router | Layarnya sedikit dan waktu sempit, jadi alat bawaan Flutter sudah cukup. |
| 2026-10-14 | Rubrik ditulis di dua tempat (`rubric.ts` dan `rubric.dart`) | Rubrik disimpan di tabel DB | Rubrik kecil dan tidak berubah selama hackathon. `rubric.ts` menjadi sumber utama. |
| 2026-10-14 | **`GEMINI_MODEL` = `gemini-3.5-flash-lite`** (sebelumnya `gemini-3.5-flash`) | Tetap 3.5-flash dan menunggu reset; mengaktifkan billing | Free tier 3.5-flash (dan 3.6-flash) hanya 20 panggilan/hari, dan sudah habis saat Cek gabungan Langkah 5. Versi lite teruji 1,3 detik, JSON valid, dan mendeteksi tanda bahaya. Konsekuensi: sedikit kurang teliti ("beberapa suap" → Berkurang). Relawan bisa mengoreksi di F5, dan T-024 mengukur akurasinya. Hanya secret yang diganti, tanpa perubahan kode. |
| 2026-10-15 | **Aturan siklus hidup di database (trigger), bukan di aplikasi**: status relawan selalu dihitung dari dua centang; nonaktif/cabut keahlian/kebutuhan lansia berubah → lansia ke `perlu_yayasan` | Menegakkan di Edge Function saja | Trigger berlaku untuk jalur mana pun (aplikasi, API langsung, admin), jadi pasangan yang tidak memenuhi syarat F2 tidak bisa tersisa. |
| 2026-10-15 | **Izin kolom `visits`**: aplikasi hanya boleh menulis `elder_id, volunteer_id, answers`; hasil AI, konfirmasi, dan koreksi lewat Edge Function `visit` | RLS baris saja | Uji membuktikan relawan bisa memalsukan kunjungan terkonfirmasi dan mengubah `ai_result` lewat API. |
| 2026-10-15 | **`family_members` + `is_family()`** untuk beberapa anggota keluarga; penerima notifikasi disatukan di `_shared/recipients.ts` | Menyimpan banyak `family_id` di `elders` | Satu fungsi akses dipakai semua policy; keputusan usulan tetap pendaftar supaya tidak dijawab dua orang. |
| 2026-10-15 | **`scripts/check_security.ts`** sebagai uji regresi keamanan (18 serangan sebagai pengguna biasa) di samping `check_rls.ts` | Mengandalkan review kode | Dua celah (pemalsuan kunjungan, kebocoran lintas yayasan) baru ketahuan setelah dicoba lewat API; satu di antaranya regresi dari perbaikan sebelumnya. |
| 2026-10-15 | **`push_tokens`** (banyak perangkat per akun, lewat RPC) menggantikan `profiles.fcm_token` | Satu kolom token per akun | Keluarga sering memakai HP + tablet; perangkat yang berganti akun ikut pindah pemilik sehingga tidak menerima notifikasi akun lama. |
| 2026-10-15 | **Koreksi relawan yang menurunkan penilaian AI dicatat (`visits.overrides`) dan ditulis di baris pertama `status_reason`**; mencabut tanda bahaya AI wajib beralasan | Melarang relawan mencabut tanda bahaya | Alarm palsu tetap bisa dikoreksi (10 alarm palsu di evaluasi), tapi tidak bisa dibungkam diam-diam: keluarga & yayasan melihat alasannya. |
| 2026-10-15 | **Lansia tanpa yayasan tidak terbaca langsung oleh yayasan**; pasang manual lewat RPC `manual_pair_options` (jarak dihitung server, alamat/koordinat disembunyikan) | Membiarkan semua yayasan membaca baris `elders` | Siapa pun bisa membuat akun pengurus untuk yayasan sendiri; alamat + koordinat + demensia lansia rentan tidak boleh terbuka untuk mereka. |
| 2026-10-15 | **Pengurus baru lewat undangan** (`foundation_admin_invites`, diterima pemilik akun) | Langsung mengubah peran akun | Pengurus mana pun bisa mengubah akun keluarga orang lain menjadi pengurus tanpa persetujuan. |
| 2026-10-15 | **Satu kunjungan terkonfirmasi per lansia per hari (WIB)** via trigger; koreksi lewat "Koreksi kunjungan terakhir" | Bebas | Kunjungan beruntun menggeser baseline/tren dan bisa dipakai menimpa penurunan. Seed (tanpa `auth.uid()`) tidak dibatasi. |
| 2026-10-15 | **Pengingat >7 hari tanpa kunjungan**: pg_cron → pg_net → Edge Function `reminders` (rahasia di Vault), push ke relawan, keluarga, yayasan; maks. sekali/hari per lansia | Hanya badge "Kunjungan terakhir" | Badge pasif tidak terlihat bila tidak ada yang membuka aplikasi; tujuan produk adalah pendampingan rutin. |
| 2026-10-15 | **Persetujuan syarat ditagih saat masuk** (`TermsGate` + RPC `accept_terms`) bila `terms_accepted_at` kosong | Hanya checkbox di layar daftar | Akun yang dibuat lewat API melewati checkbox. Batas: penegakan ada di aplikasi, bukan di setiap RPC. |
| 2026-10-15 | **Risiko diterima (E5): token push yang diketahui orang lain bisa didaftarkan ulang ke akunnya** | Verifikasi kepemilikan token | Token FCM hanya ada di perangkat itu sendiri; menebaknya tidak mungkin. Dampak: perangkat korban berhenti menerima notifikasi sampai login ulang. |
| 2026-10-15 | **Pemilih lokasi peta: Photon (OpenStreetMap) untuk saran saat mengetik + `flutter_map` (ubin OSM) dengan pin tetap di tengah yang digeser**, menggantikan paket `geocoding` | Google Places Autocomplete + Google Maps SDK | Gratis tanpa kartu kredit/API key. Teks alamat tidak lagi ditebak diam-diam: titik rumah selalu dikonfirmasi di peta. Batas: data tempat OSM di kampung kurang lengkap dan ejaan harus mirip ("Bringharjo"), jadi alamat lengkap dicari bertahap (tanpa No/RT/RW, lalu mundur ke kelurahan/kecamatan) dan pengguna menggeser pin. Server publik Photon & ubin OSM punya batas pemakaian wajar; untuk produksi pakai server sendiri atau penyedia berbayar. |
| 2026-10-15 | **Koordinat wajib lengkap dan di dalam Indonesia** (CHECK di `elders` dan `volunteers`) | Validasi di aplikasi | Koordinat asal (0,0 atau luar negeri) merusak jarak pemasangan. Catatan: CHECK pertama lolos untuk lat tanpa lng karena NULL dianggap lulus; diperbaiki di 001800. |
| 2026-10-15 | **Maks. 3 cerita per lansia per hari** (termasuk yang belum dikonfirmasi) | Hanya batas kunjungan terkonfirmasi | Setiap cerita baru = satu panggilan Gemini; tanpa batas satu akun relawan bisa menghabiskan kuota gratis harian. |
| 2026-10-15 | **Risiko diterima: relawan terverifikasi bisa memindahkan titik tempat tinggal tanpa verifikasi ulang** | Verifikasi ulang setiap pindah | Pindah rumah itu wajar; verifikasi menyangkut identitas, bukan alamat. Keluarga tetap harus menerima usulan (melihat foto, area, jarak). |
| 2026-10-15 | **Yayasan tidak membaca `visits` langsung** (policy dihapus); ringkasan tetap lewat `foundation_dashboard` | Membiarkan yayasan membaca cerita lengkap relawan | Data minimal (UU PDP) dan sesuai teks persetujuan; yayasan butuh pengawasan (status, alasan, keteraturan kunjungan, darurat), bukan cerita kunjungan atau profil kesehatan. |
| 2026-10-15 | **Hapus data lansia** lewat `pairing` aksi `delete` (hanya pendaftar, ketik HAPUS, cascade ke profil kesehatan/kunjungan/darurat/usulan/anggota; relawan, anggota, yayasan diberi push) | Hanya "Akhiri pendampingan" | Hak penghapusan UU PDP; sebelumnya data lansia hanya hilang bila akun pendaftar dihapus. |
| 2026-10-15 | **Verifikasi keluarga online oleh yayasan relawan yang diterima** (`elders.verify_state`, bucket privat `elder-docs`, aksi `pairing.verify`, dokumen dihapus setelah keputusan) + **langganan per lansia** (`elders.paid_until`, RPC `simulate_payment` hanya untuk demo) | Kunjungan perkenalan tatap muka oleh yayasan; admin platform pusat; e-KYC otomatis | Keputusan pengguna: relawan tatap muka, keluarga cukup online. Yayasan relawan yang menanggung risiko kunjungan, dan hanya yayasan itu yang melihat dokumen (data minimal). Celah sisa: dokumen bisa dipalsukan → relawan memastikan langsung saat kunjungan pertama (`confirm_first_visit`), dan kunjungan diblokir trigger sampai itu terjadi. Produksi: payment gateway berizin (webhook mengisi `paid_until`) dan e-KYC berbayar bila volume besar. |
| 2026-10-15 | **Kontak relawan seperti Gojek**: kartu usulan tanpa HP/kendaraan dan jarak dibulatkan km; `my_volunteer_contact` (nama lengkap, HP, kendaraan) hanya bila berpasangan + terverifikasi; foto relawan hanya selama usulan menunggu/diterima | Data lengkap sejak usulan, atau sejak bayar | Keluarga yang menolak 3× tidak membawa pulang nomor HP relawan; jarak 0,1 km memungkinkan triangulasi rumah relawan dari beberapa lansia palsu (terbukti). |
| 2026-10-15 | **Tanpa swafoto+KTP dan tanpa data kendaraan** (migration 002100) | Swafoto memegang KTP; kendaraan & plat seperti Gojek | Keputusan pengguna: lebih sedikit data sensitif dan langkah. Konsekuensi: foto KTP curian bisa lolos pemeriksaan online, jadi konfirmasi relawan pada kunjungan pertama menjadi pemeriksaan wajah/kehadiran yang utama. |
| 2026-10-15 | **Butir pemeriksaan verifikasi relawan di aplikasi** (dialog, semua wajib) tanpa disimpan per butir | Menyimpan tiap butir di database; SKCK | Menyamakan standar antar pengurus tanpa menambah data pribadi; yang dicatat tetap siapa & kapan untuk dua centang. SKCK tidak diminta (keputusan pengguna). |
| 2026-10-15 | **`reviews`** ditulis lewat Edge Function `review` (batas frekuensi + push per kategori), dibaca lewat RLS per kategori (relawan hanya `apresiasi`), ditangani lewat RPC `handle_review`; **`payments`** diisi `simulate_payment` | Rating bintang; review terbuka untuk semua keluarga; tabel dengan policy insert | Kategori menentukan penerima, jadi laporan serius aman dari pembalasan. Tanpa policy insert, batas frekuensi tidak bisa dilewati lewat API. |
| 2026-10-15 | **Langganan habis: masa tenggang 7 hari**, lalu trigger `visits_need_verified` menolak kunjungan | Langsung memutus pendampingan; tidak ditegakkan | Lansia tidak tiba-tiba kehilangan pendamping karena telat bayar, tapi langganan tetap berarti. |
| 2026-10-15 | **Kode verifikasi tatap muka** (`volunteer_codes`: hash bcrypt, berlaku 2 menit, maks. 5 percobaan, sekali pakai; `issue_verification_code` oleh pengurus, `redeem_verification_code` oleh relawan; trigger menolak centang langsung kecuali lewat redeem) | Dua centang langsung oleh pengurus; kode undangan saja | Membuktikan relawan dan pengurus benar-benar bertemu; kode undangan bisa bocor. Batas percobaan membuat tebakan 6 digit sia-sia. |
| 2026-10-15 | **`stop_requests`** + `approve_stop_request` (service role) dipakai `pairing.approve_stop` dan `reminders` (otomatis 7 hari); relawan tidak bisa `release` sendiri | Relawan melepas langsung | Lansia tidak tiba-tiba tanpa pendamping; yayasan mengatur waktu pergantian. Tidak bisa ditolak supaya relawan tidak terjebak. Serangan W6 menemukan bug kolom ambigu di versi pertama (diperbaiki 002400). |
| 2026-10-15 | **`pairing_changes`** + aksi `pairing.change` (batas 30 hari di server, alasan wajib, alasan serius juga menjadi `reviews` serius) dan **putaran usulan** (hitungan 3 usulan dimulai lagi setelah ganti; relawan yang pernah diusulkan, diganti, atau berkunjung dikecualikan) | Lepas langsung lalu yayasan memasangkan manual | Keputusan pengguna: pengganti otomatis seperti awal. Serangan G3 menemukan relawan lama terusul lagi bila pasangan lama tidak punya baris `proposals` (data seed) — pengecualian kini juga dari `pairing_changes` dan `visits`. |
| 2026-10-16 | **Pencocokan ulang otomatis** (`_shared/propose.ts`: `proposeNext`, `rematch`, `rematchReleased`; kolom `elders.match_round_at`): relawan lepas → putaran baru 3 usulan lintas yayasan, dipanggil `pairing` (release/approve_stop/deactivate), `account` (relawan hapus akun), dan sapuan harian `reminders`. Usulan ke-3 tidak bisa ditolak; minta ganti 1× per lansia. Pencocokan tetap aturan (filter syarat → jarak → beban), bukan machine learning. | Yayasan lama memasangkan manual (perlu_yayasan); ML untuk pencocokan | Keputusan pengguna: lansia tidak bergantung pada satu yayasan karena akan ada banyak yayasan. ML belum punya data latih; aturan bisa dijelaskan ke keluarga. Jalur SQL (mis. relawan mencabut keahlian) tertangkap sapuan harian. |
