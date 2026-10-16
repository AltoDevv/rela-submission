import { assertEquals } from "jsr:@std/assert@1";

// Memastikan `deno test supabase/functions/_shared` berjalan sejak awal proyek.
Deno.test("deno test berjalan", () => {
  assertEquals(1 + 1, 2);
});
