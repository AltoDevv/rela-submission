import { assert, assertEquals } from "jsr:@std/assert@1";
import { sendPush, type ServiceAccount } from "./push.ts";

// Service account palsu dengan kunci RSA baru, supaya tanda tangan JWT bisa diverifikasi.
const keys = await crypto.subtle.generateKey(
  {
    name: "RSASSA-PKCS1-v1_5",
    modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]),
    hash: "SHA-256",
  },
  true,
  ["sign", "verify"],
);
const pkcs8 = new Uint8Array(
  await crypto.subtle.exportKey("pkcs8", keys.privateKey),
);
const pem = `-----BEGIN PRIVATE KEY-----\n${
  btoa(String.fromCharCode(...pkcs8))
}\n-----END PRIVATE KEY-----\n`;
const sa: ServiceAccount = {
  project_id: "temansenja-uji",
  client_email: "push@temansenja-uji.iam.gserviceaccount.com",
  private_key: pem,
  token_uri: "https://oauth2.googleapis.com/token",
};

type Call = { url: string; init: RequestInit };

/** fetch palsu: token OAuth selalu berhasil, FCM membalas sesuai `fcm(token)`. */
function fakeFetch(
  calls: Call[],
  fcm: (token: string) => Response = () => new Response("{}"),
) {
  return (input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    calls.push({ url, init: init! });
    if (url === sa.token_uri) {
      return Promise.resolve(
        Response.json({ access_token: "akses-123", expires_in: 3600 }),
      );
    }
    return Promise.resolve(fcm(JSON.parse(String(init!.body)).message.token));
  };
}

const b64urlDecode = (s: string) =>
  Uint8Array.from(
    atob(s.replace(/-/g, "+").replace(/_/g, "/")),
    (c) => c.charCodeAt(0),
  );

Deno.test("format request FCM HTTP v1 dan token OAuth dari JWT service account", async () => {
  const calls: Call[] = [];
  const res = await sendPush(
    ["hp-keluarga"],
    {
      title: "Segera dikabari",
      body: "Ibu Sri jatuh",
      data: { elder_id: "e1" },
    },
    { fetchFn: fakeFetch(calls), serviceAccount: sa, cache: false },
  );
  assertEquals(res, { sent: 1, skipped: 0, failed: 0 });

  // 1) Tukar JWT menjadi access token.
  const tokenCall = calls[0];
  assertEquals(tokenCall.url, sa.token_uri);
  const form = new URLSearchParams(String(tokenCall.init.body));
  assertEquals(
    form.get("grant_type"),
    "urn:ietf:params:oauth:grant-type:jwt-bearer",
  );
  const [h, p, sig] = form.get("assertion")!.split(".");
  assertEquals(JSON.parse(new TextDecoder().decode(b64urlDecode(h))), {
    alg: "RS256",
    typ: "JWT",
  });
  const claims = JSON.parse(new TextDecoder().decode(b64urlDecode(p)));
  assertEquals(claims.iss, sa.client_email);
  assertEquals(claims.aud, sa.token_uri);
  assertEquals(
    claims.scope,
    "https://www.googleapis.com/auth/firebase.messaging",
  );
  assertEquals(claims.exp - claims.iat, 3600);
  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    keys.publicKey,
    b64urlDecode(sig),
    new TextEncoder().encode(`${h}.${p}`),
  );
  assert(valid, "tanda tangan JWT tidak valid");

  // 2) Kirim ke FCM.
  const send = calls[1];
  assertEquals(
    send.url,
    "https://fcm.googleapis.com/v1/projects/temansenja-uji/messages:send",
  );
  assertEquals(
    new Headers(send.init.headers).get("authorization"),
    "Bearer akses-123",
  );
  assertEquals(JSON.parse(String(send.init.body)), {
    message: {
      token: "hp-keluarga",
      notification: { title: "Segera dikabari", body: "Ibu Sri jatuh" },
      data: { elder_id: "e1" },
      android: { priority: "HIGH" },
    },
  });
});

Deno.test("token kosong dan duplikat dilewati; tanpa token tidak ada panggilan sama sekali", async () => {
  const calls: Call[] = [];
  const res = await sendPush(["", null, "a", "a", undefined, "b"], {
    title: "t",
    body: "b",
  }, {
    fetchFn: fakeFetch(calls),
    serviceAccount: sa,
    cache: false,
  });
  assertEquals(res.sent, 2);
  const sentTo = calls.slice(1).map((c) =>
    JSON.parse(String(c.init.body)).message.token
  );
  assertEquals(sentTo, ["a", "b"]);

  const none: Call[] = [];
  assertEquals(
    await sendPush([null, ""], { title: "t", body: "b" }, {
      fetchFn: fakeFetch(none),
      serviceAccount: sa,
    }),
    { sent: 0, skipped: 0, failed: 0 },
  );
  assertEquals(none.length, 0);
});

Deno.test("token UNREGISTERED dilewati, kegagalan lain dihitung tanpa melempar error", async () => {
  const calls: Call[] = [];
  const res = await sendPush(["lama", "baik", "rusak"], {
    title: "t",
    body: "b",
  }, {
    fetchFn: fakeFetch(
      calls,
      (token) =>
        token === "lama"
          ? Response.json({
            error: {
              status: "NOT_FOUND",
              details: [{ errorCode: "UNREGISTERED" }],
            },
          }, { status: 404 })
          : token === "rusak"
          ? new Response("server error", { status: 500 })
          : new Response("{}"),
    ),
    serviceAccount: sa,
    cache: false,
  });
  assertEquals(res, { sent: 1, skipped: 1, failed: 1 });
});
