// Aturan pemasangan relawan F2 (fungsi murni, tanpa database).
// Urutan: syarat wajib → jarak terdekat → beban terendah. Hari, bahasa, dan agama sengaja tidak dipakai.

export type Elder = {
  lat: number;
  lng: number;
  has_dementia: boolean;
  has_mobility_issue: boolean;
};

export type Candidate = {
  id: string;
  status: string; // 'terdaftar' | 'aktif'
  lat: number;
  lng: number;
  can_dementia: boolean;
  can_mobility: boolean;
  max_load: number;
  load: number; // jumlah lansia yang sedang didampingi, dihitung oleh query pemanggil
  available_days: string[]; // ditampilkan ke keluarga (F2a), tidak dipakai untuk memilih
  languages: string[]; // idem
};

export type Match = { volunteer: Candidate; distanceKm: number; reasonText: string };

export function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371.0088;
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export function pickVolunteer(elder: Elder, candidates: Candidate[], excludedIds: string[]): Match | null {
  const ranked = candidates
    .filter((v) =>
      !excludedIds.includes(v.id) &&
      v.status === "aktif" &&
      v.load < v.max_load &&
      (!elder.has_dementia || v.can_dementia) &&
      (!elder.has_mobility_issue || v.can_mobility)
    )
    // Jarak dibulatkan ke 0,1 km (yang dilihat keluarga), jadi "jarak sama" berarti sama setelah dibulatkan.
    .map((v) => ({ v, km: Math.round(haversineKm(elder.lat, elder.lng, v.lat, v.lng) * 10) / 10 }))
    .sort((a, b) => a.km - b.km || a.v.load - b.v.load || a.v.id.localeCompare(b.v.id));

  if (ranked.length === 0) return null;
  const { v, km } = ranked[0];

  const parts = [`Jarak ${km.toFixed(1).replace(".", ",")} km`];
  if (elder.has_dementia) parts.push("berpengalaman mendampingi lansia dengan demensia");
  if (elder.has_mobility_issue) parts.push("mampu membantu lansia dengan mobilitas sulit");
  return { volunteer: v, distanceKm: km, reasonText: parts.join(" · ") };
}
