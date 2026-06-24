import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/attribution_beacon.dart';
import 'core/link_monitor.dart';
import 'core/net_client.dart';
import 'core/route_resolver.dart';
import 'core/signal_dispatcher.dart';
import 'core/vault_store.dart';
import 'views/intro_view.dart';

// ─── bootstrap ──────────────────────────────────────────────
// One-stop wiring helper called from main(). Initialises every
// long-lived dependency, then hands a fully-built widget tree
// back to the caller.
// ────────────────────────────────────────────────────────────

Future<Widget> wire() async {
  WidgetsFlutterBinding.ensureInitialized();

  // System chrome — gray flow supports both orientations; the
  // IntroView itself flips into immersive sticky mode.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Firebase + App Check — wrapped in catch so a missing
  // google-services.json never bricks the app.
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {
    // Push + verdict signing will be unavailable — gray flow
    // still falls back into the white game cleanly.
  }

  // HTTP client with real-device UA must be primed first so any
  // subsequent service can post with it.
  await netClient.prime();

  final vault = VaultStore();
  await vault.wireUp();

  final link = LinkMonitor();
  final beacon = AttributionBeacon();
  final resolver = RouteResolver(vault);
  final signal = SignalDispatcher(vault);

  return _SphinxFuryShell(
    vault: vault,
    link: link,
    beacon: beacon,
    resolver: resolver,
    signal: signal,
  );
}

class _SphinxFuryShell extends StatelessWidget {
  final VaultStore vault;
  final LinkMonitor link;
  final AttributionBeacon beacon;
  final RouteResolver resolver;
  final SignalDispatcher signal;

  const _SphinxFuryShell({
    required this.vault,
    required this.link,
    required this.beacon,
    required this.resolver,
    required this.signal,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sphinx Fury',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4AF37),
          brightness: Brightness.dark,
        ),
      ),
      home: IntroView(
        vault: vault,
        link: link,
        beacon: beacon,
        resolver: resolver,
        signal: signal,
      ),
    );
  }
}
