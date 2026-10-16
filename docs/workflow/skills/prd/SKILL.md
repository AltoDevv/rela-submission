---
name: prd
description: Menyusun atau memperbarui docs/prd.md (Product Requirements Document) lewat wawancara dengan pengguna — north star, masalah, pengguna, fitur MVP, non-goals, metrik sukses. Gunakan skill ini setiap kali pengguna mau memulai proyek baru, punya ide aplikasi/SaaS, ingin menulis atau merevisi PRD, spec, atau kebutuhan produk, atau mengetik /prd — meskipun mereka tidak menyebut kata "PRD".
---

# Menyusun PRD

Tujuan skill ini adalah menghasilkan `docs/prd.md` yang isinya benar-benar keputusan
pengguna, bukan tebakan AI. PRD yang ditulis AI tanpa wawancara cenderung penuh fitur
generik yang terdengar bagus tapi tidak pernah diminta. Karena itu, peranmu di sini
adalah pewawancara dan penulis, sedangkan pengguna adalah pengambil keputusan.

## Langkah

1. **Cek kondisi awal.** Baca `docs/prd.md`. Kalau sudah terisi, tanyakan apakah
   pengguna mau merevisi bagian tertentu atau menyusun ulang. Saat merevisi, pertahankan
   isi yang tidak dibahas dan catat perubahannya di "Riwayat perubahan".

2. **Minta coretan kasar.** Kalau pengguna belum menjelaskan idenya, minta mereka
   menulis idenya dengan bahasa bebas: masalahnya apa, untuk siapa, dan kira-kira fiturnya
   apa. Ide awal harus datang dari pengguna.

3. **Wawancara, satu pertanyaan per giliran.** Pertanyaan yang ditumpuk sekaligus
   membuat jawaban dangkal. Gali area berikut sesuai kebutuhan (lewati yang sudah jelas):
   - Siapa pengguna utamanya, dan seperti apa situasi mereka sehari-hari?
   - Bagaimana mereka mengatasi masalah ini sekarang, dan apa yang menyebalkan dari cara itu?
   - Apa satu hal yang harus bisa dilakukan produk ini di versi pertama?
   - Fitur apa yang menggoda untuk dibuat tapi sebaiknya ditunda? (non-goals)
   - Bagaimana tahu produk ini berhasil? (metrik sukses)
   - Batasan apa yang ada: deadline, budget, kemampuan tim?

   Kalau jawaban pengguna samar ("untuk semua orang", "fitur lengkap"), tanyakan versi yang
   lebih spesifik. Biasanya 6–10 pertanyaan sudah cukup; jangan memperpanjang wawancara
   hanya demi kelengkapan.

4. **Jangan bahas teknologi.** PRD menjelaskan apa dan kenapa. Kalau pengguna menyebut
   tech stack, catat sebagai batasan atau preferensi, lalu kembalikan pembahasan ke kebutuhan.
   Pemilihan teknologi dilakukan di skill `/architecture`.

5. **Tulis `docs/prd.md`** mengikuti struktur template yang ada di file tersebut. Aturan
   penulisan:
   - Fitur MVP ditulis sebagai cerita pengguna, masing-masing dengan kondisi "Berhasil
     kalau" yang bisa dicek.
   - Tandai setiap hal yang tidak dikatakan pengguna dengan `[ASUMSI]`.
   - Buat MVP sekecil mungkin. Kalau ragu sebuah fitur wajib atau tidak, masukkan ke
     non-goals dan sebutkan di ringkasan.
   - Gunakan bahasa yang sama dengan pengguna.

6. **Tambahkan entri di paling bawah `progress.md` (tanpa membacanya), lalu tutup dengan ringkasan singkat**: north star, jumlah fitur MVP, daftar `[ASUMSI]`
   yang perlu dikonfirmasi, dan pertanyaan terbuka. Minta pengguna membaca PRD-nya dan
   memastikan mereka bisa membela setiap baris. Sarankan `/architecture` sebagai langkah
   berikutnya setelah PRD disetujui.
