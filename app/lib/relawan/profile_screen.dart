import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/location_picker.dart';
import '../shared/models.dart';
import 'join_screen.dart' show volunteerDays, volunteerLanguages;

String _cap(String s) => s[0].toUpperCase() + s.substring(1);

/// Relawan memperbarui area & titik tempat tinggal (pindah rumah), hari tersedia, bahasa, dan keahlian. Menambah keahlian (demensia/mobilitas) membuat status
/// kembali "terdaftar" sampai yayasan memverifikasi ulang; mencabut keahlian yang dibutuhkan lansia pasangan
/// membuat lansia itu diteruskan ke yayasan (aturan di trigger database).
class VolunteerProfileScreen extends StatefulWidget {
  const VolunteerProfileScreen({super.key, this.pickLocation = pickOnMap});

  final PickLocation pickLocation;

  @override
  State<VolunteerProfileScreen> createState() => _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  final _db = Supabase.instance.client;
  late final Future<Volunteer> _me = _load();
  Set<String> _days = {}, _langs = {};
  bool _dementia = false, _mobility = false, _busy = false;
  Volunteer? _orig;
  final _area = TextEditingController();
  LatLng2? _loc;

  Future<Volunteer> _load() async {
    final v = Volunteer.fromMap(await _db.from('volunteers').select().eq('id', _db.auth.currentUser!.id).single());
    _orig = v;
    _days = v.availableDays.toSet();
    _langs = v.languages.toSet();
    _dementia = v.canDementia;
    _mobility = v.canMobility;
    _area.text = v.areaLabel ?? '';
    if (v.lat != null && v.lng != null) _loc = (v.lat!, v.lng!);
    return v;
  }

  @override
  void dispose() {
    _area.dispose();
    super.dispose();
  }

  bool get _addsSkill => (_dementia && !_orig!.canDementia) || (_mobility && !_orig!.canMobility);

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await _db.from('volunteers').update({
        'area_label': _area.text.trim(),
        if (_loc != null) 'lat': _loc!.$1,
        if (_loc != null) 'lng': _loc!.$2,
        'available_days': volunteerDays.where(_days.contains).toList(),
        'languages': volunteerLanguages.where(_langs.contains).toList(),
        'can_dementia': _dementia,
        'can_mobility': _mobility,
      }).eq('id', _orig!.id);
      messenger.showSnackBar(SnackBar(
          content: Text(_addsSkill
              ? 'Tersimpan. Keahlian baru perlu diverifikasi ulang oleh pengurus yayasan sebelum Anda diusulkan lagi.'
              : 'Profil tersimpan.')));
      nav.pop();
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal: ${e.message}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil saya')),
      body: FutureBuilder<Volunteer>(
        future: _me,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Gagal memuat: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(padding: const EdgeInsets.all(16), children: [
            TextField(
              controller: _area,
              maxLength: 100,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Area tempat tinggal', hintText: 'Kotabaru, Yogyakarta'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.location_pin, color: _loc == null ? null : Colors.red),
              title: const Text('Titik tempat tinggal di peta'),
              subtitle: const Text('Dipakai untuk mencarikan lansia terdekat.'),
              trailing: TextButton(
                onPressed: () async {
                  final p = await widget.pickLocation(context, _area.text.trim(), _loc);
                  if (p == null || !context.mounted) return;
                  await fillAddressFromPin(context, _area, p);
                  setState(() => _loc = p);
                },
                child: Text(_loc == null ? 'Pilih di peta' : 'Ubah'),
              ),
            ),
            const SizedBox(height: 16),
            Text('Hari tersedia', style: Theme.of(context).textTheme.titleMedium),
            Wrap(spacing: 8, children: [
              for (final d in volunteerDays)
                FilterChip(
                  label: Text(_cap(d)),
                  selected: _days.contains(d),
                  onSelected: (on) => setState(() => on ? _days.add(d) : _days.remove(d)),
                ),
            ]),
            const SizedBox(height: 16),
            Text('Bahasa', style: Theme.of(context).textTheme.titleMedium),
            Wrap(spacing: 8, children: [
              for (final l in volunteerLanguages)
                FilterChip(
                  label: Text(_cap(l)),
                  selected: _langs.contains(l),
                  onSelected: (on) => setState(() => on ? _langs.add(l) : _langs.remove(l)),
                ),
            ]),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Mampu mendampingi lansia dengan demensia'),
              value: _dementia,
              onChanged: (v) => setState(() => _dementia = v),
            ),
            SwitchListTile(
              title: const Text('Mampu membantu lansia dengan mobilitas sulit'),
              value: _mobility,
              onChanged: (v) => setState(() => _mobility = v),
            ),
            if (_addsSkill)
              const Text('Menambah keahlian membuat Anda perlu diverifikasi ulang oleh pengurus yayasan.',
                  style: TextStyle(color: Colors.orange)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy || _days.isEmpty || _langs.isEmpty || _area.text.trim().isEmpty ? null : _save,
              child: Text(_busy ? 'Menyimpan…' : 'Simpan'),
            ),
          ]);
        },
      ),
    );
  }
}
