// Supabase Edge Function. Deploy only after the F19–F29 migrations and configure
// APPLE_CLIENT_ID, APPLE_TEAM_ID, APPLE_KEY_ID and APPLE_PRIVATE_KEY as server secrets.
// Never put service_role or Apple private keys in the iOS app.
import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "npm:jose@6.1.0";

const appleKeys = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
const reply = (status: number, body: unknown) => new Response(JSON.stringify(body), {
  status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
});
const required = (key: string) => {
  const value = Deno.env.get(key);
  if (!value) throw new Error(`Missing configuration: ${key}`);
  return value;
};

Deno.serve(async (request) => {
  if (request.method !== "POST") return reply(405, { message: "只接受 POST。" });
  const bearer = request.headers.get("Authorization")?.replace(/^Bearer /i, "");
  if (!bearer) return reply(401, { message: "請重新登入。" });
  let admin: ReturnType<typeof createClient> | undefined;
  let userID: string | undefined;
  let accepted = false;
  try {
    const url = required("SUPABASE_URL");
    admin = createClient(url, required("SUPABASE_SERVICE_ROLE_KEY"), { auth: { persistSession: false, autoRefreshToken: false } });
    // Scheduled retry endpoint is server-only; an ordinary user's JWT never enters here.
    if (bearer === required("SUPABASE_SERVICE_ROLE_KEY")) {
      const { data: pending, error } = await admin.from("account_deletion_requests").select("user_id").eq("apple_revoked", true).limit(10);
      if (error) throw error;
      let completed = 0, deferred = 0;
      for (const request of pending ?? []) {
        try {
          const ban = await admin.auth.admin.updateUserById(request.user_id, { ban_duration: "876000h" });
          if (ban.error) throw ban.error;
          await finishDeletion(admin, request.user_id); completed++;
        } catch { deferred++; }
      }
      return reply(200, { completed, deferred });
    }
    const { data: auth, error: authError } = await admin.auth.getUser(bearer);
    if (authError || !auth.user) return reply(401, { message: "請重新登入。" });
    userID = auth.user.id;
    if (Number(request.headers.get("Content-Length") ?? 0) > 24_000) return reply(413, { message: "請求太大。" });
    const body = await request.json();
    if (typeof body.authorizationCode !== "string" || typeof body.identityToken !== "string") return reply(400, { message: "請使用 Apple 重新驗證。" });
    const clientID = required("APPLE_CLIENT_ID");
    const { payload } = await jwtVerify(body.identityToken, appleKeys, { issuer: "https://appleid.apple.com", audience: clientID, maxTokenAge: "5m" });
    const appleIdentity = auth.user.identities?.find((identity) => identity.provider === "apple");
    if (!appleIdentity || payload.sub !== (appleIdentity.identity_data?.sub ?? appleIdentity.id)) {
      return reply(403, { message: "請使用目前登入的同一個 Apple 帳號。" });
    }
    const key = await importPKCS8(required("APPLE_PRIVATE_KEY").replace(/\\n/g, "\n"), "ES256");
    const clientSecret = await new SignJWT({}).setProtectedHeader({ alg: "ES256", kid: required("APPLE_KEY_ID") })
      .setIssuer(required("APPLE_TEAM_ID")).setSubject(clientID).setAudience("https://appleid.apple.com")
      .setIssuedAt().setExpirationTime("5m").sign(key);
    const response = await fetch("https://appleid.apple.com/auth/token", {
      method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ client_id: clientID, client_secret: clientSecret, code: body.authorizationCode, grant_type: "authorization_code" }),
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) return reply(409, { message: "Apple 驗證已過期，請重新確認刪除。" });
    const token = await response.json();
    const verified = await jwtVerify(token.id_token, appleKeys, { issuer: "https://appleid.apple.com", audience: clientID });
    if (verified.payload.sub !== payload.sub || !token.refresh_token) return reply(403, { message: "Apple 帳號驗證不一致。" });
    const revocation = await fetch("https://appleid.apple.com/auth/revoke", {
      method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ client_id: clientID, client_secret: clientSecret, token: token.refresh_token, token_type_hint: "refresh_token" }),
      signal: AbortSignal.timeout(15_000),
    });
    if (!revocation.ok) return reply(503, { message: "Apple 授權撤銷未完成，尚未刪除帳號，請稍後重試。" });
    const begin = await admin.rpc("begin_account_deletion", { p_user: userID });
    if (begin.error) throw begin.error;
    accepted = true;
    // Immediately ban refresh/new login. RLS/RPC guards also revoke existing JWT access.
    const ban = await admin.auth.admin.updateUserById(userID, { ban_duration: "876000h" });
    if (ban.error) throw ban.error;
    await admin.auth.admin.signOut(bearer, "global");
    await finishDeletion(admin, userID);
    return reply(200, { status: "deleted" });
  } catch {
    // Never return keys, Apple tokens, raw database errors or private payloads.
    if (accepted && admin && userID) {
      await admin.from("account_deletion_requests").update({ state: "retry_cleanup" }).eq("user_id", userID);
      return reply(202, { status: "pending", message: "已停止帳號使用，刪除清理待後台重試。", reference: userID });
    }
    return reply(503, { message: "刪除服務尚未就緒或驗證未完成，帳號尚未刪除。請稍後重試或聯絡 Snoots!。" });
  }
});

async function finishDeletion(admin: ReturnType<typeof createClient>, userID: string) {
  const { data: objects, error } = await admin.rpc("account_deletion_objects", { p_user: userID });
  if (error) throw error;
  const buckets = new Map<string, string[]>();
  for (const object of (objects ?? []) as { bucket: string; path: string }[]) {
    const list = buckets.get(object.bucket) ?? []; list.push(object.path); buckets.set(object.bucket, list);
  }
  for (const [bucket, paths] of buckets) for (let i = 0; i < paths.length; i += 100) {
    const { error } = await admin.storage.from(bucket).remove(paths.slice(i, i + 100));
    if (error) throw error;
  }
  const finalized = await admin.rpc("finalize_account_deletion", { p_user: userID });
  if (finalized.error) throw finalized.error;
  const deletion = await admin.auth.admin.deleteUser(userID);
  if (deletion.error) throw deletion.error;
}
