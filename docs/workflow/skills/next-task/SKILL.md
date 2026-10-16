---
name: next-task
description: Mengambil satu tugas dari todo.md (tugas berikutnya yang siap, atau ID tertentu seperti T-004), mengerjakannya sampai semua kriteria selesai terverifikasi lewat test, lalu memperbarui statusnya. Gunakan skill ini setiap kali pengguna bilang "lanjut", "kerjakan tugas berikutnya", "next task", menyebut ID tugas, atau mengetik /next-task.
---

# Mengerjakan Tugas Berikutnya

Tujuan skill ini adalah menyelesaikan tepat satu tugas dengan benar dan bisa
dipertanggungjawabkan. "Selesai" berarti setiap kriteria selesai sudah dicek, bukan
sekadar kodenya sudah ditulis. Pengguna adalah developer junior, jadi penjelasan tentang
apa yang dilakukan dan kenapa sama pentingnya dengan kodenya.

Argumen (opsional): $ARGUMENTS

## Mode sesi paralel

Kalau prompt menyebut ada sesi Claude lain yang bekerja di folder yang sama, ikuti
bagian "Sesi paralel" di `CLAUDE.md`. Langkah di bawah tetap dijalankan, dengan
batasan berikut:

- Hanya ubah file di daftar "File yang boleh diubah" di prompt. Kalau perlu file lain,
  berhenti dan tanya pengguna.
- Jangan menginstal library.
- Jalankan hanya test milik tugas ini (perintahnya ada di prompt), bukan seluruh test.
- Di `todo.md`, ubah hanya blok tugasmu. Kalau file berubah saat diedit, baca ulang lalu
  ulangi.
- Commit hanya file milik tugas ini (`git add <file>` satu per satu).

## Langkah

1. **Baca konteks.** Ikuti "Wajib baca" di `CLAUDE.md`: "Catatan sesi terakhir" di
   `todo.md` dan bagian PRD serta arsitektur yang relevan. Jangan membaca
   `progress.md`, karena file itu laporan untuk pengguna. Lalu tentukan tugasnya:
   - Kalau argumen berisi ID tugas, ambil tugas itu.
   - Kalau ada tugas berstatus `[~]` atau `[!]`, tawarkan untuk melanjutkannya dulu.
   - Kalau tidak, ambil tugas `[ ]` pertama yang semua ketergantungannya sudah `[x]`.

   Sebutkan ringkasan dari "Wajib baca" beserta tugas yang dipilih dan kriteria
   selesainya, lalu ubah statusnya menjadi `[~]` (kecuali sesi paralel B/C).

2. **Pahami sebelum menulis.** Baca bagian `docs/architecture.md` dan kode yang relevan.
   Untuk tugas yang tidak sepele, sampaikan rencana singkat (file yang akan diubah dan
   pendekatannya) lalu tunggu persetujuan pengguna.

3. **Kerjakan dengan test.** Tulis test untuk kriteria selesai, lalu implementasikan
   sampai test lulus. Pilih solusi paling sederhana yang memenuhi kriteria. Jangan
   mengerjakan hal di luar tugas; kalau muncul ide lain, catat di bagian "Usulan" di
   `todo.md`.

4. **Verifikasi.** Jalankan seluruh test dan lint (perintahnya ada di `CLAUDE.md`). Cek
   setiap kriteria selesai satu per satu dan centang yang sudah terbukti.

5. **Langsung perbarui `todo.md`** begitu tugas selesai atau macet, sebelum melapor ke
   pengguna (saat sesi paralel, ubah hanya blok tugasmu):
   - Semua kriteria terpenuhi dan test lulus → status `[x]`.
   - Ada yang belum bisa diselesaikan → status `[!]` dengan catatan penyebabnya dan apa
     yang sudah dicoba.

   Jangan menandai `[x]` kalau ada test yang gagal atau kriteria yang belum dicek.

   Centang setiap kriteria yang sudah terbukti dan isi bagian "Catatan" tugas itu.

   Lalu tambahkan satu entri di **paling bawah** `progress.md` dengan format yang ada di
   "Alur kerja" di `CLAUDE.md`, tanpa membaca isi lamanya (misalnya dengan
   `cat >> progress.md`). Tulis entri ini baik tugasnya selesai maupun macet. Entri harus
   **detail**, karena pengguna memakainya untuk belajar: isi semua bagian format, termasuk
   posisi proyek (hitung dari `todo.md`), cara kerja kode, cara mengecek sendiri, dan
   istilah baru.

6. **Laporkan ke pengguna:**
   - Ringkasan perubahan dan file yang disentuh.
   - Satu atau dua keputusan penting beserta alasannya, dijelaskan supaya pengguna belajar.
   - Bagian kode yang sebaiknya dibaca pengguna saat mereview diff.
   - Usulan pesan commit yang ringkas. Jangan commit sendiri kecuali pengguna memintanya.
     Kalau diminta, commit hanya file milik tugas ini, jangan `git add -A`.
