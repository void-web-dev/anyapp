import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/marketplace_catalog.dart';

abstract interface class MarketplaceRepository {
  Future<MarketplaceCatalog> load();
}

class AssetMarketplaceRepository implements MarketplaceRepository {
  const AssetMarketplaceRepository();

  @override
  Future<MarketplaceCatalog> load() async {
    final source = await rootBundle.loadString(
      'assets/config/marketplace.json',
    );
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Корень marketplace должен быть объектом');
    }
    return MarketplaceCatalog.fromJson(decoded);
  }
}
