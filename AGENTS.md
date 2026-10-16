# AGENTS.md — untuk Codex (dan agen lain selain Claude Code)

Proyek ini dikerjakan dengan alur kerja yang sama apa pun agennya. **Baca `CLAUDE.md` sekarang dan ikuti
seluruhnya**; semua aturan di sana berlaku untuk Codex. Di `CLAUDE.md` dan skill, kata "Claude" atau "sesi Claude"
berarti agen yang sedang bekerja, termasuk Codex.

## Urutan baca di awal sesi
1. `CLAUDE.md` (aturan, perintah, lingkungan laptop, konvensi).
2. Bagian "Catatan sesi terakhir" di `todo.md`, lalu blok tugas yang akan dikerjakan.
3. Bagian `docs/prd.md` dan `docs/architecture.md` yang relevan. **Jangan membaca `progress.md`**; cukup tambah
   entri di bawahnya dengan `cat >> progress.md`.

## Perintah alur kerja (skill)
Pengguna memakai perintah yang sama seperti di Claude Code. Bila pengguna mengetik salah satu perintah di bawah,
atau maksudnya sama ("lanjut", "kerjakan tugas berikutnya", "akhiri sesi"), **buka file skill-nya dan ikuti
langkahnya persis**:

| Perintah | File |
|---|---|
| `/prd` | `docs/workflow/skills/prd/SKILL.md` |
| `/architecture` | `docs/workflow/skills/architecture/SKILL.md` |
| `/breakdown` | `docs/workflow/skills/breakdown/SKILL.md` |
| `/next-task [T-xxx]` | `docs/workflow/skills/next-task/SKILL.md` |
| `/handoff` | `docs/workflow/skills/handoff/SKILL.md` |

Skill yang sama juga terpasang di `~/.codex/skills/` di laptop ini. Di laptop anggota tim lain, salin dulu:
`mkdir -p ~/.codex/skills && cp -R docs/workflow/skills/* ~/.codex/skills/`.

## Hal yang sering terlewat
- Satu sesi = satu tugas `todo.md`; test dulu, lalu implementasi, lalu perbarui blok tugas, lalu entri `progress.md`.
- Commit hanya bila pengguna meminta. `git add <file>` satu per satu, jangan `git add -A`, dan pastikan tidak ada
  `.env.local`, `app/env.json`, atau `firebase/service-account.json`. Akhiri pesan commit dengan baris
  co-author agen yang dipakai.
- Rahasia (API key, service_role, token) jangan pernah ditampilkan di chat atau ditulis ke file yang di-commit.
- Perubahan skema lewat file migration baru di `supabase/migrations/`, lalu `supabase db push --yes`.
- Setelah menjalankan skrip uji yang mengubah data, jalankan reset demo:
  `supabase db query --linked -f supabase/seeds/04_reset_demo.sql && supabase db query --linked -f supabase/seeds/03_visits_ibu_sri.sql`.
- Evaluasi akurasi hanya dengan `GEMINI_EVAL_API_KEY` (kuota demo jangan dipakai).
- Pengguna adalah developer junior: jelaskan keputusan penting dan apa yang perlu ia cek, dalam bahasa Indonesia.
