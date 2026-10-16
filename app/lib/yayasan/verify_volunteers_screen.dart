import 'dart:async';

import 'package:flutter/material.dart';

import '../shared/theme.dart';

/// Ketentuan verifikasi relawan (SOP yayasan). Semua butir wajib dicentang sebelum kode verifikasi ditampilkan;
/// yang disimpan tetap hanya siapa dan kapan (tanpa dokumen, PRD F1b). SKCK sengaja tidak diminta (keputusan pengguna).
const identityChecklist = [
  'Wajah sama dengan foto di aplikasi dan dengan KTP asli (bukan fotokopi atau foto KTP)',
  'Nama di aplikasi sama persis dengan nama di KTP (nama dikunci setelah verifikasi)',
  'Usia minimal 18 tahun menurut KTP',
  'Nomor HP aktif: sudah ditelepon saat bertemu',
  'Bila mencentang keahlian demensia atau mobilitas sulit, pengalamannya sudah ditanyakan',
];
const orientationChecklist = [
  'Relawan adalah teman pendamping, bukan tenaga kesehatan: tidak memberi obat dan tidak mendiagnosis',
  'Tidak meminta atau menerima uang/barang, tidak meminjam dan tidak meminjamkan',
  'Tidak membawa lansia keluar rumah tanpa izin keluarga dan tidak memotret lansia tanpa persetujuan',
  'Menjaga kerahasiaan data dan cerita lansia',
  'Paham tanda bahaya dan alur Darurat (119 dan tombol Darurat di aplikasi)',
  'Paham cara menulis cerita kunjungan dan memastikan lansia ada & setuju pada kunjungan pertama',
  'Tahu cara berhenti, minta ganti, dan menghubungi yayasan',
  'Sudah menandatangani perjanjian relawan dan kode etik',
];

/// Dialog butir pemeriksaan; mengembalikan true bila semua butir dicentang lalu Simpan ditekan.
/// Kode verifikasi tatap muka seperti authenticator: 6 digit, berlaku 2 menit, otomatis diganti saat habis.
/// Dialog tertutup sendiri begitu relawan memasukkan kode (status menjadi aktif).
class VerificationCodeDialog extends StatefulWidget {
  const VerificationCodeDialog({super.key, required this.volunteerName, required this.issue, required this.isActive});

  final String volunteerName;
  final Future<({String code, DateTime expiresAt})> Function() issue;
  final Future<bool> Function() isActive;

  @override
  State<VerificationCodeDialog> createState() => _VerificationCodeDialogState();
}

class _VerificationCodeDialogState extends State<VerificationCodeDialog> {
  ({String code, DateTime expiresAt})? _code;
  Timer? _tick;
  int _polls = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _newCode();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  Future<void> _newCode() async {
    try {
      final c = await widget.issue();
      if (mounted) setState(() => _code = c);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _onTick() async {
    if (!mounted) return;
    final c = _code;
    if (c != null && DateTime.now().isAfter(c.expiresAt)) {
      _code = null;
      await _newCode();
    }
    if (++_polls % 3 == 0 && await widget.isActive() && mounted) {
      _tick?.cancel();
      Navigator.pop(context, true);
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _code;
    final left = c == null ? 0 : c.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 120);
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
      title: Row(children: [
        const SizedBox(width: 40),
        const Expanded(
          child: Text('KODE VERIFIKASI', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        IconButton(tooltip: 'Tutup', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red))
        else if (c == null)
          const CircularProgressIndicator()
        else ...[
          SelectableText(
            '${c.code.substring(0, 3)} ${c.code.substring(3)}',
            key: const Key('kode-tampil'),
            style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: RelaColors.primary, letterSpacing: 4),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: left / 120, backgroundColor: RelaColors.cream),
          Text('Berganti dalam $left detik', style: const TextStyle(color: RelaColors.muted)),
        ],
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: RelaColors.paper, borderRadius: BorderRadius.circular(16)),
          child: Text('Berikan kode kepada ${widget.volunteerName}. Ia memasukkannya di aplikasinya sekarang, di depan '
              'Anda.', textAlign: TextAlign.center),
        ),
      ]),
    );
  }
}

class ChecklistDialog extends StatefulWidget {
  const ChecklistDialog({super.key, required this.title, required this.volunteerName, required this.items});

  final String title, volunteerName;
  final List<String> items;

  @override
  State<ChecklistDialog> createState() => _ChecklistDialogState();
}

class _ChecklistDialogState extends State<ChecklistDialog> {
  final _done = <int>{};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(shrinkWrap: true, children: [
          Text('Relawan: ${widget.volunteerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
          for (var i = 0; i < widget.items.length; i++)
            CheckboxListTile(
              key: Key('butir-$i'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              value: _done.contains(i),
              title: Text(widget.items[i]),
              onChanged: (on) => setState(() { on == true ? _done.add(i) : _done.remove(i); }),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(
          onPressed: _done.length == widget.items.length ? () => Navigator.pop(context, true) : null,
          child: const Text('Simpan centang'),
        ),
      ],
    );
  }
}
