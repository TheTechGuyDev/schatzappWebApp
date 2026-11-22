/// Public client configuration.
///
/// The Supabase anon key is a public key protected by RLS. It is the same key
/// the mobile app ships with. The service_role key must never appear here.
/// Both values can be overridden at build time with --dart-define.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hkcykdxiinvmepxebdsm.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhrY3lrZHhpaW52bWVweGViZHNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODczMTY0OTgsImV4cCI6MjEwMjg5MjQ5OH0.YSHUDWqOAd5mSuABx9_J4_phV0rdidy-CIBdqqVWJ1U',
  );
}
