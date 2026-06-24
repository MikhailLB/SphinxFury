// ─── keymint ────────────────────────────────────────────────
// Tool to mint Cryptex-compatible byte arrays from plain text.
//
//   dart run tool/keymint.dart
//
// Edit the [_plaintext] map below with your project's secrets,
// then run the script.  Each entry is printed as a Dart list
// literal that you can paste into lib/setup/* files.
//
// ⚠️ Always use `dart run` — never PowerShell foreach loops
// (32-bit overflow on Windows produces wrong byte values).
// ────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'dart:convert';

// SphinxFury seed — keep aligned with lib/security/cryptex.dart::_seedBytes
const List<int> _seedBytes = <int>[
  0x73, 0x70, 0x68, 0x78, 0x66, 0x75, 0x72, 0x79,
];

const int _keyLen = 24;

Uint8List _buildStream() {
  if (_seedBytes.isEmpty) return Uint8List(_keyLen);
  var state = 0x811C9DC5;
  for (final b in _seedBytes) {
    state = (state ^ (b & 0xFF)) & 0xFFFFFFFF;
    state = (state * 0x01000193) & 0xFFFFFFFF;
  }
  if (state == 0) state = 0x9E3779B9;
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

List<int> _mask(String text) {
  final stream = _buildStream();
  final src = utf8.encode(text);
  final out = List<int>.filled(src.length, 0);
  for (var i = 0; i < src.length; i++) {
    out[i] = src[i] ^ stream[i % stream.length];
  }
  return out;
}

void _printPair(String label, String text) {
  final bytes = _mask(text);
  final hex = bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ');
  print('// $label  =  $text');
  print('// → const opaque = <int>[$hex];');
  print('');
}

void main() {
  // ── Edit these for the SphinxFury build ──────────────────
  const Map<String, String> plaintext = {
    'CONFIG_HOST':       'https://sphinxfury.com',
    'CONFIG_PATH':       '/config.php',

    'TRACKER_KEY':       'zYEZsuve9xeGNUhAddaE2T',
    'TRACKER_PROJECT':   '333616663251',

    'GCD_HOST':          'https://gcdsdk.appsflyer.com',
    'GCD_PATH':          '/install_data/v4.0/',

    'CHROME_VER':        '132.0.6834.163',
    'WEBKIT_VER':        '537.36',
  };
  // ─────────────────────────────────────────────────────────

  print('// keymint output for SphinxFury');
  print('// seed: sphxfury  (8 bytes)');
  print('// generated: ${DateTime.now().toIso8601String()}');
  print('');
  plaintext.forEach(_printPair);
}
