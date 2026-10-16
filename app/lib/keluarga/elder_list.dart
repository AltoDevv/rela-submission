import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../relawan/ui.dart' show visitDate;
import '../shared/models.dart';
import '../shared/schedule.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'elder_detail_screen.dart';
import 'proposal_screen.dart';
import 'ui.dart';
import 'verify_elder_screen.dart';

const pairingLabels = {
  'mencari': 'Mencari relawan · ketuk untuk mencoba lagi',
  'menunggu_keluarga': 'Ada usulan relawan · ketuk untuk meninjau',
  'berpasangan': 'Didampingi relawan',
  'tanpa_pendamping': 'Belum ada relawan yang cocok · ketuk untuk mencari lagi',
  'perlu_yayasan': 'Sedang ditangani yayasan',
  'selesai': 'Pendampingan selesai',
};

/// Keterangan di daftar lansia: langkah langganan/verifikasi didahulukan, lalu status pemasangan.
String elderListLabel(Elder e) {
  if (e.pairingState == 'berpasangan' && !e.paid) return 'Didampingi relawan · langganan berakhir, ketuk untuk memperpanjang';
  if (e.pairingState != 'selesai') {
    if (!e.paid) return 'Langganan belum aktif · ketuk untuk melanjutkan';
    if (e.verifyState == 'belum') return 'Lengkapi dokumen verifikasi · ketuk untuk melanjutkan';
    if (e.verifyState == 'ditolak') return 'Dokumen ditolak yayasan · ketuk untuk unggah ulang';
  }
  final base = pairingLabels[e.pairingState] ?? e.pairingState;
  return e.pairingState == 'berpasangan' && e.verifyState == 'menunggu' ? '$base · dokumen sedang diperiksa yayasan' : base;
}

/// Memanggil `pairing` → `propose`. Bila ada usulan, ProposalScreen dibuka; bila tidak, pesan ditampilkan.
Future<void> proposeAndOpen(BuildContext context, String elderId) async {
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);
  try {
    final res = await Supabase.instance.client.functions.invoke(
      'pairing',
      body: {'action': 'propose', 'elder_id': elderId},
    );
    final proposalId = (res.data as Map?)?['proposal_id'] as String?;
    if (proposalId != null) {
      nav.push(MaterialPageRoute(builder: (_) => ProposalScreen(proposalId: proposalId)));
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Belum ada relawan yang cocok. Lansia akan terlihat oleh yayasan.')),
      );
    }
  } on FunctionException catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Pencarian relawan gagal. Ketuk lansia untuk mencoba lagi.')));
  }
}

/// Membuka lansia sesuai keadaannya: langkah langganan/dokumen dulu, lalu usulan relawan, pencarian, atau detail.
Future<void> openElder(BuildContext context, Elder e) async {
  final nav = Navigator.of(context);
  // Keputusan usulan relawan hanya untuk pendaftar; anggota keluarga lain langsung ke detail.
  final owner = e.familyId == Supabase.instance.client.auth.currentUser?.id;
  // Yang sedang didampingi dibuka di detail (perpanjang langganan ada di sana); yang lain menyelesaikan langkah dulu.
  if (owner && e.needsSetup && !const ['selesai', 'berpasangan'].contains(e.pairingState)) {
    await nav.push(MaterialPageRoute(
        builder: (_) => VerifyElderScreen(
            elderId: e.id,
            elderName: e.fullName,
            paid: e.paid,
            rejectedNote: e.verifyState == 'ditolak' ? e.verifyNote : null,
            needDocs: e.verifyState == 'belum' || e.verifyState == 'ditolak')));
    return;
  }
  if (owner && e.pairingState == 'menunggu_keluarga') {
    final p = await Supabase.instance.client
        .from('proposals')
        .select('id')
        .eq('elder_id', e.id)
        .eq('state', 'pending')
        .maybeSingle();
    if (p != null) {
      await nav.push(MaterialPageRoute(builder: (_) => ProposalScreen(proposalId: p['id'])));
      return;
    }
  }
  await nav.push(MaterialPageRoute(builder: (_) => ElderDetailScreen(elderId: e.id)));
}

/// Undangan untuk akun ini: menjadi pengurus yayasan (E3) atau ikut memantau lansia (anggota keluarga).
class FamilyInvites extends StatefulWidget {
  const FamilyInvites({super.key, this.onChanged});

  /// Dipanggil setelah undangan anggota keluarga dijawab (daftar lansia perlu dimuat ulang).
  final VoidCallback? onChanged;

  @override
  State<FamilyInvites> createState() => _FamilyInvitesState();
}

class _FamilyInvitesState extends State<FamilyInvites> {
  late Future<List<Map<String, dynamic>>> _invites = _rows('my_family_invites');
  late Future<List<Map<String, dynamic>>> _adminInvite = _rows('my_admin_invite');

  // async: Supabase baru diakses saat future berjalan, jadi error (mis. di test) menjadi daftar kosong.
  Future<List<Map<String, dynamic>>> _rows(String fn) async {
    try {
      return ((await Supabase.instance.client.rpc(fn)) as List).map((m) => (m as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Undangan menjadi pengurus yayasan (E3): peran baru berlaku setelah masuk ulang.
  Future<void> _answerAdmin(bool accept) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.rpc('answer_admin_invite', params: {'p_accept': accept});
      if (accept) {
        messenger.showSnackBar(const SnackBar(content: Text('Anda kini pengurus yayasan. Silakan masuk lagi.')));
        await LogoutButton.signOut();
        return;
      }
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    setState(() { _adminInvite = _rows('my_admin_invite'); });
  }

  Future<void> _answer(String elderId, bool accept) async {
    final db = Supabase.instance.client;
    if (accept) {
      await db.rpc('accept_family_invite', params: {'p_elder_id': elderId});
    } else {
      await db.rpc('remove_family_member', params: {'p_elder_id': elderId, 'p_profile_id': db.auth.currentUser!.id});
    }
    setState(() { _invites = _rows('my_family_invites'); });
    widget.onChanged?.call();
  }

  Widget _card(String title, String body, VoidCallback onNo, VoidCallback onYes) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: RelaColors.paper,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(body),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: onNo, child: const Text('Tolak')),
              FilledButton(onPressed: onYes, child: const Text('Terima')),
            ]),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([_adminInvite, _invites]),
      builder: (context, snap) {
        final admin = snap.data?[0] ?? const [];
        final family = snap.data?[1] ?? const [];
        return Column(children: [
          for (final i in admin)
            _card(
              'Undangan: menjadi pengurus ${i['foundation_name']}',
              'Dari ${i['inviter_name'] ?? 'pengurus yayasan'}. Akun ini akan berpindah peran menjadi pengurus yayasan '
                  'dan tidak bisa memantau lansia sebagai keluarga.',
              () => _answerAdmin(false),
              () => _answerAdmin(true),
            ),
          for (final i in family)
            _card(
              'Undangan: ikut memantau ${i['elder_name']}',
              'Dari ${i['inviter_name'] ?? 'keluarga'}. Anda akan melihat kondisi dan menerima notifikasinya.',
              () => _answer(i['elder_id'] as String, false),
              () => _answer(i['elder_id'] as String, true),
            ),
        ]);
      },
    );
  }
}

/// Pendamping untuk kartu Beranda. Nama baru terlihat setelah dokumen diverifikasi (RPC my_volunteer_contact).
Future<String?> companionLine(Elder e) async {
  if (e.pairingState != 'berpasangan') return null;
  if (e.verifyState != 'terverifikasi') return 'Pendamping sudah dipilih · menunggu verifikasi dokumen';
  try {
    final rows = await Supabase.instance.client.rpc('my_volunteer_contact', params: {'p_elder_id': e.id}) as List;
    if (rows.isEmpty) return null;
    final c = rows.first as Map;
    return 'Pendamping: ${c['nickname'] ?? c['full_name']} · ${c['foundation_name']}';
  } catch (_) {
    return null;
  }
}

/// Kartu lansia di Beranda (Figma "Home"): nama & usia, status, pendamping, kunjungan terakhir + ringkasannya.
class ElderHomeCard extends StatefulWidget {
  const ElderHomeCard({super.key, required this.elder, required this.onTap, this.loadExtra});

  final Elder elder;
  final VoidCallback onTap;

  /// (baris pendamping, kunjungan terakhir). Diganti di test.
  final Future<(String?, Visit?)> Function(Elder e)? loadExtra;

  @override
  State<ElderHomeCard> createState() => _ElderHomeCardState();
}

class _ElderHomeCardState extends State<ElderHomeCard> {
  late Future<(String?, Visit?)> _extra = (widget.loadExtra ?? _load)(widget.elder);

  static Future<(String?, Visit?)> _load(Elder e) async {
    Visit? last;
    try {
      final row = await Supabase.instance.client
          .from('visits')
          .select()
          .eq('elder_id', e.id)
          .not('confirmed_at', 'is', null)
          .order('visited_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row != null) last = Visit.fromMap(row);
    } catch (_) {}
    return (await companionLine(e), last);
  }

  @override
  void didUpdateWidget(ElderHomeCard old) {
    super.didUpdateWidget(old);
    // Realtime: status atau pasangan berubah → muat ulang baris pendamping & kunjungan terakhir.
    if (old.elder.status != widget.elder.status || old.elder.pairingState != widget.elder.pairingState ||
        old.elder.verifyState != widget.elder.verifyState) {
      _extra = (widget.loadExtra ?? _load)(widget.elder);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.elder;
    const muted = TextStyle(color: RelaColors.muted);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: RelaColors.border, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<(String?, Visit?)>(
            future: _extra,
            builder: (context, snap) {
              final (companion, last) = snap.data ?? (null, null);
              final label = elderListLabel(e);
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  ElderAvatar(name: e.fullName, photoPath: e.photoPath),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(elderTitle(e), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      statusPill(e.status),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(companion ?? label, style: muted),
                if (companion != null && label != pairingLabels['berpasangan']) Text(label, style: muted),
                if (nextVisitText(e) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Kunjungan berikutnya · ${nextVisitText(e)}',
                        style: const TextStyle(color: RelaColors.primary, fontWeight: FontWeight.w600)),
                  )
                else if (e.scheduleStatus == 'diusulkan')
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Ada usulan jadwal kunjungan · ketuk untuk menyetujui',
                        style: TextStyle(color: RelaColors.primary, fontWeight: FontWeight.w600)),
                  ),
                if (last != null) ...[
                  const SizedBox(height: 8),
                  Text('Kunjungan terakhir · ${visitDate(last.visitedAt)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (visitSummary(last.finalResult).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(visitSummary(last.finalResult)),
                  ],
                ],
              ]);
            },
          ),
        ),
      ),
    );
  }
}
