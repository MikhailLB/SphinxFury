import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

// ─── LinkMonitor ────────────────────────────────────────────
// Simple connectivity probe.  Two checks:
//   1. Reactive: stream of ConnectivityResult changes (the
//      WebView screen listens and reacts to "all none").
//   2. Active: DNS lookup against a stable host (used at
//      splash launch).  A reachable interface doesn't mean
//      actual internet, hence the DNS round-trip.
// ────────────────────────────────────────────────────────────

class LinkMonitor {
  final Connectivity _native = Connectivity();

  static const _probeHost = 'cloudflare.com';
  static const _probeTimeout = Duration(seconds: 3);

  /// True iff the OS sees a network interface *and* DNS resolves.
  Future<bool> isOnline() async {
    final hops = await _native.checkConnectivity();
    final anyLink = hops.any((r) => r != ConnectivityResult.none);
    if (!anyLink) return false;
    return _dnsAlive();
  }

  Future<bool> _dnsAlive() async {
    try {
      final r = await InternetAddress.lookup(_probeHost).timeout(_probeTimeout);
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get pulse =>
      _native.onConnectivityChanged;
}
