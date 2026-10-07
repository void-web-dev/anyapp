import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/app_config.dart';

abstract interface class ConfigRepository {
  Future<AppConfig> loadUrl(String url);
  Future<RemoteScreenBundle> loadScreenUrl(String url);
  Future<AppConfig> loadAsset(String assetPath);
  Future<AppConfig> loadInline(String source);
  Future<AppConfig> loadDemo();
}

class HttpConfigRepository implements ConfigRepository {
  HttpConfigRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<AppConfig> loadUrl(String url) async {
    return _decode(await _loadSource(url));
  }

  @override
  Future<RemoteScreenBundle> loadScreenUrl(String url) async {
    final decoded = jsonDecode(await _loadSource(url));
    if (decoded is! Map) {
      throw const FormatException('Описание экрана должно быть объектом');
    }
    return RemoteScreenBundle.fromJson(Map<String, dynamic>.from(decoded));
  }

  @override
  Future<AppConfig> loadAsset(String assetPath) async {
    final source = await rootBundle.loadString(assetPath);
    return _decode(source);
  }

  @override
  Future<AppConfig> loadInline(String source) async => _decode(source);

  @override
  Future<AppConfig> loadDemo() => loadAsset('assets/config/dummyjson_demo.json');

  AppConfig _decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Корень конфигурации должен быть объектом');
    }
    return AppConfig.fromJson(decoded);
  }

  Future<String> _loadSource(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('Введите корректный HTTP или HTTPS URL');
    }
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ConfigLoadException(
        'Сервер конфигурации вернул ${response.statusCode}',
      );
    }
    if (response.bodyBytes.length > 1024 * 1024) {
      throw const ConfigLoadException(
        'Конфигурация или экран превышает допустимый размер 1 MB',
      );
    }
    return utf8.decode(response.bodyBytes);
  }
}

class ConfigLoadException implements Exception {
  const ConfigLoadException(this.message);
  final String message;

  @override
  String toString() => message;
}
