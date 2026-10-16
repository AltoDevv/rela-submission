# Naskah Demo — ReLa

## Persiapan sebelum tampil

Reset data Ibu Sri ke 6 kunjungan awal (status **Stabil**). Perintah ini aman dijalankan berulang kali:

```bash
supabase db query --linked -f supabase/seeds/03_visits_ibu_sri.sql
```

Akun demo (password `demo1234`): relawan `relawan1@demo.id`, keluarga `keluarga1@demo.id`, yayasan `pengurus@demo.id`.

## Alur B — Rekap cerita dan deteksi penurunan

**Tokoh:** Ibu Sri Wahyuni, 60 tahun. Tinggal sendiri sejak suaminya meninggal, punya hipertensi dan diabetes tipe 2.
Suka merawat tanaman, menonton TV, dan memasak. Relawan pendampingnya adalah relawan1.

**Yang sudah ada (seed):** 6 kunjungan mingguan, dari 1 September sampai 6 Oktober 2026.
- Kunjungan 1–3 sehat. Ini yang menjadi baseline.
- Kunjungan 4–6 menurun pelan: makan berkurang, jalan perlu pegangan, lebih pendiam, kurang fit, dan sekali lupa obat malam.
- Semuanya hanya turun 1 tingkat, sehingga status tetap **Stabil**.

### Cerita ke-7, versi A → **Perlu perhatian**

Login sebagai relawan1 → Ibu Sri → Cerita kunjungan. Ketik atau ucapkan jawaban berikut:

| Pertanyaan | Jawaban |
|---|---|
| Makan | Ibu cuma makan beberapa suap, katanya lagi nggak nafsu. |
| Obat | Obat tadi pagi belum diminum, Ibu lupa. Saya ingetin terus diminum. |
| Berjalan/bergerak | Jalannya masih pelan pegangan tembok. |
| Mandi/berpakaian/toilet | Mandi sama ganti baju masih sendiri. |
| Ingatan dan obrolan | Ngobrolnya masih nyambung. |
| Suasana hati | Ibu kelihatan capek, nggak banyak ngomong. |
| Keluhan lain dan kegiatan | Katanya masih kurang fit, tanaman cabainya mulai layu nggak keurus. |

**Yang diharapkan muncul:**
- Ringkasan: Nafsu makan **Sangat sedikit** · Obat **Kadang terlewat** · Mobilitas **Pelan atau perlu pegangan** · Suasana hati **Biasa** · Kondisi umum **Kurang fit**.
- Status menjadi **Perlu perhatian**, dengan dua alasan:
  - Nafsu makan: Sangat sedikit (biasanya Baik), turun 2 tingkat. Kutipan: *"cuma makan beberapa suap"*.
  - Obat: Kadang terlewat (biasanya Teratur), terlewat pada 2 dari 3 kunjungan terakhir. Kutipan: *"Obat tadi pagi belum diminum"*.
- Grafik tren di HP keluarga1 bergeser tanpa perlu di-refresh.

### Cerita ke-7, versi B → **Segera dikabari**

> Satu lansia hanya bisa punya satu kunjungan terkonfirmasi per hari. Kalau versi A sudah disimpan, jalankan
> dulu `supabase db query --linked -f supabase/seeds/03_visits_ibu_sri.sql` sebelum versi B (atau pilih salah satu
> versi saja untuk panggung).

Sama seperti versi A, tetapi dua jawaban berikut diganti:

| Pertanyaan | Jawaban |
|---|---|
| Berjalan/bergerak | Tadi pagi Ibu terpeleset di kamar mandi, lututnya memar. Sekarang jalannya harus saya bantu. |
| Keluhan lain dan kegiatan | Ibu ngeluh lututnya sakit habis jatuh tadi. |

**Yang diharapkan muncul:**
- Tanda bahaya **Jatuh**, dengan kutipan *"terpeleset di kamar mandi"*.
- Status langsung menjadi **Segera dikabari**.
- Push notification masuk ke HP keluarga dan yayasan (setelah T-020 selesai).

> Data kedua cerita ini juga ada di `supabase/seeds/ibu_sri.json` (`story7`) dan dites di
> `supabase/functions/_shared/status_test.ts`. Kalau teks di sini diubah, ubah juga JSON-nya.

## Angka untuk pitch

Diukur pada **15 Oktober 2026** dengan model **`gemini-3.5-flash-lite`** (`deno run -A scripts/eval_extraction.ts`),
memakai 35 cerita berlabel di `data/eval/stories.jsonl` (245 kategori, 18 tanda bahaya).

| Metrik | Hasil |
|---|---|
| Akurasi kategori keseluruhan | **88,6%** (217/245) |
| Recall tanda bahaya | **100%** (18/18, tidak ada yang terlewat) |
| Alarm palsu tanda bahaya | 10 (6 di antaranya "keluhan baru") |
| Bahasa Indonesia | 92,9% (20 cerita) |
| Bahasa Jawa/campuran | 82,7% (14 cerita) |

Per domain: Obat 97,1% · Mobilitas 94,3% · Daya ingat 94,3% · Kemandirian harian 88,6% · Suasana hati 85,7% ·
Nafsu makan 82,9% · Kondisi umum 77,1%.

**Cara menyampaikan:** sistem tidak melewatkan satu pun tanda bahaya dan lebih memilih waspada (alarm palsu),
sedangkan kategori yang keliru bisa dikoreksi relawan di layar konfirmasi sebelum disimpan.

**Batasan yang harus disebut (jangan klaim lebih):** 35 cerita disusun tim, bukan data lapangan. Labelnya
belum diperiksa orang kedua (T-023). Angka ini mengukur ekstraksi cerita, bukan ketepatan deteksi kondisi
kesehatan.

**Tentang alarm palsu (siapkan untuk pertanyaan juri):** 10 alarm palsu di atas adalah hasil AI **sebelum** diperiksa
relawan. Di layar konfirmasi relawan bisa mencabut tanda bahaya yang keliru dan menambah yang terlewat, jadi status
dan notifikasi ke keluarga dihitung dari hasil yang sudah disaring manusia. Percobaan prompt dengan definisi tanda
bahaya menurunkan alarm palsu ke 3 (akurasi 89,4%) tetapi satu tanda bahaya ambigu terlewat (recall 17/18), sehingga
prompt lama dipertahankan demi keselamatan.

## Alur verifikasi keluarga (baru, 15 Okt)

Ibu Sri dan Pak Harjo di seed sudah berlangganan dan terverifikasi. Untuk memperlihatkan alurnya:
1. keluarga (akun baru) → Daftarkan lansia → pilih titik di peta → **Bayar (simulasi)** → foto 3 dokumen → **Kirim dan cari relawan** → Terima usulan.
2. Kartu usulan hanya nama, foto, yayasan, keahlian, "Jarak ± N km". Di detail lansia: "Nama lengkap dan nomor HP relawan muncul setelah yayasan memeriksa dokumen Anda".
3. pengurus → dashboard → baris oranye "Dokumen keluarga perlu diperiksa" → lihat dokumen → **Setujui**.
4. keluarga → detail lansia menampilkan nama lengkap dan nomor HP relawan (tombol telepon).
5. relawan → Cerita kunjungan → dialog **Kunjungan pertama**: "Lansia ada & setuju" → baru bisa menulis cerita.
Reset setelahnya: `04_reset_demo.sql` lalu `03_visits_ibu_sri.sql`.

## Alur relawan baru (15 Okt)

1. relawan baru: daftar akun → OTP simulasi → **Pilih yayasan** (atau buka tautan undangan) → isi profil, titik peta, foto → Gabung. Beranda menampilkan "Menunggu verifikasi tatap muka".
2. pengurus: Verifikasi relawan → **Verifikasi tatap muka** → centang semua butir → kode 6 digit tampil (berganti tiap 2 menit).
3. relawan memasukkan kode → "Terverifikasi! Anda sekarang relawan aktif." Dialog pengurus tertutup sendiri.
4. relawan1 → Ibu Sri → **Ajukan berhenti** (alasan) → pengurus melihat baris oranye "Relawan mengajukan berhenti" di dashboard → ketuk → **Terima & cari pengganti** → layar Pasang manual.
5. pengurus → Verifikasi relawan → relawan aktif → **Nonaktifkan relawan** (alasan) → lansianya masuk "Perlu ditangani".
Reset setelahnya: `04_reset_demo.sql` lalu `03_visits_ibu_sri.sql`.

## Ganti pendamping (15 Okt)
keluarga1 → Ibu Sri → ⋮ → **Minta ganti pendamping** → pilih alasan → **Ganti & cari relawan** → kartu usulan relawan baru
(bukan relawan1) → Terima. relawan1 menerima notifikasi netral "Pendampingan Ibu Sri dialihkan". Coba ganti lagi →
ditolak "sekali dalam 30 hari" dengan tombol **Lapor masalah serius**. Reset setelahnya.

