// Pemanggil Gemini generateContent. `fetchFn` dan opsi bisa diganti saat test.
type FetchFn = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

const TIMEOUT_MS = 15_000;

/** Mengirim request ke Gemini dan mengembalikan JSON hasil `responseSchema` (belum divalidasi). */
export async function generateJson(
  request: unknown,
  fetchFn: FetchFn = fetch,
  // Nilai default hanya dibaca bila opsi tidak diberikan, jadi test tidak butuh izin env.
  {
    apiKey = Deno.env.get("GEMINI_API_KEY"),
    model = Deno.env.get("GEMINI_MODEL"),
  } = {},
): Promise<unknown> {
  if (!apiKey || !model) {
    throw new Error("GEMINI_API_KEY dan GEMINI_MODEL belum diset");
  }
  const res = await fetchFn(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: { "content-type": "application/json", "x-goog-api-key": apiKey },
      body: JSON.stringify(request),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    },
  );
  if (!res.ok) {
    throw new Error(`Gemini gagal (${res.status}): ${await res.text()}`);
  }
  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof text !== "string") {
    throw new Error("Gemini tidak mengembalikan teks");
  }
  return JSON.parse(text);
}
