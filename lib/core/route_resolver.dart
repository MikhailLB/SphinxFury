import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/route_verdict.dart';
import '../setup/app_spec.dart';
import 'net_client.dart';
import 'vault_store.dart';

// ─── RouteResolver ──────────────────────────────────────────
// Single responsibility: POST the body produced by
// AttributionBeacon.assembleBody() to the masked endpoint and
// turn the JSON response into a [RouteVerdict].
//
// Side-effects on a successful (ok+url) verdict:
//   • Persist the url through VaultStore.writeSavedUrl().
//   • Persist the expires timestamp through writeExpiry().
// ────────────────────────────────────────────────────────────

const String _logTag = '«resolver»';

class RouteResolver {
  static const _httpCap = Duration(seconds: 15);

  final VaultStore _vault;
  const RouteResolver(this._vault);

  Future<RouteVerdict> probe(Map<String, dynamic> body) async {
    final endpoint = AppSpec.verdictEndpoint;
    if (endpoint.isEmpty) {
      return RouteVerdict.faulty('endpoint not configured');
    }

    try {
      final response = await netClient
          .post(
            Uri.parse(endpoint),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_httpCap);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('$_logTag non-200 → ${response.statusCode}');
        }
        return RouteVerdict.faulty('http_${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return RouteVerdict.faulty('bad payload shape');
      }

      final verdict =
          RouteVerdict.parse(Map<String, dynamic>.from(decoded));

      if (verdict.directsToWeb) {
        await _vault.writeSavedUrl(verdict.url!);
        if (verdict.expires != null) {
          await _vault.writeExpiry(verdict.expires!);
        }
      }
      if (kDebugMode) {
        debugPrint(
            '$_logTag verdict → ok=${verdict.ok} url=${verdict.url ?? "—"}');
      }
      return verdict;
    } on TimeoutException {
      return RouteVerdict.faulty('timeout');
    } catch (e) {
      if (kDebugMode) debugPrint('$_logTag failure: $e');
      return RouteVerdict.faulty(e.toString());
    }
  }

  Future<String?> recallUrl() => _vault.readSavedUrl();
}
