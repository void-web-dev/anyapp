import 'dart:convert';

import 'package:crypto/crypto.dart';

String createAppScope(String source) {
  final normalized = source.trim();
  final digest = sha256.convert(utf8.encode(normalized)).toString();
  return 'app.$digest';
}
