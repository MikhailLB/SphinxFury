// ─── RouteMode ──────────────────────────────────────────────
// One of three persistent "modes" the app sits in:
//
//   • pending  → never resolved (first-ever launch).
//   • online   → the verdict picked the WebView path.
//   • offline  → the verdict picked the native game path.
//
// Once we land on online/offline we never re-evaluate to the
// opposite — the verdict is intentionally sticky.
// ────────────────────────────────────────────────────────────

enum RouteMode {
  pending,
  online,
  offline;

  /// Re-hydrate from SharedPreferences storage.
  static RouteMode wire(String? raw) => switch (raw) {
        'online' => RouteMode.online,
        'offline' => RouteMode.offline,
        _ => RouteMode.pending,
      };

  /// Serialise for SharedPreferences storage.
  String marshal() => switch (this) {
        RouteMode.online => 'online',
        RouteMode.offline => 'offline',
        RouteMode.pending => 'pending',
      };
}
