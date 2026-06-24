import 'network_info.dart';
import 'tracker_info.dart';

// ─── AppSpec ────────────────────────────────────────────────
// Central read-only facade for all app-wide constants.
// Provides indirection for masked values so call sites stay
// declarative and free of cryptex plumbing.
// ────────────────────────────────────────────────────────────

class AppSpec {
  AppSpec._();

  static const String bundleId = 'com.legendsphinx.sphinxfury';
  static const String storeId = 'com.legendsphinx.sphinxfury';
  static const String displayName = 'Sphinx Fury';

  /// iOS-only App Store id. Empty on Android.
  static const String storefrontId = '';

  static String get verdictEndpoint => resolveVerdictUrl();
  static String get trackerKey => unwrapTrackerKey();
  static String get projectNumber => unwrapProjectNumber();

  /// Push prompt re-show cool-down (3 days).
  static const Duration consentColdDown = Duration(days: 3);

  /// Delay after an "Organic" attribution payload before issuing
  /// the GCD retry call.
  static const Duration organicRetryDelay = Duration(seconds: 5);

  /// Hard cap on the first-launch attribution wait.
  static const Duration firstAttributionWait = Duration(seconds: 30);

  /// Hard cap on the warm-launch attribution wait.
  static const Duration warmAttributionWait = Duration(seconds: 10);

  /// Hard cap on the deep-link callback wait.
  static const Duration deepLinkWait = Duration(seconds: 5);
}
