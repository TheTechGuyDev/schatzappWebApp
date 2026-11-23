// SchatzApp Web: QR login Edge Function ("web-login").
//
// Actions (POST JSON { action, ... }):
//   create   (web, no login)  -> new QR request, valid 60 seconds
//   poll     (web, no login)  -> status; when approved, returns the web session
//   inspect  (phone, logged in) -> device details to show before approving
//   approve  (phone, logged in) -> approve the scanned QR
//   reject   (phone, logged in) -> reject the scanned QR
//   register (web, after phone-number OTP login) -> registers the browser
//            as a linked device with the same rules as QR login
//   issue_code (phone, logged in) -> a 6-digit "Link with code" code,
//            valid 2 minutes, one use, locked after 5 wrong tries
//   code_login (web, no login) -> phone number + code; returns the web
//            session exactly like an approved QR (no SMS, no Twilio)
//
// Rules: max 7 active web devices per account; web login lasts 7 days
// ("Keep me signed in") or 24 hours; 4 hours idle logs out (SQL heartbeat
// + 10-minute sweep). The service_role key never leaves this function.

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const QR_TTL_SECONDS = 60;
const MAX_DEVICES = 7;
const LONG_SESSION_DAYS = 7;
const SHORT_SESSION_HOURS = 24;
const IDLE_HOURS = 4;
const CODE_TTL_SECONDS = 120;
const CODE_MAX_TRIES = 5;

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function fail(code: string, message: string, status = 400) {
  return json({ ok: false, code, message }, status);
}

function randomToken(bytes = 32): string {
  const b = crypto.getRandomValues(new Uint8Array(bytes));
  return btoa(String.fromCharCode(...b))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

async function sha256(text: string): Promise<string> {
  const data = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((x) => x.toString(16).padStart(2, "0"))
    .join("");
}

function clip(v: unknown, max = 120): string | null {
  if (typeof v !== "string") return null;
  const s = v.trim();
  return s ? s.slice(0, max) : null;
}

/** Reads the session_id claim from a Supabase access token. */
function sessionIdFromJwt(jwt: string): string | null {
  try {
    const payload = JSON.parse(
      atob(jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")),
    );
    return payload.session_id ?? null;
  } catch {
    return null;
  }
}

/** The logged-in phone user calling inspect / approve / reject. */
async function phoneUser(req: Request) {
  const auth = req.headers.get("Authorization") ?? "";
  const jwt = auth.replace(/^Bearer\s+/i, "");
  if (!jwt) return null;
  const { data, error } = await admin.auth.getUser(jwt);
  if (error || !data?.user) return null;
  return data.user;
}

async function activeDeviceCount(userId: string): Promise<number> {
  const idleCutoff = new Date(Date.now() - IDLE_HOURS * 3600_000).toISOString();
  const { count } = await admin
    .from("web_devices")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .is("revoked_at", null)
    .gt("expires_at", new Date().toISOString())
    .gt("last_active_at", idleCutoff);
  return count ?? 0;
}

/** Finds a request from the QR payload: "<request_id>.<qr_token>". */
async function requestFromQr(qr: unknown) {
  if (typeof qr !== "string") return null;
  const raw = qr.includes("r=")
    ? (() => {
      const u = new URL(qr.replace("schatzapp://", "https://x/"));
      return `${u.searchParams.get("r")}.${u.searchParams.get("t")}`;
    })()
    : qr;
  const [id, token] = raw.split(".");
  if (!id || !token) return null;
  const { data } = await admin
    .from("web_login_requests")
    .select("*")
    .eq("id", id)
    .eq("qr_code_hash", await sha256(token))
    .maybeSingle();
  return data;
}

// ---------------------------------------------------------------------------

async function create(body: Record<string, unknown>, req: Request) {
  const qrToken = randomToken();
  const pollSecret = randomToken();
  const expiresAt = new Date(Date.now() + QR_TTL_SECONDS * 1000);
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim();

  const { data, error } = await admin
    .from("web_login_requests")
    .insert({
      qr_code_hash: await sha256(qrToken),
      poll_secret_hash: await sha256(pollSecret),
      device_name: clip(body.device_name),
      browser: clip(body.browser),
      os: clip(body.os),
      location: clip(body.location),
      ip_address: clip(ip, 64),
      keep_signed_in: body.keep_signed_in !== false,
      expires_at: expiresAt.toISOString(),
    })
    .select("id")
    .single();
  if (error) return fail("server_error", "Could not create QR code", 500);

  return json({
    ok: true,
    request_id: data.id,
    poll_secret: pollSecret,
    qr: `schatzapp://link-device?r=${data.id}&t=${qrToken}`,
    expires_at: expiresAt.toISOString(),
    ttl_seconds: QR_TTL_SECONDS,
  });
}

async function poll(body: Record<string, unknown>) {
  const id = body.request_id;
  const secret = body.poll_secret;
  if (typeof id !== "string" || typeof secret !== "string") {
    return fail("bad_request", "Missing request");
  }
  const { data: r } = await admin
    .from("web_login_requests")
    .select("*")
    .eq("id", id)
    .eq("poll_secret_hash", await sha256(secret))
    .maybeSingle();
  if (!r) return fail("not_found", "QR code not found", 404);

  if (r.status === "rejected") return json({ ok: true, status: "rejected" });
  if (r.status === "consumed") return json({ ok: true, status: "used" });
  if (r.status === "pending") {
    const expired = new Date(r.expires_at).getTime() < Date.now();
    return json({ ok: true, status: expired ? "expired" : "pending" });
  }

  // Approved: claim it exactly once.
  const { data: claimed } = await admin
    .from("web_login_requests")
    .update({ status: "consumed", consumed_at: new Date().toISOString() })
    .eq("id", r.id)
    .eq("status", "approved")
    .select("*")
    .maybeSingle();
  if (!claimed) return json({ ok: true, status: "used" });

  if ((await activeDeviceCount(claimed.user_id)) >= MAX_DEVICES) {
    return json({ ok: true, status: "device_limit" });
  }

  return await openWebSession(claimed.user_id, {
    device_name: claimed.device_name,
    browser: claimed.browser,
    os: claimed.os,
    ip_address: claimed.ip_address,
    location: claimed.location,
  }, claimed.keep_signed_in, "qr");
}

type DeviceInfo = {
  device_name: string | null;
  browser: string | null;
  os: string | null;
  ip_address: string | null;
  location: string | null;
};

/** Opens a separate web session for a user and registers the browser as a
 *  linked device. Phone-number accounts have no email, so: set a random
 *  one-time password, sign in with it once, then replace it with another
 *  random value nobody knows. */
async function openWebSession(
  userId: string,
  info: DeviceInfo,
  keep: boolean,
  method: "qr" | "phone",
) {
  const { data: u } = await admin.auth.admin.getUserById(userId);
  const user = u?.user;
  if (!user) return fail("server_error", "Account not found", 500);

  const tempPassword = randomToken(24);
  const { error: pwErr } = await admin.auth.admin.updateUserById(user.id, {
    password: tempPassword,
  });
  if (pwErr) return fail("server_error", "Could not start session", 500);

  const signer = createClient(SUPABASE_URL, ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const creds = user.phone
    ? { phone: user.phone, password: tempPassword }
    : { email: user.email!, password: tempPassword };
  const { data: s, error: sErr } = await signer.auth.signInWithPassword(creds);

  await admin.auth.admin.updateUserById(user.id, { password: randomToken(32) });

  if (sErr || !s?.session) {
    return fail("server_error", "Could not start session", 500);
  }

  const deviceToken = randomToken();
  const expiresAt = new Date(
    Date.now() +
      (keep ? LONG_SESSION_DAYS * 86400_000 : SHORT_SESSION_HOURS * 3600_000),
  );
  const { data: device, error: dErr } = await admin
    .from("web_devices")
    .insert({
      user_id: user.id,
      device_token_hash: await sha256(deviceToken),
      session_id: sessionIdFromJwt(s.session.access_token),
      ...info,
      login_method: method,
      keep_signed_in: keep,
      expires_at: expiresAt.toISOString(),
    })
    .select("id")
    .single();
  if (dErr) return fail("server_error", "Could not register device", 500);

  return json({
    ok: true,
    status: "approved",
    device_id: device.id,
    device_expires_at: expiresAt.toISOString(),
    keep_signed_in: keep,
    access_token: s.session.access_token,
    refresh_token: s.session.refresh_token,
  });
}

// ---------------------------------------------------------------------------
// Link with code (no SMS)
// ---------------------------------------------------------------------------

/** Uniform random 6-digit code. */
function sixDigits(): string {
  const max = Math.floor(0xffffffff / 1_000_000) * 1_000_000;
  while (true) {
    const n = crypto.getRandomValues(new Uint32Array(1))[0];
    if (n < max) return String(n % 1_000_000).padStart(6, "0");
  }
}

async function codeHash(userId: string, code: string) {
  return await sha256(`${userId}:${code}`);
}

/** Phone (logged in): a fresh code. Any earlier unused code stops working. */
async function issueCode(req: Request) {
  const user = await phoneUser(req);
  if (!user) return fail("unauthorized", "Please log in on your phone", 401);

  if ((await activeDeviceCount(user.id)) >= MAX_DEVICES) {
    return fail(
      "device_limit",
      `You can link up to ${MAX_DEVICES} devices. Remove a device first.`,
    );
  }

  await admin
    .from("web_link_codes")
    .update({ used_at: new Date().toISOString() })
    .eq("user_id", user.id)
    .is("used_at", null);

  const code = sixDigits();
  const expiresAt = new Date(Date.now() + CODE_TTL_SECONDS * 1000);
  const { error } = await admin.from("web_link_codes").insert({
    user_id: user.id,
    code_hash: await codeHash(user.id, code),
    expires_at: expiresAt.toISOString(),
  });
  if (error) return fail("server_error", "Could not create a code", 500);

  return json({
    ok: true,
    code,
    expires_at: expiresAt.toISOString(),
    ttl_seconds: CODE_TTL_SECONDS,
  });
}

/** The account for a phone number typed on the web (+2348012345678). */
async function userIdForPhone(raw: unknown): Promise<string | null> {
  if (typeof raw !== "string") return null;
  const digits = raw.replace(/\D/g, "");
  if (digits.length < 7 || digits.length > 15) return null;
  const { data } = await admin
    .from("profiles")
    .select("id")
    .in("phone_number", [`+${digits}`, digits])
    .limit(1);
  return data && data.length ? (data[0].id as string) : null;
}

const WRONG_CODE =
  "That code is wrong or has expired. Get a new code on your phone.";

/** Web (no login): phone number + code. Same session and device rules as
 *  the QR. Wrong answers never reveal whether the number has an account. */
async function codeLogin(body: Record<string, unknown>, req: Request) {
  const code = typeof body.code === "string" ? body.code.trim() : "";
  if (!/^\d{6}$/.test(code)) return fail("invalid_code", "Enter the 6-digit code");

  const userId = await userIdForPhone(body.phone);
  if (!userId) return fail("invalid_code", WRONG_CODE);

  const { data: row } = await admin
    .from("web_link_codes")
    .select("*")
    .eq("user_id", userId)
    .is("used_at", null)
    .gt("expires_at", new Date().toISOString())
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (!row) return fail("invalid_code", WRONG_CODE);

  if (row.code_hash !== (await codeHash(userId, code))) {
    const tries = (row.attempts ?? 0) + 1;
    await admin
      .from("web_link_codes")
      .update({
        attempts: tries,
        ...(tries >= CODE_MAX_TRIES ? { used_at: new Date().toISOString() } : {}),
      })
      .eq("id", row.id);
    return tries >= CODE_MAX_TRIES
      ? fail(
        "locked",
        "Too many wrong tries. Get a new code on your phone.",
      )
      : fail(
        "invalid_code",
        `Wrong code. ${CODE_MAX_TRIES - tries} tries left.`,
      );
  }

  // Use the code exactly once.
  const { data: claimed } = await admin
    .from("web_link_codes")
    .update({ used_at: new Date().toISOString() })
    .eq("id", row.id)
    .is("used_at", null)
    .select("id")
    .maybeSingle();
  if (!claimed) return fail("invalid_code", WRONG_CODE);

  if ((await activeDeviceCount(userId)) >= MAX_DEVICES) {
    return fail(
      "device_limit",
      `You can link up to ${MAX_DEVICES} devices. Remove a device on your phone first.`,
    );
  }

  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim();
  return await openWebSession(userId, {
    device_name: clip(body.device_name),
    browser: clip(body.browser),
    os: clip(body.os),
    location: clip(body.location),
    ip_address: clip(ip, 64),
  }, body.keep_signed_in !== false, "phone");
}

async function inspect(body: Record<string, unknown>, req: Request) {
  const user = await phoneUser(req);
  if (!user) return fail("unauthorized", "Please log in on your phone", 401);
  const r = await requestFromQr(body.qr);
  if (!r) return fail("invalid_qr", "This QR code is not valid");
  if (r.status !== "pending" || new Date(r.expires_at).getTime() < Date.now()) {
    return fail("expired", "This QR code has expired. Refresh it on the computer.");
  }
  return json({
    ok: true,
    device_name: r.device_name,
    browser: r.browser,
    os: r.os,
    location: r.location,
    ip_address: r.ip_address,
    requested_at: r.created_at,
    active_devices: await activeDeviceCount(user.id),
    max_devices: MAX_DEVICES,
  });
}

async function decide(
  body: Record<string, unknown>,
  req: Request,
  approve: boolean,
) {
  const user = await phoneUser(req);
  if (!user) return fail("unauthorized", "Please log in on your phone", 401);
  const r = await requestFromQr(body.qr);
  if (!r) return fail("invalid_qr", "This QR code is not valid");
  if (r.status !== "pending" || new Date(r.expires_at).getTime() < Date.now()) {
    return fail("expired", "This QR code has expired. Refresh it on the computer.");
  }
  if (approve && (await activeDeviceCount(user.id)) >= MAX_DEVICES) {
    return fail(
      "device_limit",
      `You can link up to ${MAX_DEVICES} devices. Remove a device first.`,
    );
  }
  const { data } = await admin
    .from("web_login_requests")
    .update({
      status: approve ? "approved" : "rejected",
      user_id: user.id,
      approved_at: approve ? new Date().toISOString() : null,
    })
    .eq("id", r.id)
    .eq("status", "pending")
    .select("id")
    .maybeSingle();
  if (!data) return fail("expired", "This QR code was already used.");
  return json({ ok: true, status: approve ? "approved" : "rejected" });
}

/** Phone-number login on the web: the browser already has a session from
 *  the OTP. Register it as a linked device (same limits as QR), or end the
 *  session if the account already has 7 devices. */
async function registerPhoneLogin(body: Record<string, unknown>, req: Request) {
  const user = await phoneUser(req);
  if (!user) return fail("unauthorized", "Please log in again", 401);
  const jwt = (req.headers.get("Authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  );
  const sessionId = sessionIdFromJwt(jwt);

  // Same browser session registering twice: return the existing device.
  if (sessionId) {
    const { data: existing } = await admin
      .from("web_devices")
      .select("id, expires_at, keep_signed_in")
      .eq("user_id", user.id)
      .eq("session_id", sessionId)
      .is("revoked_at", null)
      .maybeSingle();
    if (existing) {
      return json({
        ok: true,
        device_id: existing.id,
        device_expires_at: existing.expires_at,
        keep_signed_in: existing.keep_signed_in,
      });
    }
  }

  if ((await activeDeviceCount(user.id)) >= MAX_DEVICES) {
    // The web signs this session out when it gets device_limit.
    return fail(
      "device_limit",
      `You can link up to ${MAX_DEVICES} devices. Remove a device on your phone first.`,
    );
  }

  const keep = body.keep_signed_in !== false;
  const expiresAt = new Date(
    Date.now() +
      (keep ? LONG_SESSION_DAYS * 86400_000 : SHORT_SESSION_HOURS * 3600_000),
  );
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim();
  const { data: device, error } = await admin
    .from("web_devices")
    .insert({
      user_id: user.id,
      device_token_hash: await sha256(randomToken()),
      session_id: sessionId,
      device_name: clip(body.device_name),
      browser: clip(body.browser),
      os: clip(body.os),
      location: clip(body.location),
      ip_address: clip(ip, 64),
      login_method: "phone",
      keep_signed_in: keep,
      expires_at: expiresAt.toISOString(),
    })
    .select("id")
    .single();
  if (error) return fail("server_error", "Could not register device", 500);

  return json({
    ok: true,
    device_id: device.id,
    device_expires_at: expiresAt.toISOString(),
    keep_signed_in: keep,
  });
}

// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return fail("method", "Use POST", 405);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return fail("bad_request", "Invalid JSON");
  }

  try {
    switch (body.action) {
      case "create":
        return await create(body, req);
      case "poll":
        return await poll(body);
      case "inspect":
        return await inspect(body, req);
      case "approve":
        return await decide(body, req, true);
      case "reject":
        return await decide(body, req, false);
      case "register":
        return await registerPhoneLogin(body, req);
      case "issue_code":
        return await issueCode(req);
      case "code_login":
        return await codeLogin(body, req);
      default:
        return fail("bad_request", "Unknown action");
    }
  } catch (e) {
    console.error(e);
    return fail("server_error", "Something went wrong", 500);
  }
});
