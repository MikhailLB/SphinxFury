import 'package:flutter/material.dart';

import 'bootstrap.dart';

Future<void> main() async {
  final root = await wire();
  runApp(root);
}
