import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/theme.dart';
import '../shared/widgets.dart';

/// Lokasi HP saat ini, atau null bila izin ditolak, GPS mati, atau lebih dari 10 detik.
/// Keadaan darurat tidak boleh tertahan oleh GPS, jadi kegagalan di sini tidak menghentikan apa pun.
Future<({double lat, double lng})?> currentLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
    );
    return (lat: p.latitude, lng: p.longitude);
  } catch (_) {
    return null;
  }
}

/// Edge Function `emergency`: simpan kejadian, push ke keluarga + yayasan, kembalikan profil kesehatan.
Future<Map<String, dynamic>> triggerEmergency(String elderId, double? lat, double? lng) async {
  final res = await Supabase.instance.client.functions
      .invoke('emergency', body: {'elder_id': elderId, 'lat': ?lat, 'lng': ?lng});
  return (res.data as Map).cast<String, dynamic>();
}

/// F8: tombol Darurat di Beranda → layar ini langsung meminta konfirmasi → GPS → simulasi panggilan 119 + profil
/// kesehatan. Batal di konfirmasi pertama menutup layar; tombol besar tetap ada untuk mencoba lagi bila gagal.
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key, required this.elderId, this.elderName, this.locate, this.trigger});

  final String elderId;
  final String? elderName;

  // Bisa diganti di test. Default: geolocator dan Edge Function `emergency`.
  final Future<({double lat, double lng})?> Function()? locate;
  final Future<Map<String, dynamic>> Function(String elderId, double? lat, double? lng)? trigger;

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _sending = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _press(closeOnCancel: true));
  }

  Future<void> _press({bool closeOnCancel = false}) async {
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aktifkan fitur darurat?',
            style: TextStyle(color: RelaColors.danger, fontWeight: FontWeight.w700)),
        content: const Text('Panggilan 119 akan disimulasikan dan keluarga serta yayasan akan diberi tahu '
            'beserta lokasi Anda.'),
        actions: [
          FilledButton(
            style: bigDanger,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, aktifkan darurat'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(style: bigOutlined, onPressed: () => Navigator.pop(context, false), child: const Text('Batalkan')),
        ],
      ),
    );
    if (ok != true) { // dibatalkan: tidak ada panggilan ke server
      if (closeOnCancel && mounted) nav.maybePop();
      return;
    }

    setState(() => _sending = true);
    try {
      final loc = await (widget.locate ?? currentLocation)();
      final res = await (widget.trigger ?? triggerEmergency)(widget.elderId, loc?.lat, loc?.lng);
      setState(() => _result = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Gagal mengirim. Telepon 119 dan keluarga langsung.'), action: SnackBarAction(label: 'Coba lagi', onPressed: _press)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.elderName == null ? 'Darurat' : 'Darurat · ${widget.elderName}')),
      body: _result != null
          ? _CallView(result: _result!, elderName: widget.elderName)
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                    'Tekan bila lansia butuh pertolongan segera. Panggilan ke 119 disimulasikan, '
                    'lalu keluarga dan yayasan menerima notifikasi berisi lokasi Anda.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: FilledButton(
                      key: const Key('tombol-darurat'),
                      style: FilledButton.styleFrom(backgroundColor: RelaColors.danger, shape: const CircleBorder()),
                      onPressed: _sending ? null : _press,
                      child: _sending
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('DARURAT', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }
}

/// Layar setelah konfirmasi: simulasi 119 + Profil Kesehatan Ringkas siap dibacakan ke operator.
class _CallView extends StatelessWidget {
  const _CallView({required this.result, this.elderName});

  final Map<String, dynamic> result;
  final String? elderName;

  @override
  Widget build(BuildContext context) {
    final h = (result['health'] as Map?)?.cast<String, dynamic>() ?? const {};
    final meds = ((h['medications'] as List?) ?? const [])
        .map((m) => '${(m as Map)['name']}${m['times'] != null ? ' (${m['times']})' : ''}')
        .join(', ');
    final rows = {
      'Kondisi': h['conditions'],
      'Alergi': h['allergies'],
      'Obat rutin': meds.isEmpty ? null : meds,
      'Pantangan makanan': h['diet_restrictions'],
      'Alat bantu': h['mobility_aids'],
      'Dokter langganan': h['doctor_hospital'],
      'Instruksi darurat': h['emergency_instructions'],
    };
    const white = TextStyle(color: Colors.white);
    const whiteBold = TextStyle(color: Colors.white, fontWeight: FontWeight.w700);
    final who = elderName ?? 'lansia';
    return ListView(padding: const EdgeInsets.all(24), children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(color: RelaColors.cream, borderRadius: BorderRadius.circular(16)),
        child: const Text('SIMULASI PROTOTYPE · bukan panggilan nyata',
            style: TextStyle(color: RelaColors.danger, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: RelaColors.danger, borderRadius: BorderRadius.circular(24)),
        child: const Row(children: [
          CircleAvatar(radius: 32, backgroundColor: Colors.white, child: Icon(Icons.phone_in_talk, color: RelaColors.danger, size: 32)),
          SizedBox(width: 20),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Memanggil 119…', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
              Text('tersambung (simulasi)', style: white),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bacakan kepada operator', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (h.isEmpty) const Text('Profil kesehatan belum diisi keluarga.'),
            for (final e in rows.entries)
              if (e.value != null && '${e.value}'.trim().isNotEmpty)
                Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• ${e.key}: ${e.value}')),
            const SizedBox(height: 8),
            const DisclaimerLabel(),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: RelaColors.primary, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            result['duplicate'] == true
                ? 'Darurat ini sudah dikirim beberapa menit lalu, jadi tidak dikirim ulang.'
                : result['notified'] == true
                    ? 'Keluarga dan yayasan sudah diberi tahu.'
                    : 'Notifikasi belum terkirim. Hubungi keluarga langsung.',
            style: whiteBold,
          ),
          const SizedBox(height: 8),
          Text(result['maps_url'] != null ? 'Lokasi Anda ikut dikirim.' : 'Lokasi tidak tersedia.', style: white),
          Text('Kejadian tersimpan di riwayat $who.', style: white),
        ]),
      ),
      const SizedBox(height: 16),
      OutlinedButton(style: bigOutlined, onPressed: () => Navigator.of(context).pop(), child: const Text('Kembali ke Beranda')),
    ]);
  }
}
