import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/models.dart';
import '../shared/schedule.dart';
import '../shared/widgets.dart' show staleAfterDays;

/// Semua yang ditampilkan tab Beranda, Relawan, dan Ulasan yayasan; dimuat sekali lalu dimuat ulang setelah aksi.
class YayasanData {
  YayasanData({
    required this.foundation,
    required this.dash,
    this.volunteers = const [],
    this.elders = const [],
    this.weekVisits = const [],
    this.reviews = const [],
    this.authors = const {},
  });

  final String foundation;
  final Map<String, dynamic> dash; // RPC foundation_dashboard
  final List<Volunteer> volunteers;
  final List<Elder> elders; // lansia yang sedang didampingi relawan yayasan ini
  final List<DateTime> weekVisits; // kunjungan terkonfirmasi sejak Senin
  final List<Map<String, dynamic>> reviews; // terbaru dulu
  final Map<String, String> authors; // review_id → nama penulis

  late final Map<String, Map> _dashVols = {for (final v in (dash['volunteers'] as List).cast<Map>()) v['id'] as String: v};
  late final Map<String, Map> _dashElders = {for (final e in (dash['elders'] as List).cast<Map>()) e['id'] as String: e};

  String nameOf(String volunteerId) => (_dashVols[volunteerId]?['full_name'] as String?) ?? 'Relawan';
  int loadOf(String volunteerId) => (_dashVols[volunteerId]?['load'] as int?) ?? 0;
  String elderName(String elderId) => (_dashElders[elderId]?['full_name'] as String?) ?? 'Lansia';
  DateTime? lastVisit(String elderId) {
    final v = _dashElders[elderId]?['last_visit_at'];
    return v == null ? null : DateTime.parse(v as String);
  }

  Map? stopRequest(String elderId) => _dashElders[elderId]?['stop_request'] as Map?;
  List<Elder> eldersOf(String volunteerId) => elders.where((e) => e.volunteerId == volunteerId).toList();
  List<Map<String, dynamic>> reviewsOf(String volunteerId) =>
      reviews.where((r) => r['volunteer_id'] == volunteerId).toList();
  List<Elder> missedElders(DateTime now) => elders.where((e) => isMissed(e, lastVisit(e.id), now)).toList();
}

Future<YayasanData> loadYayasanData() async {
  final db = Supabase.instance.client;
  final dash = ((await db.rpc('foundation_dashboard')) as Map).cast<String, dynamic>();
  final foundation = await db.from('foundations').select('name').single(); // RLS: hanya yayasan sendiri
  final volunteers = (await db.from('volunteers').select().order('created_at')).map(Volunteer.fromMap).toList();
  final ids = volunteers.map((v) => v.id).toList();
  final elders = ids.isEmpty
      ? const <Elder>[]
      : (await db.from('elders').select().eq('pairing_state', 'berpasangan').inFilter('volunteer_id', ids))
          .map(Elder.fromMap)
          .toList();
  // Yayasan tidak membaca tabel visits (data minimal); RPC ini hanya memberi waktu kunjungan minggu ini.
  final visits = (await db.rpc('foundation_week_visits',
      params: {'p_since': weekStart(DateTime.now()).toUtc().toIso8601String()}) as List);
  final reviews = (await db.from('reviews').select().order('created_at', ascending: false)).cast<Map<String, dynamic>>();
  final authors = (await db.rpc('foundation_review_authors') as List).cast<Map>();
  return YayasanData(
    foundation: foundation['name'] as String,
    dash: dash,
    volunteers: volunteers,
    elders: elders,
    weekVisits: [for (final v in visits) DateTime.parse(v as String)],
    reviews: reviews,
    authors: {for (final a in authors) a['review_id'] as String: (a['author_name'] as String?) ?? 'Keluarga'},
  );
}

/// Senin pukul 00.00 waktu HP pada minggu [now].
DateTime weekStart(DateTime now) {
  final l = now.toLocal();
  return DateTime(l.year, l.month, l.day).subtract(Duration(days: l.weekday - 1));
}

/// Jumlah kunjungan per hari Senin–Minggu minggu ini.
List<int> visitsPerDay(List<DateTime> visits, DateTime now) {
  final start = weekStart(now);
  final days = List.filled(7, 0);
  for (final v in visits) {
    final i = v.toLocal().difference(start).inDays;
    if (i >= 0 && i < 7) days[i]++;
  }
  return days;
}

/// Terlewat (keputusan pengguna 16 Okt): bila ada jadwal rutin yang disetujui, slot terakhir (lewat > 1 hari) tidak
/// diikuti kunjungan (boleh sehari lebih awal). Tanpa jadwal: belum dikunjungi lebih dari [staleAfterDays] hari sejak
/// kunjungan terakhir, atau sejak mulai didampingi bila belum pernah dikunjungi pendamping ini.
bool isMissed(Elder e, DateTime? last, DateTime now) {
  if (e.pairingState != 'berpasangan') return false;
  if (hasSchedule(e)) {
    final due = lastDue(e.scheduleWeekday!, e.scheduleTime!, e.scheduleShiftAt, now);
    if (e.pairedAt != null && due.isBefore(e.pairedAt!)) return false;
    return last == null || last.isBefore(due.subtract(const Duration(days: 1)));
  }
  final since = [last, e.pairedAt].whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
  return since == null || now.difference(since).inDays > staleAfterDays;
}

/// Persen lansia yang tidak terlewat; null bila tidak ada lansia (mis. relawan tanpa pasangan).
int? visitedPercent(List<Elder> elders, DateTime? Function(String elderId) last, DateTime now) {
  if (elders.isEmpty) return null;
  final ok = elders.where((e) => !isMissed(e, last(e.id), now)).length;
  return (ok * 100 / elders.length).round();
}

enum VolunteerState { mundur, nonaktif, belum, penuh, tersedia }

VolunteerState volunteerState(Volunteer v, int load) {
  if (v.resignRequestedAt != null) return VolunteerState.mundur;
  if (v.status != 'aktif') {
    return (v.statusNote ?? '').startsWith('Dinonaktifkan') ? VolunteerState.nonaktif : VolunteerState.belum;
  }
  return load >= v.maxLoad ? VolunteerState.penuh : VolunteerState.tersedia;
}
