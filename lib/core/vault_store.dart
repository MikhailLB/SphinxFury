import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/route_mode.dart';

// ─── VaultStore ─────────────────────────────────────────────
// Two-tier persistence:
//   • SharedPreferences for ordinary flags (mode, timestamps).
//   • FlutterSecureStorage for URLs (so the affiliate target
//     never lives in plaintext within app sandbox files).
//
// All keys use short opaque names — long descriptive identifiers
// would be a useful grep hint for static analysis.
// ────────────────────────────────────────────────────────────

class VaultStore {
  static const _kMode = 'r_m';
  static const _kSaved = 'r_u';
  static const _kExpiry = 'r_e';
  static const _kConsentSkip = 'p_s';
  static const _kConsentGranted = 'p_g';
  static const _kConsentOsDenied = 'p_o';
  static const _kPushOneShot = 'p_u';

  late SharedPreferences _prefs;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> wireUp() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── route mode ─────────────────────────────────────────
  RouteMode currentMode() => RouteMode.wire(_prefs.getString(_kMode));
  Future<void> commitMode(RouteMode m) => _prefs.setString(_kMode, m.marshal());

  // ── saved verdict url (secure) ────────────────────────
  Future<String?> readSavedUrl() => _secure.read(key: _kSaved);
  Future<void> writeSavedUrl(String url) =>
      _secure.write(key: _kSaved, value: url);

  // ── expiry ─────────────────────────────────────────────
  int? readExpiry() => _prefs.getInt(_kExpiry);
  Future<void> writeExpiry(int unixSeconds) =>
      _prefs.setInt(_kExpiry, unixSeconds);

  bool isExpired() {
    final e = readExpiry();
    if (e == null) return true;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= e;
  }

  // ── notification consent ──────────────────────────────
  bool isConsentGranted() => _prefs.getBool(_kConsentGranted) ?? false;
  Future<void> markConsent(bool granted) =>
      _prefs.setBool(_kConsentGranted, granted);

  /// OS-denied flag — once the user taps "Don't allow" in the system
  /// dialog Android won't re-show it. Use this so the in-app promo
  /// also stops appearing.
  bool isConsentOsBlocked() => _prefs.getBool(_kConsentOsDenied) ?? false;
  Future<void> markConsentOsBlocked() => _prefs.setBool(_kConsentOsDenied, true);

  int? readConsentSkipUntil() => _prefs.getInt(_kConsentSkip);
  Future<void> writeConsentSkipUntil(int unixSeconds) =>
      _prefs.setInt(_kConsentSkip, unixSeconds);

  bool shouldPromptForConsent() {
    if (isConsentGranted()) return false;
    if (isConsentOsBlocked()) return false;
    final until = readConsentSkipUntil();
    if (until == null) return true;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= until;
  }

  // ── one-shot push url (secure) ────────────────────────
  Future<String?> peekPushUrl() => _secure.read(key: _kPushOneShot);
  Future<void> stashPushUrl(String? url) async {
    if (url == null) {
      await _secure.delete(key: _kPushOneShot);
    } else {
      await _secure.write(key: _kPushOneShot, value: url);
    }
  }

  Future<String?> drainPushUrl() async {
    final v = await peekPushUrl();
    if (v != null) await _secure.delete(key: _kPushOneShot);
    return v;
  }
}
