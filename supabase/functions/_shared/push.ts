// Push notification lewat FCM HTTP v1. Token OAuth dibuat dari service account (secret FIREBASE_SERVICE_ACCOUNT)
// dengan JWT RS256 via WebCrypto bawaan Deno, jadi tidak perlu library tambahan.
type FetchFn = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri: string;
};
export type PushMessage = {
  title: string;
  body: string;
  data?: Record<string, string>;
};
export type PushResult = { sent: number; skipped: number; failed: number };

const SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

const b64url = (bytes: Uint8Array | string) =>
  btoa(typeof bytes === "string" ? bytes : String.fromCharCode(...bytes))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

async function signJwt(sa: ServiceAccount): Promise<string> {
  const der = Uint8Array.from(
    atob(sa.private_key.replace(/-----[A-Z ]+-----/g, "").replace(/\s/g, "")),
    (c) => c.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const iat = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: SCOPE,
      aud: sa.token_uri,
      iat,
      exp: iat + 3600,
    }),
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  return `${header}.${claims}.${b64url(new Uint8Array(sig))}`;
}

// Access token berlaku 1 jam, jadi disimpan di memori fungsi supaya tidak meminta ulang setiap push.
let cached: { token: string; until: number } | null = null;

async function accessToken(
  sa: ServiceAccount,
  fetchFn: FetchFn,
  useCache: boolean,
): Promise<string> {
  if (useCache && cached && cached.until > Date.now()) return cached.token;
  const res = await fetchFn(sa.token_uri, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: await signJwt(sa),
    }),
  });
  if (!res.ok) {
    throw new Error(
      `Token OAuth Google gagal (${res.status}): ${await res.text()}`,
    );
  }
  const { access_token, expires_in } = await res.json();
  if (useCache) {
    cached = {
      token: access_token,
      until: Date.now() + (expires_in - 60) * 1000,
    };
  }
  return access_token;
}

/** Mengirim notifikasi ke setiap token (kosong/duplikat dilewati). Tidak melempar error per token. */
export async function sendPush(
  tokens: (string | null | undefined)[],
  { title, body, data }: PushMessage,
  {
    fetchFn = fetch as FetchFn,
    serviceAccount,
    cache = true,
  }: { fetchFn?: FetchFn; serviceAccount?: ServiceAccount; cache?: boolean } =
    {},
): Promise<PushResult> {
  const result: PushResult = { sent: 0, skipped: 0, failed: 0 };
  const unique = [...new Set(tokens.filter((t): t is string => !!t))];
  if (unique.length === 0) return result;

  const sa = serviceAccount ??
    JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "null");
  if (!sa) throw new Error("FIREBASE_SERVICE_ACCOUNT belum diset");
  const auth = `Bearer ${await accessToken(sa, fetchFn, cache)}`;

  for (const token of unique) {
    const res = await fetchFn(
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
      {
        method: "POST",
        headers: { "content-type": "application/json", authorization: auth },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            ...(data ? { data } : {}),
            android: { priority: "HIGH" },
          },
        }),
      },
    );
    if (res.ok) {
      result.sent++;
      continue;
    }
    const text = await res.text();
    // Token lama (aplikasi dihapus atau login di HP lain): cukup dilewati.
    if (text.includes("UNREGISTERED")) result.skipped++;
    else {
      result.failed++;
      console.error(`FCM gagal (${res.status}): ${text}`);
    }
  }
  return result;
}
