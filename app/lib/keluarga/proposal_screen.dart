import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../relawan/join_screen.dart' show volunteerDays;
import '../shared/theme.dart';
import '../shared/widgets.dart';
import '../yayasan/ui.dart' show DayCircles;
import 'ui.dart';

/// Alasan penolakan (PRD F2a), sama dengan REJECT_REASONS di functions/pairing.
const rejectReasons = {
  'jarak': 'Jarak terlalu jauh',
  'jadwal': 'Jadwal tidak cocok',
  'bahasa': 'Bahasa',
  'lainnya': 'Lainnya',
};

/// Kartu relawan dari RPC `get_proposal_card` + `photo_url` (signed URL foto, berlaku 10 menit).
Future<Map<String, dynamic>> loadProposalCard(String proposalId) async {
  final db = Supabase.instance.client;
  final rows = await db.rpc('get_proposal_card', params: {'proposal_id': proposalId}) as List;
  if (rows.isEmpty) throw StateError('Usulan tidak ditemukan');
  final card = (rows.first as Map).cast<String, dynamic>();
  final path = card['photo_path'] as String?;
  card['photo_url'] = path == null ? null : await db.storage.from('volunteer-photos').createSignedUrl(path, 600);
  return card;
}

Future<Map<String, dynamic>> _pairing(Map<String, dynamic> body) async =>
    ((await Supabase.instance.client.functions.invoke('pairing', body: body)).data as Map).cast<String, dynamic>();

/// F2a: keluarga meninjau relawan yang diusulkan, lalu menerima atau menolak.
class ProposalScreen extends StatefulWidget {
  const ProposalScreen({super.key, required this.proposalId, this.loadCard, this.onAccept, this.onReject});

  final String proposalId;

  // Bisa diganti di test. Default: Supabase (RPC dan Edge Function `pairing`).
  final Future<Map<String, dynamic>> Function(String proposalId)? loadCard;
  final Future<void> Function(String proposalId)? onAccept;
  final Future<Map<String, dynamic>> Function(String proposalId, String reason, String? note)? onReject;

  @override
  State<ProposalScreen> createState() => _ProposalScreenState();
}

class _ProposalScreenState extends State<ProposalScreen> {
  late String _id = widget.proposalId;
  late Future<Map<String, dynamic>> _card = _load();
  String? _finalMessage; // tampil bila tidak ada usulan lagi
  bool _busy = false;

  Future<Map<String, dynamic>> _load() => (widget.loadCard ?? loadProposalCard)(_id);

  Future<void> _accept() async {
    final card = await _card;
    setState(() => _busy = true);
    try {
      await (widget.onAccept ?? (id) => _pairing({'action': 'accept', 'proposal_id': id}))(_id);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => AssignedScreen(
          volunteerName: card['volunteer_name'] as String? ?? 'Relawan',
          elderName: card['elder_name'] as String? ?? 'lansia',
        ),
      ));
    } catch (e) {
      _error('Gagal menerima usulan');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final left = (await _card)['rejects_left'] as int? ?? 0;
    if (!mounted) return;
    final picked = await showDialog<(String, String?)>(context: context, builder: (_) => _RejectDialog(left: left));
    if (picked == null) return; // dibatalkan
    setState(() => _busy = true);
    try {
      final (reason, note) = picked;
      final res = await (widget.onReject ??
          (id, r, n) => _pairing({'action': 'reject', 'proposal_id': id, 'reason': r, 'note': ?n}))(_id, reason, note);
      final next = res['proposal_id'] as String?;
      setState(() {
        if (next != null) {
          _id = next;
          _card = _load();
        } else if (res['pairing_state'] == 'perlu_yayasan') {
          _finalMessage = 'Diteruskan ke yayasan. Pengurus akan menghubungi Anda untuk memilih pendamping bersama.';
        } else {
          _finalMessage = 'Belum ada relawan lain yang cocok. Lansia akan terlihat oleh yayasan.';
        }
      });
    } catch (e) {
      _error('Gagal menolak usulan');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: _finalMessage != null
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_finalMessage!, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Kembali ke beranda'),
                ),
              ]),
            )
          : FutureBuilder<Map<String, dynamic>>(
              future: _card,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Gagal memuat usulan: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                return _CardView(card: snap.data!, busy: _busy, onAccept: _accept, onReject: _reject);
              },
            ),
    );
  }
}


class _CardView extends StatelessWidget {
  const _CardView({required this.card, required this.busy, required this.onAccept, required this.onReject});

  final Map<String, dynamic> card;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final photo = card['photo_url'] as String?;
    final left = card['rejects_left'] as int? ?? 0;
    final km = (card['distance_km'] as num?)?.toStringAsFixed(1).replaceAll('.', ',');
    final birth = card['birth_date'] == null ? null : DateTime.parse(card['birth_date'] as String);
    final skills = [
      if (card['can_dementia'] == true) 'Mampu mendampingi lansia dengan demensia',
      if (card['can_mobility'] == true) 'Mampu membantu lansia dengan mobilitas sulit',
    ];
    final verification = (card['verification'] as String?) ?? '';
    final days = ((card['available_days'] as List?) ?? const []).cast<String>();
    final name = card['volunteer_name'] as String? ?? '-';

    return ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 32), children: [
      Text('Relawan ${card['attempt'] ?? ''}', style: const TextStyle(color: RelaColors.muted)),
      const Text('Pencarian Relawan', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
      const Divider(height: 32),
      Center(
        child: CircleAvatar(
          radius: 52,
          backgroundColor: RelaColors.sand,
          backgroundImage: photo == null ? null : NetworkImage(photo),
          child: photo == null
              ? Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: RelaColors.ink))
              : null,
        ),
      ),
      const SizedBox(height: 12),
      Center(child: Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700))),
      const SizedBox(height: 8),
      Center(
        child: verification.isEmpty
            ? const Pill(label: 'Belum ada keterangan verifikasi', fg: RelaColors.muted, bg: RelaColors.paper)
            : const Pill(label: 'Terverifikasi', fg: RelaColors.okText, bg: RelaColors.okBg),
      ),
      TitledBox(
        title: 'Informasi Relawan',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InfoRow('Nama panggilan', card['nickname'] as String?),
          InfoRow('Usia', birth == null ? null : '${ageFrom(birth)} tahun'),
          InfoRow('Kemampuan', skills.isEmpty ? 'Pendampingan umum' : skills.join('; ')),
          if (km != null) InfoRow('Jarak', '±$km km'),
          InfoRow('Yayasan', 'Relawan ${card['foundation_name'] ?? ''}'),
          if (verification.isNotEmpty) InfoRow('Verifikasi', verification),
          InfoRow('Alasan', card['reason_text'] as String?),
          const SizedBox(height: 4),
          const Text('Kemampuan diisi sendiri oleh relawan', style: TextStyle(fontSize: 12, color: RelaColors.muted)),
        ]),
      ),
      TitledBox(
        title: 'Jadwal Tersedia',
        child: DayCircles(on: {for (var i = 0; i < 7; i++) if (days.contains(volunteerDays[i])) i}),
      ),
      const SizedBox(height: 16),
      Text(
        left > 0
            ? 'Sisa $left kali tolak'
            : 'Ini usulan terakhir dan tidak bisa ditolak. Bila nanti kurang cocok, Anda bisa minta ganti pendamping '
                'satu kali.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: RelaColors.muted),
      ),
      const SizedBox(height: 12),
      FilledButton(style: bigFilled, onPressed: busy ? null : onAccept, child: const Text('Terima')),
      // Keputusan pengguna 16 Okt: usulan ke-3 hanya bisa diterima.
      if (left > 0) ...[
        const SizedBox(height: 12),
        OutlinedButton(
          style: bigOutlined.copyWith(
            foregroundColor: const WidgetStatePropertyAll(RelaColors.danger),
            side: const WidgetStatePropertyAll(BorderSide(color: RelaColors.danger)),
          ),
          onPressed: busy ? null : onReject,
          child: const Text('Tolak'),
        ),
      ],
    ]);
  }
}

/// Figma "Volunteer Assigned": pendamping ditetapkan setelah keluarga menerima usulan.
class AssignedScreen extends StatelessWidget {
  const AssignedScreen({super.key, required this.volunteerName, required this.elderName});

  final String volunteerName, elderName;

  @override
  Widget build(BuildContext context) {
    final first = volunteerName.split(' ').first;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Pendamping ditetapkan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircleAvatar(
              radius: 44,
              backgroundColor: RelaColors.primary,
              child: Icon(Icons.check, color: Colors.white, size: 52),
            ),
            const SizedBox(height: 24),
            Text('$volunteerName kini menjadi pendamping aktif $elderName.',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('$first baru dapat melihat informasi $elderName setelah penetapan ini. Nama lengkap dan nomor HP '
                'relawan muncul setelah yayasan memeriksa dokumen Anda.',
                textAlign: TextAlign.center, style: const TextStyle(color: RelaColors.muted)),
            const SizedBox(height: 24),
            FilledButton(
              style: bigFilled,
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Ke Beranda'),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Figma "Reject Reason Dialog". Mengembalikan (alasan, catatan) atau null bila dibatalkan.
class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.left});

  final int left;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  String? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _valid => _reason != null && (_reason != 'lainnya' || _note.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kenapa ditolak?', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final e in rejectReasons.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _reason = e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _reason == e.key ? RelaColors.okBg : RelaColors.paper,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: RelaColors.border),
                  ),
                  child: Row(children: [
                    Icon(_reason == e.key ? Icons.check_circle : Icons.radio_button_unchecked, color: RelaColors.primary),
                    const SizedBox(width: 12),
                    Text(e.value, style: const TextStyle(fontSize: 16)),
                  ]),
                ),
              ),
            ),
          TextField(
            controller: _note,
            maxLength: 300,
            decoration: const InputDecoration(hintText: 'Keterangan (untuk "Lainnya")...'),
            onChanged: (_) => setState(() {}),
          ),
          Text('KESEMPATAN MENOLAK TERSISA ${widget.left}', style: const TextStyle(color: RelaColors.danger)),
          const SizedBox(height: 4),
          const Text('Alasan hanya dilihat yayasan, tidak diberitahukan ke relawan.',
              style: TextStyle(fontSize: 12, color: RelaColors.muted)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: RelaColors.danger),
          onPressed: _valid
              ? () => Navigator.pop(context, (_reason!, _note.text.trim().isEmpty ? null : _note.text.trim()))
              : null,
          child: const Text('Kirim alasan'),
        ),
      ],
    );
  }
}
