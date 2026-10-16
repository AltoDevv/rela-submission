import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widgets.dart' show LogoutButton;

/// Syarat & Persetujuan yang disetujui saat daftar akun dan saat mendaftarkan lansia (UU PDP).
/// ponytail: teks ringkas untuk MVP; perlu ditinjau ahli hukum sebelum dipakai di lapangan.
const termsSections = <(String, String)>[
  (
    'Apa itu ReLa',
    'ReLa menghubungkan lansia dengan relawan dari yayasan atau komunitas untuk pendampingan rutin. '
        'ReLa bukan layanan kesehatan. Relawan bukan tenaga kesehatan, dan status yang ditampilkan adalah '
        'ringkasan pengamatan relawan, bukan diagnosis.',
  ),
  (
    'Persetujuan lansia',
    'Keluarga yang mendaftarkan lansia menyatakan bahwa lansia sudah dijelaskan tentang layanan ini dan setuju '
        'datanya dipakai. Bila lansia tidak mampu memberi persetujuan (misalnya karena demensia), keluarga bertindak '
        'sebagai walinya. Relawan memastikan kembali kesediaan lansia saat kunjungan pertama.',
  ),
  (
    'Langganan dan verifikasi keluarga',
    'Setiap lansia memerlukan langganan bulanan sebelum relawan dicarikan. Untuk keamanan relawan yang datang ke '
        'rumah, keluarga mengunggah KTP, KTP lansia, dan Kartu Keluarga (atau surat RT/RW). '
        'Dokumen hanya dilihat pengurus yayasan relawan yang Anda terima dan dihapus setelah diperiksa. Nama lengkap '
        'dan nomor HP relawan terlihat setelah verifikasi. Pada kunjungan pertama relawan menanyakan '
        'langsung kesediaan lansia.',
  ),
  (
    'Data yang dikumpulkan',
    'Nama, alamat, kontak keluarga, Profil Kesehatan Ringkas yang diisi keluarga, cerita kunjungan relawan, '
        'status kondisi, dan kejadian darurat (termasuk lokasi saat tombol Darurat ditekan).',
  ),
  (
    'Siapa yang bisa melihat',
    'Keluarga yang terdaftar (pendaftar dan anggota yang menerima undangan) melihat seluruh data. Relawan '
        'pendamping melihat data lansia pasangannya. Yayasan yang memverifikasi relawan itu melihat nama, alamat, '
        'status kondisi beserta alasannya, keteraturan kunjungan, dan kejadian darurat, tanpa profil kesehatan dan '
        'tanpa cerita kunjungan lengkap.',
  ),
  (
    'Pemrosesan di luar Indonesia',
    'Data disimpan di Supabase (server Singapura). Cerita kunjungan dibaca oleh Google Gemini untuk diringkas '
        'menjadi kategori; nama dan alamat lansia dihapus sebelum dikirim. Notifikasi dikirim lewat Firebase '
        'Cloud Messaging (Google). Kata yang diketik saat mencari lokasi dikirim ke layanan peta OpenStreetMap '
        '(Photon oleh komoot, Jerman), dan peta ditampilkan dari server OpenStreetMap. Dengan menyetujui, Anda '
        'mengizinkan pemrosesan ini.',
  ),
  (
    'Hak Anda',
    'Anda bisa mengubah data lansia dan profil kesehatan kapan saja, mengakhiri pendampingan, menghapus semua data '
        'lansia (menu di halaman detail lansia), dan menghapus akun beserta datanya lewat menu akun.',
  ),
];

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Syarat & Persetujuan')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final (title, body) in termsSections) ...[
          Text(title, style: t.titleMedium),
          Padding(padding: const EdgeInsets.only(top: 4, bottom: 16), child: Text(body)),
        ],
      ]),
    );
  }
}

/// Tautan kecil "Baca Syarat & Persetujuan".
Widget termsLink(BuildContext context) => TextButton(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsScreen())),
      child: const Text('Baca Syarat & Persetujuan'),
    );

/// Akun yang belum menyetujui syarat (mis. dibuat lewat API, bukan layar daftar) harus menyetujuinya dulu
/// sebelum [child] (beranda) dibuka. [onAccept] diganti di test.
class TermsGate extends StatefulWidget {
  const TermsGate({super.key, required this.child, this.onAccept});

  final Widget child;
  final Future<void> Function()? onAccept;

  @override
  State<TermsGate> createState() => _TermsGateState();
}

class _TermsGateState extends State<TermsGate> {
  bool _accepted = false, _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await (widget.onAccept ?? () => Supabase.instance.client.rpc('accept_terms'))();
      setState(() => _accepted = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan, coba lagi')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted) return widget.child;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Syarat & Persetujuan'), actions: const [LogoutButton()]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Sebelum memakai ReLa, baca dan setujui syarat berikut.'),
        const SizedBox(height: 16),
        for (final (title, body) in termsSections) ...[
          Text(title, style: t.titleMedium),
          Padding(padding: const EdgeInsets.only(top: 4, bottom: 16), child: Text(body)),
        ],
        FilledButton(onPressed: _busy ? null : _accept, child: const Text('Saya setuju')),
      ]),
    );
  }
}
