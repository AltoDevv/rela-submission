import 'package:app/shared/rubric.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rubrik punya 7 domain dengan 4 label masing-masing', () {
    expect(rubricDomains.map((d) => d.key), [
      'makan',
      'obat',
      'gerak',
      'harian',
      'ingatan',
      'hati',
      'umum',
    ]);
    for (final d in rubricDomains) {
      expect(d.labels.length, 4, reason: d.key);
    }
    expect(rubricDomains[0].labels.first, 'Baik');
    expect(rubricDomains[0].labels.last, 'Tidak makan');
  });

  test('ada 6 tanda bahaya', () {
    expect(redFlags.length, 6);
  });
}
