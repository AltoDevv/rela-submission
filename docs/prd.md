# PRD — ReLa

**Konteks:** Hackathon JOINTS UGM 2026, tema Healthcare
**Sumber:** `temansenja-ide-v2.md` (revisi terbaru: rekap berbasis cerita, darurat di sisi relawan)
**Status:** Draf, menunggu persetujuan tim

---

## 1. North Star

> Mengubah kepedulian komunitas menjadi pendampingan lansia yang terorganisir, aman, dan bisa dipantau keluarga.

Komunitas sudah peduli dan punya relawan. Yang belum ada adalah sistem untuk mengatur, mencatat, dan menyampaikan apa yang mereka lihat kepada keluarga.

**Posisi:** ReLa adalah pendamping dan teman. ReLa bukan layanan kesehatan, dan relawan bukan tenaga kesehatan. Yang disampaikan ke keluarga adalah pengamatan, bukan diagnosis.

---

## 2. Masalah

- Lansia yang tinggal sendiri atau ditinggal anaknya merantau tidak punya orang yang melihat kondisinya secara langsung dan rutin.
- Keluarga hanya mengandalkan telepon. Jawaban "Ibu sehat" sering tidak sesuai kenyataan: obat habis, makan makin sedikit, atau makin sulit berjalan.
- Yayasan dan komunitas punya relawan, tetapi pengelolaannya masih manual lewat grup chat dan catatan kertas. Tidak ada pasangan tetap, laporan, maupun pantauan.
- Perawat lansia berbayar per jam, sehingga tidak terjangkau untuk pendampingan jangka panjang.
- Saat darurat, orang yang menolong sering tidak tahu riwayat penyakit lansia.

**Kaitan dengan subtema** (keluarga kesulitan memantau kondisi, kepatuhan obat, dan menjangkau bantuan, sehingga lansia berisiko memburuk tanpa terdeteksi):

| Bagian subtema | Jawaban ReLa |
|---|---|
| Memantau kondisi kesehatan | Rekap kunjungan yang langsung terlihat oleh keluarga |
| Kepatuhan pengobatan | Relawan menceritakan soal obat, lalu sistem mengategorikannya |
| Menjangkau bantuan sehari-hari | Relawan sebagai buddy rutin, ditambah tombol darurat di aplikasi relawan |
| Memburuk tanpa terdeteksi | Deteksi penurunan kondisi dari tren rekap kunjungan |

**Cara sekarang dan kelemahannya:**

| Cara | Kelemahan |
|---|---|
| Telepon keluarga | Hanya kabar lisan, tidak menggambarkan kondisi sebenarnya |
| Grup WhatsApp yayasan | Tidak ada pasangan tetap, rekap terstruktur, maupun pantauan keluarga |
| Perawat berbayar (Homecare24, RuangRawat) | Mahal untuk jangka panjang |
| Aplikasi caregiver keluarga (Carebuddy, Balas Kasih) | Tidak melibatkan yayasan dan relawan |

**Data pendukung:** lansia mencapai 11,97% penduduk Indonesia pada 2025 (BPS, SUPAS 2025).

---

## 3. Pengguna

Pengguna ditentukan berdasarkan situasi, bukan kelas ekonomi. Sasarannya adalah **lansia yang tinggal sendiri atau jauh dari anaknya**.

| Peran | Situasi | Kebutuhan utama di MVP |
|---|---|---|
| **Keluarga** | Anak yang merantau atau tinggal jauh dari orang tuanya | Mendaftarkan lansia, menerima atau menolak usulan relawan, melihat rekap dan status kondisi, menerima notifikasi darurat |
| **Yayasan** | Yayasan, rumah ibadah, atau komunitas yang punya relawan dan mengelolanya secara manual | Mengundang relawan, memverifikasi relawan tatap muka, memantau usulan pemasangan, memasangkan secara manual lansia yang sudah menolak 3 usulan, melihat lansia yang paling perlu perhatian, menerima notifikasi darurat |
| **Relawan** | Anggota komunitas yang menjadi *buddy* tetap seorang lansia, bukan tenaga kesehatan | Bergabung lewat undangan yayasan, diverifikasi tatap muka, bercerita tentang kunjungan tanpa harus menghafal skala, menekan tombol darurat saat bersama lansia |
| **Lansia** | Tinggal sendiri dan tidak terbiasa dengan aplikasi | Tidak ada fitur khusus di MVP (lihat Non-goals) |

---

## 4. Fitur MVP

MVP untuk demo hackathon terdiri dari **tiga alur yang harus benar-benar berjalan**, ditambah satu layar dashboard.

### Alur A: Pendaftaran dan pemasangan otomatis

**F1. Keluarga mendaftarkan lansia**
Sebagai keluarga, saya ingin mendaftarkan orang tua saya beserta Profil Kesehatan Ringkas, supaya relawan tahu apa yang perlu diperhatikan.
- Berhasil kalau keluarga dapat mengisi nama, alamat, kontak keluarga, kebutuhan, serta Profil Kesehatan Ringkas (kondisi atau penyakit, alergi, obat rutin dan jam minumnya, pantangan makanan, kemampuan bergerak dan alat bantu, dokter atau RS langganan, instruksi darurat), lalu menyimpannya.
- Berhasil kalau profil selalu menampilkan label *"Diisi oleh keluarga. Bukan diagnosis medis dan bukan rekam medis resmi."*

**F0. Platform memverifikasi yayasan**
Sebagai pengelola platform, saya ingin memastikan setiap yayasan benar-benar ada sebelum yayasan itu bisa mengirim relawan ke rumah lansia.
- Berhasil kalau yayasan dapat membuat akun, lalu statusnya menjadi **Menunggu verifikasi**.
- Berhasil kalau pengelola platform dapat menandai yayasan sebagai **Terverifikasi** setelah memeriksa dokumen legalitas atau surat dari pengurus rumah ibadah secara manual. Dokumen dikirim di luar aplikasi dan tidak disimpan. [ASUMSI]
- Berhasil kalau hanya yayasan Terverifikasi yang dapat mengundang relawan.
- Berhasil kalau ini menjadi satu-satunya verifikasi yang dilakukan platform. Verifikasi relawan sepenuhnya menjadi tanggung jawab yayasan.

**F1a. Relawan bergabung lewat undangan yayasan**
Sebagai relawan, saya ingin bergabung ke yayasan atau gereja saya dengan mudah, misalnya dari tautan yang dibagikan di grup WhatsApp.
- Berhasil kalau yayasan dapat membuat tautan atau kode undangan yang bisa disalin dan dibagikan ke grup WhatsApp.
- Berhasil kalau relawan dapat membuat akun dengan membuka tautan undangan, atau membuat akun sendiri lalu memasukkan kode undangan. Kedua cara ini sama-sama menghubungkan relawan ke yayasan pengundang. [ASUMSI: akun yang dibuat sendiri tetap perlu kode supaya terhubung ke yayasan]
- Berhasil kalau pendaftaran memverifikasi nomor HP dengan OTP.
- Berhasil kalau relawan mengisi profil: nama, area, hari tersedia, keahlian (mendampingi lansia dengan **demensia** dan dengan **mobilitas sulit**, ya/tidak), dan bahasa.
- Berhasil kalau foto wajah hanya bisa diambil langsung dari kamera aplikasi, bukan dipilih dari galeri.
- Berhasil kalau, setelah semua itu selesai, status relawan menjadi **Terdaftar**.
- Berhasil kalau relawan yang tidak terhubung ke yayasan tidak pernah bisa dipasangkan dengan lansia.

**F1b. Yayasan memverifikasi relawan secara tatap muka**
Sebagai pengurus yayasan, saya ingin mencatat bahwa saya sudah bertemu langsung dengan relawan dan memeriksa identitasnya, tanpa harus menyimpan dokumen apa pun.
- Berhasil kalau pengurus melihat daftar relawan berstatus Terdaftar di yayasannya beserta profil dan fotonya.
- Berhasil kalau pengurus dapat mencentang dua hal:
  - Identitas sudah dicek tatap muka
  - Sudah mengikuti orientasi singkat
- Berhasil kalau status relawan langsung menjadi **Aktif** setelah kedua centang terisi, sehingga relawan bisa langsung dipasangkan dengan lansia. [ASUMSI: keduanya wajib]
- Berhasil kalau aplikasi mencatat nama pengurus yang mencentang dan waktunya.
- Berhasil kalau setiap centang meminta **butir pemeriksaan** yang semuanya wajib dicentang (ditambahkan 15 Okt):
  - *Identitas:* wajah sama dengan foto aplikasi dan KTP asli; nama di aplikasi sama persis dengan KTP; **usia minimal 18 tahun**; nomor HP aktif (ditelepon saat bertemu); pengalaman ditanyakan bila mencentang keahlian demensia/mobilitas. **SKCK tidak diminta.**
  - *Orientasi:* bukan tenaga kesehatan (tidak memberi obat/diagnosis); tidak meminta/menerima uang atau barang; tidak membawa lansia keluar tanpa izin dan tidak memotret tanpa persetujuan; menjaga kerahasiaan; paham tanda bahaya dan alur Darurat; paham cerita kunjungan dan konfirmasi kunjungan pertama; tahu cara berhenti/minta ganti; sudah menandatangani perjanjian relawan dan kode etik.
- Berhasil kalau tidak ada tempat untuk mengunggah KTP atau dokumen lain.
- Berhasil kalau keahlian (demensia, mobilitas sulit) tetap ditampilkan dengan keterangan *"Diisi sendiri oleh relawan"*. [ASUMSI]

**F2. Sistem mengusulkan relawan secara otomatis**
Sebagai keluarga, saya ingin orang tua saya langsung mendapat usulan relawan yang paling cocok tanpa menunggu yayasan mencocokkan secara manual.
- Berhasil kalau, begitu lansia terdaftar, sistem langsung mengusulkan satu relawan tanpa campur tangan manusia.
- Berhasil kalau yang bisa diusulkan hanya relawan berstatus **Aktif** (F1b).
- Berhasil kalau, setelah usulan diterima keluarga, lansia ikut dipantau oleh yayasan tempat relawannya bergabung. [ASUMSI]
- Berhasil kalau lansia dengan **demensia** hanya diusulkan ke relawan yang tercatat mampu mendampingi lansia dengan demensia, dan lansia dengan **mobilitas sulit** hanya diusulkan ke relawan yang tercatat mampu membantu lansia dengan mobilitas sulit. Lansia yang punya keduanya hanya diusulkan ke relawan yang mampu menangani keduanya. Kondisi lain tidak menjadi syarat. [ASUMSI: syarat wajib, bukan sekadar nilai tambah]
- Berhasil kalau kedua kondisi tersebut diisi keluarga di F1 sebagai pilihan ya/tidak yang jelas, bukan disimpulkan dari teks bebas. [ASUMSI]
- Berhasil kalau, di antara relawan yang memenuhi syarat, sistem memilih yang paling dekat dengan alamat lansia. Bila jaraknya sama, relawan dengan beban paling sedikit didahulukan. Hari tersedia dan bahasa tidak dipakai sebagai kriteria pemasangan (diputuskan 2026-10-14), tetapi tetap ditampilkan di profil relawan pada F2a.
- Berhasil kalau relawan yang sudah mencapai batas beban maksimal tidak dipasangkan lagi. [ASUMSI: angka batasnya belum ditentukan]
- Berhasil kalau hasil pemasangan menampilkan alasannya dalam kalimat, misalnya *"Jarak 1,2 km · berpengalaman mendampingi lansia dengan demensia"*.
- Berhasil kalau agama tidak dipakai sebagai kriteria.
- Berhasil kalau, bila tidak ada relawan yang memenuhi syarat, lansia tercatat "tanpa pendamping" dan muncul di dashboard semua yayasan. [ASUMSI: uji awal hanya melibatkan satu yayasan, jadi aturan pembagiannya belum diperlukan]
- Berhasil kalau yayasan dapat melihat setiap usulan beserta alasannya, tetapi hanya melihat ringkasan kondisi lansia (misalnya "ada kondisi kronis"), tanpa detail profil kesehatan.

**F2a. Keluarga meninjau usulan relawan, lalu menerima atau menolak**
Sebagai keluarga, saya ingin melihat dulu siapa relawan yang diusulkan sebelum ia mulai berkunjung ke rumah orang tua saya.
- Berhasil kalau keluarga melihat profil relawan yang diusulkan: foto wajah (F1a), nama, yayasan asal, keahlian (demensia, mobilitas sulit), hari tersedia, bahasa, perkiraan jarak, alasan pemasangan, serta keterangan verifikasi (misalnya *"Identitas dicek tatap muka oleh pengurus Yayasan X"*). Nomor HP dan alamat relawan tidak ditampilkan.
- Berhasil kalau keluarga dapat menekan **Terima** atau **Tolak**.
- Berhasil kalau, setelah **Terima**, pasangan menjadi aktif dan baru setelah itu relawan dapat melihat lansia pasangannya.
- Berhasil kalau **Tolak** meminta keluarga memilih satu alasan (jarak terlalu jauh, jadwal tidak cocok, bahasa, atau lainnya disertai teks), lalu sistem langsung mencarikan usulan berikutnya.
- Berhasil kalau relawan yang sudah ditolak tidak diusulkan lagi untuk lansia yang sama.
- Berhasil kalau relawan tidak diberi tahu bahwa ia ditolak, dan alasan penolakan hanya bisa dilihat yayasan.
- Berhasil kalau keluarga mendapat **paling banyak 3 usulan**, artinya boleh menolak 2 kali. Setiap usulan menampilkan sisa kesempatan, misalnya *"Sisa 1 kali tolak"*.
- Berhasil kalau usulan ketiga **tidak bisa ditolak** (hanya tombol Terima); bila nanti kurang cocok, keluarga memakai jatah Minta ganti satu kali (F19). [Keputusan 2026-10-16; sebelumnya usulan ketiga yang ditolak diteruskan ke yayasan.]
- Berhasil kalau, saat relawan lepas (berhenti mendampingi, mengundurkan diri, dinonaktifkan, dilepas yayasan, atau menghapus akun), lansia langsung masuk pencocokan otomatis putaran baru (3 usulan, bisa dari yayasan lain, relawan lama tidak diusulkan lagi); dokumen keluarga yang sudah diverifikasi tetap berlaku. Bila tidak ada relawan yang cocok, lansia terlihat oleh semua yayasan untuk dipasangkan manual. [Keputusan 2026-10-16]
- Berhasil kalau, selama usulan belum dijawab, relawan tersebut dianggap "dipesan" dan tidak diusulkan ke lansia lain.

Semua angka dan ketentuan di F2a adalah [ASUMSI] yang ditetapkan untuk MVP. Alasannya:
- **3 usulan:** cukup memberi pilihan, tetapi tidak membuat relawan seperti barang yang bisa dipilih-pilih.
- **Alasan wajib dan dirahasiakan dari relawan:** membantu yayasan melihat pola penolakan tanpa melukai relawan, sejalan dengan prinsip "bukan rating publik" di ide 5.8.
- **Diteruskan ke yayasan, bukan ditolak terus:** penolakan berulang biasanya berarti ada kebutuhan yang belum tertangkap di pendaftaran, dan hal ini lebih baik dibicarakan langsung dengan keluarga.

### Alur B: Rekap cerita dan deteksi penurunan

**F3. Relawan bercerita tentang kunjungan**
Sebagai relawan, saya ingin cukup bercerita tentang kunjungan saya, tanpa harus menghafal arti angka 1–5.
- Berhasil kalau form rekap menampilkan tujuh pertanyaan terbuka: makan, obat, berjalan atau bergerak (termasuk ada jatuh atau tidak), mandi/berpakaian/ke toilet sendiri, ingatan dan obrolan, suasana hati, serta keluhan lain dan kegiatan hari itu.
- Berhasil kalau relawan dapat menjawab dengan mengetik atau merekam suara, dan rekaman suara berubah menjadi teks yang bisa disunting sebelum dikirim.
- Berhasil kalau relawan hanya bisa mengisi rekap untuk lansia pasangannya sendiri.
- **Navigasi relawan (keputusan 16 Okt):** Beranda menampilkan ringkasan jadwal tanpa pemilih kartu; rekap dan riwayat di Beranda mengikuti kunjungan berikutnya secara otomatis. Pengaturan/perubahan jadwal rutin dan geseran satu kunjungan berada di tab **Lansia**, mengikuti lansia pada dropdown. Tab ini menampilkan hari/jam rutin, waktu kunjungan berikutnya, atau status menunggu persetujuan/belum ada jadwal. Rekap umum di tab Riwayat tetap meminta pilihan lansia bila pasangan lebih dari satu.

**F4. Sistem mengubah cerita menjadi kategori, dengan bukti**
Sebagai relawan, saya ingin sistem yang menerjemahkan cerita saya ke kategori, supaya semua relawan dinilai dengan ukuran yang sama.
- Berhasil kalau setiap cerita menghasilkan kategori untuk tujuh domain sesuai rubrik:

  | Domain | Kategori (baik → buruk) |
  |---|---|
  | Nafsu makan | Baik → Berkurang → Sangat sedikit → Tidak makan |
  | Obat | Teratur → Kadang terlewat → Sering terlewat → Habis atau berhenti |
  | Mobilitas | Mandiri → Pelan atau perlu pegangan → Perlu dibantu → Tidak bisa bangun |
  | Kemandirian harian | Mandiri → Butuh sedikit bantuan → Butuh banyak bantuan → Bergantung penuh |
  | Daya ingat | Seperti biasa → Agak pelupa → Bingung → Bingung mendadak |
  | Suasana hati | Ceria → Biasa → Murung → Menarik diri |
  | Kondisi umum | Sehat → Kurang fit → Tampak lemah → Tampak sakit berat |

- Berhasil kalau setiap kategori yang terisi disertai kalimat bukti yang benar-benar ada di cerita relawan.
- Berhasil kalau domain yang tidak diceritakan tercatat sebagai "tidak disebut", bukan dianggap baik.
- Berhasil kalau tanda bahaya ikut terdeteksi: jatuh, bingung mendadak, sesak atau nyeri dada, tidak makan sama sekali, obat habis, dan keluhan baru.
- Berhasil kalau teks yang dikirim ke model bahasa tidak memuat nama dan alamat lansia.
- Berhasil kalau hasilnya muncul dalam beberapa detik setelah cerita dikirim. [ASUMSI: "beberapa detik" dari skenario demo; batas angkanya belum ditentukan]

**F5. Relawan mengonfirmasi ringkasan**
- Berhasil kalau, setelah mengirim, relawan melihat ringkasan singkat (misalnya *"Nafsu makan: Berkurang · Mobilitas: Perlu pegangan"*), dapat mengoreksi kategori yang salah, lalu menyimpannya.
- Berhasil kalau koreksi relawan disimpan berdampingan dengan hasil asli AI, sehingga bisa dipakai sebagai data berlabel.

**F6. Status kondisi lansia**
Sebagai keluarga dan yayasan, kami ingin tahu kapan kondisi lansia berubah, supaya bisa bertindak sebelum terjadi darurat.
- Berhasil kalau setiap lansia memiliki status **Stabil**, **Perlu perhatian**, atau **Segera dikabari**.
- Berhasil kalau tanda bahaya pada rekap terbaru langsung mengubah status menjadi **Segera dikabari**.
- Berhasil kalau status **Perlu perhatian** muncul bila dibanding kebiasaan (baseline) lansia itu sendiri terjadi salah satu kondisi berikut:
  - sebuah domain turun 2 tingkat atau lebih,
  - sebuah domain turun tiga kunjungan berturut-turut,
  - obat "kadang" atau "sering terlewat" pada 2 dari 3 kunjungan terakhir,
  - ada kemampuan harian yang baru hilang.
- Berhasil kalau baseline setiap domain adalah kategori yang paling sering muncul pada 3 kunjungan pertama yang sudah dikonfirmasi relawan. Sebelum ada 3 kunjungan, hanya tanda bahaya yang bisa mengubah status.
- Berhasil kalau kondisi buruk yang memang sudah menjadi baseline (misalnya daya ingat pada lansia dengan demensia) tidak memicu status.
- Berhasil kalau setiap status selain Stabil disertai alasan yang mengutip kalimat relawan, serta saran umum (menelepon lansia, mengisi ulang obat, atau memeriksakan ke puskesmas atau dokter langganan) dan pernyataan bahwa ini bukan diagnosis.
- Berhasil kalau, begitu status berubah menjadi **Segera dikabari**, HP keluarga dan pengurus yayasan menerima push notification, tanpa harus membuka aplikasi.

**F7. Keluarga melihat rekap, tren, dan status**
- Berhasil kalau rekap, kategori, dan status muncul di halaman keluarga begitu relawan menyimpannya.
- Berhasil kalau halaman keluarga menampilkan grafik tren per domain dari seluruh kunjungan.

**Skenario demo Alur B:** sudah tersedia enam cerita kunjungan Ibu Sri yang perlahan menurun. Relawan mengetik atau merekam cerita ketujuh secara langsung, lalu ringkasan kategori dan kalimat buktinya muncul, grafik tren bergeser, dan status berubah menjadi "Perlu perhatian" dengan alasan yang mengutip tulisan relawan. Cerita yang menyebut "terpeleset di kamar mandi" mengubah status menjadi "Segera dikabari".

### Alur C: Darurat saat kunjungan

**F8. Relawan menekan tombol Darurat**
Sebagai relawan yang sedang bersama lansia, saya ingin memanggil bantuan dan mengabari keluarga dengan sekali tindakan.
- Berhasil kalau tombol **Darurat** di aplikasi relawan meminta konfirmasi terlebih dahulu, dan tidak terjadi apa-apa bila konfirmasi dibatalkan.
- Berhasil kalau, setelah dikonfirmasi, panggilan ke 119 disimulasikan dan layar relawan menampilkan Profil Kesehatan Ringkas lansia yang siap dibacakan ke operator.
- Berhasil kalau, bersamaan dengan itu, HP keluarga dan yayasan menerima notifikasi berisi lokasi dan ringkasan kejadian.
- Berhasil kalau kejadian tersebut tercatat di riwayat lansia.
- Berhasil kalau aplikasi meminta izin notifikasi kepada keluarga dan pengurus yayasan setelah login, dan bila izin ditolak, aplikasi menampilkan pengingat bahwa notifikasi darurat tidak akan muncul.

### Pendukung

**F9. Dashboard yayasan (satu layar)**
- Berhasil kalau satu layar menampilkan daftar lansia yang diurutkan dari status paling mendesak (Segera dikabari → Perlu perhatian → Stabil), jumlah lansia yang didampingi, jumlah lansia tanpa pendamping, lansia berstatus "Perlu ditangani yayasan" (F2a), dan beban tiap relawan. [ASUMSI: subset dari daftar di ide 5.9]

**Data demo:** satu yayasan sudah terverifikasi platform, dan beberapa relawan sudah berstatus Aktif supaya pemasangan punya pilihan. Saat demo, satu relawan baru bergabung lewat tautan undangan lalu diverifikasi. [ASUMSI]

---

### Prioritas pengerjaan

Dengan sisa waktu sekitar 1,5 hari dan 4 orang, tidak semua fitur bisa dibangun penuh. Urutan berikut menentukan apa yang dikerjakan lebih dulu. Seluruh pembagian ini adalah [ASUMSI] dan perlu disetujui tim.

| Prioritas | Fitur | Perlakuan |
|---|---|---|
| **P1: inti pitch, wajib jalan langsung** | F4, F5, F6, F7 (rekap cerita → kategori dan bukti → status → tren) | Dibangun penuh. Ini pembeda utama ReLa. |
| | F3 | Input dengan mengetik. Rekam suara dikerjakan bila sempat. |
| | F1, F2, F2a | Dibangun penuh, tetapi formnya ringkas. |
| | F8 | Dibangun penuh. Notifikasi berupa push notification langsung dari aplikasi (Firebase Cloud Messaging). WhatsApp tidak dipakai karena templatenya tidak mungkin disetujui dalam 1,5 hari. |
| **P2: dibangun sederhana** | F1b, F9 | Checklist dua centang, dashboard satu layar. |
| | F1a | Tautan undangan dan foto dari kamera dibangun. OTP disimulasikan (kode tampil di layar). |
| **P3: data awal saja** | F0 | Yayasan langsung tersedia sebagai Terverifikasi. Tidak ada halaman pengelola platform. |

Kalau waktu sangat mepet, urutan pemangkasan berikutnya adalah: rekam suara, lalu animasi grafik, lalu batas 3 usulan di F2a (diganti terima/tolak tanpa batas).

### Fitur tambahan setelah MVP (14–15 Okt)
Rincian dan alasannya ada di Riwayat Perubahan dan Log keputusan arsitektur.

| ID | Fitur | Inti |
|---|---|---|
| F10 | Siklus hidup pendampingan | Relawan berhenti, keluarga minta ganti, yayasan melepas; akhiri/aktifkan kembali; ubah data & profil kesehatan; koreksi kunjungan terakhir; hapus data lansia; hapus akun |
| F11 | Keluarga & persetujuan | Beberapa anggota keluarga (undangan diterima); persetujuan lansia/wali; Syarat & Persetujuan saat daftar dan saat masuk |
| F12 | Verifikasi keluarga/lansia | KTP keluarga, KTP lansia, KK/surat RT-RW diperiksa online oleh yayasan relawan; kontak lengkap relawan setelah verifikasi; kunjungan pertama memastikan lansia ada & setuju |
| F13 | Langganan per lansia per bulan | Simulasi bayar, perpanjang, riwayat, pengingat, tenggang 7 hari |
| F14 | Masukan keluarga untuk relawan | Apresiasi / perlu diperbaiki / masalah serius; yayasan menindaklanjuti |
| F15 | Pengawasan & pengingat | Koreksi AI oleh relawan tercatat dan terlihat; pengingat >7 hari tanpa kunjungan; tanda "sudah ditangani"; usulan kedaluwarsa 48 jam |
| F16 | Pemilih lokasi peta | Cari tempat (OpenStreetMap), geser pin, satelit, lokasi HP |
| F17 | Verifikasi relawan terstandar | Relawan memilih yayasan dari daftar lalu apply; datang tatap muka; pengurus mengisi butir pemeriksaan wajib (KTP asli, nama sama, usia ≥ 18, HP aktif, kode etik; tanpa SKCK) lalu menampilkan **kode sekali pakai 6 digit (2 menit, seperti authenticator)**; relawan memasukkannya → Aktif. Yayasan bisa **menonaktifkan** relawan dengan alasan |
| F19 | Ganti pendamping oleh keluarga | Wajib alasan (jadwal / kurang cocok / perlu diperbaiki / masalah serius), **maks. 1× per lansia (selamanya; keputusan 16 Okt, sebelumnya 1× per 30 hari)**; pengganti lewat **pencocokan otomatis** (bisa dari yayasan lain, relawan lama tidak diusulkan lagi); relawan lama diberi tahu secara netral, yayasannya membaca alasan; jatah habis → masalah serius lewat laporan ke yayasan |
| F18 | Permintaan berhenti relawan | Relawan mengajukan berhenti dari seorang lansia dengan alasan; tetap pendamping sampai yayasan menerima (tidak bisa ditolak) atau otomatis setelah 7 hari; lalu yayasan langsung memasangkan pengganti |

## 5. Non-goals

### Ditunda dari MVP (masuk pengembangan setelah hackathon)
- ~~Persetujuan lansia pada kunjungan pertama dan pembatasan profil sebelum persetujuan~~ **Dikerjakan 15 Okt** (relawan memastikan lansia ada & setuju; kunjungan diblokir sebelum itu).
- Pencocokan sebagai optimasi penugasan global yang menata ulang seluruh pasangan sekaligus. Di MVP, setiap lansia dipasangkan saat mendaftar. [ASUMSI]
- Deteksi lapis ketiga: model bahasa yang membandingkan cerita hari ini dengan cerita kunjungan sebelumnya [ASUMSI: ditunda karena tidak disebut di skenario demo]
- Permintaan detail tambahan otomatis bila jawaban relawan terlalu pendek [ASUMSI]
- Pertanyaan rekap yang menyesuaikan kondisi lansia
- Check-in kunjungan dengan waktu dan lokasi
- Jadwal kunjungan
- Halaman lansia (tombol Telepon Keluarga, tombol Telepon 119, serta info dan foto relawan yang akan datang) [ASUMSI: tidak disebut di MVP ide]
- ~~Masukan privat dari keluarga~~ **Dikerjakan 15 Okt** (F14: 3 kategori; permintaan ganti pendamping juga sudah ada).
- ~~Peringatan otomatis untuk relawan yang jarang berkunjung~~ **Dikerjakan 15 Okt** (push harian bila >7 hari tanpa kunjungan).
- Catatan akses setiap pembukaan profil
- Pembayaran sungguhan lewat payment gateway dan pengelolaan dana operasional relawan (langganan per lansia **disimulasikan** sejak 15 Okt, F13)
- Pengingat pembaruan profil setiap 3 bulan
- ~~Batas waktu menjawab usulan 48 jam~~ **Dikerjakan 15 Okt** (usulan kedaluwarsa, tidak dihitung penolakan).
- Kartu Darurat dan tombol darurat di sisi lansia, bila nanti uji lapangan menunjukkan kebutuhannya

### Sengaja tidak akan pernah dikerjakan
- Check-in harian dan eskalasi otomatis saat tidak ada kabar
- Relawan memegang kunci rumah
- Panggilan ambulans otomatis. Panggilan darurat selalu dipicu oleh orang.
- Tombol darurat yang diproses sistem di sisi lansia (setidaknya untuk versi ini)
- Telepon sapa antar kunjungan di dalam sistem
- Layanan medis apa pun: memberi obat, tindakan medis, atau diagnosis
- Penyimpanan hasil lab, diagnosis rinci, dokumen medis, atau dokumen identitas dan SKCK relawan (dokumen keluarga untuk verifikasi F12 hanya sementara: dihapus setelah diperiksa)
- Penanganan lansia yang tumbang saat sendirian. Hal ini dinyatakan sebagai batasan versi ini.

---

## 6. Metrik Sukses

**Untuk hackathon:**
- Ketiga alur (A, B, C) berjalan dari awal sampai akhir saat demo langsung, dan hanya panggilan 119 yang disimulasikan. [ASUMSI]
- Akurasi ekstraksi kategori diukur dengan 30–50 contoh cerita berlabel manual, termasuk bahasa santai dan daerah (misalnya "ora doyan mangan"). Angkanya dicantumkan di pitch. Target akurasi belum ditentukan.

**Untuk produk (uji awal: satu yayasan di satu kecamatan):**
- Persentase kunjungan yang terlaksana dibanding yang terjadwal
- Jumlah tanda "Perlu perhatian" yang ditindaklanjuti keluarga
- Waktu dari munculnya tanda sampai ada tindak lanjut
- Retensi relawan

---

## 7. Batasan dan Preferensi

- **Event:** Hackathon JOINTS UGM 2026. Deadline **15 Oktober 2026 pukul 23.50**, dikerjakan oleh **4 orang**. Waktu pengerjaan tersisa sekitar 1,5 hari sejak PRD ini ditulis (14 Oktober).
- **Aturan lomba:** semua penggunaan AI, baik di dalam produk maupun dalam proses pengerjaan, wajib dicantumkan di pitch deck.
- **Regulasi:** data kesehatan tergolong data pribadi sensitif menurut UU No. 27 Tahun 2022 (PDP).
- **Kejujuran teknis:** data uji akurasi dibuat oleh tim. Evaluasi dengan cerita nyata adalah langkah berikutnya, dan pitch tidak boleh mengklaim lebih dari itu.
- **Preferensi teknologi** (dicatat saja, keputusan di `/architecture`): web responsif (Next.js), Supabase atau FastAPI dengan PostgreSQL, WhatsApp Cloud API dengan bot Telegram sebagai cadangan (template pesan WhatsApp perlu diajukan lebih awal), speech-to-text, model bahasa dengan keluaran JSON terstruktur, dan algoritma penugasan.
- **Model bisnis** (tidak dibangun di MVP): keluarga membayar biaya layanan bulanan, 50% untuk operasional relawan di yayasan dan 50% untuk platform, ditambah CSR bagi keluarga kurang mampu.

---

## 8. Pertanyaan Terbuka

Dibawa dari bagian 16 dokumen ide:
- [ ] Ambang tren pada F6 perlu dikonsultasikan dengan tenaga kesehatan
- [ ] Finalisasi rubrik kategori dan penyusunan 30–50 contoh cerita berlabel
- [ ] Layanan model bahasa dan speech-to-text yang dipakai, termasuk biaya dan kebijakan datanya (dibahas di `/architecture`)
- [ ] Bobot awal tiap kriteria pencocokan (F2)
- [ ] Bolehkah relawan bergabung ke lebih dari satu yayasan? (F1a)
- [ ] Apa batasan "mobilitas sulit": perlu alat bantu, perlu dibantu berpindah, atau terbaring? (F1, F2)
- [ ] Batas beban maksimal per relawan (F2)
- [ ] Apakah batas 3 usulan (2 kali tolak) dan daftar alasan penolakan sudah sesuai? (F2a)
- [ ] Rasio pendamping: 1 relawan untuk 1 lansia, atau tim 2–3 relawan dengan satu pendamping utama
- [ ] Frekuensi kunjungan minimal
- [ ] Apakah "antar kontrol" dan "perbaikan rumah" termasuk tugas relawan
- [ ] Bekal pelatihan relawan, misalnya "SeGeRa Ke RS"
- [ ] Besaran biaya layanan bulanan, dan apakah 50% cukup untuk transport relawan
- [ ] Data persentase lansia yang tinggal sendiri (BPS) dan kutipan wawancara dengan 2–3 yayasan
- [ ] Ketersediaan nama "ReLa"

Baru:
- [x] Kanal notifikasi darurat untuk demo: push notification dari aplikasi (diputuskan 2026-10-14)
- [ ] Berapa target akurasi ekstraksi yang dianggap cukup?
- [ ] Berapa kunjungan minimal sebelum baseline dianggap sah?

---

## Riwayat Perubahan

| Tanggal | Perubahan |
|---|---|
| 2026-10-14 | Draf pertama disusun dari `temansenja-ide-v2.md` |
| 2026-10-14 | Revisi mengikuti ide terbaru. Rekap diganti dari skala 1–5 menjadi cerita (ketik atau suara) yang diekstraksi AI ke rubrik 7 domain dengan kalimat bukti, ditambah konfirmasi relawan (F3–F5). Deteksi kini memakai 3 status dan aturan baseline pribadi (F6), plus grafik tren (F7). Darurat dipindah ke aplikasi relawan dengan notifikasi ke keluarga dan yayasan (F8). Tombol darurat lansia, Kartu Darurat, dan QR dihapus. Dashboard diurutkan berdasarkan status. Analisis model bahasa tidak lagi ditunda. Lapis ketiga deteksi dan halaman lansia ditunda. Metrik akurasi ekstraksi ditambahkan. |
| 2026-10-14 | F2: pemasangan relawan dengan lansia kini otomatis oleh sistem, bukan dipilih yayasan. Pemasangan memprioritaskan jarak terdekat, dan kemampuan relawan menangani kondisi tertentu (misalnya demensia) menjadi syarat. Ini menggantikan prinsip "yayasan yang memutuskan" di ide 5.4. |
| 2026-10-14 | F2 kini berupa usulan. F2a baru: keluarga melihat profil relawan lalu menerima atau menolak, paling banyak 3 usulan (2 kali tolak) dengan alasan wajib yang dirahasiakan dari relawan. Setelah 3 kali ditolak, lansia diteruskan ke yayasan untuk dipasangkan manual. Relawan baru melihat lansia setelah usulan diterima. Hak yayasan untuk mengganti pasangan sesuka hati dihapus. |
| 2026-10-14 | F2: kondisi yang mewajibkan relawan berkemampuan khusus ditetapkan, yaitu demensia dan mobilitas sulit. |
| 2026-10-14 | F1a dan F1b baru: relawan membuat akun dan mengisi data sendiri (termasuk kemampuan demensia dan mobilitas sulit), mengajukan bergabung ke yayasan, lalu yayasan menerima atau menolak. Hanya relawan Diterima yang bisa diusulkan ke lansia. Verifikasi relawan oleh yayasan tidak lagi ditunda, tetapi SKCK dan verifikasi yayasan tetap ditunda. |
| 2026-10-14 | Alur verifikasi diganti. F0 baru: platform memverifikasi yayasan secara manual, dan ini satu-satunya verifikasi oleh platform. F1a: relawan bergabung lewat tautan atau kode undangan yayasan, dengan OTP dan foto wajah dari kamera. F1b: yayasan memverifikasi tatap muka lewat tiga centang (identitas, SKCK dan masa berlakunya, orientasi), dan aplikasi mencatat siapa yang memverifikasi dan kapan. F1c baru: status Terdaftar → Terverifikasi → Aktif, dan hanya relawan Aktif yang bisa dipasangkan dengan lansia. Status Diterima/Ditolak dihapus. |
| 2026-10-14 | Ralat verifikasi relawan: SKCK tidak dipakai, dan centang di F1b tinggal dua (identitas tatap muka, orientasi). Relawan langsung **Aktif** begitu diverifikasi yayasan, tanpa kunjungan pertama yang didampingi. F1c dihapus, sehingga status relawan menjadi Terdaftar → Aktif. |
| 2026-10-14 | Batasan dicatat: deadline 15 Oktober 2026 pukul 23.50, tim 4 orang. Bagian "Prioritas pengerjaan" ditambahkan (P1/P2/P3). |
| 2026-10-14 | F8: notifikasi darurat (dan status "Segera dikabari") dikirim sebagai push notification langsung dari aplikasi lewat Firebase Cloud Messaging, menggantikan Telegram. |
| 2026-10-14 | Keputusan T-001: F2 tidak memakai hari tersedia dan bahasa sebagai kriteria (jarak, lalu beban). F6: baseline = kategori tersering pada 3 kunjungan pertama yang dikonfirmasi, dan status "Segera dikabari" mengirim push notification. F8: aplikasi meminta izin notifikasi setelah login. |
| 2026-10-15 | Siklus hidup setelah pemasangan (dari kritik alur): relawan bisa **berhenti mendampingi**, keluarga bisa **minta ganti pendamping**, yayasan bisa **melepas pendamping** dan **menonaktifkan relawan** (cabut centang) — lansia diteruskan ke yayasan (perlu_yayasan) untuk dipasangkan ulang. Keluarga bisa **mengubah data lansia dan profil kesehatan**; bila kebutuhan demensia/mobilitas berubah dan relawan tidak mampu, lansia otomatis diteruskan ke yayasan. Keahlian yang ditambah relawan sendiri harus diverifikasi ulang. Relawan bisa **mengoreksi kunjungan terakhir** (status dihitung ulang). Status **"Pendampingan selesai"** (meninggal/pindah/tidak butuh/lainnya). **Beberapa anggota keluarga** per lansia (keputusan usulan tetap pendaftar). **Hapus akun** beserta data (UU PDP). **"Kunjungan terakhir: X hari lalu"** di halaman keluarga dan dashboard. Token push dihapus saat Keluar. |
| 2026-10-15 | Pengerasan dari serangan menyeluruh: lansia yang pernah punya yayasan hanya terlihat oleh yayasannya; nama relawan terverifikasi tidak bisa diganti sendiri, foto baru → verifikasi ulang; status nomor HP terverifikasi hanya dari server; anggota keluarga harus **menerima undangan**; "Akhiri pendampingan" khusus pendaftar/yayasan dan bisa **diaktifkan kembali**; pendaftar hapus akun → kepemilikan pindah ke anggota; Darurat berulang dalam 2 menit tidak digandakan; satu panggilan Gemini per kunjungan; notifikasi ke **banyak perangkat** per akun; tombol **"Tandai sudah ditangani"**; usulan tidak dijawab **48 jam kedaluwarsa** (bukan penolakan); pengurus bisa **menambah pengurus**; relawan bisa **mengubah profil** (hari, bahasa, keahlian). |
| 2026-10-15 | **Persetujuan lansia**: saat mendaftarkan lansia keluarga wajib memilih "lansia sudah setuju" atau "saya walinya" (dicatat siapa dan kapan oleh server); saat daftar akun wajib menyetujui **Syarat & Persetujuan** yang menyebut pemrosesan data di luar Indonesia (Supabase Singapura, Google Gemini, Firebase). **Relawan bisa mencabut tanda bahaya yang keliru dan menambah yang terlewat** di layar konfirmasi (F5), sehingga alarm ke keluarga sudah disaring manusia. |
| 2026-10-15 | Evaluasi E1–E8 dan serangan lanjutan: koreksi relawan yang menurunkan penilaian AI wajib beralasan dan terlihat keluarga & yayasan; undangan pengurus harus diterima; satu kunjungan terkonfirmasi per hari (maks. 3 cerita); **pengingat** bila >7 hari tanpa kunjungan; **pemilih lokasi peta** (OpenStreetMap, pin digeser, satelit); yayasan tidak membaca cerita kunjungan lengkap; **hapus data lansia** oleh pendaftar. |
| 2026-10-15 | **Langganan + verifikasi keluarga/lansia** (keputusan pengguna, serangan K1/K5: akun keluarga palsu bisa memanen data relawan dan membuat lansia umpan). (1) **Langganan per lansia per bulan** wajib sebelum relawan dicarikan; pembayaran disimulasikan untuk demo. (2) Keluarga mengunggah **KTP, swafoto memegang KTP, KTP lansia, Kartu Keluarga / surat RT-RW**; diperiksa **online oleh pengurus yayasan relawan yang diterima** (relawan tetap diverifikasi tatap muka); dokumen dihapus setelah diputuskan. (3) Seperti Gojek: kartu usulan hanya nama, foto, yayasan, keahlian, jarak dibulatkan km; **nama lengkap, nomor HP, dan kendaraan relawan** terlihat setelah diterima dan terverifikasi. (4) Relawan baru boleh berkunjung setelah terverifikasi; pada **kunjungan pertama** relawan memastikan lansia ada dan setuju. (5) Maks. 3 lansia per akun. Ditunda sampai produksi: konfirmasi email (K2) dan aturan kata sandi (K3). |
| 2026-10-15 | Penyederhanaan (keputusan pengguna): dokumen verifikasi keluarga cukup **KTP keluarga, KTP lansia, dan Kartu Keluarga / surat RT-RW** (tanpa swafoto memegang KTP); **data kendaraan/plat nomor relawan tidak dikumpulkan** — setelah verifikasi keluarga melihat nama lengkap dan nomor HP relawan. |
| 2026-10-15 | F1b: **butir pemeriksaan wajib** di balik dua centang verifikasi relawan (identitas: KTP asli, nama sama, usia ≥ 18, HP aktif, pengalaman keahlian; orientasi: kode etik, kerahasiaan, Darurat, kunjungan pertama, perjanjian relawan). Tanpa SKCK (keputusan pengguna). |
| 2026-10-15 | **Masukan keluarga untuk relawan** (bukan bintang): 3 kategori — *Terima kasih/apresiasi* (relawan + yayasan), *Perlu diperbaiki* (hanya yayasan), *Masalah serius* (hanya yayasan, push langsung, relawan tidak membaca). Ajakan sekitar sebulan sekali, bisa kapan saja dari menu, ulasan penutup saat ganti/akhiri pendampingan; masukan biasa maks. 1/minggu per orang per lansia, laporan serius tidak dibatasi. Yayasan melihat ringkasan per relawan dan menandai "ditangani" dengan catatan yang terlihat keluarga; masukan tidak dipakai otomatis untuk pemasangan. **Langganan**: kartu status + perpanjang + riwayat pembayaran di detail lansia, pengingat 3 hari sebelum dan saat berakhir, masa tenggang 7 hari lalu kunjungan diblokir. |
| 2026-10-15 | **Alur relawan baru** (keputusan pengguna): apply ke yayasan dari daftar (tautan undangan tetap memilihkan), verifikasi tatap muka dengan **kode sekali pakai** yang ditampilkan pengurus dan dimasukkan relawan (centang langsung tidak bisa lagi), yayasan bisa **menonaktifkan** relawan, relawan **berhenti lewat permintaan** ke yayasan (otomatis diterima 7 hari, tidak bisa ditolak). |
| 2026-10-15 | **Nama aplikasi menjadi ReLa** (Relawan Lansia) dengan logo baru; sebelumnya TemanSenja. Fokus subtema dipertajam ke **deteksi dini penurunan kondisi lansia yang tinggal sendiri** (lihat `docs/ringkasan-proyek.md`). |
| 2026-10-15 | **Ganti pendamping** (keputusan pengguna): satu lansia satu relawan; keluarga boleh ganti maks. 1× per 30 hari dengan alasan, pengganti otomatis lewat pencocokan (putaran 3 usulan baru), relawan baru wajib konfirmasi kunjungan pertama lagi; setelah jatah habis, masalah serius lewat laporan ke yayasan. |
