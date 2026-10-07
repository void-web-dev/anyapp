import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

import '../models/app_config.dart';
import '../runtime/value_resolver.dart';

class AppLinkPayload {
  const AppLinkPayload({this.configUrl, this.config, this.initial = const {}});

  final String? configUrl;
  final Map<String, dynamic>? config;
  final Map<String, dynamic> initial;

  bool get hasConfiguration =>
      (configUrl != null && configUrl!.isNotEmpty) || config != null;

  Uri toUri(Uri base) {
    return base.replace(
      queryParameters: {
        ...base.queryParameters,
        if (configUrl != null && configUrl!.isNotEmpty) 'configUrl': configUrl!,
        if (config != null) 'config': _encodeJson(config!),
        if (initial.isNotEmpty) 'initial': _encodeJson(initial),
      },
    );
  }

  factory AppLinkPayload.fromUri(Uri uri) {
    final parameters = uri.queryParameters;
    return AppLinkPayload(
      configUrl: parameters['configUrl'],
      config: _decodeMap(parameters['config']),
      initial: _decodeMap(parameters['initial']) ?? const {},
    );
  }

  factory AppLinkPayload.fromRaw(String raw) {
    final value = raw.trim();
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      if ((uri.scheme == 'http' || uri.scheme == 'https') &&
          !uri.queryParameters.containsKey('config') &&
          !uri.queryParameters.containsKey('configUrl')) {
        return AppLinkPayload(configUrl: value);
      }
      return AppLinkPayload.fromUri(uri);
    }
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('QR payload должен быть JSON-объектом');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (map.containsKey('config') || map.containsKey('configUrl')) {
      return AppLinkPayload(
        configUrl: map['configUrl'] as String?,
        config: map['config'] is Map
            ? Map<String, dynamic>.from(map['config'] as Map)
            : null,
        initial: map['initial'] is Map
            ? Map<String, dynamic>.from(map['initial'] as Map)
            : const {},
      );
    }
    return AppLinkPayload(config: map);
  }

  static String _encodeJson(Object value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  static Map<String, dynamic>? _decodeMap(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    dynamic decoded;
    try {
      final normalized = encoded.padRight(
        encoded.length + ((4 - encoded.length % 4) % 4),
        '=',
      );
      decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
    } on FormatException {
      decoded = jsonDecode(encoded);
    }
    if (decoded is! Map) {
      throw const FormatException('Payload должен содержать JSON-объект');
    }
    return Map<String, dynamic>.from(decoded);
  }
}

abstract interface class AppLinkService {
  Future<void> launchAction(ActionConfig action, RuntimeValues values);
}

class UrlAppLinkService implements AppLinkService {
  const UrlAppLinkService();

  @override
  Future<void> launchAction(ActionConfig action, RuntimeValues values) async {
    final request = resolveTemplate(action.request, values);
    final rawUrl = request['url']?.toString() ?? 'any2app://open';
    final base = Uri.tryParse(rawUrl);
    if (base == null || !base.hasScheme) {
      throw const FormatException('LINK action требует абсолютный URL');
    }
    final rawConfig = request['config'];
    final payload = AppLinkPayload(
      configUrl: request['configUrl']?.toString(),
      config: rawConfig is Map
          ? Map<String, dynamic>.from(rawConfig)
          : rawConfig is String && rawConfig.trim().startsWith('{')
          ? Map<String, dynamic>.from(jsonDecode(rawConfig) as Map)
          : null,
      initial: request['initial'] is Map
          ? Map<String, dynamic>.from(request['initial'] as Map)
          : const {},
    );
    final extraQuery = request['query'] is Map
        ? (request['query'] as Map).map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : const <String, String>{};
    final withPayload = payload.toUri(base);
    final target = withPayload.replace(
      queryParameters: {...withPayload.queryParameters, ...extraQuery},
    );
    final launched = await launchUrl(
      target,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw FormatException('Не удалось открыть ссылку $target');
    }
  }
}
