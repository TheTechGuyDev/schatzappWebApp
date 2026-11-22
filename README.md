# SchatzApp Web

Flutter Web client for SchatzApp (WhatsApp Web style). Connects to the same Supabase project as the mobile app. Users sign in by scanning a QR code with the logged-in phone app.

- Deploys to GitHub Pages on every push to `main` (`.github/workflows/deploy.yml`).
- Only the public Supabase anon key is used in the client. Privileged work runs in Supabase Edge Functions.
