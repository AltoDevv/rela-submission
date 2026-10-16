import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/models.dart';
import '../shared/rubric.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'visit_story_screen.dart';

typedef FamilyContact = ({String? name, String? phone});

/// Semua yang ditampilkan keempat tab relawan, dimuat sekali lalu dimuat ulang setelah ada aksi.
class RelawanData {
  RelawanData({
    required this.volunteer,
    this.name,
    this.foundation,
    this.elders = const [],
    this.pendingStops = const {},
    this.contacts = const {},
    this.health = const {},
    this.visits = const {},
  });

  final Volunteer volunteer;
  final String? name; // profiles.full_name
  final String? foundation;
  final List<Elder> elders;
  final Set<String>
  pendingStops; // lansia yang permintaan berhentinya menunggu yayasan
  final Map<String, FamilyContact> contacts; // elder_id → pendaftar
  final Map<String, HealthProfile> health;
  final Map<String, List<Visit>> visits; // terkonfirmasi, terbaru dulu

  List<Visit> visitsOf(String elderId) => visits[elderId] ?? const [];
}

/// RLS hanya memberi relawan lansia, profil kesehatan, dan kunjungan pasangannya sendiri.
Future<RelawanData> loadRelawanData() async {
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser!.id;
  final volunteer = Volunteer.fromMap(
    await db.from('volunteers').select().eq('id', uid).single(),
  );
  final me = await db
      .from('profiles')
      .select('full_name')
      .eq('id', uid)
      .single();
  final foundation = await db.rpc('my_foundation_name') as String?;
  final elders =
      (await db
              .from('elders')
              .select()
              .eq('volunteer_id', uid)
              .order('full_name'))
          .map(Elder.fromMap)
          .toList();
  final ids = elders.map((e) => e.id).toList();
  final stops = await db
      .from('stop_requests')
      .select('elder_id')
      .isFilter('decided_at', null);
  final contacts = (await db.rpc('my_elders_family_contacts') as List)
      .cast<Map>();
  final health = ids.isEmpty
      ? const <Map<String, dynamic>>[]
      : await db.from('health_profiles').select().inFilter('elder_id', ids);
  final visits = ids.isEmpty
      ? const <Map<String, dynamic>>[]
      : await db
            .from('visits')
            .select()
            .inFilter('elder_id', ids)
            .not('confirmed_at', 'is', null)
            .order('visited_at', ascending: false);
  final byElder = <String, List<Visit>>{};
  for (final v in visits.map(Visit.fromMap)) {
    byElder.putIfAbsent(v.elderId, () => []).add(v);
  }
  return RelawanData(
    volunteer: volunteer,
    name: me['full_name'] as String?,
    foundation: foundation,
    elders: elders,
    pendingStops: {for (final r in stops) r['elder_id'] as String},
    contacts: {
      for (final c in contacts)
        c['elder_id'] as String: (
          name: c['full_name'] as String?,
          phone: c['phone'] as String?,
        ),
    },
    health: {for (final h in health.map(HealthProfile.fromMap)) h.elderId: h},
    visits: byElder,
  );
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// "3 Okt 2026"
String visitDate(DateTime t) {
  final l = t.toLocal();
  return '${l.day} ${_months[l.month - 1]} ${l.year}';
}

List<Map> flagsOf(Map<String, dynamic>? result) =>
    (result?['red_flags'] as List? ?? const []).cast<Map>();

/// Baris riwayat: tanggal · ada/tidak tanda bahaya (status lansia dihitung per lansia, bukan per kunjungan).
String visitLine(Visit v) =>
    '${visitDate(v.visitedAt)} · ${flagsOf(v.finalResult).isEmpty ? 'Tanpa tanda bahaya' : 'Ada tanda bahaya'}';

/// Status yang direkam saat kunjungan itu disimpan; kunjungan lama tanpa status tetap memakai label tanda bahaya.
class VisitHistoryTile extends StatelessWidget {
  const VisitHistoryTile({
    super.key,
    required this.visit,
    required this.onTap,
    this.compact = false,
  });

  final Visit visit;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final status = visit.statusAfter;
    final color = switch (status) {
      'stabil' => RelaColors.okText,
      'perlu_perhatian' => const Color(0xFF7A5A00),
      _ => RelaColors.danger,
    };
    final bg = switch (status) {
      'stabil' => RelaColors.okBg,
      'perlu_perhatian' => const Color(0xFFF8E6B8),
      _ => const Color(0xFFF6DADA),
    };
    final label = switch (status) {
      'stabil' => 'Stabil',
      'perlu_perhatian' => 'Perlu perhatian',
      'segera_dikabari' => 'Segera dikabari',
      _ => status ?? '',
    };
    return Card(
      margin: EdgeInsets.only(bottom: compact ? 12 : 10),
      shape: compact
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: RelaColors.sand),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 14 : 24),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: compact ? 12 : 16,
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                status == null ? visitLine(visit) : visitDate(visit.visitedAt),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (status != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    '● $label',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                )
              else
                const Icon(Icons.chevron_right, color: RelaColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip "Terverifikasi · Aktif" + nama yayasan.
class ActiveChip extends StatelessWidget {
  const ActiveChip({
    super.key,
    required this.active,
    this.foundation,
    this.compact = false,
  });

  final bool active;
  final String? foundation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = active ? RelaColors.okText : RelaColors.danger;
    return Wrap(
      spacing: compact ? 8 : 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 5 : 8,
          ),
          decoration: BoxDecoration(
            color: active ? RelaColors.okBg : RelaColors.cream,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: compact ? 6 : 10, color: color),
              SizedBox(width: compact ? 6 : 8),
              Flexible(
                child: Text(
                  active ? 'Terverifikasi · Aktif' : 'Belum aktif',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 12 : null,
                    height: compact ? 1.2 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (foundation != null)
          Text(
            foundation!,
            style: TextStyle(
              color: RelaColors.muted,
              fontSize: compact ? 12 : null,
            ),
          ),
      ],
    );
  }
}

/// Kotak inisial berwarna pasir (avatar di Figma).
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.name, this.size = 96});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 1.1,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: RelaColors.sand,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          fontSize: size / 3,
          fontWeight: FontWeight.w700,
          color: RelaColors.ink,
        ),
      ),
    );
  }
}

/// Kartu lansia: nama, kontak keluarga, alamat, status.
class ElderCard extends StatelessWidget {
  const ElderCard({super.key, required this.elder, this.contact});

  final Elder elder;
  final FamilyContact? contact;

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(color: RelaColors.muted);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialAvatar(name: elder.fullName),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    elder.fullName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (contact?.name != null)
                    Text('Keluarga: ${contact!.name}', style: muted),
                  if (contact?.phone != null)
                    Text(contact!.phone!, style: muted),
                  const SizedBox(height: 4),
                  Text(elder.address, style: muted),
                  const SizedBox(height: 4),
                  StatusBadge(status: elder.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dropdown pemilih lansia untuk tab Lansia & Riwayat; tetap terlihat bila hanya satu pasangan.
class ElderPicker extends StatelessWidget {
  const ElderPicker({
    super.key,
    required this.elders,
    required this.selected,
    required this.onChanged,
  });

  final List<Elder> elders;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('pilih-lansia'),
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey('pilih-lansia-$selected'),
        initialValue: selected,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Pilih lansia',
          prefixIcon: Icon(Icons.person_outline),
        ),
        items: [
          for (final e in elders)
            DropdownMenuItem(
              value: e.id,
              child: Text(e.fullName, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (id) {
          if (id != null) onChanged(id);
        },
      ),
    );
  }
}

/// Kotak krem berjudul tebal (Cerita asli Anda, Tanda bahaya).
class NoteBox extends StatelessWidget {
  const NoteBox({super.key, required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RelaColors.cream,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          body,
        ],
      ),
    );
  }
}

/// Hasil kunjungan seperti di Figma: cerita asli, kartu per domain beserta bukti, lalu tanda bahaya.
/// Dipakai layar konfirmasi dan detail riwayat.
class VisitResultView extends StatelessWidget {
  const VisitResultView({
    super.key,
    required this.answers,
    required this.result,
  });

  final Map<String, dynamic> answers;
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final story = [
      for (final k in storyQuestions.keys) '${answers[k] ?? ''}'.trim(),
    ].where((s) => s.isNotEmpty);
    final flags = flagsOf(result);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (story.isNotEmpty)
          NoteBox(title: 'Cerita asli Anda', body: Text(story.join(' … '))),
        for (final d in rubricDomains)
          _DomainCard(
            domain: d,
            data: (result[d.key] as Map?)?.cast<String, dynamic>(),
          ),
        const SizedBox(height: 12),
        NoteBox(
          title: flags.isEmpty
              ? 'Tanda bahaya: tidak ditemukan'
              : 'Tanda bahaya ditemukan',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in flags)
                Text(
                  '• ${redFlags[f['flag']] ?? f['flag']}: "${f['evidence']}"',
                ),
              const Text('Bukan diagnosis medis.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _DomainCard extends StatelessWidget {
  const _DomainCard({required this.domain, required this.data});

  final RubricDomain domain;
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    final level = data?['level'] as int?;
    final evidence = '${data?['evidence'] ?? ''}'.trim();
    final severe = level != null && level >= 2;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: severe ? RelaColors.border : RelaColors.cream),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(domain.name),
            const SizedBox(height: 8),
            LevelChip(
              label: level == null ? 'Tidak disebut' : domain.labels[level],
              severe: severe,
              none: level == null,
            ),
            if (evidence.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Bukti: "$evidence"'),
            ],
          ],
        ),
      ),
    );
  }
}

class LevelChip extends StatelessWidget {
  const LevelChip({
    super.key,
    required this.label,
    this.severe = false,
    this.none = false,
  });

  final String label;
  final bool severe, none;

  @override
  Widget build(BuildContext context) {
    final fg = severe
        ? RelaColors.danger
        : (none ? RelaColors.muted : RelaColors.ink);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: severe
            ? RelaColors.sand
            : (none ? RelaColors.paper : RelaColors.cream),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: fg),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Kunjungan pertama: relawan memastikan lansia benar ada di alamat ini dan setuju didampingi (persetujuan langsung,
/// melengkapi verifikasi dokumen online). Tidak → ajukan berhenti mendampingi supaya yayasan menindaklanjuti.
Future<void> startStory(BuildContext context, Elder e) async {
  final nav = Navigator.of(context);
  Future<void> open() => nav.push(
    MaterialPageRoute(
      builder: (_) => VisitStoryScreen(elderId: e.id, elderName: e.fullName),
    ),
  );
  if (e.firstVisitAt != null) return open();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Kunjungan pertama'),
      content: Text(
        'Pastikan ${e.fullName} benar tinggal di alamat ini, dan tanyakan langsung apakah ia setuju '
        'didampingi relawan ReLa.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Tidak sesuai'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Lansia ada & setuju'),
        ),
      ],
    ),
  );
  if (ok == null || !context.mounted) return;
  if (!ok) {
    return requestStop(
      context,
      e,
      reason: 'Kunjungan pertama: lansia tidak ada di alamat atau tidak setuju didampingi',
    );
  }
  await Supabase.instance.client.rpc(
    'confirm_first_visit',
    params: {'p_elder_id': e.id},
  );
  await open();
}

/// Berhenti = permintaan ke yayasan (lansia tidak tiba-tiba tanpa pendamping). Sampai diterima — atau otomatis
/// setelah 7 hari — relawan tetap pendamping dan tetap bisa berkunjung.
Future<void> requestStop(
  BuildContext context,
  Elder e, {
  String? reason,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final c = TextEditingController(text: reason);
  final text = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Ajukan berhenti mendampingi ${e.fullName}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Sistem akan mencarikan relawan pengganti. Sampai permintaan diterima (paling lama 7 hari), Anda tetap '
            'pendamping. Setelah itu Anda tidak bisa melihat data lansia ini lagi.',
          ),
          TextField(
            key: const Key('alasan-berhenti'),
            controller: c,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Alasan untuk yayasan',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text.trim()),
          child: const Text('Kirim permintaan'),
        ),
      ],
    ),
  );
  if (text == null || text.length < 3) return;
  try {
    await Supabase.instance.client.functions.invoke(
      'pairing',
      body: {'action': 'request_stop', 'elder_id': e.id, 'reason': text},
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Permintaan berhenti dikirim ke yayasan.')),
    );
  } on FunctionException catch (err) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${(err.details as Map?)?['error'] ?? 'Gagal, coba lagi'}',
        ),
      ),
    );
  }
}
