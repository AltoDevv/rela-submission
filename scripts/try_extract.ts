// Satu panggilan sungguhan ke Gemini untuk cerita contoh. Jalankan: deno run -A scripts/try_extract.ts
import {
  type Answers,
  extractVisit,
} from "../supabase/functions/_shared/extract.ts";
import { generateJson } from "../supabase/functions/_shared/gemini.ts";

const env = Object.fromEntries(
  Deno.readTextFileSync(".env.local").split("\n")
    .filter((l) => l.includes("="))
    .map((
      l,
    ) => [
      l.slice(0, l.indexOf("=")).trim(),
      l.slice(l.indexOf("=") + 1).trim(),
    ]),
);

const elder = {
  name: "Sri Wahyuni",
  address: "Jl. Kaliurang km 5, Ngaglik, Sleman",
};
const answers: Answers = {
  makan: "Makannya tinggal setengah piring, katanya tidak selera.",
  obat: "Obat darah tinggi masih diminum pagi, tapi yang malam kadang lupa.",
  gerak:
    "Bu Sri cerita kemarin terpeleset di kamar mandi, lututnya memar. Jalannya sekarang pegangan tembok.",
  harian: "Mandi masih sendiri, tapi pakai baju minta dibantu.",
  ingatan: "",
  hati: "Agak murung, lebih banyak diam.",
  lain: "Mengeluh pusing sejak pagi.",
};

const start = Date.now();
const result = await extractVisit(
  answers,
  elder,
  (req) =>
    generateJson(req, fetch, {
      apiKey: env.GEMINI_API_KEY,
      model: env.GEMINI_MODEL,
    }),
);
console.log(JSON.stringify(result, null, 2));
console.log(`Waktu: ${((Date.now() - start) / 1000).toFixed(1)} detik`);

if (!result.red_flags.some((f) => f.flag === "jatuh")) {
  console.error("GAGAL: tanda bahaya 'jatuh' tidak terdeteksi");
  Deno.exit(1);
}
console.log("OK: tanda bahaya 'jatuh' terdeteksi");
