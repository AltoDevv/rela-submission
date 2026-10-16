import 'package:app/shared/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 16, 9); // Jumat

  test('kunjungan berikutnya: Rabu 10.00 → Rabu depan; Jumat 15.00 → hari ini; geseran menggantikan', () {
    expect(nextVisit(3, '10:00:00', null, now), DateTime(2026, 10, 21, 10));
    expect(nextVisit(5, '15:00', null, now), DateTime(2026, 10, 16, 15));
    expect(nextVisit(5, '08:00', null, now), DateTime(2026, 10, 23, 8));
    expect(nextVisit(3, '10:00', DateTime(2026, 10, 18, 14), now), DateTime(2026, 10, 18, 14));
  });

  test('slot terakhir yang sudah lewat > 1 hari (dasar terlewat)', () {
    expect(lastDue(3, '10:00', null, now), DateTime(2026, 10, 14, 10)); // Rabu kemarin lusa
    expect(lastDue(4, '10:00', null, now), DateTime(2026, 10, 8, 10), reason: 'Kamis kemarin belum lewat sehari penuh');
    // Rabu 14 digeser ke Kamis 15 sore → belum lewat sehari → pakai slot minggu sebelumnya.
    expect(lastDue(3, '10:00', DateTime(2026, 10, 15, 15), now), DateTime(2026, 10, 7, 10));
    // Digeser ke Selasa 13 → sudah lewat → slot itu yang dipakai.
    expect(lastDue(3, '10:00', DateTime(2026, 10, 13, 15), now), DateTime(2026, 10, 13, 15));
  });

  test('label jadwal', () {
    expect(scheduleLabel(3, '10:00:00'), 'Rabu 10.00');
  });
}
