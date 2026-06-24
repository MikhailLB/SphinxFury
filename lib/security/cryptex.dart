import 'dart:typed_data';

// ─── Cryptex ─────────────────────────────────────────────────
// Tiny string demasker for binary-baked secrets.
//
// Sensitive strings (config endpoint host, AppsFlyer key,
// Firebase project number, UA fragments) live in source as
// byte lists rather than literal text. They are stitched back
// into UTF-8 at runtime by [unmask] using a per-project key
// stream derived from [_seedBytes].
//
// Rotate [_seedBytes] for each new project and re-mint every
// byte array via tool/keymint.dart.
// ────────────────────────────────────────────────────────────

// Seed phrase for the SphinxFury project — ASCII bytes of "sphxfury".
// Unique per project. Any rotation MUST be paired with a full re-mint.
const List<int> _seedBytes = <int>[
  0x73, 0x70, 0x68, 0x78, 0x66, 0x75, 0x72, 0x79,
];

const int _keyLen = 24;

Uint8List _buildStream() {
  if (_seedBytes.isEmpty) return Uint8List(_keyLen);

  // Mix the seed into a 32-bit state by hashing with FNV-1a flavor.
  var state = 0x811C9DC5;
  for (final b in _seedBytes) {
    state = (state ^ (b & 0xFF)) & 0xFFFFFFFF;
    state = (state * 0x01000193) & 0xFFFFFFFF;
  }
  if (state == 0) state = 0x9E3779B9;

  // Stretch via xorshift32 into a 24-byte stream.
  final out = Uint8List(_keyLen);
  var s = state;
  for (var i = 0; i < _keyLen; i++) {
    s ^= (s << 13) & 0xFFFFFFFF;
    s ^= (s >> 17);
    s ^= (s << 5) & 0xFFFFFFFF;
    s &= 0xFFFFFFFF;
    out[i] = (s ^ (s >> 8) ^ (s >> 16) ^ (s >> 24)) & 0xFF;
  }
  return out;
}

final Uint8List _stream = _buildStream();

/// Lift a hidden ASCII/UTF-8 string out of its byte list form.
/// Invariant: [unmask] on output of tool/keymint.dart returns the source string.
String unmask(List<int> opaque) {
  if (opaque.isEmpty) return '';
  final buf = Uint8List(opaque.length);
  for (var i = 0; i < opaque.length; i++) {
    buf[i] = opaque[i] ^ _stream[i % _stream.length];
  }
  return String.fromCharCodes(buf);
}
