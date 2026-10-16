import '../relawan/ui.dart' show visitDate;
import 'models.dart';

/// Jadwal kunjungan rutin (keputusan pengguna 16 Okt). Sama dengan supabase/functions/_shared/schedule.ts; waktu HP
/// dianggap WIB.
const weekdayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

String _hm(int h, int m) => '${h.toString().padLeft(2, '0')}.${m.toString().padLeft(2, '0')}';
(int, int) _parse(String time) {
  final p = time.split(':');
  return (int.parse(p[0]), int.parse(p[1]));
}

/// "Rabu 10.00"
String scheduleLabel(int weekday, String time) {
  final (h, m) = _parse(time);
  return '${weekdayNames[weekday - 1]} ${_hm(h, m)}';
}

/// Kunjungan berikutnya setelah [now]; geseran yang akan datang menggantikan slot minggu itu.
DateTime nextVisit(int weekday, String time, DateTime? shiftAt, DateTime now) {
  if (shiftAt != null && shiftAt.isAfter(now)) return shiftAt.toLocal();
  final (h, m) = _parse(time);
  var at = DateTime(now.year, now.month, now.day + (weekday - now.weekday + 7) % 7, h, m);
  if (!at.isAfter(now)) at = at.add(const Duration(days: 7));
  return at;
}

/// Slot terjadwal terakhir yang sudah lewat lebih dari sehari (dasar "terlewat"). Geseran menggantikan slot di
/// minggu yang sama; bila geserannya belum lewat, slot minggu sebelumnya yang dipakai.
DateTime lastDue(int weekday, String time, DateTime? shiftAt, DateTime now) {
  final (h, m) = _parse(time);
  final limit = now.subtract(const Duration(days: 1));
  var slot = DateTime(limit.year, limit.month, limit.day - (limit.weekday - weekday + 7) % 7, h, m);
  if (slot.isAfter(limit)) slot = slot.subtract(const Duration(days: 7));
  final shift = shiftAt?.toLocal();
  if (shift != null && shift.difference(slot).inDays.abs() < 7 && shift.isAfter(slot.subtract(const Duration(days: 3)))) {
    return shift.isAfter(limit) ? slot.subtract(const Duration(days: 7)) : shift;
  }
  return slot;
}

bool hasSchedule(Elder e) => e.scheduleStatus == 'disetujui' && e.scheduleWeekday != null && e.scheduleTime != null;

/// "Rab 22 Okt · 10.00" untuk kunjungan berikutnya lansia ini, atau null bila belum ada jadwal disetujui.
String? nextVisitText(Elder e, {DateTime? now}) {
  if (!hasSchedule(e)) return null;
  final n = nextVisit(e.scheduleWeekday!, e.scheduleTime!, e.scheduleShiftAt, now ?? DateTime.now());
  return '${weekdayNames[n.weekday - 1].substring(0, 3)} ${visitDate(n)} · ${_hm(n.hour, n.minute)}';
}
