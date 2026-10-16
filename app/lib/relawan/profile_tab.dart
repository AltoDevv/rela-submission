import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../keluarga/ui.dart' show ElderAvatar;
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'profile_screen.dart';
import 'ui.dart';

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Tab Profil: data relawan (ubah lewat [VolunteerProfileScreen]), berhenti per lansia, dan pengunduran diri.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.data, required this.onOpen, required this.onRun});

  final RelawanData data;
  final Future<void> Function(Widget) onOpen;
  final Future<void> Function(Future<void> Function()) onRun;

  @override
  Widget build(BuildContext context) {
    final v = data.volunteer;
    const muted = TextStyle(color: RelaColors.muted);
    String orEmpty(String s) => s.isEmpty ? 'Belum diisi' : s;
    final rows = {
      'Area': orEmpty(v.areaLabel ?? ''),
      'Hari tersedia': orEmpty(v.availableDays.map(_cap).join(', ')),
      'Demensia': v.canDementia ? 'Bisa' : 'Tidak',
      'Mobilitas sulit': v.canMobility ? 'Bisa' : 'Tidak',
      'Bahasa': orEmpty(v.languages.map(_cap).join(', ')),
    };
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Row(children: [
        Expanded(child: Text('Profil', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700))),
        LogoutButton(),
      ]),
      const Text('Relawan', style: muted),
      const SizedBox(height: 16),
      ActiveChip(active: v.status == 'aktif', foundation: data.foundation),
      const SizedBox(height: 16),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            // Foto wajah verifikasi; hanya bisa diganti lewat pengurus yayasan (keputusan pengguna 16 Okt).
            ElderAvatar(name: data.name ?? '', photoPath: v.photoPath, bucket: 'volunteer-photos', radius: 44),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data.name ?? 'Relawan', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Relawan pendamping', style: muted),
                Text(v.areaLabel ?? 'Area layanan', style: muted),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(children: [
            for (final r in rows.entries)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: RelaColors.cream))),
                child: Row(children: [
                  Text(r.key, style: muted),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(r.value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => onOpen(const VolunteerProfileScreen()), child: const Text('Edit')),
          ]),
        ),
      ),
      if (data.elders.isNotEmpty) ...[
        const SizedBox(height: 24),
        const Text('Lansia pasangan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        for (final e in data.elders)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(e.fullName),
            trailing: data.pendingStops.contains(e.id)
                ? const Text('Berhenti menunggu yayasan', style: muted)
                : TextButton(onPressed: () => onRun(() => requestStop(context, e)), child: const Text('Ajukan berhenti')),
          ),
      ],
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(20),
        color: RelaColors.paper,
        child: Text(v.resignRequestedAt == null
            ? 'Jika ingin berhenti menjadi relawan, kirim pengajuan kepada yayasan.'
            : 'Pengunduran diri sudah diajukan dan menunggu yayasan. Alasan: ${v.resignReason ?? '-'}'),
      ),
      const SizedBox(height: 16),
      if (v.resignRequestedAt == null)
        FilledButton(
          style: bigDanger,
          onPressed: () => onOpen(ResignScreen(foundation: data.foundation)),
          child: const Text('Ajukan Pengunduran Diri'),
        ),
    ]);
  }
}

/// Mengirim pengunduran diri ke Edge Function `pairing` (aksi resign).
Future<void> submitResign(String reason) =>
    Supabase.instance.client.functions.invoke('pairing', body: {'action': 'resign', 'reason': reason});

/// Pengajuan pengunduran diri: semua lansia pasangan ikut diajukan berhenti, lalu yayasan menonaktifkan relawan.
class ResignScreen extends StatefulWidget {
  const ResignScreen({super.key, this.foundation, this.submit = submitResign});

  final String? foundation;
  final Future<void> Function(String reason) submit;

  @override
  State<ResignScreen> createState() => _ResignScreenState();
}

class _ResignScreenState extends State<ResignScreen> {
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await widget.submit(_reason.text.trim());
      messenger.showSnackBar(const SnackBar(content: Text('Pengajuan pengunduran diri dikirim ke yayasan.')));
      nav.pop();
    } catch (e) {
      final msg = e is FunctionException && e.details is Map ? (e.details as Map)['error'] : null;
      messenger.showSnackBar(SnackBar(content: Text('${msg ?? 'Gagal mengirim, coba lagi'}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(color: RelaColors.muted);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengajuan Pengunduran Diri'), centerTitle: true),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Text(
          'Pengajuan ini akan dikirim ke ${widget.foundation ?? 'yayasan'}. Sampaikan alasanmu agar yayasan dapat '
          'menindaklanjutinya. Lansia pasanganmu ikut diajukan berhenti supaya sistem mencarikan pengganti; sampai '
          'itu, kamu tetap pendamping mereka.',
          style: muted,
        ),
        const SizedBox(height: 24),
        const Text('Alasan pengunduran diri', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextField(
          key: const Key('alasan-mundur'),
          controller: _reason,
          minLines: 8,
          maxLines: 12,
          maxLength: 300,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'Tuliskan alasanmu di sini...'),
        ),
        const Text('Pastikan alasan sudah sesuai sebelum dikirim. Pengajuan akan diterima oleh yayasan.', style: muted),
        const SizedBox(height: 24),
        FilledButton(
          style: bigFilled,
          onPressed: _busy || _reason.text.trim().length < 3 ? null : _send,
          child: Text(_busy ? 'Mengirim…' : 'Kirim'),
        ),
      ]),
    );
  }
}
