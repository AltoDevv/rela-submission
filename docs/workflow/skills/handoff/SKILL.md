---
name: handoff
description: Menulis catatan serah terima di bagian "Catatan sesi terakhir" pada todo.md supaya sesi berikutnya bisa langsung melanjutkan pekerjaan — apa yang selesai, apa yang sedang dikerjakan, masalah, keputusan, dan langkah berikutnya. Gunakan skill ini setiap kali pengguna mau mengakhiri sesi, berhenti kerja, pindah ke sesi baru, konteks sudah terlalu panjang, atau mengetik /handoff.
---

# Handoff Akhir Sesi

Tujuan skill ini adalah memastikan sesi berikutnya (yang tidak ingat apa pun dari sesi
ini) bisa melanjutkan pekerjaan dalam hitungan menit. Tulis seolah-olah untuk rekan kerja
yang baru datang: singkat, konkret, dan tanpa asumsi bahwa pembacanya tahu konteks.

## Langkah

1. **Kumpulkan fakta**, jangan mengandalkan ingatan percakapan saja:
   - Cek status tugas di `todo.md`. Jangan membaca `progress.md`, karena file itu laporan
     untuk pengguna.
   - Jalankan `git status` dan `git diff --stat` untuk melihat perubahan yang belum di-commit.
   - Jalankan test untuk mengetahui kondisi terakhirnya.

2. **Ganti isi bagian "Catatan sesi terakhir"** di `todo.md` (timpa, jangan ditambahkan
   di bawahnya, supaya bagian ini tetap pendek):
   - **Tanggal**: tanggal hari ini.
   - **Selesai di sesi ini**: ID dan judul tugas yang menjadi `[x]`.
   - **Sedang dikerjakan**: tugas `[~]`, sampai mana, dan file mana yang sedang diubah.
   - **Masalah yang belum terpecahkan**: error, test yang gagal, atau hal yang membingungkan,
     termasuk apa yang sudah dicoba.
   - **Keputusan penting**: keputusan yang diambil di sesi ini beserta alasannya. Kalau
     keputusannya bersifat arsitektural, catat juga di "Log keputusan" di
     `docs/architecture.md`.
   - **Langkah berikutnya**: satu atau dua langkah paling konkret untuk memulai sesi
     berikutnya.

   Sebutkan juga kalau ada perubahan yang belum di-commit.

   Pastikan juga status setiap tugas yang dikerjakan di sesi ini sudah benar di `todo.md`.

   Lalu **tambahkan satu entri** di paling bawah `progress.md` dengan format yang ada di
   "Alur kerja" di `CLAUDE.md`, tanpa membaca isi lamanya (misalnya dengan
   `cat >> progress.md`). Entri ini hanya berisi hal di sesi ini yang belum tercatat oleh
   `/next-task`, misalnya perbaikan, perubahan rencana, atau pekerjaan yang terhenti di
   tengah. Kalau semuanya sudah tercatat, lewati. Kalau menulis entri, isi semua bagian
   formatnya secara detail, karena pengguna memakainya untuk belajar.

   **Kalau masih ada sesi Claude lain yang berjalan di folder ini**, jangan menimpa
   "Catatan sesi terakhir", karena sesi lain belum selesai. Beri tahu pengguna untuk
   memakai prompt "Cek gabungan" setelah semua sesi selesai, lalu langsung ke langkah 4.

3. **Tinjau pelajaran.** Kalau di sesi ini ada kesalahan yang terulang atau koreksi yang
   harus diberikan pengguna lebih dari sekali, usulkan satu aturan singkat untuk
   ditambahkan ke bagian "Pelajaran" di `CLAUDE.md`. Tambahkan hanya setelah pengguna setuju.

4. **Tutup dengan ringkasan satu paragraf** untuk pengguna, dan ingatkan untuk commit
   kalau masih ada perubahan yang tertunda.
