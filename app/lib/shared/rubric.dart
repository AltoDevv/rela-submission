// Salinan dari supabase/functions/_shared/rubric.ts (sumber utama). Ubah keduanya bersamaan.
// Index label = level: 0 = terbaik, 3 = terburuk. `null` = tidak disebut.

typedef RubricDomain = ({String key, String name, List<String> labels});

const List<RubricDomain> rubricDomains = [
  (
    key: 'makan',
    name: 'Nafsu makan',
    labels: ['Baik', 'Berkurang', 'Sangat sedikit', 'Tidak makan'],
  ),
  (
    key: 'obat',
    name: 'Obat',
    labels: [
      'Teratur',
      'Kadang terlewat',
      'Sering terlewat',
      'Habis atau berhenti',
    ],
  ),
  (
    key: 'gerak',
    name: 'Mobilitas',
    labels: [
      'Mandiri',
      'Pelan atau perlu pegangan',
      'Perlu dibantu',
      'Tidak bisa bangun',
    ],
  ),
  (
    key: 'harian',
    name: 'Kemandirian harian',
    labels: [
      'Mandiri',
      'Butuh sedikit bantuan',
      'Butuh banyak bantuan',
      'Bergantung penuh',
    ],
  ),
  (
    key: 'ingatan',
    name: 'Daya ingat',
    labels: ['Seperti biasa', 'Agak pelupa', 'Bingung', 'Bingung mendadak'],
  ),
  (
    key: 'hati',
    name: 'Suasana hati',
    labels: ['Ceria', 'Biasa', 'Murung', 'Menarik diri'],
  ),
  (
    key: 'umum',
    name: 'Kondisi umum',
    labels: ['Sehat', 'Kurang fit', 'Tampak lemah', 'Tampak sakit berat'],
  ),
];

const Map<String, String> redFlags = {
  'jatuh': 'Jatuh',
  'bingung_mendadak': 'Bingung mendadak',
  'sesak_nyeri_dada': 'Sesak atau nyeri dada',
  'tidak_makan': 'Tidak makan sama sekali',
  'obat_habis': 'Obat habis',
  'keluhan_baru': 'Keluhan baru',
};
