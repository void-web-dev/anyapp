class MarketplaceCatalog {
  const MarketplaceCatalog({
    required this.title,
    required this.description,
    required this.apps,
  });

  final String title;
  final String description;
  final List<MarketplaceApp> apps;

  factory MarketplaceCatalog.fromJson(Map<String, dynamic> json) {
    final rawApps = json['apps'];
    if (rawApps is! List) {
      throw const FormatException('Поле marketplace.apps должно быть списком');
    }
    return MarketplaceCatalog(
      title: json['title'] as String? ?? 'Маркетплейс any2app',
      description: json['description'] as String? ?? '',
      apps: rawApps
          .map(
            (item) =>
                MarketplaceApp.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
    );
  }
}

class MarketplaceApp {
  const MarketplaceApp({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.sourceType,
    required this.source,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final String icon;
  final String sourceType;
  final String source;

  factory MarketplaceApp.fromJson(Map<String, dynamic> json) {
    final configuration = Map<String, dynamic>.from(
      json['configuration'] as Map? ?? const {},
    );
    final app = MarketplaceApp(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      icon: json['icon'] as String? ?? 'apps',
      sourceType: configuration['type'] as String? ?? '',
      source: configuration['source'] as String? ?? '',
    );
    if (app.id.isEmpty || app.name.isEmpty || app.source.isEmpty) {
      throw const FormatException(
        'Приложению marketplace нужны id, name и configuration.source',
      );
    }
    if (app.sourceType != 'asset' && app.sourceType != 'url') {
      throw FormatException('Неизвестный тип конфигурации "${app.sourceType}"');
    }
    return app;
  }
}
