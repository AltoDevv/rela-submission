---
name: breakdown
description: Memecah rencana di docs/prd.md dan docs/architecture.md menjadi tugas-tugas kecil di todo.md, lengkap dengan kriteria selesai yang bisa dicek, urutan tahap, dan ketergantungan antar tugas. Gunakan skill ini setiap kali pengguna ingin membagi pekerjaan, membuat task list, roadmap implementasi, atau rencana pengerjaan, atau mengetik /breakdown.
---

# Memecah Pekerjaan Jadi Tugas

Tujuan skill ini adalah mengisi `todo.md` dengan tugas-tugas yang masing-masing bisa
diselesaikan dan dicek dalam satu sesi. Tugas yang terlalu besar membuat AI kehilangan
arah dan membuat review sulit. Kriteria selesai yang samar membuat AI "mengaku selesai"
padahal belum.

## Langkah

1. **Baca `docs/prd.md` dan `docs/architecture.md`.** Kalau arsitektur belum ada,
   sarankan `/architecture` dulu. Kalau `todo.md` sudah berisi tugas, tanyakan apakah
   mau menambah tugas baru atau menyusun ulang; jangan menghapus tugas yang statusnya
   `[x]` atau `[~]`.

2. **Susun tahap-tahap:**
   - **Tahap 0: Fondasi.** Setup proyek, konfigurasi test beserta satu test sederhana yang
     lulus, lint, dan struktur folder sesuai arsitektur. Test harus sudah bisa jalan sejak
     awal supaya semua tugas berikutnya bisa diverifikasi.
     Siapkan juga lahan untuk kerja paralel: pasang semua library yang sudah diputuskan
     di arsitektur, dan buat file bersama (routing, layout, halaman yang tersusun dari
     beberapa bagian) sebagai kerangka dengan komponen stub. Dengan begitu tugas
     paralel nanti hanya mengisi filenya masing-masing, tanpa dua sesi mengedit file
     yang sama.
   - **Tahap berikutnya** mengikuti fitur MVP di PRD. Utamakan irisan vertikal: satu tugas
     menghasilkan satu kemampuan yang utuh dan bisa dicoba (misalnya "pengguna bisa
     mendaftar"), bukan lapisan terpisah ("buat semua tabel", lalu "buat semua API").

3. **Ukuran tugas.** Satu tugas sebaiknya selesai dalam satu sesi kerja dan hanya
   menyentuh sedikit file. Kalau sebuah tugas butuh lebih dari 3–4 kriteria selesai,
   kemungkinan besar perlu dipecah lagi.

4. **Tulis setiap tugas** dengan format yang ada di `todo.md`:
   - ID berurutan (`T-001`, `T-002`, ...).
   - Tahap dan ketergantungan (`Bergantung pada: T-003`).
   - Deskripsi yang menjelaskan apa dan kenapa.
   - Kriteria selesai yang bisa dicek secara objektif, sebaiknya lewat test. Hindari
     kriteria seperti "berfungsi dengan baik" atau "tampilan rapi".
   - Untuk tugas yang menyentuh data pengguna, sertakan kriteria keamanan, misalnya
     "pengguna A tidak bisa melihat data pengguna B".

5. **Tulis prompt siap copy-paste untuk setiap tugas di `prompt.md`.** Kerja paralel
   di starter kit ini berarti sampai 3 sesi Claude bekerja **di folder yang sama** pada
   waktu yang sama, masing-masing mengerjakan satu tugas. Tidak ada worktree atau branch
   tambahan.
   - Isi bagian "Langkah demi langkah" dengan daftar langkah bernomor dari awal sampai
     akhir proyek, supaya pengguna cukup membaca dari atas lalu copy-paste. Setiap langkah
     diberi label **SENDIRIAN** (1 sesi, untuk tugas yang menyentuh banyak file atau file
     bersama) atau **PARALEL, N sesi** (2–3 tugas yang bisa berjalan bersamaan), target
     tanggal, dan prompt mana yang ditempel di sesi mana. Tambahkan juga penjelasan
     singkat kenapa langkah tertentu tidak bisa paralel. Judul setiap prompt diawali
     nomor langkahnya, misalnya "Langkah 3 · Sesi 2 · T-004 ...".
   - Tugas dalam satu langkah paralel tidak boleh saling bergantung dan **tidak boleh
     menyentuh file yang sama**, termasuk daftar dependensi (lockfile akan bentrok).
     Semua ketergantungannya harus sudah selesai di langkah sebelumnya.
   - Isi bagian "Prompt" dengan satu prompt lengkap per tugas, mengikuti bentuk
     contoh di `prompt.md`. Prompt itu berisi: file yang harus dibaca, apa yang dibuat,
     daftar "File yang boleh diubah", aturan paralel beserta nama sesi lain di langkahnya
     (atau keterangan sendirian), perintah test milik tugas itu, dan langkah penutup
     (update blok todo, entri progress, commit hanya file sendiri). Setelah setiap
     langkah paralel, tambahkan satu prompt "Cek gabungan".
   - Tugas yang harus dikerjakan bersama manusia (konten, akun, keputusan) juga diberi
     prompt, berupa wawancara satu pertanyaan per giliran tanpa mengarang fakta.
   - Hapus bagian contoh prompt dari `prompt.md` setelah semua prompt terisi.
   - Tugas konten atau tugas bersama manusia juga dimasukkan ke urutan langkah, bukan
     "kapan saja", supaya urutannya tetap jelas.
   - Tandai tugas di `todo.md` yang masuk langkah paralel dengan `(bisa paralel)`.

   Sarankan pengguna mencoba satu sesi dulu sampai alurnya terasa natural, baru setelah
   itu menjalankan langkah paralel.

6. **Jangan mulai menulis kode.** Skill ini hanya merencanakan.

7. **Tambahkan entri di paling bawah `progress.md` (tanpa membacanya), lalu tutup dengan ringkasan**: jumlah tahap,
   tugas, dan langkah, tugas pertama yang disarankan, dan bagian yang paling berisiko. Minta pengguna mengecek apakah ukuran dan urutannya masuk
   akal, lalu sarankan `/next-task` untuk mulai.
