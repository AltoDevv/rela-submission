import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Titik lokasi (lat, lng).
typedef LatLng2 = (double, double);

/// Membuka pemilih lokasi. [query] mengisi kotak cari (mis. alamat yang sudah diketik), [initial] posisi awal pin.
/// Mengembalikan titik yang dipilih, atau null bila dibatalkan. Diganti di test.
typedef PickLocation = Future<LatLng2?> Function(BuildContext context, String query, LatLng2? initial);

Future<LatLng2?> pickOnMap(BuildContext context, String query, LatLng2? initial) => Navigator.of(context).push<LatLng2>(
  MaterialPageRoute(
    builder: (_) => LocationPickerScreen(query: query, initial: initial),
  ),
);

typedef Place = ({String name, String detail, double lat, double lng});

// Photon (komoot): pencarian OpenStreetMap gratis tanpa API key, mendukung saran saat mengetik.
// ponytail: server publik dengan batas pemakaian wajar; bila ramai, jalankan Photon sendiri atau ganti ke Google Places.
const _photon = 'https://photon.komoot.io';
const _indonesiaBbox = '94.7,-11.2,141.2,6.3'; // minLon,minLat,maxLon,maxLat

/// GeoJSON Photon → daftar tempat. Fungsi murni supaya bisa dites.
List<Place> parsePhoton(Map<String, dynamic> json) => [
  for (final f in (json['features'] as List? ?? const []).cast<Map>())
    if ((f['geometry']?['coordinates'] as List?)?.length == 2)
      () {
        final p = (f['properties'] as Map? ?? const {}).cast<String, dynamic>();
        final c = f['geometry']['coordinates'] as List;
        final street = [p['street'], p['housenumber']].whereType<String>().join(' ');
        final name = (p['name'] as String?) ?? (street.isEmpty ? 'Tanpa nama' : street);
        final detail = [
          if (p['name'] != null && street.isNotEmpty) street,
          p['district'],
          p['city'] ?? p['county'],
          p['state'],
        ].whereType<String>().where((s) => s.isNotEmpty && s != name).toSet().join(', ');
        return (name: name, detail: detail, lat: (c[1] as num).toDouble(), lng: (c[0] as num).toDouble());
      }(),
];

/// Singkatan alamat yang tidak dikenali OpenStreetMap ("jl" tidak menemukan "Jalan …").
String normalizeQuery(String q) => q
    .replaceAllMapped(RegExp(r'\b(jl|jln)\b\.?', caseSensitive: false), (_) => 'jalan')
    .replaceAllMapped(RegExp(r'\bgg\b\.?', caseSensitive: false), (_) => 'gang')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Urutan kata kunci untuk alamat lengkap: nomor rumah/RT/RW dibuang (OSM jarang punya), lalu bila tetap tidak
/// ketemu, bagian depan dibuang satu per satu sampai tersisa wilayah (mis. "Caturtunggal, Depok, Sleman").
List<String> searchQueries(String q) {
  final clean = normalizeQuery(
    q
        .replaceAll(RegExp(r'\b(no|nomor)\.?\s*\d+\w*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(rt|rw)\.?\s*\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b\d{1,3}\s*/\s*\d{1,3}\b'), '')
        .replaceAll(RegExp(r'\b(kel|kec|kab|desa|kelurahan|kecamatan|kabupaten)\b\.?', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*,\s*(,\s*)*'), ', '),
  ).replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '');
  final parts = clean.split(', ').where((p) => p.isNotEmpty).toList();
  return [for (var i = 0; i < parts.length && i < 3; i++) parts.sublist(i).join(', ')]
      .where((x) => x.length >= 3)
      .toList();
}

/// Satu objek OSM sering muncul beberapa kali (gedung, titik, area): nama + detail sama dalam ±300 m dibuang.
List<Place> dedupePlaces(List<Place> places) {
  final out = <Place>[];
  for (final p in places) {
    final dup = out.any(
      (o) => o.name == p.name && o.detail == p.detail && (o.lat - p.lat).abs() < 0.003 && (o.lng - p.lng).abs() < 0.003,
    );
    if (!dup) out.add(p);
  }
  return out;
}

/// Saran tempat di Indonesia untuk [q], diutamakan yang dekat [near]. Alamat lengkap dicoba bertahap ([searchQueries]).
/// Semua tahap dikirim bersamaan (server publik bisa lambat); hasil tahap paling rinci yang tidak kosong dipakai.
/// Hasil disimpan di memori, jadi mengetik ulang kata yang sama langsung muncul.
Future<List<Place>> searchPlaces(String q, {LatLng2? near}) async {
  final key = '${q.trim().toLowerCase()}|${near?.$1.toStringAsFixed(2)},${near?.$2.toStringAsFixed(2)}';
  if (_cache[key] case final hit?) return hit;
  final all = await Future.wait([
    for (final query in searchQueries(q))
      http
          .get(
            Uri.parse('$_photon/api/').replace(
              queryParameters: {
                'q': query,
                'limit': '8',
                'bbox': _indonesiaBbox,
                if (near != null) ...{'lat': '${near.$1}', 'lon': '${near.$2}'},
              },
            ),
            headers: {'User-Agent': 'ReLa (id.temansenja.app)'},
          )
          .timeout(searchTimeout)
          .then((res) {
            if (res.statusCode != 200) throw Exception('Pencarian gagal (${res.statusCode})');
            return dedupePlaces(parsePhoton(jsonDecode(res.body) as Map<String, dynamic>));
          }),
  ]);
  final found = all.firstWhere((r) => r.isNotEmpty, orElse: () => []);
  if (_cache.length > 100) _cache.clear();
  return _cache[key] = found;
}

const searchTimeout = Duration(seconds: 12);
final _cache = <String, List<Place>>{};

/// Nama jalan/tempat terdekat dari titik pin, untuk konfirmasi ("Dekat: …").
Future<String?> nearestLabel(LatLng2 p) async {
  try {
    final res = await http
        .get(
          Uri.parse('$_photon/reverse?lat=${p.$1}&lon=${p.$2}&limit=1'),
          headers: {'User-Agent': 'ReLa (id.temansenja.app)'},
        )
        .timeout(searchTimeout);
    final places = parsePhoton(jsonDecode(res.body) as Map<String, dynamic>);
    return places.isEmpty ? null : [places.first.name, places.first.detail].where((s) => s.isNotEmpty).join(', ');
  } catch (_) {
    return null;
  }
}

/// Alamat mengikuti titik yang dipilih di peta (keputusan pengguna 16 Okt): kolom kosong langsung diisi; bila sudah
/// berisi, diganti dengan alamat dari peta dan bisa diurungkan lewat snackbar. Mengembalikan teks akhir kolom.
Future<String> fillAddressFromPin(
  BuildContext context,
  TextEditingController field,
  LatLng2 p, {
  Future<String?> Function(LatLng2 p) reverse = nearestLabel,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final label = await reverse(p);
  if (label == null || label.trim().isEmpty || label.trim() == field.text.trim()) return field.text.trim();
  final before = field.text;
  field.text = label;
  if (before.trim().isNotEmpty) {
    messenger.showSnackBar(SnackBar(
      content: const Text('Alamat diisi dari titik peta. Lengkapi nomor rumah/RT bila perlu.'),
      action: SnackBarAction(label: 'Urungkan', onPressed: () => field.text = before),
    ));
  }
  return field.text.trim();
}

/// Lokasi HP tidak bisa dibaca: [message] untuk pengguna, [fix] membuka pengaturan yang perlu diubah.
class LocationIssue implements Exception {
  const LocationIssue(this.message, [this.fixLabel, this.fix]);
  final String message;
  final String? fixLabel;
  final Future<bool> Function()? fix;
}

/// Posisi HP (meminta izin bila belum). Melempar [LocationIssue] bila GPS mati, izin ditolak, atau tidak ada sinyal.
Future<LatLng2?> phoneLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationIssue('Lokasi (GPS) HP sedang mati.', 'Nyalakan', Geolocator.openLocationSettings);
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
  if (perm == LocationPermission.deniedForever) {
    throw const LocationIssue('Izin lokasi untuk ReLa ditolak.', 'Buka izin', Geolocator.openAppSettings);
  }
  if (perm == LocationPermission.denied) throw const LocationIssue('Izin lokasi ditolak.');
  try {
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
    return (p.latitude, p.longitude);
  } catch (_) {
    final last = await Geolocator.getLastKnownPosition(); // di dalam rumah GPS sering lama
    if (last != null) return (last.latitude, last.longitude);
    throw const LocationIssue('Sinyal GPS belum didapat. Coba dekat jendela atau cari alamat.');
  }
}

/// Seperti Gojek: ketik nama tempat → pilih saran → geser peta sampai pin tepat di rumah → Pilih lokasi ini.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.query = '',
    this.initial,
    this.search = searchPlaces,
    this.reverse = nearestLabel,
    this.locate = phoneLocation,
    this.showTiles = true,
  });

  final String query;
  final LatLng2? initial;
  final Future<List<Place>> Function(String q, {LatLng2? near}) search;
  final Future<String?> Function(LatLng2 p) reverse;
  final Future<LatLng2?> Function() locate;
  final bool showTiles; // false di test (tanpa internet)

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _indonesia = LatLng(-2.5, 118.0);
  final _map = MapController();
  late final _q = TextEditingController(text: widget.query);
  late LatLng _center = widget.initial == null ? _indonesia : LatLng(widget.initial!.$1, widget.initial!.$2);
  late bool _placed = widget.initial != null; // pin sudah di titik yang berarti (bukan tengah Indonesia)
  List<Place> _results = [];
  String? _searchError, _near;
  bool _searching = false;
  Timer? _typing, _moving;
  int _seq = 0; // abaikan jawaban pencarian yang sudah basi
  bool _satellite = false;
  LatLng2? _bias; // posisi HP, untuk mengutamakan hasil yang dekat (tanpa memindahkan pin)

  @override
  void initState() {
    super.initState();
    if (_placed) _lookupNear();
    _start();
  }

  /// Seperti Gojek: posisi HP dipakai sebagai bias pencarian; bila belum ada titik, peta langsung ke posisi HP.
  Future<void> _start() async {
    LatLng2? here;
    try {
      here = await widget.locate();
    } catch (_) {} // diam saat membuka layar; pesan baru muncul bila tombol lokasi ditekan
    if (!mounted) return;
    if (here != null) {
      _bias = here;
      if (!_placed && _q.text.trim().length < 3) _goTo(LatLng(here.$1, here.$2), zoom: 16);
    }
    if (_q.text.trim().length >= 3) _search(_q.text);
  }

  @override
  void dispose() {
    _typing?.cancel();
    _moving?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onType(String q) {
    _typing?.cancel();
    _typing = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    final seq = ++_seq;
    if (q.trim().length < 3) {
      return setState(() {
        _results = [];
        _searching = false;
      });
    }
    setState(() => _searching = true);
    try {
      final r = await widget.search(q.trim(), near: _placed ? (_center.latitude, _center.longitude) : _bias);
      if (!mounted || seq != _seq) return;
      setState(() {
        _searching = false;
        _results = r;
        _searchError = r.isEmpty ? 'Tidak ada hasil. Coba nama jalan, kampung, atau tempat terdekat.' : null;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _searching = false;
        _results = [];
        _searchError = e is TimeoutException
            ? 'Pencarian sedang lambat. Geser peta atau pakai Satelit untuk menemukan rumah.'
            : 'Pencarian gagal. Geser peta secara manual.';
      });
    }
  }

  void _choose(Place p) {
    FocusScope.of(context).unfocus();
    _goTo(LatLng(p.lat, p.lng));
    setState(() => _results = []);
  }

  void _goTo(LatLng p, {double zoom = 18}) {
    setState(() {
      _center = p;
      _placed = true;
    });
    if (widget.showTiles) _map.move(p, zoom);
    _lookupNear();
  }

  void _onMoved(MapCamera camera, bool byUser) {
    if (!byUser) return;
    _center = camera.center;
    _placed = true;
    _moving?.cancel();
    _moving = Timer(const Duration(milliseconds: 600), _lookupNear);
  }

  Future<void> _lookupNear() async {
    final near = await widget.reverse((_center.latitude, _center.longitude));
    if (mounted) setState(() => _near = near);
  }

  Future<void> _useMyLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final p = await widget.locate();
      if (p != null) _goTo(LatLng(p.$1, p.$2));
    } on LocationIssue catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          action: e.fix == null ? null : SnackBarAction(label: e.fixLabel!, onPressed: () => e.fix!()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0; // keyboard terbuka: ruang sempit
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih lokasi rumah')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              key: const Key('cari-lokasi'),
              controller: _q,
              onChanged: _onType,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari nama jalan, kampung, atau tempat terdekat',
              ),
            ),
          ),
          if (_searching) const LinearProgressIndicator(),
          if (_results.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: typing ? 200 : 260),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in _results)
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(p.name),
                      subtitle: p.detail.isEmpty ? null : Text(p.detail),
                      onTap: () => _choose(p),
                    ),
                ],
              ),
            )
          else if (_searchError != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(_searchError!)),
          Expanded(
            child: Stack(
              children: [
                if (widget.showTiles)
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: _placed ? 18 : 4.5,
                      maxZoom: 19,
                      onPositionChanged: _onMoved,
                    ),
                    children: [
                      if (_satellite) ...[
                        // ponytail: citra Esri World Imagery tanpa key, cocok untuk demo/non-komersial; produksi perlu
                        // lisensi ArcGIS atau citra lain.
                        TileLayer(
                          urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                          userAgentPackageName: 'id.temansenja.app',
                          maxNativeZoom: 19,
                        ),
                        TileLayer(
                          urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
                          userAgentPackageName: 'id.temansenja.app',
                          maxNativeZoom: 19,
                        ),
                      ] else
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'id.temansenja.app',
                          maxNativeZoom: 19,
                        ),
                      RichAttributionWidget(
                        attributions: [
                          if (_satellite)
                            const TextSourceAttribution('Esri, Maxar, Earthstar Geographics')
                          else
                            TextSourceAttribution(
                              'OpenStreetMap contributors',
                              onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                            ),
                        ],
                      ),
                    ],
                  ),
                // Pin tetap di tengah; peta yang digeser. Ujung bawah ikon tepat di titik tengah.
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.location_pin, size: 40, color: Colors.red),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'satelit',
                    tooltip: _satellite ? 'Peta jalan' : 'Satelit (lihat atap rumah)',
                    onPressed: () => setState(() => _satellite = !_satellite),
                    child: Icon(_satellite ? Icons.map_outlined : Icons.satellite_alt),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'lokasi-saya',
                    tooltip: 'Pakai lokasi saya',
                    onPressed: _useMyLocation,
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          if (!typing)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_placed ? 'Dekat: ${_near ?? '…'}' : 'Cari tempat atau tekan tombol lokasi, lalu geser peta.'),
                    const Text('Geser peta sampai pin tepat di atap rumah.', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const Key('pilih-lokasi'),
                      onPressed: _placed ? () => Navigator.pop(context, (_center.latitude, _center.longitude)) : null,
                      child: const Text('Pilih lokasi ini'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
