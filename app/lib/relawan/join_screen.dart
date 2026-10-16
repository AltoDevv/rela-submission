import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/signup_screen.dart' show validateRequired;
import '../shared/location_picker.dart';
import '../shared/widgets.dart';
import 'home_screen.dart';

typedef JoinData = ({
  String foundationId,
  String fullName,
  String? nickname,
  DateTime birthDate,
  String area,
  double lat,
  double lng,
  List<String> days,
  List<String> languages,
  bool canDementia,
  bool canMobility,
  XFile photo,
});

const volunteerDays = ['senin', 'selasa', 'rabu', 'kamis', 'jumat', 'sabtu', 'minggu'];
const volunteerLanguages = ['indonesia', 'jawa', 'inggris'];
String _title(String s) => s[0].toUpperCase() + s.substring(1);

typedef Foundation = ({String id, String name});

/// Yayasan terverifikasi yang namanya cocok dengan [q] (RPC list_foundations; tanpa kode undangan).
Future<List<Foundation>> searchFoundations(String q) async =>
    ((await Supabase.instance.client.rpc('list_foundations', params: {'p_query': q})) as List)
        .map((m) => (id: (m as Map)['id'] as String, name: m['name'] as String))
        .toList();

/// Tautan undangan temansenja://join?code=... memilihkan yayasannya.
Future<Foundation?> foundationByCode(String code) async {
  final rows = (await Supabase.instance.client.rpc('foundation_by_code', params: {'p_code': code})) as List;
  return rows.isEmpty ? null : (id: (rows.first as Map)['id'] as String, name: rows.first['name'] as String);
}

/// Kode dari tautan undangan diingat di sini, supaya tetap terisi setelah relawan masuk atau mendaftar dulu.
String? pendingInviteCode;

/// OTP simulasi (PRD P2): kode tampil di layar, tidak dikirim lewat SMS.
String generateOtp() => (Random().nextInt(900000) + 100000).toString();

/// Foto wajah hanya dari kamera (PRD F1a), tidak dari galeri.
Future<XFile?> takeFacePhoto() => ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 800,
      imageQuality: 80,
    );

/// Unggah foto → RPC `join_foundation` (membuat volunteers berstatus terdaftar).
Future<void> joinFoundation(JoinData d) async {
  final db = Supabase.instance.client;
  final user = db.auth.currentUser;
  if (user == null) throw const PostgrestException(message: 'Masuk atau daftar sebagai relawan dulu. Kode undangan sudah diingat.');

  // Policy storage memakai folder per relawan: <user_id>/<file>.
  final path = '${user.id}/wajah.jpg';
  await db.storage.from('volunteer-photos').uploadBinary(
        path,
        await d.photo.readAsBytes(),
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
  await db.rpc('apply_foundation', params: {
    'p_foundation_id': d.foundationId,
    'p_full_name': d.fullName,
    'p_area_label': d.area,
    'p_lat': d.lat,
    'p_lng': d.lng,
    'p_available_days': d.days,
    'p_languages': d.languages,
    'p_can_dementia': d.canDementia,
    'p_can_mobility': d.canMobility,
    'p_photo_path': path,
  });
  // Ditampilkan ke keluarga (usia & nama panggilan); dikunci setelah verifikasi (profiles_guard).
  await db.from('profiles').update({
    'nickname': d.nickname,
    'birth_date': '${d.birthDate.year}-${d.birthDate.month.toString().padLeft(2, '0')}-${d.birthDate.day.toString().padLeft(2, '0')}',
  }).eq('id', user.id);
}

/// "dd/mm/yyyy" → tanggal, atau null bila tidak valid.
DateTime? parseBirthDate(String text) {
  final m = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$').firstMatch(text.trim());
  if (m == null) return null;
  final d = DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  return d.day == int.parse(m[1]!) && d.month == int.parse(m[2]!) && d.year >= 1900 ? d : null;
}

/// Usia minimal 18 tahun (ketentuan relawan; dicek ulang dari KTP saat verifikasi tatap muka).
String? validateBirthDate(String? v, {DateTime? now}) {
  final d = parseBirthDate(v ?? '');
  if (d == null) return 'Tulis tanggal lahir, mis. 17/08/2001';
  final n = now ?? DateTime.now();
  final age = n.year - d.year - ((n.month < d.month || (n.month == d.month && n.day < d.day)) ? 1 : 0);
  return age < 18 ? 'Relawan minimal berusia 18 tahun' : null;
}

/// F1a: OTP simulasi → pilih yayasan + profil → foto kamera → apply. Setelah itu relawan "Terdaftar" sampai datang
/// ke yayasan dan memasukkan kode verifikasi dari pengurus. [code] terisi bila dibuka dari temansenja://join?code=...
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, this.code, this.otp, this.takePhoto = takeFacePhoto, this.submit = joinFoundation, this.pickLocation = pickOnMap,
      this.search = searchFoundations, this.resolveCode = foundationByCode});

  final String? code;
  final String? otp; // tetap saat test; acak bila null
  final Future<XFile?> Function() takePhoto;
  final Future<void> Function(JoinData) submit;
  final PickLocation pickLocation;
  final Future<List<Foundation>> Function(String q) search;
  final Future<Foundation?> Function(String code) resolveCode;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  late final _otp = widget.otp ?? generateOtp();
  final _otpInput = TextEditingController();
  String? _otpError;
  bool _otpOk = false;

  final _form = GlobalKey<FormState>();
  Foundation? _foundation;
  final _name = TextEditingController();
  final _nickname = TextEditingController();
  final _birth = TextEditingController();
  final _area = TextEditingController();
  LatLng2? _loc; // titik tempat tinggal di peta (untuk jarak ke lansia)
  final _pickedDays = <String>{};
  final _pickedLanguages = <String>{};
  bool _canDementia = false;
  bool _canMobility = false;
  XFile? _photo;
  bool _showChoiceErrors = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.code != null) pendingInviteCode = widget.code;
    final code = widget.code ?? pendingInviteCode;
    if (code != null) {
      widget.resolveCode(code).then((f) {
        if (mounted && f != null && _foundation == null) setState(() => _foundation = f);
      }, onError: (_) {});
    }
  }

  Future<void> _pickFoundation() async {
    final f = await showDialog<Foundation>(context: context, builder: (_) => _FoundationPicker(search: widget.search));
    if (f != null) setState(() => _foundation = f);
  }

  @override
  void dispose() {
    for (final c in [_otpInput, _name, _nickname, _birth, _area]) {
      c.dispose();
    }
    super.dispose();
  }

  void _checkOtp() => setState(() {
        _otpOk = _otpInput.text.trim() == _otp;
        _otpError = _otpOk ? null : 'Kode OTP salah';
      });

  Future<void> _pickPhoto() async {
    final photo = await widget.takePhoto();
    if (photo != null) setState(() => _photo = photo);
  }

  Future<void> _join() async {
    final fieldsOk = _form.currentState!.validate();
    setState(() => _showChoiceErrors = true);
    if (!fieldsOk || _foundation == null || _pickedDays.isEmpty || _pickedLanguages.isEmpty || _photo == null) return;
    _loc ??= await widget.pickLocation(context, _area.text.trim(), null);
    if (_loc == null) {
      setState(() => _error = 'Pilih titik tempat tinggal di peta supaya Anda dipasangkan dengan lansia terdekat.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.submit((
        foundationId: _foundation!.id,
        fullName: _name.text.trim(),
        nickname: _nickname.text.trim().isEmpty ? null : _nickname.text.trim(),
        birthDate: parseBirthDate(_birth.text)!,
        area: _area.text.trim(),
        lat: _loc!.$1,
        lng: _loc!.$2,
        days: [for (final d in volunteerDays) if (_pickedDays.contains(d)) d],
        languages: [for (final l in volunteerLanguages) if (_pickedLanguages.contains(l)) l],
        canDementia: _canDementia,
        canMobility: _canMobility,
        photo: _photo!,
      ));
      pendingInviteCode = null;
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RelawanHomeScreen()),
        (_) => false,
      );
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } on StorageException catch (e) {
      setState(() => _error = 'Gagal mengunggah foto: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gabung ke yayasan'), actions: const [LogoutButton()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _otpOk ? _profileStep(context) : _otpStep(context),
      ),
    );
  }

  List<Widget> _otpStep(BuildContext context) => [
        if (widget.code != null) Text('Dari tautan undangan: ${_foundation?.name ?? widget.code}'),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.sms),
            title: const Text('SMS OTP (simulasi)'),
            subtitle: Text('Kode verifikasi nomor HP kamu: $_otp'),
          ),
        ),
        TextField(
          key: const Key('otp'),
          controller: _otpInput,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(labelText: 'Masukkan kode OTP', errorText: _otpError),
        ),
        FilledButton(onPressed: _checkOtp, child: const Text('Verifikasi')),
      ];

  List<Widget> _profileStep(BuildContext context) {
    final errorStyle = TextStyle(color: Theme.of(context).colorScheme.error);
    return [
      Form(
        key: _form,
        child: Column(children: [
          ListTile(
            key: const Key('yayasan'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.apartment),
            title: Text(_foundation?.name ?? 'Pilih yayasan tujuan'),
            subtitle: _foundation == null && _showChoiceErrors
                ? Text('Pilih yayasan dulu', style: errorStyle)
                : const Text('Anda akan diverifikasi tatap muka oleh pengurus yayasan ini.'),
            trailing: TextButton(onPressed: _pickFoundation, child: Text(_foundation == null ? 'Pilih' : 'Ganti')),
          ),
          TextFormField(
            key: const Key('nama'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nama lengkap'),
            validator: validateRequired,
          ),
          TextFormField(
            key: const Key('nama-panggilan'),
            controller: _nickname,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Nama panggilan (dilihat keluarga)', hintText: 'Mis. Kak Rina'),
          ),
          TextFormField(
            key: const Key('tanggal-lahir'),
            controller: _birth,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(labelText: 'Tanggal lahir', hintText: 'HH/BB/TTTT, mis. 17/08/2001'),
            validator: validateBirthDate,
          ),
          TextFormField(
            key: const Key('area'),
            controller: _area,
            decoration: const InputDecoration(labelText: 'Area tempat tinggal', hintText: 'Kotabaru, Yogyakarta'),
            validator: validateRequired,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.location_pin, color: _loc == null ? null : Colors.red),
            title: const Text('Titik tempat tinggal di peta'),
            subtitle: Text(_loc == null ? 'Belum dipilih' : 'Sudah dipilih'),
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
        ]),
      ),
      const SizedBox(height: 16),
      const Text('Hari tersedia'),
      Wrap(spacing: 8, children: [
        for (final d in volunteerDays)
          FilterChip(
            label: Text(_title(d)),
            selected: _pickedDays.contains(d),
            onSelected: (on) => setState(() => on ? _pickedDays.add(d) : _pickedDays.remove(d)),
          ),
      ]),
      if (_showChoiceErrors && _pickedDays.isEmpty) Text('Pilih minimal satu hari', style: errorStyle),
      const SizedBox(height: 8),
      const Text('Bahasa'),
      Wrap(spacing: 8, children: [
        for (final l in volunteerLanguages)
          FilterChip(
            label: Text(_title(l)),
            selected: _pickedLanguages.contains(l),
            onSelected: (on) => setState(() => on ? _pickedLanguages.add(l) : _pickedLanguages.remove(l)),
          ),
      ]),
      if (_showChoiceErrors && _pickedLanguages.isEmpty) Text('Pilih minimal satu bahasa', style: errorStyle),
      SwitchListTile(
        title: const Text('Mendampingi lansia dengan demensia'),
        value: _canDementia,
        onChanged: (v) => setState(() => _canDementia = v),
      ),
      SwitchListTile(
        title: const Text('Mendampingi lansia dengan mobilitas sulit'),
        value: _canMobility,
        onChanged: (v) => setState(() => _canMobility = v),
      ),
      OutlinedButton.icon(
        onPressed: _pickPhoto,
        icon: Icon(_photo == null ? Icons.camera_alt : Icons.check_circle),
        label: Text(_photo == null ? 'Ambil foto wajah (kamera)' : 'Foto wajah sudah diambil · ambil ulang'),
      ),
      if (_showChoiceErrors && _photo == null) Text('Foto wajah wajib diambil dari kamera', style: errorStyle),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: errorStyle)),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : _join,
        child: _busy ? const CircularProgressIndicator() : const Text('Gabung'),
      ),
    ];
  }
}

/// Cari yayasan terverifikasi berdasarkan nama.
class _FoundationPicker extends StatefulWidget {
  const _FoundationPicker({required this.search});

  final Future<List<Foundation>> Function(String q) search;

  @override
  State<_FoundationPicker> createState() => _FoundationPickerState();
}

class _FoundationPickerState extends State<_FoundationPicker> {
  late Future<List<Foundation>> _results = widget.search('');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pilih yayasan'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            key: const Key('cari-yayasan'),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Nama yayasan atau komunitas'),
            onChanged: (q) => setState(() { _results = widget.search(q); }),
          ),
          FutureBuilder<List<Foundation>>(
            future: _results,
            builder: (context, snap) {
              if (!snap.hasData) return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
              if (snap.data!.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('Tidak ditemukan.'));
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(shrinkWrap: true, children: [
                  for (final f in snap.data!)
                    ListTile(title: Text(f.name), onTap: () => Navigator.pop(context, f)),
                ]),
              );
            },
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal'))],
    );
  }
}
