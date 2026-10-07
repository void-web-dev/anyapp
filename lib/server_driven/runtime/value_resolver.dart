import 'dart:convert';

import 'package:crypto/crypto.dart';

class RuntimeValues {
  const RuntimeValues({
    required this.form,
    required this.data,
    required this.auth,
    this.result,
    this.extra = const {},
  });

  final Map<String, dynamic> form;
  final Map<String, dynamic> data;
  final Map<String, dynamic> auth;
  final dynamic result;
  final Map<String, dynamic> extra;

  dynamic root(String name) {
    return switch (name) {
      'form' => form,
      'data' => data,
      'auth' => auth,
      'result' => result,
      _ => extra[name],
    };
  }
}

dynamic resolveTemplate(dynamic template, RuntimeValues values) {
  if (template is List) {
    return template.map((item) => resolveTemplate(item, values)).toList();
  }
  if (template is Map) {
    return template.map(
      (key, value) => MapEntry(key.toString(), resolveTemplate(value, values)),
    );
  }
  if (template is! String) return template;

  final exact = RegExp(r'^\{\{\s*([^}]+?)\s*\}\}$').firstMatch(template);
  if (exact != null) return resolveValue(exact.group(1)!, values);

  return template.replaceAllMapped(RegExp(r'\{\{\s*([^}]+?)\s*\}\}'), (match) {
    final value = resolveValue(match.group(1)!, values);
    return value?.toString() ?? '';
  });
}

dynamic resolveValue(String expression, RuntimeValues values) {
  final source = expression.trim();
  final literal = _literalValue(source);
  if (literal.$1) return literal.$2;

  final function = RegExp(
    r'^([A-Za-z_][A-Za-z0-9_]*)\s*\((.*)\)$',
    dotAll: true,
  ).firstMatch(source);
  if (function != null) {
    final name = function.group(1)!.toLowerCase();
    final arguments = _splitArguments(
      function.group(2)!,
    ).map((argument) => resolveValue(argument, values)).toList(growable: false);
    return switch (name) {
      'concat' => arguments.map(_stringify).join(),
      'sha256' || 'hash' when arguments.length == 1 =>
        sha256.convert(utf8.encode(_stringify(arguments.single))).toString(),
      'sha256' || 'hash' => throw const FormatException(
        'sha256() принимает ровно один аргумент',
      ),
      _ => throw FormatException('Неизвестная функция шаблона: $name'),
    };
  }

  final parts = source
      .replaceFirst(RegExp(r'^\$\.'), '')
      .split('.')
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;
  dynamic current = values.root(parts.removeAt(0));
  for (final part in parts) {
    current = readSegment(current, part);
    if (current == null) return null;
  }
  return current;
}

(bool, dynamic) _literalValue(String source) {
  if (source.length >= 2 && source.startsWith('"') && source.endsWith('"')) {
    try {
      return (true, jsonDecode(source));
    } on FormatException {
      throw const FormatException('Некорректная строка в шаблоне');
    }
  }
  if (source.length >= 2 && source.startsWith("'") && source.endsWith("'")) {
    final value = source
        .substring(1, source.length - 1)
        .replaceAll(r"\'", "'")
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\\', '\\');
    return (true, value);
  }
  if (source == 'true') return (true, true);
  if (source == 'false') return (true, false);
  if (source == 'null') return (true, null);
  final number = num.tryParse(source);
  return number == null ? (false, null) : (true, number);
}

List<String> _splitArguments(String source) {
  if (source.trim().isEmpty) return const [];
  final arguments = <String>[];
  var depth = 0;
  String? quote;
  var escaped = false;
  var start = 0;
  for (var index = 0; index < source.length; index++) {
    final character = source[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (character == '\\') {
      escaped = true;
      continue;
    }
    if (quote != null) {
      if (character == quote) quote = null;
      continue;
    }
    if (character == '"' || character == "'") {
      quote = character;
      continue;
    }
    if (character == '(') {
      depth++;
    } else if (character == ')') {
      depth--;
      if (depth < 0) {
        throw const FormatException('Некорректные скобки в шаблоне');
      }
    } else if (character == ',' && depth == 0) {
      arguments.add(source.substring(start, index).trim());
      start = index + 1;
    }
  }
  if (quote != null || depth != 0) {
    throw const FormatException('Незавершённое выражение шаблона');
  }
  arguments.add(source.substring(start).trim());
  if (arguments.any((argument) => argument.isEmpty)) {
    throw const FormatException('Пустой аргумент функции шаблона');
  }
  return arguments;
}

String _stringify(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return jsonEncode(_canonicalize(value));
}

dynamic _canonicalize(dynamic value) {
  if (value is List) return value.map(_canonicalize).toList();
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {for (final key in keys) key: _canonicalize(value[key])};
  }
  return value;
}

dynamic readJsonPath(dynamic value, String? path) {
  if (path == null || path.isEmpty || path == r'$') return value;
  final normalized = path.replaceFirst(RegExp(r'^\$\.'), '');
  dynamic current = value;
  for (final segment in normalized.split('.')) {
    current = readSegment(current, segment);
    if (current == null) return null;
  }
  return current;
}

dynamic readSegment(dynamic current, String segment) {
  final indexed = RegExp(r'^([^\[]+)?\[(\d+)\]$').firstMatch(segment);
  if (indexed != null) {
    final key = indexed.group(1);
    if (key != null && key.isNotEmpty) {
      if (current is! Map) return null;
      current = current[key];
    }
    if (current is! List) return null;
    final index = int.parse(indexed.group(2)!);
    return index < current.length ? current[index] : null;
  }
  if (current is Map) return current[segment];
  if (current is List) {
    final index = int.tryParse(segment);
    return index != null && index < current.length ? current[index] : null;
  }
  return null;
}
