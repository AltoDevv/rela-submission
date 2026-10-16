# Memasang dan mencoba ReLa

ReLa adalah prototype untuk Android 7.0 atau lebih baru. Unduh
[ReLa.apk terbaru](https://github.com/AltoDevv/rela-submission/releases/latest/download/ReLa.apk)
atau buka [rilis terbaru](https://github.com/AltoDevv/rela-submission/releases/latest). Versi pengumpulan saat ini **1.0.1**.
Source code: [repository pengumpulan ReLa](https://github.com/AltoDevv/rela-submission).
Tautan perlu diuji tanpa login setelah rilis diterbitkan sebelum diserahkan kepada juri.

## Instalasi di HP baru

1. Buka tautan unduh melalui browser HP, lalu unduh file `.apk` sampai selesai.
2. Buka file dari Unduhan. Jika Android meminta izin, izinkan pemasangan aplikasi dari browser/pengelola berkas
   yang dipakai, lalu tekan **Instal**. Izin ini dapat dimatikan lagi setelah instalasi selesai.
3. Buka **ReLa**, pastikan internet aktif, dan masuk menggunakan akun demo di bawah.
4. Izin notifikasi diperlukan agar pemberitahuan bisa muncul. Kamera dipakai saat pendaftaran relawan/foto,
   mikrofon untuk dikte, dan lokasi untuk peta/Darurat; izin diminta saat fiturnya digunakan.

Jika sebelumnya sudah memasang ReLa dari tim, coba perbarui langsung. Bila Android melaporkan tanda tangan
tidak cocok, hubungi tim untuk APK dengan signing yang sesuai; jangan menghapus aplikasi tanpa menyadari bahwa
data lokal/sesi akan ikut hilang. Data server tetap dikelola oleh akun masing-masing.

## Akun demo

Password ketiganya: **`demo1234`**.

| Peran | Email | Yang bisa dilihat |
|---|---|---|
| Keluarga | `keluarga1@demo.id` | Lansia demo, status, riwayat/grafik, pendamping, profil |
| Relawan | `relawan1@demo.id` | Kartu kunjungan, profil lansia pasangan, rekap, riwayat, Darurat |
| Yayasan | `pengurus@demo.id` | Dashboard, relawan, verifikasi, usulan/tindak lanjut, ulasan |

Akun demo dipakai bersama dan berisi data fiktif. Gunakan akun demo terlebih dahulu agar tidak perlu melalui
verifikasi relawan/keluarga. Pembuatan akun baru tetap tersedia untuk Keluarga dan Relawan; aktivasi relawan
memerlukan proses verifikasi oleh yayasan. Akun yayasan disiapkan tim, bukan didaftarkan dari form publik.

## Uji singkat

- Keluarga: pilih Ibu Sri, buka Riwayat, lihat grafik, lalu ganti kategori.
- Relawan: **Lansia** → pilih lansia dari dropdown → lihat jadwal kunjungan. **Atur/Ubah jadwal** mengirim
  usulan rutin untuk disetujui keluarga; **Geser kunjungan** mengubah satu kunjungan dan memberi tahu keluarga.
- Beranda relawan menampilkan titik dan garis timeline. Kunjungan berikutnya dipilih otomatis; kartu bukan
  pemilih lansia. **Rekap Kunjungan** langsung untuk lansia pada kunjungan tersebut. **Tampilkan** membuka
  tab Lansia untuk melihat detail dan tidak mengganti target otomatis Beranda.
- Riwayat relawan → Rekap Kunjungan: bila lebih dari satu pasangan, pilih lansia dahulu.
- Kembali/keluar dari form tanpa menyimpan jika hanya ingin melihat tampilan. Penyimpanan rekap mengubah data
  demo bersama. Satu kunjungan terkonfirmasi per hari dibatasi server.
- Darurat meminta konfirmasi. Jangan mengonfirmasi jika hanya ingin melihat tombol: tindakan yang dikonfirmasi
  mencatat kejadian dan mengirim pemberitahuan ke akun demo lain. Panggilan 119 sendiri disimulasikan.

Jika daftar kosong pada akun baru, itu berarti belum ada pasangan; gunakan akun demo untuk meninjau alur lengkap.
Jika jadwal kosong pada data demo lama, buka **Lansia → pilih lansia → Atur jadwal**, lalu setujui dari akun
keluarga. Rekap umum tetap bisa dibuka dari tab Riwayat saat belum ada jadwal Beranda.

## Mencoba di dua HP

Gunakan akun keluarga pada HP pertama dan relawan yang mendampingi lansia tersebut pada HP kedua.
Keduanya perlu internet. Rekap yang sudah disimpan bisa dilihat pada akun keluarga terkait; detail lansia
keluarga menerima pembaruan Realtime. Beberapa halaman relawan perlu dibuka ulang agar memuat data terbaru.

## Kondisi distribusi

APK adalah build rilis untuk prototype, dengan signing debug lokal yang sama dengan aplikasi uji tim.
Pemasangan tidak memerlukan Flutter, Android Studio, atau akun Google Play. Backend Supabase/Firebase tetap
diperlukan dan harus dijaga aktif oleh tim selama penilaian. ReLa belum menyediakan versi iPhone.

Sebelum dikumpulkan, tim harus menguji unduhan tanpa login dan pemasangan di HP baru, lalu memastikan akun demo
bisa masuk. Pemeriksaan berkas APK saja belum membuktikan bahwa tautan unggah publik atau login di HP baru bekerja.
