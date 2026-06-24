// ─── RouteVerdict ───────────────────────────────────────────
// Decoded form of the JSON returned by the config endpoint:
//
//   { "ok": true,  "url": "https://...", "expires": 1700000000 }
//   { "ok": false, "message": "organic" }
//
// `expires` is a Unix epoch in seconds; null means "no expiry".
// ────────────────────────────────────────────────────────────

class RouteVerdict {
  final bool ok;
  final String? url;
  final String? message;
  final int? expires;

  const RouteVerdict({
    required this.ok,
    this.url,
    this.message,
    this.expires,
  });

  factory RouteVerdict.parse(Map<String, dynamic> json) => RouteVerdict(
        ok: json['ok'] == true,
        url: json['url'] is String ? json['url'] as String : null,
        message: json['message'] is String ? json['message'] as String : null,
        expires: json['expires'] is int ? json['expires'] as int : null,
      );

  factory RouteVerdict.faulty(String reason) =>
      RouteVerdict(ok: false, message: reason);

  bool get directsToWeb => ok && url != null && url!.isNotEmpty;
}
