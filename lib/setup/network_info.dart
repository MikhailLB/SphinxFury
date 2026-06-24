import '../security/cryptex.dart';

// ─── network_info ───────────────────────────────────────────
// Hidden config endpoint.  The route resolver POSTs the
// attribution body to this URL and receives a {ok,url,expires}
// verdict back.  Both host and path are masked so the binary
// holds no obvious string fingerprint of the partner backend.
// ────────────────────────────────────────────────────────────

const List<int> _hostMask = <int>[
  0x17, 0x05, 0xae, 0x3a, 0xa7, 0x1e, 0x91, 0x68,
  0x51, 0x24, 0x11, 0x0f, 0xf0, 0x07, 0x65, 0xdb,
  0xf2, 0x34, 0xe0, 0x8b, 0x78, 0xd0,
];

const List<int> _pathMask = <int>[
  0x50, 0x12, 0xb5, 0x24, 0xb2, 0x4d, 0xd9, 0x69,
  0x52, 0x3c, 0x09,
];

String resolveVerdictUrl() => unmask(_hostMask) + unmask(_pathMask);
