import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/signup_screen.dart' show validatePhone, validateRequired;
import '../shared/location_picker.dart';
import '../shared/models.dart';
import '../shared/terms_screen.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'ui.dart';
import 'verify_elder_screen.dart';

String? Function(String?) maxLength(int n, {bool required = false}) => (v) {
  if (required && validateRequired(v) != null) return 'Wajib diisi';
  return (v ?? '').trim().length > n ? 'Maksimal $n karakter' : null;
};

final _time = RegExp(r'(\d{1,2})[.:](\d{2})');

/// Satu obat per baris, misalnya "Metformin 500 mg 07.00, 19.00" → {name, times}.
List<Map<String, dynamic>> parseMedications(String text) => [
  for (final line in text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty))
    {
      'name': line.replaceAll(_time, '').replaceAll(RegExp(r'[\s,\-–:]+$'), '').trim(),
      'times': [for (final m in _time.allMatches(line)) '${m[1]!.padLeft(2, '0')}.${m[2]}'],
    },
];

/// Kebalikan [parseMedications], untuk mengisi form saat mengubah profil.
String medicationsToText(List<Map<String, dynamic>> meds) => [
  for (final m in meds) [m['name'], ...((m['times'] as List?) ?? const [])].join(' ').trim(),
].join('\n');

/// Baris obat (nama, jadwal) dari form langkah 3 → {name, times}. Jam (07.00) diambil dari jadwal; jadwal tanpa jam
/// (mis. "setiap pagi") disimpan apa adanya supaya tidak hilang.
List<Map<String, dynamic>> medicationsFromRows(List<(String, String)> rows) => [
  for (final (name, schedule) in rows)
    if (name.trim().isNotEmpty)
      {
        'name': name.trim(),
        'times': _time.hasMatch(schedule)
            ? [for (final m in _time.allMatches(schedule)) '${m[1]!.padLeft(2, '0')}.${m[2]}']
            : [if (schedule.trim().isNotEmpty) schedule.trim()],
      },
];

/// Pengambil foto lansia (galeri atau kamera); diganti di test.
typedef PickPhoto = Future<XFile?> Function(BuildContext context);

Future<XFile?> pickElderPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_camera),
          title: const Text('Ambil foto'),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: const Text('Pilih dari galeri'),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (source == null) return null;
  return ImagePicker().pickImage(source: source, maxWidth: 800, imageQuality: 80);
}

final _contact = RegExp(r'^Kontak keluarga: (.+?) (\+?\d+)\.\s*(.*)$', dotAll: true);

/// `emergency_instructions` diawali "Kontak keluarga: Nama HP." (lihat _save). Mengembalikan (nama, hp, sisa).
(String, String, String) splitContact(String? text) {
  final m = _contact.firstMatch(text ?? '');
  return m == null ? ('', '', text ?? '') : (m[1]!, m[2]!, m[3]!);
}

/// F1: keluarga mendaftarkan lansia beserta Profil Kesehatan Ringkas, lalu sistem langsung mengusulkan relawan.
class RegisterElderScreen extends StatefulWidget {
  const RegisterElderScreen({
    super.key,
    this.pickLocation = pickOnMap,
    this.pickPhoto = pickElderPhoto,
    this.reverse = nearestLabel,
    this.elder,
    this.health,
  });

  /// Titik rumah dipilih di peta (bukan ditebak dari teks alamat), supaya jarak ke relawan akurat.
  final PickLocation pickLocation;
  final PickPhoto pickPhoto;
  final Future<String?> Function(LatLng2 p) reverse; // alamat dari titik peta

  /// Diisi untuk mode ubah (data dan profil kesehatan lansia yang sudah terdaftar).
  final Elder? elder;
  final HealthProfile? health;

  @override
  State<RegisterElderScreen> createState() => _RegisterElderScreenState();
}

class _RegisterElderScreenState extends State<RegisterElderScreen> {
  final _form = GlobalKey<FormState>();
  final _c = {
    for (final k in [
      'nama',
      'alamat',
      'kontak_nama',
      'kontak_hp',
      'kebutuhan',
      'kondisi',
      'alergi',
      'obat',
      'pantangan',
      'gerak',
      'alat',
      'dokter',
      'darurat',
    ])
      k: TextEditingController(),
  };
  bool _dementia = false;
  bool _mobility = false;
  bool _chronic = false;
  bool _busy = false;
  String? _consent; // 'lansia' atau 'wali' (wajib saat mendaftarkan, UU PDP)
  LatLng2? _loc; // titik rumah di peta
  String? _locForAddress; // alamat saat titik dipilih; alamat diubah → titik dikonfirmasi ulang
  int _step = 0; // 0..4 (Figma: Registrasi Lansia · Langkah 1–5)
  DateTime? _birth;
  XFile? _photo; // foto baru (diunggah setelah lansia tersimpan)
  final List<(TextEditingController, TextEditingController)> _meds = [];

  void _addMed([String name = '', String schedule = '']) =>
      _meds.add((TextEditingController(text: name), TextEditingController(text: schedule)));

  List<Map<String, dynamic>> get _medications => medicationsFromRows([for (final (n, t) in _meds) (n.text, t.text)]);

  bool get _editing => widget.elder != null;

  @override
  void initState() {
    super.initState();
    final e = widget.elder, h = widget.health;
    for (final m in h?.medications ?? const <Map<String, dynamic>>[]) {
      _addMed('${m['name'] ?? ''}', ((m['times'] as List?) ?? const []).join(', '));
    }
    if (_meds.isEmpty) _addMed();
    if (e == null) return;
    _birth = e.birthDate;
    final (contactName, contactPhone, rest) = splitContact(h?.emergencyInstructions);
    final values = {
      'nama': e.fullName, 'alamat': e.address, 'kebutuhan': e.needs, 'kontak_nama': contactName,
      'kontak_hp': contactPhone, 'kondisi': h?.conditions, 'alergi': h?.allergies,
      'pantangan': h?.dietRestrictions, 'gerak': h?.mobility, 'alat': h?.mobilityAids,
      'dokter': h?.doctorHospital, 'darurat': rest,
    };
    values.forEach((k, v) => _c[k]!.text = v ?? '');
    _dementia = e.hasDementia;
    _mobility = e.hasMobilityIssue;
    _chronic = h?.hasChronic ?? false;
    if (e.lat != null && e.lng != null) {
      _loc = (e.lat!, e.lng!);
      _locForAddress = e.address;
    }
  }

  /// Membuka peta (kotak cari terisi alamat). true bila titik dipilih.
  Future<bool> _pickLoc() async {
    final p = await widget.pickLocation(context, _c['alamat']!.text.trim(), _loc);
    if (p == null || !mounted) return false;
    final address = await fillAddressFromPin(context, _c['alamat']!, p, reverse: widget.reverse);
    setState(() {
      _loc = p;
      _locForAddress = address;
    });
    return true;
  }

  /// Titik yang berlaku untuk alamat saat ini; bila belum ada atau alamat berubah, peta dibuka dulu.
  Future<LatLng2?> _ensureLoc() async {
    if (_loc != null && _locForAddress == _text('alamat')) return _loc;
    if (!await _pickLoc()) {
      _say('Titik lokasi rumah belum dipilih. Pilih di peta supaya relawan terdekat bisa dicarikan.');
      return null;
    }
    return _loc;
  }

  String? _text(String key) => _c[key]!.text.trim().isEmpty ? null : _c[key]!.text.trim();

  void _say(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!_editing && _consent == null) {
      _say('Pilih persetujuan lansia terlebih dahulu.');
      return;
    }
    final nav = Navigator.of(context); // diambil sebelum await, karena layar ini ditutup setelah tersimpan
    setState(() => _busy = true);
    try {
      if (_editing) return await _update(nav);
      final loc = await _ensureLoc();
      if (loc == null) return;
      final db = Supabase.instance.client;
      final elder = await db
          .from('elders')
          .insert({
            'family_id': db.auth.currentUser!.id,
            'full_name': _text('nama'),
            'address': _text('alamat'),
            'lat': loc.$1,
            'lng': loc.$2,
            'needs': _text('kebutuhan'),
            'has_dementia': _dementia,
            'has_mobility_issue': _mobility,
            'birth_date': _birthIso,
            'consent_type': _consent, // siapa dan kapan diisi trigger database
          })
          .select('id')
          .single();

      // Tabel elders tidak punya kolom kontak, jadi kontak keluarga disimpan di awal instruksi darurat.
      final contact =
          'Kontak keluarga: ${_text('kontak_nama')} ${_text('kontak_hp')!.replaceAll(RegExp(r'[\s-]'), '')}.';
      await db.from('health_profiles').insert({
        'elder_id': elder['id'],
        'conditions': _text('kondisi'),
        'allergies': _text('alergi'),
        'medications': _medications,
        'diet_restrictions': _text('pantangan'),
        'mobility': _text('gerak'),
        'mobility_aids': _text('alat'),
        'doctor_hospital': _text('dokter'),
        'emergency_instructions': [contact, _text('darurat')].nonNulls.join(' '),
        'has_chronic': _chronic,
      });
      await _uploadPhoto(elder['id'] as String);
      // Lanjut ke langganan + dokumen verifikasi; relawan dicarikan setelah itu (VerifyElderScreen).
      await nav.pushReplacement(MaterialPageRoute(
          builder: (_) => VerifyElderScreen(elderId: elder['id'] as String, elderName: _text('nama')!)));
    } on PostgrestException catch (e) {
      _say('Gagal menyimpan: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? get _birthIso => _birth == null
      ? null
      : '${_birth!.year}-${_birth!.month.toString().padLeft(2, '0')}-${_birth!.day.toString().padLeft(2, '0')}';

  /// Foto lansia ke bucket privat `elder-photos/<id>/foto.jpg`. Gagal unggah tidak membatalkan pendaftaran.
  Future<void> _uploadPhoto(String elderId) async {
    final photo = _photo;
    if (photo == null) return;
    try {
      final db = Supabase.instance.client;
      final path = '$elderId/foto.jpg';
      await db.storage.from('elder-photos').uploadBinary(path, await photo.readAsBytes(),
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
      await db.from('elders').update({'photo_path': path}).eq('id', elderId);
    } catch (_) {
      _say('Foto lansia gagal diunggah. Bisa diulang dari Edit.');
    }
  }

  /// Mode ubah: titik lokasi dikonfirmasi ulang di peta hanya bila alamat berubah. Bila kebutuhan (demensia/mobilitas) berubah dan
  /// relawan tidak mampu, trigger database meneruskan lansia ke yayasan (perlu_yayasan).
  Future<void> _update(NavigatorState nav) async {
    final e = widget.elder!;
    final loc = await _ensureLoc();
    if (loc == null) return;
    final db = Supabase.instance.client;
    final updated = await db.from('elders').update({
      'full_name': _text('nama'),
      'address': _text('alamat'),
      'lat': loc.$1,
      'lng': loc.$2,
      'needs': _text('kebutuhan'),
      'has_dementia': _dementia,
      'has_mobility_issue': _mobility,
      'birth_date': _birthIso,
    }).eq('id', e.id).select('pairing_state').single();
    final contact =
        'Kontak keluarga: ${_text('kontak_nama')} ${_text('kontak_hp')!.replaceAll(RegExp(r'[\s-]'), '')}.';
    await db.from('health_profiles').upsert({
      'elder_id': e.id,
      'conditions': _text('kondisi'),
      'allergies': _text('alergi'),
      'medications': _medications,
      'diet_restrictions': _text('pantangan'),
      'mobility': _text('gerak'),
      'mobility_aids': _text('alat'),
      'doctor_hospital': _text('dokter'),
      'emergency_instructions': [contact, _text('darurat')].nonNulls.join(' '),
      'has_chronic': _chronic,
    });
    await _uploadPhoto(e.id);
    final released = e.pairingState == 'berpasangan' && updated['pairing_state'] == 'perlu_yayasan';
    _say(released
        ? 'Tersimpan. Relawan saat ini belum mampu mendampingi kebutuhan baru, jadi yayasan akan mencarikan pengganti.'
        : 'Perubahan tersimpan.');
    nav.pop(true);
  }

  Widget _field(
    String key,
    String label, {
    String? Function(String?)? validator,
    int maxLines = 1,
    String? hint,
    TextInputType? keyboard,
  }) {
    return TextFormField(
      key: Key(key),
      controller: _c[key],
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: validator ?? maxLength(500),
      maxLines: maxLines,
      keyboardType: keyboard,
    );
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    for (final (a, b) in _meds) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  static const _titles = ['Informasi Dasar', 'Kebutuhan Pendampingan', 'Alergi dan Obat', 'Mobilitas dan Dokter', 'Instruksi Darurat'];

  void _next() {
    if (!_form.currentState!.validate()) return;
    if (_step < 4) {
      setState(() => _step++);
    } else {
      _save();
    }
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 70),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Tanggal lahir lansia',
    );
    if (d != null) setState(() => _birth = d);
  }

  Widget _label(String text) =>
      Padding(padding: const EdgeInsets.only(top: 16, bottom: 6), child: Text(text, style: const TextStyle(fontSize: 16)));

  Widget _yesNo(String key, String label, bool value, ValueChanged<bool> onChanged) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          Wrap(spacing: 12, children: [
            for (final (v, text) in [(true, 'Ya'), (false, 'Tidak')])
              ChoiceChip(
                key: Key('$key-${v ? 'ya' : 'tidak'}'),
                label: Text(text),
                selected: value == v,
                showCheckmark: false,
                selectedColor: RelaColors.primary,
                labelStyle: TextStyle(color: value == v ? Colors.white : RelaColors.ink, fontSize: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                onSelected: (_) => onChanged(v),
              ),
          ]),
        ],
      );

  static const _disclaimer = Padding(
    padding: EdgeInsets.only(top: 8),
    child: DecoratedBox(
      decoration: BoxDecoration(color: Color(0xFFF8E6B8), borderRadius: BorderRadius.all(Radius.circular(16))),
      child: Padding(padding: EdgeInsets.all(16), child: DisclaimerLabel()),
    ),
  );

  List<Widget> _stepFields() {
    switch (_step) {
      case 0:
        return [
          _label('Nama lansia'),
          _field('nama', 'Nama lansia', validator: maxLength(100, required: true)),
          _label('Usia / tanggal lahir'),
          InkWell(
            key: const Key('tanggal-lahir'),
            onTap: _pickBirth,
            child: InputDecorator(
              decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined)),
              child: Text(_birth == null ? 'Pilih tanggal lahir' : '${ageFrom(_birth!)} tahun · ${longDate(_birth!)}'),
            ),
          ),
          _label('Alamat'),
          _field('alamat', 'Alamat lengkap',
              validator: maxLength(300, required: true), maxLines: 2, hint: 'Jalan, nomor, RT/RW, patokan, kelurahan, kota'),
          ListTile(
            key: const Key('titik-lokasi'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.location_pin, color: _loc == null ? null : Colors.red),
            title: const Text('Titik lokasi rumah di peta'),
            subtitle: Text(_loc == null
                ? 'Belum dipilih · dipakai untuk mencarikan relawan terdekat'
                : '${_loc!.$1.toStringAsFixed(5)}, ${_loc!.$2.toStringAsFixed(5)}'
                    '${_locForAddress == _c['alamat']!.text.trim() ? '' : ' · alamat berubah, konfirmasi ulang saat simpan'}'),
            trailing: TextButton(onPressed: _pickLoc, child: Text(_loc == null ? 'Pilih di peta' : 'Ubah')),
          ),
          _label('Kontak keluarga'),
          _field('kontak_nama', 'Nama kontak keluarga', validator: maxLength(100, required: true)),
          const SizedBox(height: 8),
          _field('kontak_hp', 'Nomor HP kontak keluarga', validator: validatePhone, keyboard: TextInputType.phone),
          _label('Foto lansia'),
          InkWell(
            key: const Key('foto-lansia'),
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              final p = await widget.pickPhoto(context);
              if (p != null) setState(() => _photo = p);
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: RelaColors.border, width: 1.5),
              ),
              child: Column(children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: RelaColors.cream,
                  child: Icon(_photo == null ? Icons.add : Icons.check, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(_photo == null ? (widget.elder?.photoPath == null ? 'Tambahkan foto' : 'Ganti foto') : 'Foto dipilih',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const Text('Unggah foto lansia untuk memudahkan identifikasi',
                    textAlign: TextAlign.center, style: TextStyle(color: RelaColors.muted)),
              ]),
            ),
          ),
        ];
      case 1:
        return [
          _disclaimer,
          _label('Kebutuhan pendampingan'),
          _field('kebutuhan', 'Kebutuhan pendampingan', maxLines: 2, hint: 'Ditemani mengobrol, bantu minum obat'),
          _label('Kondisi atau penyakit yang dimiliki'),
          _field('kondisi', 'Kondisi atau penyakit', maxLines: 2, hint: 'Hipertensi'),
          _yesNo('kronis', 'Ada penyakit kronis? (hanya jawaban ini yang terlihat oleh yayasan)', _chronic,
              (v) => setState(() => _chronic = v)),
          _yesNo('demensia', 'Demensia', _dementia, (v) => setState(() => _dementia = v)),
          _yesNo('mobilitas', 'Kesulitan mobilitas', _mobility, (v) => setState(() => _mobility = v)),
        ];
      case 2:
        return [
          _disclaimer,
          _label('Alergi'),
          _field('alergi', 'Alergi', hint: 'Udang'),
          for (final (i, (name, schedule)) in _meds.indexed) ...[
            _label(_meds.length == 1 ? 'Obat rutin' : 'Obat rutin ${i + 1}'),
            TextFormField(
              key: Key('obat-$i'),
              controller: name,
              decoration: const InputDecoration(labelText: 'Nama obat', hintText: 'Amlodipin 5 mg'),
              validator: maxLength(200),
            ),
            _label('Jadwal konsumsi'),
            TextFormField(
              key: Key('jadwal-$i'),
              controller: schedule,
              decoration: const InputDecoration(labelText: 'Jadwal', hintText: 'Setiap pagi pukul 08.00'),
              validator: maxLength(200),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('tambah-obat'),
              icon: const Icon(Icons.add),
              label: const Text('Tambah obat'),
              onPressed: () => setState(_addMed),
            ),
          ),
          _label('Pantangan makanan'),
          _field('pantangan', 'Pantangan makanan', hint: 'Makanan asin, santan kental'),
        ];
      case 3:
        return [
          _disclaimer,
          _label('Kemampuan bergerak'),
          _field('gerak', 'Kemampuan bergerak', hint: 'Berjalan pelan, perlu pegangan'),
          _label('Alat bantu'),
          _field('alat', 'Alat bantu', hint: 'Tongkat'),
          _label('Dokter atau rumah sakit langganan'),
          _field('dokter', 'Dokter atau RS langganan', hint: 'RS Harapan Kita · dr. Lukman'),
        ];
      default:
        final summary = [
          [_text('nama'), if (_birth != null) '${ageFrom(_birth!)} tahun'].nonNulls.join(', '),
          [_text('kondisi'), if (_dementia) 'demensia', if (_mobility) 'kesulitan mobilitas'].nonNulls.join(', '),
          if (_text('alergi') != null) 'alergi ${_text('alergi')}',
        ].where((x) => x.isNotEmpty).join(' · ');
        return [
          _disclaimer,
          _label('Instruksi darurat'),
          _field('darurat', 'Instruksi darurat', maxLines: 3, hint: 'Hubungi Hendra, bawa ke RS Harapan Kita, bawa kartu BPJS'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: RelaColors.cream, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ringkasan', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('$summary.'),
            ]),
          ),
          if (!_editing) ...[
            _label('Persetujuan lansia'),
            RadioGroup<String>(
              groupValue: _consent,
              onChanged: (v) => setState(() => _consent = v),
              child: const Column(children: [
                RadioListTile<String>(
                  value: 'lansia',
                  contentPadding: EdgeInsets.zero,
                  title: Text('Lansia sudah saya jelaskan tentang layanan ini dan ia setuju'),
                ),
                RadioListTile<String>(
                  value: 'wali',
                  contentPadding: EdgeInsets.zero,
                  title: Text('Lansia tidak bisa memberi persetujuan (mis. demensia); saya bertindak sebagai walinya'),
                ),
              ]),
            ),
            Align(alignment: Alignment.centerLeft, child: termsLink(context)),
          ],
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _step == 4;
    return Scaffold(
      appBar: AppBar(),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Text('${_editing ? 'Ubah Data Lansia' : 'Registrasi Lansia'} · Langkah ${_step + 1} dari 5',
                style: const TextStyle(color: RelaColors.muted)),
            const SizedBox(height: 6),
            Text(_titles[_step], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Container(
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: i <= _step ? RelaColors.primary : const Color(0xFFF1E4DA),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ]),
            const Divider(height: 32),
            ..._stepFields(),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('lanjut'),
              style: bigFilled,
              onPressed: _busy ? null : _next,
              child: Text(!last
                  ? 'Lanjut'
                  : _busy
                      ? 'Menyimpan…'
                      : _editing
                          ? 'Simpan perubahan'
                          : 'Simpan dan Lihat Rekomendasi'),
            ),
            if (_step > 0) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                style: bigOutlined.copyWith(foregroundColor: const WidgetStatePropertyAll(RelaColors.primary)),
                onPressed: () => setState(() => _step--),
                child: const Text('Kembali'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
