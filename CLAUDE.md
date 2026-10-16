# ReLa (Relawan Lansia; dulu bernama TemanSenja)

Aplikasi pendampingan lansia oleh relawan komunitas (Hackathon JOINTS UGM 2026, tema Healthcare).
Kebutuhan produk ada di `docs/prd.md`, desain teknis di `docs/architecture.md`, dan daftar tugas di `todo.md`.

## Wajib baca di awal setiap sesi

1. Bagian "Catatan sesi terakhir" di `todo.md`.
2. Blok tugas yang akan dikerjakan di `todo.md`, beserta bagian PRD dan arsitektur yang disebut di prompt.
3. Jangan membaca `progress.md`. File itu laporan untuk pengguna, dan isinya cukup ditambah di bagian bawah.

## Alur kerja

Satu sesi mengerjakan satu tugas dari `todo.md`, dengan prompt dari `prompt.md`. Test ditulis dulu, lalu
diimplementasikan sampai lulus, kemudian blok tugas di `todo.md` diperbarui. Setelah itu tambahkan entri di
**paling bawah** `progress.md` dengan `cat >> progress.md`, tanpa membaca isinya, mengikuti format ini:

```
## <tanggal> — T-xxx <judul> (<selesai | macet>)
- **Posisi proyek:** <jumlah [x]>/<total> tugas selesai; langkah <n> di prompt.md.
- **Yang dikerjakan:** <ringkas, beserta file yang disentuh>
- **Cara kerja kodenya:** <penjelasan untuk developer junior, alurnya dari input sampai output>
- **Cara mengecek sendiri:** <perintah test dan/atau langkah manual di HP>
- **Istilah baru:** <istilah teknis yang muncul beserta artinya dalam satu kalimat>
- **Masalah / catatan:** <bila ada>
```

## Sesi paralel

Sampai 3 sesi Claude bisa bekerja di folder ini pada waktu yang sama (Sesi A, B, C dalam satu langkah di `prompt.md`).

- Ubah hanya file di daftar "File yang boleh diubah" di prompt. Bila butuh file lain, berhenti dan tanya pengguna.
- Jangan menginstal atau menghapus package. Semua package dipasang di T-002.
- Jalankan hanya test milik tugasmu (perintahnya ada di prompt), bukan seluruh test.
- Di `todo.md`, ubah hanya blok tugasmu. Sesi A boleh menandai `[~]` di awal, sedangkan sesi B dan C tidak
  mengubah status di awal. Bila `todo.md` berubah saat hendak diedit, baca ulang lalu ulangi edit.
- `supabase db push` hanya dijalankan oleh sesi yang punya migration di langkah itu.
- Commit hanya file milik tugasmu dengan `git add <file>` satu per satu. Jangan pernah `git add -A`.
- Setelah semua sesi selesai, pengguna menjalankan prompt "Cek gabungan" langkah tersebut.

## Perintah proyek

```bash
# Aplikasi Flutter (folder app/)
cd app && flutter pub get
cd app && flutter run --dart-define-from-file=env.json   # env.json berisi SUPABASE_URL & SUPABASE_PUBLISHABLE_KEY
cd app && flutter test
cd app && flutter analyze

# Supabase (dari root)
supabase link --project-ref <ref>
supabase db push                       # terapkan supabase/migrations ke proyek cloud
supabase functions deploy <nama>       # pairing | visit | emergency | account | review
supabase functions deploy reminders --no-verify-jwt   # dipanggil pg_cron, bukan pengguna
supabase secrets set GEMINI_API_KEY=... GEMINI_MODEL=... FIREBASE_SERVICE_ACCOUNT="$(cat firebase/service-account.json)"

# Test logika server & akurasi ekstraksi
deno test supabase/functions/_shared
deno run -A scripts/eval_extraction.ts
deno run -A scripts/check_rls.ts          # aturan akses (RLS) per peran
deno run -A scripts/check_security.ts     # 61 serangan regresi; lalu reset demo:
supabase db query --linked -f supabase/seeds/04_reset_demo.sql && supabase db query --linked -f supabase/seeds/03_visits_ibu_sri.sql
```

## Lingkungan laptop ini (berlaku untuk Claude Code dan Codex)

- PATH yang dibutuhkan: `~/development/flutter/bin`, `~/.deno/bin`, `~/.local/bin` (supabase CLI), `~/Library/Android/sdk/platform-tools` (adb). Tidak ada Homebrew dan psql; SQL dijalankan dengan `supabase db query --linked -f <file>`.
- Shell zsh: `head` di laptop ini adalah Perl `HEAD` (pakai `sed -n 1,20p`); tulis variabel sebagai `${VAR}` (zsh menganggap `$VAR:x` modifier); BSD sed tidak mengenal `\b`.
- HP uji: Android fisik lewat USB (emulator di Mac Intel ini sering crash). `adb devices` kosong → cek kabel/izin USB debugging. Xiaomi/Redmi: nyalakan "Install via USB".
- Setelah skrip uji (`check_security`, `check_rls`, `try_*`) selalu jalankan reset demo (04 lalu 03) dan jalankan reset di antara skrip, karena skrip meninggalkan data uji.
- File yang **tidak boleh** di-commit: `.env.local`, `app/env.json`, `firebase/service-account.json`. Cek `git diff --cached --name-only` sebelum commit.

## Nama & merek

Nama aplikasi **ReLa**; logo di `docs/brand/rela-logo.png` (biru `#356A90`-an dan krem). Kode paket Android
`id.temansenja.app`, skema tautan `temansenja://`, dan proyek Supabase/Firebase sengaja **tidak** diganti (mengganti
memutus Firebase dan tautan undangan yang sudah tersebar).

## Konvensi

- **Stack:** Flutter (Dart) + Supabase (Postgres, Auth, Storage, Realtime, Edge Functions TypeScript/Deno) + Gemini + Firebase Cloud Messaging (hanya untuk push notification). Jangan menambah dependency tanpa alasan jelas.
- **Aturan akses dijaga RLS**, bukan kode aplikasi. Setiap tabel baru wajib punya policy di `supabase/migrations/`. Yayasan tidak boleh membaca `health_profiles`, dan relawan tidak boleh membaca `proposals`.
- **Rahasia** (`GEMINI_API_KEY`, `FIREBASE_SERVICE_ACCOUNT`, `service_role`) hanya ada di Supabase secrets. Jangan pernah menaruhnya di `app/` atau meng-commit-nya. `env.json` masuk `.gitignore`.
- **Logika penting di Edge Function**, sebagai fungsi murni di `supabase/functions/_shared/` beserta `*_test.ts`.
- **Jangan kirim nama atau alamat lansia ke Gemini.** Kalimat bukti dari Gemini wajib dicek benar-benar ada di cerita relawan.
- **Rubrik:** sumber utamanya `supabase/functions/_shared/rubric.ts`. Bila diubah, ubah juga `app/lib/shared/rubric.dart`. Level 0 = terbaik, 3 = terburuk, `null` = tidak disebut.
- **Flutter:** pakai `setState` dan `StreamBuilder`/`FutureBuilder` serta `Navigator` bawaan, tanpa Riverpod, Bloc, atau go_router. Kode dikelompokkan per peran di `lib/keluarga`, `lib/relawan`, dan `lib/yayasan`.
- **Database:** nama tabel dan kolom memakai `snake_case` bahasa Inggris. Nilai enum memakai bahasa Indonesia (`stabil`, `perlu_perhatian`, ...). Semua perubahan skema dibuat lewat file migration baru, bukan diedit langsung di dashboard.
- **Teks UI** memakai bahasa Indonesia. Profil kesehatan selalu tampil dengan `DisclaimerLabel`.

## Pelajaran

(Aturan singkat dari kesalahan yang pernah terulang. Ditambahkan lewat `/handoff` setelah disetujui pengguna.)

- Nama file sama ada di tiap peran (`home_screen.dart`, `profile_tab.dart`, `ui.dart`): saat mengganti import dengan `sed`, batasi ke file target, jangan semua file yang cocok.

## Pengingat kunjungan (pg_cron)

Job `visit-reminders` (08.00 WIB) memanggil Edge Function `reminders` dengan header `x-cron-secret`. Rahasianya
ada di dua tempat dan TIDAK di git: secret fungsi `REMINDERS_CRON_SECRET` dan Vault `reminders_cron_secret`.
Mengganti rahasia: buat nilai acak, `supabase secrets set REMINDERS_CRON_SECRET=...`, lalu
`select vault.update_secret((select id from vault.secrets where name='reminders_cron_secret'), '<nilai>')`.
Deploy fungsi ini dengan `--no-verify-jwt` (sudah di `supabase/config.toml`).
