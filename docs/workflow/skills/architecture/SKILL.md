---
name: architecture
description: Menyusun atau memperbarui docs/architecture.md berdasarkan docs/prd.md — memilih tech stack lewat perbandingan beberapa opsi, lalu menuliskan struktur folder, model data, alur utama, keamanan, dan strategi testing. Gunakan skill ini setiap kali pengguna perlu memilih tech stack, merancang arsitektur, desain database, atau rencana teknis sebuah proyek, atau mengetik /architecture.
---

# Menyusun Arsitektur

Tujuan skill ini adalah menghasilkan `docs/architecture.md` yang menjelaskan bagaimana
produk di `docs/prd.md` dibangun. Pengguna adalah developer junior, jadi pilihan yang
baik biasanya teknologi yang populer, dokumentasinya banyak, dan mudah dipelajari,
bukan yang paling canggih. Keputusan akhir tetap di tangan pengguna.

## Langkah

1. **Baca `docs/prd.md`.** Kalau belum terisi atau masih penuh `[ASUMSI]` penting, beri
   tahu pengguna dan sarankan menyelesaikan `/prd` dulu. Arsitektur yang dibangun di atas
   kebutuhan yang belum jelas biasanya harus dirombak.

2. **Tanyakan batasan teknis** yang belum ada di PRD, satu pertanyaan per giliran:
   - Bahasa atau framework apa yang sudah dikuasai atau ingin dipelajari?
   - Di mana aplikasi akan di-hosting, dan berapa budget per bulannya?
   - Apakah ada kebutuhan khusus, misalnya pembayaran lokal, akses mobile, atau data sensitif?

3. **Tawarkan 2–3 opsi stack**, jangan langsung memilihkan. Untuk setiap opsi jelaskan:
   komponennya, kelebihan, kekurangan, perkiraan biaya, dan cocoknya untuk kondisi apa.
   Sebutkan opsi mana yang kamu anggap paling cocok dan alasannya, lalu tunggu pilihan
   pengguna. Proses membandingkan ini adalah bagian belajar yang penting bagi pengguna.

4. **Setelah pengguna memilih, tulis `docs/architecture.md`** mengikuti struktur template
   di file tersebut:
   - Tabel tech stack dengan kolom alasan yang diisi sungguhan.
   - Struktur folder yang konkret.
   - Model data untuk entitas yang dibutuhkan fitur MVP saja.
   - Alur utama untuk cerita pengguna terpenting.
   - Bagian keamanan wajib diisi: cara autentikasi, aturan siapa boleh mengakses data
     apa, cara menyimpan rahasia, dan validasi input.
   - Strategi testing: alat, jenis test, dan perintah menjalankannya.
   - Catat pilihan stack di "Log keputusan" beserta alternatif yang ditolak dan alasannya.

5. **Perbarui `CLAUDE.md`** bagian "Perintah proyek" dan "Konvensi" sesuai stack yang
   dipilih, supaya sesi berikutnya tahu cara menjalankan dan mengetes proyek.

6. **Jangan menambah fitur** di luar PRD. Kalau desain teknis memunculkan kebutuhan baru,
   sebutkan dan usulkan untuk ditambahkan ke PRD lebih dulu.

7. **Tambahkan entri di paling bawah `progress.md` (tanpa membacanya), lalu tutup dengan ringkasan**: stack yang dipilih, hal yang perlu disiapkan pengguna
   (akun layanan, API key), dan risiko teknis terbesar. Sarankan `/breakdown` sebagai
   langkah berikutnya.
