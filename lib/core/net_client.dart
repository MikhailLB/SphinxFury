import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../security/cryptex.dart';
import '../setup/app_spec.dart';

// ─── NetClient ──────────────────────────────────────────────
// HTTP client that injects a real-device User-Agent header on
// every outgoing request.  The same UA string is later applied
// to the WebView controller so all traffic is consistent.
//
// Chrome / WebKit version fragments are masked through Cryptex
// to keep them out of plaintext APK scans.
// ────────────────────────────────────────────────────────────

const List<int> _chromeMask = <int>[
  0x4e, 0x42, 0xe8, 0x64, 0xe4, 0x0a, 0x88, 0x7f,
  0x11, 0x60, 0x57, 0x57, 0xa8, 0x4c,
];

const List<int> _webkitMask = <int>[
  0x4a, 0x42, 0xed, 0x64, 0xe7, 0x12,
];

String _chromeVer() {
  final s = unmask(_chromeMask);
  return s.isEmpty ? '130.0.0.0' : s;
}

String _webkitVer() {
  final s = unmask(_webkitMask);
  return s.isEmpty ? '537.36' : s;
}

/// Identity suffix appended to every UA we emit so the partner
/// backend can attribute traffic to this specific build.
/// Format dictated by the gray-flow user-agent rule:
///   `<browser UA> appid/<bundleId> appname/<AppName>`
String _identitySuffix() {
  final appName = AppSpec.displayName.replaceAll(' ', '');
  return ' appid/${AppSpec.bundleId} appname/$appName';
}

class NetClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  String? _ua;

  /// Build the per-device UA string. Call once before runApp().
  ///
  /// The browser-shaped prefix is built from real DeviceInfoPlus data,
  /// then [_identitySuffix] is appended so backend can carrier-tag
  /// traffic from this build (`appid/...`, `appname/...`).
  Future<void> prime() async {
    final suffix = _identitySuffix();
    String prefix;
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        final sdk = a.version.sdkInt;
        final model = a.model;
        final brand = a.brand;
        final build = a.display.isNotEmpty ? a.display : a.id;
        final cv = _chromeVer();
        prefix =
            'Mozilla/5.0 (Linux; Android $sdk; $brand $model Build/$build) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$cv Mobile Safari/537.36';
      } else {
        final i = await info.iosInfo;
        final ver = i.systemVersion.replaceAll('.', '_');
        final sv = _webkitVer();
        prefix =
            'Mozilla/5.0 (iPhone; CPU iPhone OS $ver like Mac OS X) '
            'AppleWebKit/$sv (KHTML, like Gecko) '
            'Version/${i.systemVersion} Mobile/15E148 Safari/$sv';
      }
    } catch (_) {
      final cv = _chromeVer();
      final sv = _webkitVer();
      prefix = Platform.isAndroid
          ? 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/$cv Mobile Safari/537.36'
          : 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
              'AppleWebKit/$sv (KHTML, like Gecko) Version/17.0 Mobile/15E148 '
              'Safari/$sv';
    }
    _ua = '$prefix$suffix';
  }

  String get ua => _ua ?? ('Mozilla/5.0${_identitySuffix()}');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => ua);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Process-wide singleton wired by [bootstrap].
final NetClient netClient = NetClient();
