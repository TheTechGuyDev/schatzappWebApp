# SchatzApp Web: what the phone app must call

All calls use the logged-in phone user's Supabase session.

## 1. Scan the QR code
The web QR code contains text like:
`schatzapp://link-device?r=<request_id>&t=<token>`
Pass the whole scanned text as `qr`.

## 2. Edge Function `web-login`
URL: `https://hkcykdxiinvmepxebdsm.supabase.co/functions/v1/web-login`
Method: POST
Headers:
- `Authorization: Bearer <current user's access token>`
- `apikey: <anon key>`
- `Content-Type: application/json`

In FlutterFlow you can call it as a Supabase Edge Function / API call with
these headers. From custom code: `SupaFlow.client.functions.invoke('web-login', body: {...})`
(the user's token is added automatically).

### a) Show device details before approving
Body: `{ "action": "inspect", "qr": "<scanned text>" }`
Success:
```json
{ "ok": true, "device_name": "Chrome on Windows", "browser": "Chrome",
  "os": "Windows", "location": "WAT (UTC+1)", "ip_address": "...",
  "requested_at": "2026-11-23T00:30:00Z", "active_devices": 2, "max_devices": 7 }
```

### b) Approve
Body: `{ "action": "approve", "qr": "<scanned text>" }`
Success: `{ "ok": true, "status": "approved" }`

### c) Reject
Body: `{ "action": "reject", "qr": "<scanned text>" }`
Success: `{ "ok": true, "status": "rejected" }`

### Errors (all actions)
`{ "ok": false, "code": "...", "message": "..." }` - show `message` to the user.
- `unauthorized` - not logged in on the phone
- `invalid_qr` - not a SchatzApp QR code
- `expired` - QR expired or already used (refresh on the computer)
- `device_limit` - already 7 linked devices; remove one first

## 3. Linked Devices list
Query table `web_devices` (RLS returns only the user's own rows):
- filter `revoked_at` is null
- show `device_name`, `location`, `last_active_at`, `created_at`, `expires_at`
- order by `last_active_at` descending

## 4. Log out a device
- One device: RPC `revoke_web_device` with `p_device_id` = the row `id` -> returns true/false
- All devices: RPC `revoke_all_web_devices` (no params) -> returns number logged out

The web tab signs out immediately (Realtime), and its session is deleted on the server.

## Rules (enforced on the server)
- Max 7 linked web devices
- "Keep me signed in" ticked: 7 days; unticked: 24 hours
- 4 hours without activity: logged out
