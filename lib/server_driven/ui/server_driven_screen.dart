import 'dart:convert';

import 'package:flutter/material.dart';

import '../../ui/ui.dart';
import '../models/app_config.dart';
import '../runtime/app_controller.dart';
import '../runtime/value_resolver.dart';

class ServerDrivenScreen extends StatefulWidget {
  const ServerDrivenScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ServerDrivenScreen> createState() => _ServerDrivenScreenState();
}

class _ServerDrivenScreenState extends State<ServerDrivenScreen> {
  final Map<String, TextEditingController> _textControllers = {};

  AppController get controller => widget.controller;
  ScreenConfig get screen => controller.currentScreen!;

  @override
  void initState() {
    super.initState();
    for (final component in screen.components) {
      if ((component.type == 'input' || component.type == 'inputGroup') &&
          component.id != null) {
        _textControllers[component.id!] = TextEditingController(
          text: controller.form[component.id!]?.toString() ?? '',
        );
      }
      if ((component.type == 'select' || component.type == 'combobox') &&
          component.id != null &&
          !controller.form.containsKey(component.id) &&
          component.properties['defaultValue'] != null) {
        controller.setFormValue(
          component.id!,
          component.properties['defaultValue'],
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final entry in _textControllers.entries) {
      final value = controller.form[entry.key]?.toString() ?? '';
      if (entry.value.text != value) {
        entry.value.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    }
    Widget content = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
      children: [
        if (!screen.showAppBar) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              key: const Key('return-to-any2app'),
              size: AppButtonSize.small,
              variant: AppButtonVariant.ghost,
              leading: const Icon(Icons.arrow_back),
              onPressed: controller.changeConfiguration,
              child: const Text('В any2app'),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            screen.title,
            style: TextStyle(
              color: context.colors.foreground,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.7,
            ),
          ),
          if (screen.description != null) ...[
            const SizedBox(height: 8),
            Text(
              screen.description!,
              style: TextStyle(
                color: context.colors.mutedForeground,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 28),
        ],
        if (controller.error != null) ...[
          AppAlert(
            title: 'Ошибка',
            description: controller.error!,
            icon: Icons.error_outline,
            variant: AppAlertVariant.destructive,
          ),
          const SizedBox(height: 18),
        ],
        if (controller.message != null) ...[
          AppAlert(
            title: 'Готово',
            description: controller.message!,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 18),
        ],
        for (final component in screen.components) _component(component),
      ],
    );

    content = AppPullToRefresh(
      onRefresh: controller.refreshCurrentScreen,
      child: content,
    );

    return Scaffold(
      appBar: screen.showAppBar
          ? AppBar(
              backgroundColor: context.colors.background,
              surfaceTintColor: Colors.transparent,
              title: Text(
                screen.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              leading: screen.canGoBack
                  ? IconButton(
                      onPressed: controller.goBack,
                      icon: const Icon(Icons.arrow_back),
                    )
                  : IconButton(
                      key: const Key('return-to-any2app'),
                      tooltip: 'Вернуться в any2app',
                      onPressed: controller.changeConfiguration,
                      icon: const Icon(Icons.arrow_back),
                    ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: AppSeparator(),
              ),
            )
          : null,
      body: SafeArea(top: !screen.showAppBar, child: content),
    );
  }

  Widget _component(ComponentConfig component) {
    return switch (component.type) {
      'text' => _text(component),
      'jsonResource' => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ExpansionTile(
          title: Text(component.string('title') ?? 'Данные'),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(
                  controller.resolve('data.${component.string('dataPath')}'),
                ),
              ),
            ),
          ],
        ),
      ),
      'input' => _input(component),
      'inputGroup' => _inputGroup(component),
      'select' => _select(component),
      'combobox' => _combobox(component),
      'list' => _list(component),
      'image' => _image(component),
      'button' => _button(component),
      'spacer' => SizedBox(
        height: (component.number('height') ?? 16).toDouble(),
      ),
      'separator' => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: AppSeparator(),
      ),
      'alert' => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: AppAlert(
          title: _render(component.string('title') ?? '').toString(),
          description: _render(
            component.string('description') ?? '',
          ).toString(),
        ),
      ),
      'balance' => _balance(component),
      'productList' => _productList(component),
      'card' => _card(component),
      _ => AppAlert(
        title: 'Неизвестный компонент',
        description: 'Тип "${component.type}" не поддерживается renderer.',
        variant: AppAlertVariant.destructive,
      ),
    };
  }

  Widget _text(ComponentConfig component) {
    final style = component.string('style') ?? 'body';
    final text = _render(component.string('text') ?? '').toString();
    final textStyle = switch (style) {
      'display' => TextStyle(
        color: context.colors.foreground,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      ),
      'title' => TextStyle(
        color: context.colors.foreground,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      'muted' => TextStyle(
        color: context.colors.mutedForeground,
        fontSize: 14,
        height: 1.5,
      ),
      _ => TextStyle(
        color: context.colors.foreground,
        fontSize: 14,
        height: 1.5,
      ),
    };
    return Padding(
      padding: EdgeInsets.only(
        bottom: component.number('bottom')?.toDouble() ?? 8,
      ),
      child: Text(
        text,
        textAlign: component.string('align') == 'center'
            ? TextAlign.center
            : TextAlign.start,
        style: textStyle,
      ),
    );
  }

  Widget _input(ComponentConfig component) {
    final id = component.id!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppInput(
        controller: _textControllers[id],
        label: component.string('label'),
        hint: component.string('placeholder'),
        obscureText:
            component.boolean('obscure') || component.boolean('obscureText'),
        keyboardType: switch (component.string('keyboard')) {
          'email' => TextInputType.emailAddress,
          'number' => TextInputType.number,
          'url' => TextInputType.url,
          _ => TextInputType.text,
        },
        errorText: controller.fieldErrors[id],
        onChanged: (value) => controller.setFormValue(id, value),
      ),
    );
  }

  Widget _inputGroup(ComponentConfig component) {
    final id = component.id!;
    final prefix = component.string('prefix');
    final suffix = component.string('suffix');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppField(
        label: component.string('label'),
        required: component.boolean('required'),
        error: controller.fieldErrors[id],
        child: AppInputGroup(
          controller: _textControllers[id],
          hint: component.string('placeholder'),
          obscureText: component.boolean('obscure'),
          onChanged: (value) {
            controller.setFormValue(id, value);
            setState(() {});
          },
          addons: [
            if (prefix != null)
              AppInputGroupAddon(child: AppInputGroupText(prefix)),
            if (suffix != null)
              AppInputGroupAddon(
                alignment: AppInputGroupAddonAlignment.end,
                child: AppInputGroupText(suffix),
              ),
          ],
        ),
      ),
    );
  }

  Widget _select(ComponentConfig component) {
    final id = component.id!;
    final items = _options(component);
    final value = controller.form[id]?.toString();
    final selected = items.any((item) => item.value == value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppField(
        label: component.string('label'),
        required: component.boolean('required'),
        error: controller.fieldErrors[id],
        child: AppSelect<String>(
          value: selected,
          placeholder: component.string('placeholder') ?? 'Выберите значение',
          items: items
              .map(
                (item) => AppSelectItem(value: item.value, label: item.label),
              )
              .toList(growable: false),
          onChanged: (value) {
            controller.setFormValue(id, value);
            setState(() {});
          },
        ),
      ),
    );
  }

  Widget _combobox(ComponentConfig component) {
    final id = component.id!;
    final items = _options(component);
    final online = component.string('searchAction') != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppField(
        label: component.string('label'),
        required: component.boolean('required'),
        error: controller.fieldErrors[id],
        child: AppCombobox<String>(
          value: controller.form[id]?.toString(),
          placeholder: component.string('placeholder') ?? 'Выберите значение',
          searchPlaceholder:
              component.string('searchPlaceholder') ?? 'Поиск...',
          items: items,
          minSearchLength: online
              ? (component.number('minSearchLength')?.toInt() ?? 2)
              : 0,
          searchDebounce: Duration(
            milliseconds: component.number('searchDebounceMs')?.toInt() ?? 350,
          ),
          onSearch: online
              ? (query) async {
                  final options = await controller.searchComboboxOptions(
                    component,
                    query,
                  );
                  return options
                      .map(
                        (option) => AppComboboxItem(
                          value: option.value,
                          label: option.label,
                        ),
                      )
                      .toList(growable: false);
                }
              : null,
          onChanged: (value) {
            controller.setFormValue(id, value);
            setState(() {});
          },
        ),
      ),
    );
  }

  Widget _list(ComponentConfig component) {
    final sourceExpression = component.string('source');
    final source = sourceExpression == null
        ? component.properties['items']
        : _render(sourceExpression);
    final items = source is List ? source : const [];
    final action = component.string('action');
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(component.string('emptyText') ?? 'Список пуст'),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++)
              AppItem(
                title: component.string('titleField') == null
                    ? _listValue(items[index], 'title', index)
                    : readJsonPath(
                            items[index],
                            component.string('titleField'),
                          )?.toString() ??
                          '',
                description: component.properties['descriptionFields'] is List
                    ? (component.properties['descriptionFields'] as List)
                          .map(
                            (field) =>
                                readJsonPath(
                                  items[index],
                                  field.toString(),
                                )?.toString() ??
                                '',
                          )
                          .join(' → ')
                    : _listDescription(items[index]),
                leading: const Icon(Icons.list_alt_outlined, size: 20),
                trailing: action == null
                    ? null
                    : const Icon(Icons.chevron_right, size: 18),
                onTap: action == null
                    ? null
                    : () {
                        final id = component.id;
                        if (id != null) {
                          controller.setFormValue(
                            id,
                            _listRawValue(items[index]),
                          );
                        }
                        controller.executeAction(action, validate: false);
                      },
              ),
          ],
        ),
      ),
    );
  }

  List<AppComboboxItem<String>> _options(ComponentConfig component) {
    final raw = component.properties['options'];
    if (raw is! List) return const [];
    return [
      for (var index = 0; index < raw.length; index++)
        if (raw[index] is Map)
          AppComboboxItem(
            value: (raw[index] as Map)['value']?.toString() ?? index.toString(),
            label:
                (raw[index] as Map)['label']?.toString() ??
                (raw[index] as Map)['value']?.toString() ??
                'Вариант ${index + 1}',
          )
        else
          AppComboboxItem(
            value: raw[index].toString(),
            label: raw[index].toString(),
          ),
    ];
  }

  String _listValue(dynamic item, String key, int index) {
    if (item is Map) {
      return item[key]?.toString() ??
          item['label']?.toString() ??
          'Элемент ${index + 1}';
    }
    return item.toString();
  }

  String? _listDescription(dynamic item) {
    return item is Map ? item['description']?.toString() : null;
  }

  dynamic _listRawValue(dynamic item) {
    return item is Map && item.containsKey('value') ? item['value'] : item;
  }

  Widget _image(ComponentConfig component) {
    final source = _render(component.string('source') ?? '').toString();
    final height = component.number('height')?.toDouble() ?? 200;
    final width = component.number('width')?.toDouble() ?? double.infinity;
    final radius = component.number('borderRadius')?.toDouble() ?? 12;
    final fit = switch (component.string('fit')) {
      'contain' => BoxFit.contain,
      'fill' => BoxFit.fill,
      'fitWidth' => BoxFit.fitWidth,
      _ => BoxFit.cover,
    };
    final image = source.startsWith('assets/')
        ? Image.asset(
            source,
            width: width,
            height: height,
            fit: fit,
            semanticLabel: component.string('alt'),
          )
        : Image.network(
            source,
            width: width,
            height: height,
            fit: fit,
            semanticLabel: component.string('alt'),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : AppSkeleton(width: width, height: height),
            errorBuilder: (_, _, _) => AppEmpty(
              title: 'Изображение недоступно',
              description: source,
              icon: Icons.broken_image_outlined,
            ),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: image,
      ),
    );
  }

  Widget _button(ComponentConfig component) {
    final action = component.string('action');
    final loading = action != null && controller.busyAction == action;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppButton(
        expanded: component.boolean('expanded', true),
        loading: loading,
        variant: _buttonVariant(component.string('variant')),
        leading: _icon(component.string('icon')),
        onPressed: action == null || controller.isBusy
            ? null
            : () => controller.executeAction(action),
        child: Text(component.string('label') ?? 'Продолжить'),
      ),
    );
  }

  Widget _balance(ComponentConfig component) {
    final amount = _render(component.string('amount') ?? '');
    final currency = _render(component.string('currency') ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              component.string('label') ?? 'Общий баланс',
              style: TextStyle(
                color: context.colors.mutedForeground,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '${_formatAmount(amount)} $currency',
              style: TextStyle(
                color: context.colors.foreground,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productList(ComponentConfig component) {
    final source = _render(component.string('source') ?? '');
    if (source is! List) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            AppSkeleton(height: 82),
            SizedBox(height: 10),
            AppSkeleton(height: 82),
          ],
        ),
      );
    }
    if (source.isEmpty) {
      return const AppEmpty(
        title: 'Продуктов пока нет',
        description: 'Откройте первый счёт или карту.',
      );
    }
    return Column(
      children: [
        for (final item in source)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.colors.muted,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _productIcon(readJsonPath(item, 'type')?.toString()),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          readJsonPath(item, 'name')?.toString() ?? 'Продукт',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          readJsonPath(item, 'number')?.toString() ?? '',
                          style: TextStyle(
                            color: context.colors.mutedForeground,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_formatAmount(readJsonPath(item, 'amount'))} '
                    '${readJsonPath(item, 'currency') ?? ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(ComponentConfig component) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _render(component.string('title') ?? '').toString(),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            if (component.string('description') != null) ...[
              const SizedBox(height: 6),
              Text(
                _render(component.string('description')!).toString(),
                style: TextStyle(
                  color: context.colors.mutedForeground,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  dynamic _render(dynamic value) {
    return resolveTemplate(
      value,
      RuntimeValues(
        form: controller.form,
        data: controller.data,
        auth: const {},
      ),
    );
  }

  String _formatAmount(dynamic value) {
    if (value is num) {
      return value
          .toStringAsFixed(2)
          .replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+\.)'), (_) => ' ');
    }
    return value?.toString() ?? '—';
  }

  AppButtonVariant _buttonVariant(String? value) {
    return switch (value) {
      'secondary' => AppButtonVariant.secondary,
      'outline' => AppButtonVariant.outline,
      'ghost' => AppButtonVariant.ghost,
      'destructive' => AppButtonVariant.destructive,
      'link' => AppButtonVariant.link,
      _ => AppButtonVariant.primary,
    };
  }

  Widget? _icon(String? value) {
    final icon = switch (value) {
      'add' => Icons.add,
      'login' => Icons.login,
      'logout' => Icons.logout,
      'arrow' => Icons.arrow_forward,
      _ => null,
    };
    return icon == null ? null : Icon(icon);
  }

  IconData _productIcon(String? type) {
    return switch (type) {
      'card' => Icons.credit_card,
      'deposit' => Icons.savings_outlined,
      'credit' => Icons.payments_outlined,
      _ => Icons.account_balance_wallet_outlined,
    };
  }
}
