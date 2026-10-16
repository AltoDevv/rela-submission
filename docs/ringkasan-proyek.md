# Ringkasan Proyek — ReLa (Relawan Lansia)

Bahan untuk menyusun proposal (Hackathon JOINTS UGM 2026, tema Healthcare). Status per 15 Oktober 2026.
Sumber rinci: `docs/prd.md` (kebutuhan), `docs/architecture.md` (teknis & Log keputusan), `docs/demo-script.md` (demo & angka).

---

## 1. Satu paragraf

**ReLa** (Relawan Lansia, sebelumnya ReLa) adalah aplikasi Android yang mengubah kepedulian komunitas menjadi **pendampingan lansia yang
terorganisir, aman, dan bisa dipantau keluarga**. Yayasan atau komunitas mendaftarkan relawannya; sistem
memasangkan setiap lansia dengan relawan tetap yang terdekat; setelah berkunjung relawan cukup **bercerita dengan
bahasa sehari-hari** (boleh bahasa Jawa, boleh lewat suara), lalu AI merangkumnya menjadi 7 kategori kondisi
beserta kutipan buktinya. Dari tren kunjungan, sistem mendeteksi **penurunan kondisi yang pelan** yang biasanya
tidak terlihat lewat telepon, dan langsung mengabari keluarga bila ada tanda bahaya. ReLa adalah teman
pendamping, **bukan layanan kesehatan**: yang disampaikan adalah pengamatan, bukan diagnosis.

## 2. Masalah

- Lansia yang tinggal sendiri atau ditinggal anak merantau tidak punya orang yang melihat kondisinya langsung dan rutin.
- Keluarga hanya mengandalkan telepon; "Ibu sehat" sering tidak sesuai kenyataan (obat habis, makan makin sedikit, makin sulit berjalan).
- Yayasan sudah punya relawan, tetapi dikelola manual lewat grup chat dan kertas: tanpa pasangan tetap, laporan, atau pantauan.
- Perawat berbayar per jam tidak terjangkau untuk pendampingan jangka panjang.
- Saat darurat, penolong sering tidak tahu riwayat penyakit lansia.
- Lansia 11,97% penduduk Indonesia pada 2025 (BPS, SUPAS 2025).

| Cara sekarang | Kelemahan |
|---|---|
| Telepon keluarga | Kabar lisan, tidak menggambarkan kondisi sebenarnya |
| Grup WhatsApp yayasan | Tanpa pasangan tetap, rekap terstruktur, maupun pantauan keluarga |
| Perawat berbayar (Homecare24, RuangRawat) | Mahal untuk jangka panjang |
| Aplikasi caregiver keluarga (Carebuddy, Balas Kasih) | Tidak melibatkan yayasan dan relawan |

## 2a. Fokus subtema: satu masalah yang kita selesaikan sepenuhnya

Subtema hackathon: keluarga kesulitan memantau kondisi, kepatuhan obat, dan menjangkau bantuan, **sehingga lansia
berisiko memburuk tanpa terdeteksi**. ReLa menekuni ujung kalimat itu:

> **Penurunan kondisi lansia yang tinggal sendiri terjadi pelan-pelan dan tidak terlihat lewat telepon. Keluarga
> baru tahu saat sudah parah.**

Kenapa ini masalah terkuat:
- **Nyata dan sering:** "Ibu sehat kok" di telepon tidak menangkap makan yang makin sedikit, obat yang mulai
  terlewat, atau jalan yang makin perlu pegangan. Penurunan seperti ini tidak punya satu momen darurat, jadi tidak
  ada yang menelepon siapa pun.
- **Butuh mata yang hadir rutin**, dan itulah yang dimiliki komunitas: relawan yang berkunjung tiap minggu.
- **Tepat di keunggulan teknis kita:** cerita bebas relawan → 7 domain terstruktur dengan kutipan bukti → tren
  dibanding baseline lansia itu sendiri → keluarga dikabari dengan alasan yang bisa dicek.
- **Bisa diukur:** akurasi ekstraksi 88,6%, recall tanda bahaya 100% (data uji tim), dan untuk uji lapangan: waktu
  dari tanda "Perlu perhatian" sampai ada tindak lanjut keluarga.

Bagian subtema lain dijawab sebagai **pendukung**, bukan klaim utama:
| Bagian subtema | Peran di ReLa | Yang sengaja tidak kita klaim |
|---|---|---|
| Memantau kondisi | Inti: status, tren 7 domain, rekap kunjungan | Pemantauan real-time / sensor |
| Kepatuhan obat | Domain "Obat" diamati tiap kunjungan; terlewat 2 dari 3 kunjungan → Perlu perhatian | Pengingat minum obat harian |
| Menjangkau bantuan | Relawan tetap + tombol Darurat saat bersama lansia + profil kesehatan untuk 119 | Menolong lansia yang jatuh saat sendirian |

Kalimat pitch: **"Dari 'Ibu sehat kok' menjadi data: relawan komunitas mendeteksi dini penurunan kondisi lansia yang
tinggal sendiri, dan keluarga tahu sebelum terlambat."**

Data yang perlu dikutip di proposal (ambil angka resmi, jangan perkiraan): proporsi lansia 11,97% (BPS, SUPAS 2025)
dan persentase lansia yang tinggal sendiri dari publikasi BPS *Statistik Penduduk Lanjut Usia* edisi terbaru.

## 3. Pengguna

| Peran | Siapa | Yang ia dapat |
|---|---|---|
| **Keluarga** | Anak yang jauh dari orang tuanya | Mendaftarkan lansia, memilih relawan, melihat status & tren, notifikasi darurat, memberi masukan |
| **Relawan** | Anggota komunitas, *buddy* tetap seorang lansia (bukan tenaga kesehatan, usia ≥ 18) | Cerita kunjungan tanpa menghafal skala, tombol Darurat, ucapan terima kasih |
| **Yayasan** | Yayasan, rumah ibadah, komunitas | Undang & verifikasi relawan, dashboard lansia paling mendesak, verifikasi keluarga, tindak lanjut masukan |
| **Lansia** | Tinggal sendiri, tidak perlu memakai aplikasi | Didampingi rutin; ditanya langsung kesediaannya pada kunjungan pertama |

## 4. Nilai unik

1. **Cerita → data terstruktur.** Relawan menjawab 7 pertanyaan dengan bahasa bebas; AI (Gemini) memetakan ke 7 domain
   (nafsu makan, obat, mobilitas, kemandirian harian, daya ingat, suasana hati, kondisi umum) dengan **kalimat bukti
   yang wajib benar-benar ada di cerita**. Nama dan alamat lansia dihapus sebelum dikirim ke AI.
2. **Deteksi penurunan pelan, bukan satu kejadian.** Baseline dari 3 kunjungan pertama; status naik bila turun 2
   tingkat, memburuk 3 kunjungan berturut-turut, obat terlewat 2 dari 3 kunjungan, atau kemampuan harian baru hilang.
   Tanda bahaya (jatuh, bingung mendadak, sesak/nyeri dada, tidak makan, obat habis, keluhan baru) langsung
   **"Segera dikabari"** + push ke keluarga & yayasan.
3. **Manusia tetap memegang kendali.** Relawan memeriksa dan mengoreksi hasil AI sebelum disimpan; mencabut tanda bahaya
   wajib beralasan dan terlihat oleh keluarga & yayasan.
4. **Memakai jaringan yang sudah ada.** Yayasan dan relawan komunitas, bukan tenaga berbayar.
5. **Aman di dua sisi.** Relawan diverifikasi tatap muka; keluarga diverifikasi dokumen; kontak relawan baru terbuka
   setelah verifikasi (seperti Gojek setelah pesanan diterima).

## 5. Fitur

**Inti (MVP)**
- F1 Pendaftaran lansia + Profil Kesehatan Ringkas + titik rumah di peta.
- F1a Relawan bergabung lewat tautan/kode undangan yayasan, OTP (disimulasikan), foto wajah dari kamera.
- F1b Yayasan memverifikasi relawan tatap muka dengan butir pemeriksaan wajib (KTP asli, nama sama, usia ≥ 18, HP aktif, orientasi kode etik) dan kode sekali pakai (F17).
- F2/F2a Usulan relawan otomatis (syarat keahlian demensia/mobilitas → jarak terdekat → beban terendah); keluarga terima/tolak dengan alasan; 3× ditolak → yayasan memasangkan manual; usulan kedaluwarsa 48 jam.
- F3–F7 Cerita kunjungan (ketik atau suara) → ringkasan 7 domain + bukti → konfirmasi/koreksi relawan → status (Stabil / Perlu perhatian / Segera dikabari) → 7 grafik tren untuk keluarga.
- F8 Darurat: relawan menekan tombol, panggilan 119 (disimulasikan) dengan profil kesehatan untuk dibacakan, lokasi GPS, push ke keluarga & yayasan.
- F9 Dashboard yayasan: lansia diurutkan paling mendesak, kunjungan terakhir, beban relawan.

**Tambahan (14–15 Okt)**
- F10 Siklus hidup: relawan berhenti, minta ganti pendamping, yayasan melepas, akhiri/aktifkan kembali, ubah data, koreksi kunjungan terakhir, hapus data lansia, hapus akun.
- F11 Beberapa anggota keluarga (undangan harus diterima); persetujuan lansia/wali; Syarat & Persetujuan.
- F12 Verifikasi keluarga online (KTP keluarga, KTP lansia, KK/surat RT-RW) oleh yayasan relawan; dokumen dihapus setelah diperiksa.
- F13 Langganan per lansia per bulan (pembayaran disimulasikan): perpanjang, riwayat, pengingat, tenggang 7 hari.
- F14 Masukan keluarga untuk relawan (bukan bintang): apresiasi → relawan & yayasan; perlu diperbaiki → yayasan; masalah serius → yayasan seketika, tidak dibaca relawan.
- F15 Pengingat otomatis bila >7 hari tanpa kunjungan; tanda "sudah ditangani"; satu kunjungan terkonfirmasi per hari.
- F16 Pemilih lokasi peta gratis (OpenStreetMap): cari tempat, geser pin, satelit, lokasi HP.
- F17 Relawan apply ke yayasan dari daftar → datang tatap muka → pengurus mengisi butir pemeriksaan dan menampilkan **kode sekali pakai** (seperti authenticator) → relawan memasukkannya → Aktif; yayasan bisa menonaktifkan relawan.
- F19 Keluarga **ganti pendamping** maks. 1× per 30 hari dengan alasan; pengganti dicarikan otomatis (bisa dari yayasan lain); relawan lama diberi tahu netral.
- F18 Relawan berhenti dari seorang lansia lewat **permintaan ke yayasan** (otomatis diterima 7 hari) → yayasan langsung memasangkan pengganti.

## 6. Alur utama (untuk demo)

- **A. Pendaftaran → pemasangan:** keluarga daftar lansia → bayar (simulasi) → unggah dokumen → relawan diusulkan → terima → yayasan memverifikasi dokumen → kontak relawan terbuka → kunjungan pertama memastikan lansia setuju.
- **B. Cerita → deteksi penurunan:** Ibu Sri (60 th, hipertensi & diabetes) punya 6 kunjungan yang menurun pelan tetapi masih Stabil; cerita ke-7 versi A → **Perlu perhatian** (makan "beberapa suap", obat terlewat), versi B → **Segera dikabari** (terpeleset di kamar mandi) + push.
- **C. Darurat:** relawan menekan Darurat → layar 119 dengan profil kesehatan → keluarga menerima push + peta lokasi.

## 7. Teknologi

| Bagian | Pilihan | Alasan |
|---|---|---|
| Aplikasi | Flutter (Android) | Satu kode, cepat dibuat tim kecil |
| Backend | Supabase: Postgres + Row Level Security, Auth, Storage, Realtime, Edge Functions (Deno), pg_cron | Aturan akses ditegakkan di database, bukan di aplikasi |
| AI | Google Gemini (`gemini-3.5-flash-lite`, keluaran JSON terstruktur) | Kuota gratis; hasil divalidasi server |
| Notifikasi | Firebase Cloud Messaging | Push langsung dari aplikasi |
| Peta | OpenStreetMap (flutter_map), pencarian Photon, satelit Esri | Gratis tanpa API key |

## 8. Keamanan, privasi, etika

- **Data minimal (UU PDP):** yayasan melihat ringkasan, bukan cerita lengkap atau profil kesehatan; dokumen verifikasi dihapus setelah diperiksa; hak hapus data lansia dan akun.
- **Persetujuan:** lansia sendiri atau keluarga sebagai wali, dicatat server; relawan menanyakan langsung pada kunjungan pertama; Syarat & Persetujuan menyebut pemrosesan di luar Indonesia (Supabase Singapura, Gemini, Firebase, OpenStreetMap).
- **AI aman:** nama/alamat dihapus sebelum ke AI; bukti harus kutipan asli; status selalu disertai "Ini bukan diagnosis".
- **Diuji sebagai penyerang:** `scripts/check_security.ts` berisi **61 serangan** lewat API sebagai pengguna biasa (memalsukan kunjungan, membaca data yayasan lain, membungkam alarm, memanen data relawan dengan akun palsu, memalsukan pembayaran, dll.) — semuanya gagal.

## 9. Hasil uji (angka untuk pitch)

| Metrik | Hasil |
|---|---|
| Akurasi kategori AI | **88,6%** (217/245) pada 35 cerita berlabel |
| Recall tanda bahaya | **100%** (18/18) |
| Alarm palsu sebelum disaring relawan | 10 (disaring manusia di layar konfirmasi) |
| Bahasa Indonesia / Jawa-campuran | 92,9% / 82,7% |
| Test otomatis | 99 test aplikasi, 47 test logika server, 61 serangan keamanan |

**Jujur soal batasan:** 35 cerita disusun tim, bukan data lapangan; label belum diperiksa orang kedua; angka
mengukur ekstraksi cerita, bukan ketepatan deteksi kesehatan.

## 10. Model bisnis

**Prinsip:** keluarga membayar untuk ketenangan dan informasi; relawan tetap relawan (penggantian transport, bukan
gaji); yayasan mendapat dana operasional rutin; lansia dari keluarga tidak mampu tetap bisa dilayani lewat sponsor.

### 10.1 Harga: **Rp200.000 per lansia per bulan** (4 kunjungan)

Sekitar **Rp6.700 per hari**, atau **Rp50.000 per kunjungan** — masih **di bawah biaya satu hari** perawat lansia dan
hanya **3–5% dari perawat menginap**.

| Pilihan keluarga | Harga | Yang didapat |
|---|---|---|
| Perawat/caregiver lansia menginap | Rp4–6 juta/bulan | Perawatan penuh, tapi mahal untuk jangka panjang |
| Perawat lansia harian | Rp200–350 ribu/hari | Sekali datang |
| Hanya telepon | Gratis | "Ibu sehat kok" — penurunan pelan tidak terlihat |
| **ReLa** | **Rp200.000/bulan** | Relawan tetap 4×/bulan, ringkasan & tren 7 kondisi, peringatan dini, tombol darurat |

Sumber pembanding: [detikHealth/Insan Medika](https://health.detik.com/berita-detikhealth/d-5549460/meski-sibuk-ini-cara-rawat-lansia-hingga-keluarga-sakit-di-rumah),
[detikFinance](https://finance.detik.com/read/2017/06/14/141857/3530408/4/tertarik-pakai-jasa-art-infal-ini-rincian-tarifnya)
(berita 2017–2021; harga sekarang kemungkinan lebih tinggi).

### 10.2 Unit economics (per lansia per bulan)

| Pos | Rp | % | Dasar |
|---|---|---|---|
| Pendapatan | 200.000 | 100% | Langganan keluarga |
| Transport relawan (4 × Rp15.000) | 60.000 | 30% | Relawan dipasangkan yang terdekat (< 3 km); ojol Zona I Rp1.850–2.300/km ([Bisnis.com](https://ekonomi.bisnis.com/read/20250701/98/1889311/simulasi-tarif-ojol-jika-naik-8-15-cek-besarannya)) |
| Porsi yayasan | 40.000 | 20% | Verifikasi tatap muka, pembinaan relawan, tindak lanjut laporan |
| Biaya pembayaran | ± 4.000 | 2% | Virtual account ± Rp4.000 / QRIS 0,7% ([perbandingan](https://quasa.io/id/media/xendit-vs-midtrans-biaya-tetap-rp4000-mengubah-pilihan-bisnis-kecil)) |
| AI (4 cerita) | ± 250 | 0,1% | ± Rp60 per cerita, Gemini Flash-Lite ([harga](https://anotherwrapper.com/llm-pricing/gemini-3.5-flash-lite)), kurs Rp16.000/US$ |
| **Kontribusi platform** | **± 95.750** | **48%** | Untuk server, dukungan, pengembangan, pemasaran |

- **Titik impas:** biaya tetap tahun 1 ± Rp30,5 juta/bulan (tim inti kecil + server) → impas di **± 320 lansia**
  (± 12 yayasan × 27 lansia).
- **LTV (nilai seumur pelanggan):** bila rata-rata berlangganan 20 bulan (asumsi churn 5%/bulan) →
  20 × Rp95.750 ≈ **Rp1,9 juta** kontribusi per lansia. Biaya akuisisi (CAC) yang sehat: **di bawah Rp500 ribu**
  (LTV/CAC ≥ 3,8), masuk akal karena akuisisi lewat yayasan dan rumah ibadah, bukan iklan.

### 10.3 TAM · SAM · SOM

| | Definisi | Jumlah lansia | Nilai per tahun |
|---|---|---|---|
| **TAM** | Semua lansia Indonesia yang **tinggal sendiri** (5,5% dari ± 33,4 juta lansia) | ± **1,84 juta** | 1,84 jt × Rp2,4 jt ≈ **Rp4,4 triliun** |
| **SAM** | TAM yang keluarganya **mampu membayar** (di luar 40% pengeluaran terbawah: 56,65%) | ± **1,04 juta** | ≈ **Rp2,5 triliun** |
| **SOM** | Target 3 tahun: **10.000 lansia** (± 1% SAM) lewat ± 370 yayasan mitra | **10.000** | ≈ **Rp24 miliar** |

Sumber: lansia ± 33,4 juta 2024 dan 65,8 juta pada 2045 ([GoodStats/BPS](https://data.goodstats.id/statistic/11-penduduk-indonesia-lansia-bonus-demografi-masih-menjanjikan-RfeWD),
[RRI/BPS](https://rri.co.id/bandar-lampung/berita-lain/2486908/bps-indonesia-resmi-masuki-kategori-aging-population));
5,5% tinggal sendiri (BPS *Statistik Penduduk Lanjut Usia 2024*, via [skripsi Undip](https://eprints2.undip.ac.id/id/eprint/52172/3/HANA%20MARYAM%20ROHMAH_13040222140094%20Bab%20I.pdf));
sebaran pengeluaran rumah tangga lansia: 40% terbawah 43,36%, menengah 37,25%, 20% teratas 19,40% (BPS 2020, via
[Badan Keahlian DPR](https://berkas.dpr.go.id/pa3kn/analisis-tematik-apbn/public-file/bib-public-22.pdf)).

**Kenapa angka ini konservatif:** TAM belum menghitung lansia yang hanya tinggal berdua dengan pasangannya lansia,
lansia yang tinggal dengan cucu, atau lansia di panti; jumlah lansia juga diproyeksikan **dua kali lipat pada 2045**.

### 10.4 Proyeksi 3 tahun (asumsi)

| Tahun | Lansia berlangganan | Yayasan mitra | Pendapatan | Kontribusi platform | Biaya tetap | Hasil |
|---|---|---|---|---|---|---|
| 1 — uji coba 1 kota | 300 | ± 11 | Rp0,72 miliar | Rp0,34 miliar | Rp0,37 miliar (Rp30,5 jt/bln) | hampir impas (−Rp0,03 miliar) |
| 2 — 3 kota | 2.500 | ± 90 | Rp6,0 miliar | Rp2,87 miliar | Rp0,96 miliar (Rp80 jt/bln) | **+Rp1,9 miliar** |
| 3 — Jawa–Bali | 10.000 | ± 370 | Rp24,0 miliar | Rp11,5 miliar | Rp1,8 miliar (Rp150 jt/bln) | **+Rp9,7 miliar** |

Di tahun 3, **Rp12 miliar per tahun mengalir ke yayasan dan transport relawan** — dampak sosial ikut tumbuh bersama bisnis.

### 10.5 Sumber pendapatan

1. **Langganan keluarga** (utama) — Rp200.000/lansia/bulan.
2. **Sponsori satu lansia** — CSR/donatur membayar **Rp2,4 juta/tahun per lansia** dari keluarga tidak mampu (40%
   terbawah, di luar SAM berbayar), dengan laporan dampak terukur.
3. **Benefit karyawan (B2B)** — perusahaan membayar langganan orang tua karyawan yang merantau.
4. **Program pemerintah (B2G)** — dinas sosial / Posyandu Lansia memakai ReLa untuk pendampingan, dengan laporan
   agregat tanpa identitas.

### 10.6 Business Model Canvas

| Komponen | Isi |
|---|---|
| **Segmen pelanggan** | Keluarga perantau (pembayar); yayasan/komunitas/rumah ibadah (mitra penyedia relawan); sponsor CSR, perusahaan, pemerintah |
| **Proposisi nilai** | Keluarga: tahu kondisi orang tua dari pengamatan langsung yang terstruktur + peringatan dini. Yayasan: alat kelola & verifikasi relawan + pemasukan rutin. Sponsor: dampak terukur per lansia |
| **Saluran** | Yayasan & rumah ibadah mitra, komunitas perantau, HR perusahaan |
| **Hubungan pelanggan** | Relawan tetap per lansia, ringkasan tiap kunjungan, masukan keluarga yang ditindaklanjuti yayasan |
| **Arus pendapatan** | Langganan, sponsor per lansia, B2B, B2G (10.5) |
| **Sumber daya kunci** | Jaringan relawan & yayasan terverifikasi dua arah; rubrik 7 domain + aturan deteksi; riwayat tren per lansia |
| **Aktivitas kunci** | Onboarding yayasan, verifikasi relawan & keluarga, menjaga kualitas AI, menindaklanjuti laporan serius |
| **Mitra kunci** | Yayasan/komunitas, puskesmas & Posyandu Lansia (rujukan), payment gateway berizin, penyedia cloud & AI |
| **Struktur biaya** | Variabel: transport relawan, porsi yayasan, pembayaran, AI (10.2). Tetap: tim, server, dukungan, pemasaran |

### 10.7 Pesaing & posisi 

| Pemain | Model | Celah yang diisi ReLa |
|---|---|---|
| Homecare24, RuangRawat, penyalur perawat | Tenaga berbayar per jam/hari/bulan | Terlalu mahal untuk pendampingan rutin jangka panjang |
| Carebuddy, Balas Kasih | Aplikasi untuk keluarga yang merawat sendiri | Tidak ada orang yang datang ketika keluarga jauh |
| Grup WhatsApp yayasan | Gratis, manual | Tanpa pasangan tetap, rekap terstruktur, atau deteksi penurunan |
| **ReLa** | Relawan komunitas + langganan terjangkau + AI untuk rekap & deteksi | Hadir rutin, murah, dan terukur |

## 11. Batasan & rencana berikutnya

- Bukan layanan medis; tidak menangani lansia yang tumbang saat sendirian; panggilan darurat selalu dipicu manusia.
- Disimulasikan di demo: OTP relawan, panggilan 119, pembayaran.
- Sebelum produksi: konfirmasi email dan aturan kata sandi, payment gateway berizin, lisensi citra satelit,
  server pencarian peta sendiri, nomor HP relawan disamarkan, notifikasi layar kunci yang umum, tombol
  "Saya merasa tidak aman" untuk relawan.
- Desain antarmuka mengikuti Figma tim (3 menu navigasi per peran) — sedang disusun.

## 12. Roadmap fitur

**Sudah ada (v1.0, hackathon):** 3 peran; rekap cerita (ketik/suara) → 7 domain + bukti → status & tren; darurat;
pemasangan otomatis + manual; verifikasi relawan (kode tatap muka) & keluarga (dokumen); langganan (simulasi);
masukan keluarga; permintaan berhenti; pengingat kunjungan; peta OSM; hapus data/akun.

| Versi | Tema | Keluarga | Relawan | Yayasan | Sistem/AI |
|---|---|---|---|---|---|
| **v1.1** (1–2 bln) | Siap pilot: aman & sungguhan | Bayar sungguhan (QRIS/VA), notifikasi layar kunci yang umum, desain final (3 menu) | OTP SMS/WhatsApp, tombol **"Saya merasa tidak aman"** (lokasi ke yayasan), **check-in/check-out kunjungan** (waktu + GPS), keluar dari yayasan | Lihat check-in relawan & laporan "tidak aman" seketika | Konfirmasi email, aturan kata sandi, nomor relawan disamarkan (telepon lewat aplikasi) |
| **v1.2** (3–4 bln) | Kunjungan lebih teratur | **Jadwal kunjungan** terlihat, **chat** dengan relawan (nomor tersembunyi), **laporan bulanan PDF** untuk keluarga/dokter | Atur jadwal + pengingat H-1, foto kunjungan (dengan persetujuan lansia) | Kalender kunjungan & relawan yang sering absen | Pertanyaan rekap menyesuaikan kondisi lansia; minta detail bila jawaban terlalu pendek |
| **v1.3** (5–6 bln) | Rujukan kesehatan | Saat "Perlu perhatian": daftar **puskesmas/Posyandu Lansia terdekat** + tombol telepon; pengingat perbarui profil kesehatan tiap 3 bulan | Catat obat hampir habis → keluarga diingatkan | Rekap tindak lanjut per lansia | Ekspor ringkasan untuk tenaga kesehatan (tetap bukan diagnosis) |
| **v2.0** (6–12 bln) | Skala yayasan | Keluarga pengganti sementara saat relawan cuti | **Jam relawan & sertifikat**, apresiasi | **Dashboard web**, laporan dampak untuk sponsor ("Sponsori satu lansia"), banyak cabang & peran pengurus | Aplikasi iOS, analitik agregat tanpa identitas |
| **v3.0** (12+ bln) | AI lebih dalam & lansia ikut | Panggilan video dengan lansia lewat HP relawan | Dukungan bahasa daerah lain (Sunda, Madura, dll.) | Integrasi program dinas sosial (B2G), e-KYC otomatis | **Deteksi lapis ketiga**: AI membandingkan cerita antar kunjungan; **halaman sederhana untuk lansia** (telepon keluarga/119, foto relawan yang akan datang) |

**Sengaja tidak akan dibuat:** layanan medis (obat, tindakan, diagnosis), panggilan ambulans otomatis, check-in
harian otomatis ke lansia, relawan memegang kunci rumah.

## 13. Roadmap teknologi (dari gratis/simulasi menjadi siap produksi)

| Komponen | Sekarang (hackathon) | Pilot (v1.1) | Skala (v2–v3) |
|---|---|---|---|
| **AI rekap cerita** | Gemini API kuota gratis | Gemini berbayar per token (± Rp60 per cerita) | **Model machine learning sendiri** (lihat di bawah); Gemini jadi cadangan |
| **Database & backend** | Supabase paket gratis (Singapura) | Supabase Pro (± US$25/bulan) + backup harian | Supabase Team / server sendiri di Indonesia bila diwajibkan regulasi data kesehatan |
| **Notifikasi push** | Firebase Cloud Messaging | Tetap FCM (**gratis**, tidak perlu berbayar) | Tetap FCM; tambah WhatsApp untuk keluarga yang jarang membuka aplikasi (berbayar per pesan) |
| **OTP nomor HP** | Disimulasikan (kode tampil di layar) | OTP SMS/WhatsApp lewat penyedia (berbayar per pesan) | Sama |
| **Email** | Bawaan Supabase (kuota kecil), konfirmasi dimatikan | SMTP sendiri (penyedia email transaksional) + konfirmasi email wajib | Sama |
| **Pembayaran** | Disimulasikan | Payment gateway berizin (QRIS ± 0,7%, VA ± Rp4.000) | Langganan otomatis berulang |
| **Verifikasi keluarga** | Dokumen diperiksa manual oleh yayasan | Sama | e-KYC otomatis (cocokkan KTP & wajah ke data kependudukan, berbayar per pemeriksaan) |
| **Pencarian alamat** | Photon publik (gratis, kadang lambat) | Penyedia geocoding dengan API key (kuota gratis harian) | Photon/Nominatim di server sendiri |
| **Peta & satelit** | Ubin OpenStreetMap publik + citra Esri tanpa lisensi | Penyedia ubin peta berbayar + citra satelit berlisensi | Sama |
| **Panggilan 119** | Disimulasikan | Membuka panggilan telepon sungguhan (gratis) | Sama |
| **Distribusi aplikasi** | APK debug dipasang lewat kabel | Google Play (biaya daftar US$25 sekali) | + App Store (US$99/tahun) untuk iOS |
| **Pemantauan** | Log Supabase | Pelaporan error & crash aplikasi | Dashboard metrik layanan |

### Dari Gemini ke machine learning sendiri

1. **Sekarang:** Gemini membaca cerita dengan prompt + skema JSON; server memeriksa kutipan bukti dan menghapus nama/alamat.
2. **Mengumpulkan data berlabel tanpa biaya tambahan:** setiap kunjungan menyimpan **hasil AI (`ai_result`) dan
   hasil yang sudah dikoreksi relawan (`final_result`)** berdampingan. Setiap koreksi relawan = satu contoh latih.
   Pilot 300 lansia × 4 kunjungan × 12 bulan ≈ **14.000 cerita berlabel per tahun**.
3. **Melatih model sendiri:** model bahasa Indonesia kecil (mis. IndoBERT) di-*fine-tune* untuk 7 domain + 6 tanda
   bahaya, termasuk bahasa Jawa campuran. Keuntungan: **data kesehatan tidak keluar Indonesia** (lebih kuat untuk
   UU PDP), biaya per cerita mendekati nol, dan tidak bergantung pada kuota pihak lain.
4. **Dijalankan berdampingan:** model sendiri dipakai bila keyakinannya tinggi; Gemini menjadi cadangan untuk cerita
   yang sulit. Model diganti hanya bila **recall tanda bahaya tetap 100%** pada data uji.
5. **Jangka panjang:** dengan riwayat tren ribuan lansia, aturan status (baseline + turun 2 tingkat, dll.) bisa
   dilengkapi **model prediksi risiko penurunan** — tetap menampilkan alasan dan kutipan supaya bisa diperiksa manusia.
