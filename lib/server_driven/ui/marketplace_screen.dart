import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../ui/ui.dart';
import '../models/marketplace_catalog.dart';
import '../runtime/app_controller.dart';

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final marketplace = controller.marketplace;
    final loading = controller.configurationLoading;
    return Scaffold(
      body: SafeArea(
        child: AppPullToRefresh(
          onRefresh: controller.refreshMarketplace,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppButton(
                      key: const Key('close-marketplace'),
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.ghost,
                      leading: const Icon(Icons.arrow_back),
                      onPressed: loading ? null : controller.closeMarketplace,
                      child: const Text('Назад'),
                    ),
                    const SizedBox(height: 28),
                    SvgPicture.asset(
                      'assets/icon/anyapp-logo.svg',
                      width: 58,
                      height: 58,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      marketplace?.title ?? 'Маркетплейс any2app',
                      style: TextStyle(
                        color: context.colors.foreground,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      marketplace?.description ??
                          'Выберите приложение из каталога.',
                      style: TextStyle(
                        color: context.colors.mutedForeground,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    if (controller.error != null) ...[
                      const SizedBox(height: 18),
                      AppAlert(
                        title: 'Не удалось открыть приложение',
                        description: controller.error!,
                        icon: Icons.error_outline,
                        variant: AppAlertVariant.destructive,
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (marketplace != null && marketplace.apps.isNotEmpty)
                      ...marketplace.apps.map(
                        (app) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MarketplaceAppCard(
                            app: app,
                            loading: loading,
                            favorite: controller.favoriteAppIds.contains(
                              app.id,
                            ),
                            onOpen: () => controller.openMarketplaceApp(app),
                            onToggleFavorite: () =>
                                controller.toggleFavorite(app.id),
                          ),
                        ),
                      )
                    else
                      const AppEmpty(
                        title: 'Каталог пока пуст',
                        description:
                            'Вернитесь назад и подключите приложение по URL.',
                        icon: Icons.apps_outlined,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketplaceAppCard extends StatelessWidget {
  const _MarketplaceAppCard({
    required this.app,
    required this.loading,
    required this.favorite,
    required this.onOpen,
    required this.onToggleFavorite,
  });

  final MarketplaceApp app;
  final bool loading;
  final bool favorite;
  final VoidCallback onOpen;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('marketplace-app-${app.id}'),
      padding: const EdgeInsets.all(18),
      onTap: loading ? null : onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.colors.secondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: Icon(
              _iconFor(app.icon),
              color: context.colors.foreground,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        app.name,
                        style: TextStyle(
                          color: context.colors.foreground,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      key: Key('favorite-app-${app.id}'),
                      size: AppButtonSize.icon,
                      variant: AppButtonVariant.ghost,
                      onPressed: loading ? null : onToggleFavorite,
                      child: Icon(
                        favorite ? Icons.favorite : Icons.favorite_border,
                        color: favorite
                            ? context.colors.destructive
                            : context.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                AppBadge(app.category, variant: AppBadgeVariant.secondary),
                const SizedBox(height: 10),
                Text(
                  app.description,
                  style: TextStyle(
                    color: context.colors.mutedForeground,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Открыть приложение',
                      style: TextStyle(
                        color: context.colors.foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward,
                      size: 15,
                      color: context.colors.foreground,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String name) {
    return switch (name) {
      'account_balance' => Icons.account_balance_outlined,
      'payments' => Icons.payments_outlined,
      'travel' => Icons.flight_takeoff_outlined,
      'train' => Icons.train_outlined,
      'shopping' => Icons.shopping_bag_outlined,
      'business' => Icons.business_center_outlined,
      _ => Icons.apps_outlined,
    };
  }
}
