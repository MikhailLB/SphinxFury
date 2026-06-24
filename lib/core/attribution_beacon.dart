import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../setup/app_spec.dart';
import '../setup/tracker_info.dart';
import 'net_client.dart';

// ─── AttributionBeacon ──────────────────────────────────────
// Thin wrapper around the AppsFlyer SDK that:
//
//   • Boots the SDK with our masked dev-key.
//   • Awaits the first conversion-data callback.
//   • Detects the well-known "false Organic" first-callback
//     bug and re-pulls via the GCD API after a short cool-down.
//   • Merges install attribution, deep-link payload and the
//     app-open attribution into a single body dict for the
//     verdict POST.
//
// Three Futures expose the timed-out waits to callers:
//   • [waitAttribution]
//   • [waitDeepLink]
//
// Helper [assembleBody] does the actual merge + device
// metadata injection.
// ────────────────────────────────────────────────────────────

const String _logTag = '«beacon»';

class AttributionBeacon {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _convPayload;
  Map<String, dynamic>? _deepLinkPayload;
  Map<String, dynamic>? _openPayload;

  final Completer<void> _convDone = Completer<void>();
  final Completer<void> _dlDone = Completer<void>();

  bool _started = false;

  Future<void> ignite() async {
    if (_started) return;
    _started = true;

    final opts = AppsFlyerOptions(
      afDevKey: AppSpec.trackerKey,
      appId: AppSpec.storefrontId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    final sdk = AppsflyerSdk(opts);
    _sdk = sdk;

    sdk.onInstallConversionData(_handleConversion);
    sdk.onAppOpenAttribution(_handleAppOpen);
    sdk.onDeepLinking(_handleDeepLink);

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('$_logTag initSdk failed: $e');
    }
  }

  // ── Callback handlers ─────────────────────────────────

  Future<void> _handleConversion(dynamic data) async {
    final payload = _extractPayload(data);
    if (kDebugMode) debugPrint('$_logTag conversion → ${jsonEncode(payload)}');

    final status = payload['af_status'];
    if (status == 'Organic') {
      await Future<void>.delayed(AppSpec.organicRetryDelay);
      final retried = await _gcdReprobe();
      _convPayload = retried ?? payload;
    } else {
      _convPayload = payload;
    }
    if (!_convDone.isCompleted) _convDone.complete();
  }

  void _handleAppOpen(dynamic data) {
    _openPayload = _extractPayload(data);
  }

  void _handleDeepLink(dynamic data) {
    try {
      final result = data is DeepLinkResult ? data : null;
      if (result?.deepLink != null) {
        _deepLinkPayload = result!.deepLink!.clickEvent;
      }
    } catch (_) {
      // tolerate SDK shape changes
    }
    if (!_dlDone.isCompleted) _dlDone.complete();
  }

  Map<String, dynamic> _extractPayload(dynamic data) {
    if (data is Map) {
      if (data['payload'] is Map) {
        return Map<String, dynamic>.from(data['payload'] as Map);
      }
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  // ── GCD retry (false-organic fix) ─────────────────────

  Future<Map<String, dynamic>?> _gcdReprobe() async {
    try {
      final uid = await readUid();
      if (uid == null || uid.isEmpty) return null;

      final appId =
          Platform.isIOS ? AppSpec.storefrontId : AppSpec.bundleId;
      final url = buildGcdEndpoint(appId: appId, deviceId: uid);

      final res = await netClient
          .get(
            Uri.parse(url),
            headers: {'authorization': 'Bearer ${AppSpec.trackerKey}'},
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          if (kDebugMode) debugPrint('$_logTag GCD payload → $decoded');
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('$_logTag GCD failed: $e');
    }
    return null;
  }

  // ── Public timed waits ────────────────────────────────

  Future<void> waitAttribution({Duration? cap}) async {
    final c = cap ?? AppSpec.firstAttributionWait;
    try {
      await _convDone.future.timeout(c);
    } on TimeoutException {
      if (kDebugMode) debugPrint('$_logTag attribution wait timed out');
    }
  }

  Future<void> waitDeepLink({Duration? cap}) async {
    final c = cap ?? AppSpec.deepLinkWait;
    try {
      await _dlDone.future.timeout(c);
    } on TimeoutException {
      // silent
    }
  }

  Future<String?> readUid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  // ── Body assembler ────────────────────────────────────

  Future<Map<String, dynamic>> assembleBody({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};

    if (_convPayload != null) body.addAll(_convPayload!);

    _deepLinkPayload?.forEach((k, v) {
      body.putIfAbsent(k, () => v);
    });
    _openPayload?.forEach((k, v) {
      body.putIfAbsent(k, () => v);
    });

    final uid = await readUid();
    body['af_id'] = uid ?? '';
    body['bundle_id'] = AppSpec.bundleId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = AppSpec.storeId;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    if (AppSpec.projectNumber.isNotEmpty) {
      body['firebase_project_id'] = AppSpec.projectNumber;
    }

    if (kDebugMode) {
      debugPrint('$_logTag verdict body → ${jsonEncode(body)}');
    }
    return body;
  }
}
