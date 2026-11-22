// SchatzApp Web: QR login Edge Function ("web-login").
//
// Actions (POST JSON { action, ... }):
//   create   (web, no login)  -> new QR request, valid 60 seconds
//   poll     (web, no login)  -> status; when approved, returns the web session
//   inspect  (phone, logged in) -> device details to show before approving
//   approve  (phone, logged in) -> approve the scanned QR
//   reject   (phone, logged in) -> reject the scanned QR
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

  // Open a separate web session for this user. Phone-number accounts have
  // no email, so: set a random one-time password, sign in with it once,
  // then replace it with another random value nobody knows.
  const { data: u } = await admin.auth.admin.getUserById(claimed.user_id);
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
      (claimed.keep_signed_in
        ? LONG_SESSION_DAYS * 86400_000
        : SHORT_SESSION_HOURS * 3600_000),
  );
  const { data: device, error: dErr } = await admin
    .from("web_devices")
    .insert({
      user_id: user.id,
      device_token_hash: await sha256(deviceToken),
      session_id: sessionIdFromJwt(s.session.access_token),
      device_name: claimed.device_name,
      browser: claimed.browser,
      os: claimed.os,
      ip_address: claimed.ip_address,
      location: claimed.location,
      login_method: "qr",
      keep_signed_in: claimed.keep_signed_in,
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
    keep_signed_in: claimed.keep_signed_in,
    access_token: s.session.access_token,
    refresh_token: s.session.refresh_token,
  });
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
      default:
        return fail("bad_request", "Unknown action");
    }
  } catch (e) {
    console.error(e);
    return fail("server_error", "Something went wrong", 500);
  }
});
