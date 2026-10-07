import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/ui.dart';
import '../runtime/app_controller.dart';

class ScreenBuilderScreen extends StatefulWidget {
  const ScreenBuilderScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ScreenBuilderScreen> createState() => _ScreenBuilderScreenState();
}

class _ScreenBuilderScreenState extends State<ScreenBuilderScreen> {
  final _appId = TextEditingController(text: 'generated-app');
  final _appName = TextEditingController(text: 'Generated App');
  final _apiBaseUrl = TextEditingController(text: 'https://api.example.com/');
  final _screenId = TextEditingController(text: 'home');
  final _title = TextEditingController(text: 'Новый экран');
  final _description = TextEditingController(
    text: 'Описание экрана для пользователя',
  );
  final List<_BuilderComponent> _components = [
    _BuilderComponent(type: 'text', value: 'Добро пожаловать'),
    _BuilderComponent(
      type: 'input',
      id: 'email',
      value: 'Электронная почта',
      required: true,
    ),
    _BuilderComponent(type: 'button', value: 'Продолжить', action: 'continue'),
  ];
  final List<_BuilderAction> _actions = [_BuilderAction()];
  var _nextId = 1;
  var _nextActionId = 1;

  @override
  void dispose() {
    _appId.dispose();
    _appName.dispose();
    _apiBaseUrl.dispose();
    _screenId.dispose();
    _title.dispose();
    _description.dispose();
    for (final component in _components) {
      component.dispose();
    }
    for (final action in _actions) {
      action.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _configuration {
    final id = _screenId.text.trim().isEmpty ? 'home' : _screenId.text.trim();
    return {
      'id': _appId.text.trim().isEmpty ? 'generated-app' : _appId.text.trim(),
      'name': _appName.text.trim().isEmpty
          ? 'Generated App'
          : _appName.text.trim(),
      'apiBaseUrl': _apiBaseUrl.text.trim(),
      'initialScreen': id,
      'auth': <String, dynamic>{},
      'screens': {
        id: {
          'title': _title.text,
          'description': _description.text,
          'showAppBar': true,
          'components': _components
              .map((component) => component.toJson())
              .toList(growable: false),
        },
      },
      'actions': {
        for (final action in _actions)
          if (action.id.text.trim().isNotEmpty)
            action.id.text.trim(): action.toJson(),
      },
    };
  }

  String get _formattedJson =>
      const JsonEncoder.withIndent('  ').convert(_configuration);

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) setState(() {});
  }

  void _addComponent(String type) {
    final number = _nextId++;
    final component = switch (type) {
      'text' => _BuilderComponent(type: type, value: 'Новый текст'),
      'input' => _BuilderComponent(
        type: type,
        id: 'field_$number',
        value: 'Поле $number',
      ),
      'inputGroup' => _BuilderComponent(
        type: type,
        id: 'amount_$number',
        value: 'Сумма',
        prefix: '₽',
      ),
      'select' || 'combobox' => _BuilderComponent(
        type: type,
        id: 'choice_$number',
        value: 'Выберите вариант',
        options: 'Первый|Второй|Третий',
        action: type == 'combobox' ? 'search_options' : '',
        onlineSearch: type == 'combobox',
      ),
      'list' => _BuilderComponent(
        type: type,
        id: 'selected_$number',
        value: 'Элементы списка',
        options: 'Первый элемент|Второй элемент',
      ),
      'image' => _BuilderComponent(
        type: type,
        value: 'assets/icon/anyapp-icon-1024.png',
        prefix: 'Изображение',
        suffix: '200',
        options: 'contain',
      ),
      'button' => _BuilderComponent(
        type: type,
        value: 'Кнопка',
        action: 'action_$number',
      ),
      'card' => _BuilderComponent(type: type, value: 'Карточка'),
      'spacer' => _BuilderComponent(type: type, value: '16'),
      _ => _BuilderComponent(type: type),
    };
    setState(() {
      _components.add(component);
      if (type == 'combobox' &&
          !_actions.any((action) => action.id.text == 'search_options')) {
        _actions.add(
          _BuilderAction(
            id: 'search_options',
            method: 'GET',
            url: 'options?query={{form.searchQuery}}',
            includeExampleBody: false,
          ),
        );
      }
    });
  }

  void _removeComponent(int index) {
    final component = _components.removeAt(index);
    component.dispose();
    setState(() {});
  }

  void _moveComponent(int index, int offset) {
    final target = index + offset;
    if (target < 0 || target >= _components.length) return;
    setState(() {
      final component = _components.removeAt(index);
      _components.insert(target, component);
    });
  }

  Future<void> _showAddComponentSheet() {
    const types = [
      ('text', 'Текст', Icons.text_fields),
      ('input', 'Поле ввода', Icons.input),
      ('inputGroup', 'Input group', Icons.view_column_outlined),
      ('select', 'Select', Icons.arrow_drop_down_circle_outlined),
      ('combobox', 'Combobox', Icons.manage_search),
      ('list', 'List', Icons.list_alt_outlined),
      ('image', 'Image', Icons.image_outlined),
      ('button', 'Кнопка', Icons.smart_button_outlined),
      ('card', 'Карточка', Icons.crop_square),
      ('separator', 'Разделитель', Icons.horizontal_rule),
      ('spacer', 'Отступ', Icons.height),
    ];
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Добавить компонент',
                  style: TextStyle(
                    color: context.colors.foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      for (final type in types)
                        ListTile(
                          key: Key('add-component-${type.$1}'),
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(type.$3),
                          title: Text(type.$2),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _addComponent(type.$1);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyJson() async {
    await Clipboard.setData(ClipboardData(text: _formattedJson));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('JSON скопирован')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppPullToRefresh(
          onRefresh: _refresh,
          child: ListView(
            key: const Key('screen-builder'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  key: const Key('close-builder'),
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.ghost,
                  leading: const Icon(Icons.arrow_back),
                  onPressed: widget.controller.closeBuilder,
                  child: const Text('Назад'),
                ),
              ),
              const SizedBox(height: 26),
              Text(
                'Конструктор экранов',
                style: TextStyle(
                  color: context.colors.foreground,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Соберите экран, проверьте preview и скопируйте '
                'server-driven JSON.',
                style: TextStyle(
                  color: context.colors.mutedForeground,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        child: Column(
                          children: [
                            AppInput(
                              controller: _appId,
                              label: 'ID приложения',
                              hint: 'generated-app',
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            AppInput(
                              controller: _appName,
                              label: 'Название приложения',
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            AppInput(
                              controller: _apiBaseUrl,
                              label: 'Базовый URL API',
                              hint: 'https://api.example.com/',
                              keyboardType: TextInputType.url,
                              onChanged: (_) => setState(() {}),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: AppSeparator(),
                            ),
                            AppInput(
                              controller: _screenId,
                              label: 'ID экрана',
                              hint: 'home',
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            AppInput(
                              controller: _title,
                              label: 'Заголовок',
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            AppInput(
                              controller: _description,
                              label: 'Описание',
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppTabs(
                        items: [
                          AppTabItem(
                            label: 'Компоненты',
                            icon: Icons.view_agenda_outlined,
                            child: _componentsEditor(),
                          ),
                          AppTabItem(
                            label: 'Actions',
                            icon: Icons.http,
                            child: _actionsEditor(),
                          ),
                          AppTabItem(
                            label: 'Preview',
                            icon: Icons.visibility_outlined,
                            child: _preview(),
                          ),
                          AppTabItem(
                            label: 'JSON',
                            icon: Icons.data_object,
                            child: _jsonPreview(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _componentsEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < _components.length; index++) ...[
          _componentEditor(index, _components[index]),
          const SizedBox(height: 12),
        ],
        AppButton(
          key: const Key('add-builder-component'),
          expanded: true,
          variant: AppButtonVariant.outline,
          leading: const Icon(Icons.add),
          onPressed: _showAddComponentSheet,
          child: const Text('Добавить компонент'),
        ),
      ],
    );
  }

  Widget _componentEditor(int index, _BuilderComponent component) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppBadge(component.type, variant: AppBadgeVariant.secondary),
              const Spacer(),
              IconButton(
                tooltip: 'Вверх',
                onPressed: index == 0 ? null : () => _moveComponent(index, -1),
                icon: const Icon(Icons.arrow_upward, size: 18),
              ),
              IconButton(
                tooltip: 'Вниз',
                onPressed: index == _components.length - 1
                    ? null
                    : () => _moveComponent(index, 1),
                icon: const Icon(Icons.arrow_downward, size: 18),
              ),
              IconButton(
                key: Key('remove-builder-component-$index'),
                tooltip: 'Удалить',
                onPressed: () => _removeComponent(index),
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          if (component.hasId) ...[
            AppInput(
              controller: component.id,
              label: component.type == 'list'
                  ? 'ID выбранного элемента'
                  : 'ID поля',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
          ],
          if (component.hasValue) ...[
            AppInput(
              controller: component.value,
              label: component.valueLabel,
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (component.type == 'inputGroup') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    controller: component.prefix,
                    label: 'Префикс',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppInput(
                    controller: component.suffix,
                    label: 'Суффикс',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
          if (component.type == 'image') ...[
            const SizedBox(height: 14),
            AppInput(
              controller: component.prefix,
              label: 'Alt-текст',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    controller: component.suffix,
                    label: 'Высота',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppField(
                    label: 'Fit',
                    child: AppSelect<String>(
                      value: component.options.text,
                      items: const [
                        AppSelectItem(value: 'cover', label: 'Cover'),
                        AppSelectItem(value: 'contain', label: 'Contain'),
                        AppSelectItem(value: 'fill', label: 'Fill'),
                        AppSelectItem(value: 'fitWidth', label: 'Fit width'),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          component.options.text = value;
                          setState(() {});
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (component.hasOptions) ...[
            const SizedBox(height: 14),
            AppField(
              label: 'Варианты через |',
              description: 'Например: RUB|USD|EUR',
              child: AppTextarea(
                controller: component.options,
                minLines: 2,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
          if (component.type == 'combobox') ...[
            const SizedBox(height: 12),
            AppCheckbox(
              value: component.onlineSearch,
              label: 'Онлайн-поиск через action',
              onChanged: (value) =>
                  setState(() => component.onlineSearch = value),
            ),
            if (component.onlineSearch) ...[
              const SizedBox(height: 14),
              AppInput(
                controller: component.action,
                label: 'Search action',
                hint: 'search_options',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              AppInput(
                controller: component.searchQueryField,
                label: 'Поле поискового запроса в form',
                hint: 'searchQuery',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              AppInput(
                controller: component.optionsPath,
                label: 'JSON path списка',
                hint: r'$.items',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppInput(
                      controller: component.optionValuePath,
                      label: 'Value path',
                      hint: r'$.id',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppInput(
                      controller: component.optionLabelPath,
                      label: 'Label path',
                      hint: r'$.name',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppInput(
                      controller: component.minSearchLength,
                      label: 'Мин. символов',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppInput(
                      controller: component.searchDebounceMs,
                      label: 'Debounce, ms',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ],
          ],
          if (component.type == 'button' || component.type == 'list') ...[
            const SizedBox(height: 14),
            AppInput(
              controller: component.action,
              label: component.type == 'list'
                  ? 'Action при выборе (необязательно)'
                  : 'ID действия',
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (component.isField) ...[
            const SizedBox(height: 12),
            AppCheckbox(
              value: component.required,
              label: 'Обязательное поле',
              onChanged: (value) => setState(() => component.required = value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionsEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < _actions.length; index++) ...[
          _actionEditor(index, _actions[index]),
          const SizedBox(height: 12),
        ],
        AppButton(
          key: const Key('add-builder-action'),
          expanded: true,
          variant: AppButtonVariant.outline,
          leading: const Icon(Icons.add),
          onPressed: () {
            setState(() {
              _actions.add(_BuilderAction(id: 'action_${_nextActionId++}'));
            });
          },
          child: const Text('Добавить action'),
        ),
      ],
    );
  }

  Widget _actionEditor(int index, _BuilderAction action) {
    const methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'LOCAL', 'LINK'];
    return AppCard(
      key: Key('builder-action-$index'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppBadge('HTTP action'),
              const Spacer(),
              IconButton(
                tooltip: 'Удалить action',
                onPressed: _actions.length == 1
                    ? null
                    : () {
                        final removed = _actions.removeAt(index);
                        removed.dispose();
                        setState(() {});
                      },
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          AppInput(
            controller: action.id,
            label: 'ID action',
            hint: 'loadProducts',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          AppField(
            label: 'Тип / HTTP метод',
            child: AppSelect<String>(
              value: action.method,
              items: methods
                  .map((method) => AppSelectItem(value: method, label: method))
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => action.method = value);
              },
            ),
          ),
          const SizedBox(height: 14),
          AppInput(
            controller: action.url,
            label: 'URL',
            hint: action.method == 'LINK'
                ? 'any2app://open'
                : 'users/{{form.userId}}',
            onChanged: (_) => setState(() {}),
          ),
          if (action.method == 'LINK') ...[
            const SizedBox(height: 18),
            AppInput(
              controller: action.linkConfigUrl,
              label: 'URL конфигурации',
              hint: 'https://example.com/config.json',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            AppField(
              label: 'Встроенный JSON конфигурации',
              description:
                  'Используется вместо URL и кодируется в параметр config.',
              child: AppTextarea(
                controller: action.linkConfigJson,
                minLines: 4,
                maxLines: 10,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 14),
            AppField(
              label: 'Начальный JSON',
              description: 'Например: {"form":{"email":"{{form.email}}"}}',
              child: AppTextarea(
                controller: action.linkInitialJson,
                minLines: 3,
                maxLines: 8,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ] else ...[
            const SizedBox(height: 18),
            _keyValueEditor(
              title: 'Headers',
              description: 'Значения поддерживают {{form.*}} и {{auth.*}}.',
              pairs: action.headers,
              keyHint: 'X-Client',
              valueHint: 'mobile',
            ),
            const SizedBox(height: 18),
            _keyValueEditor(
              title: 'Body',
              description: 'Шаблоны: {{form.*}}, concat(...) и sha256(...).',
              pairs: action.body,
              keyHint: 'email',
              valueHint: '{{form.email}}',
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: AppSeparator(),
          ),
          Text(
            'Обработка успешного результата',
            style: TextStyle(
              color: context.colors.foreground,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          AppInput(
            controller: action.navigate,
            label: 'Перейти на экран',
            hint: 'dashboard',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          AppInput(
            controller: action.screenUrlPath,
            label: 'JSON path URL следующего экрана',
            hint: r'$.nextScreenUrl',
            helperText:
                'Экран загружается асинхронно из ответа. Пустое значение '
                r'использует стандартный путь $.nextScreenUrl.',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppCheckbox(
            value: action.navigateLoadedScreen,
            label: 'Перейти на загруженный экран',
            onChanged: (value) =>
                setState(() => action.navigateLoadedScreen = value),
          ),
          const SizedBox(height: 14),
          AppInput(
            controller: action.storeAs,
            label: 'Сохранить ответ как',
            hint: 'dashboard',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          AppInput(
            controller: action.storePath,
            label: 'JSON path сохраняемых данных',
            hint: r'$.data',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          _keyValueEditor(
            title: 'Изменить runtime data',
            description:
                'Вычисляемые значения: {{result.*}}, concat(...) и sha256(...).',
            pairs: action.setData,
            keyHint: 'signature',
            valueHint:
                r'{{sha256(concat(form.userId, ":", result.challenge))}}',
          ),
          const SizedBox(height: 14),
          AppInput(
            controller: action.successMessage,
            label: 'Сообщение об успехе',
            hint: 'Операция выполнена',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          AppInput(
            controller: action.accessTokenPath,
            label: 'Access token path',
            hint: r'$.accessToken',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          AppInput(
            controller: action.refreshTokenPath,
            label: 'Refresh token path',
            hint: r'$.refreshToken',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppCheckbox(
            value: action.clearForm,
            label: 'Очистить форму после успеха',
            onChanged: (value) => setState(() => action.clearForm = value),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: AppSeparator(),
          ),
          Text(
            'Обработка ошибки',
            style: TextStyle(
              color: context.colors.foreground,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          AppInput(
            controller: action.failureMessagePath,
            label: 'JSON path сообщения',
            hint: r'$.message',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          AppInput(
            controller: action.failureMessage,
            label: 'Fallback-сообщение',
            hint: 'Не удалось выполнить операцию',
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _keyValueEditor({
    required String title,
    required String description,
    required List<_KeyValueDraft> pairs,
    required String keyHint,
    required String valueHint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.colors.foreground,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(color: context.colors.mutedForeground, fontSize: 12),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < pairs.length; index++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppInput(
                  controller: pairs[index].key,
                  label: index == 0 ? 'Ключ' : null,
                  hint: keyHint,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppInput(
                  controller: pairs[index].value,
                  label: index == 0 ? 'Значение' : null,
                  hint: valueHint,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                tooltip: 'Удалить',
                onPressed: () {
                  final removed = pairs.removeAt(index);
                  removed.dispose();
                  setState(() {});
                },
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        AppButton(
          size: AppButtonSize.small,
          variant: AppButtonVariant.outline,
          leading: const Icon(Icons.add),
          onPressed: () => setState(() => pairs.add(_KeyValueDraft())),
          child: Text('Добавить $title'),
        ),
      ],
    );
  }

  Widget _preview() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _title.text,
            style: TextStyle(
              color: context.colors.foreground,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_description.text.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              _description.text,
              style: TextStyle(
                color: context.colors.mutedForeground,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 24),
          for (final component in _components) _previewComponent(component),
        ],
      ),
    );
  }

  Widget _previewComponent(_BuilderComponent component) {
    return switch (component.type) {
      'text' => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          component.value.text,
          style: TextStyle(color: context.colors.foreground, fontSize: 16),
        ),
      ),
      'input' => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AppInput(
          label: component.value.text,
          hint: component.required ? 'Обязательное поле' : 'Введите значение',
          enabled: false,
        ),
      ),
      'inputGroup' => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AppField(
          label: component.value.text,
          required: component.required,
          child: AppInputGroup(
            enabled: false,
            hint: 'Введите значение',
            addons: [
              if (component.prefix.text.isNotEmpty)
                AppInputGroupAddon(
                  child: AppInputGroupText(component.prefix.text),
                ),
              if (component.suffix.text.isNotEmpty)
                AppInputGroupAddon(
                  alignment: AppInputGroupAddonAlignment.end,
                  child: AppInputGroupText(component.suffix.text),
                ),
            ],
          ),
        ),
      ),
      'select' => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AppField(
          label: component.value.text,
          required: component.required,
          child: AppSelect<String>(
            enabled: false,
            items: component.optionValues
                .map((value) => AppSelectItem(value: value, label: value))
                .toList(growable: false),
            onChanged: null,
          ),
        ),
      ),
      'combobox' => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AppField(
          label: component.value.text,
          required: component.required,
          child: AppCombobox<String>(
            enabled: false,
            items: component.optionValues
                .map((value) => AppComboboxItem(value: value, label: value))
                .toList(growable: false),
            onChanged: (_) {},
          ),
        ),
      ),
      'list' => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AppCard(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              for (final value in component.optionValues)
                AppItem(
                  title: value,
                  trailing: const Icon(Icons.chevron_right, size: 18),
                ),
            ],
          ),
        ),
      ),
      'image' => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: component.value.text.startsWith('assets/')
              ? Image.asset(
                  component.value.text,
                  height: double.tryParse(component.suffix.text) ?? 200,
                  fit: BoxFit.contain,
                )
              : const AppSkeleton(height: 200),
        ),
      ),
      'button' => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppButton(
          expanded: true,
          onPressed: null,
          child: Text(component.value.text),
        ),
      ),
      'card' => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(child: Text(component.value.text)),
      ),
      'separator' => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: AppSeparator(),
      ),
      'spacer' => SizedBox(height: double.tryParse(component.value.text) ?? 16),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _jsonPreview() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              key: const Key('copy-builder-json'),
              size: AppButtonSize.small,
              variant: AppButtonVariant.outline,
              leading: const Icon(Icons.copy),
              onPressed: _copyJson,
              child: const Text('Копировать'),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.muted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              _formattedJson,
              style: TextStyle(
                color: context.colors.foreground,
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuilderComponent {
  _BuilderComponent({
    required this.type,
    String id = '',
    String value = '',
    String action = '',
    String prefix = '',
    String suffix = '',
    String options = '',
    String searchQueryField = 'searchQuery',
    String optionsPath = r'$.items',
    String optionValuePath = r'$.id',
    String optionLabelPath = r'$.name',
    String minSearchLength = '2',
    String searchDebounceMs = '350',
    this.onlineSearch = false,
    this.required = false,
  }) : id = TextEditingController(text: id),
       value = TextEditingController(text: value),
       action = TextEditingController(text: action),
       prefix = TextEditingController(text: prefix),
       suffix = TextEditingController(text: suffix),
       options = TextEditingController(text: options),
       searchQueryField = TextEditingController(text: searchQueryField),
       optionsPath = TextEditingController(text: optionsPath),
       optionValuePath = TextEditingController(text: optionValuePath),
       optionLabelPath = TextEditingController(text: optionLabelPath),
       minSearchLength = TextEditingController(text: minSearchLength),
       searchDebounceMs = TextEditingController(text: searchDebounceMs);

  final String type;
  final TextEditingController id;
  final TextEditingController value;
  final TextEditingController action;
  final TextEditingController prefix;
  final TextEditingController suffix;
  final TextEditingController options;
  final TextEditingController searchQueryField;
  final TextEditingController optionsPath;
  final TextEditingController optionValuePath;
  final TextEditingController optionLabelPath;
  final TextEditingController minSearchLength;
  final TextEditingController searchDebounceMs;
  bool onlineSearch;
  bool required;

  bool get hasId =>
      type == 'input' ||
      type == 'inputGroup' ||
      type == 'select' ||
      type == 'combobox' ||
      type == 'list';

  bool get isField =>
      type == 'input' ||
      type == 'inputGroup' ||
      type == 'select' ||
      type == 'combobox';

  bool get hasOptions =>
      type == 'select' || type == 'combobox' || type == 'list';

  bool get hasValue =>
      type == 'text' ||
      type == 'input' ||
      type == 'inputGroup' ||
      type == 'select' ||
      type == 'combobox' ||
      type == 'list' ||
      type == 'image' ||
      type == 'button' ||
      type == 'card' ||
      type == 'spacer';

  String get valueLabel => switch (type) {
    'text' => 'Текст',
    'input' => 'Название поля',
    'inputGroup' => 'Название поля',
    'select' => 'Название поля',
    'combobox' => 'Название поля',
    'list' => 'Название списка',
    'image' => 'Источник изображения',
    'button' => 'Текст кнопки',
    'card' => 'Заголовок карточки',
    'spacer' => 'Высота, px',
    _ => 'Значение',
  };

  List<String> get optionValues => options.text
      .split('|')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  Map<String, dynamic> toJson() {
    return switch (type) {
      'text' => {'type': type, 'text': value.text},
      'input' => {
        'type': type,
        'id': id.text.trim(),
        'label': value.text,
        'required': required,
      },
      'inputGroup' => {
        'type': type,
        'id': id.text.trim(),
        'label': value.text,
        'prefix': prefix.text,
        'suffix': suffix.text,
        'required': required,
      },
      'select' || 'combobox' => {
        'type': type,
        'id': id.text.trim(),
        'label': value.text,
        'required': required,
        'options': [
          for (final option in optionValues) {'value': option, 'label': option},
        ],
        if (type == 'combobox' && onlineSearch) ...{
          'searchAction': action.text.trim(),
          'searchQueryField': searchQueryField.text.trim(),
          'optionsPath': optionsPath.text.trim(),
          'optionValuePath': optionValuePath.text.trim(),
          'optionLabelPath': optionLabelPath.text.trim(),
          'minSearchLength': int.tryParse(minSearchLength.text.trim()) ?? 2,
          'searchDebounceMs': int.tryParse(searchDebounceMs.text.trim()) ?? 350,
        },
      },
      'list' => {
        'type': type,
        'id': id.text.trim(),
        'items': [
          for (final option in optionValues) {'value': option, 'title': option},
        ],
        if (action.text.trim().isNotEmpty) 'action': action.text.trim(),
      },
      'image' => {
        'type': type,
        'source': value.text.trim(),
        'alt': prefix.text,
        'height': double.tryParse(suffix.text) ?? 200,
        'fit': options.text,
        'borderRadius': 12,
      },
      'button' => {
        'type': type,
        'label': value.text,
        'action': action.text.trim(),
        'expanded': true,
      },
      'card' => {'type': type, 'title': value.text},
      'spacer' => {'type': type, 'height': double.tryParse(value.text) ?? 16},
      _ => {'type': type},
    };
  }

  void dispose() {
    id.dispose();
    value.dispose();
    action.dispose();
    prefix.dispose();
    suffix.dispose();
    options.dispose();
    searchQueryField.dispose();
    optionsPath.dispose();
    optionValuePath.dispose();
    optionLabelPath.dispose();
    minSearchLength.dispose();
    searchDebounceMs.dispose();
  }
}

class _BuilderAction {
  _BuilderAction({
    String id = 'continue',
    this.method = 'POST',
    String url = 'submit',
    bool includeExampleBody = true,
  }) : id = TextEditingController(text: id),
       url = TextEditingController(text: url),
       navigate = TextEditingController(),
       screenUrlPath = TextEditingController(),
       storeAs = TextEditingController(),
       storePath = TextEditingController(),
       successMessage = TextEditingController(),
       linkConfigUrl = TextEditingController(),
       linkConfigJson = TextEditingController(),
       linkInitialJson = TextEditingController(
         text: '{"form":{"email":"{{form.email}}"}}',
       ),
       accessTokenPath = TextEditingController(),
       refreshTokenPath = TextEditingController(),
       failureMessagePath = TextEditingController(text: r'$.message'),
       failureMessage = TextEditingController(
         text: 'Не удалось выполнить операцию',
       ),
       headers = [
         _KeyValueDraft(key: 'Content-Type', value: 'application/json'),
       ],
       body = includeExampleBody
           ? [_KeyValueDraft(key: 'email', value: '{{form.email}}')]
           : [],
       setData = [];

  final TextEditingController id;
  final TextEditingController url;
  final TextEditingController navigate;
  final TextEditingController screenUrlPath;
  final TextEditingController storeAs;
  final TextEditingController storePath;
  final TextEditingController successMessage;
  final TextEditingController linkConfigUrl;
  final TextEditingController linkConfigJson;
  final TextEditingController linkInitialJson;
  final TextEditingController accessTokenPath;
  final TextEditingController refreshTokenPath;
  final TextEditingController failureMessagePath;
  final TextEditingController failureMessage;
  final List<_KeyValueDraft> headers;
  final List<_KeyValueDraft> body;
  final List<_KeyValueDraft> setData;
  String method;
  bool clearForm = false;
  bool navigateLoadedScreen = true;

  Map<String, dynamic> toJson() {
    final success = <String, dynamic>{
      if (navigate.text.trim().isNotEmpty) 'navigate': navigate.text.trim(),
      if (screenUrlPath.text.trim().isNotEmpty)
        'screenUrlPath': screenUrlPath.text.trim(),
      if (!navigateLoadedScreen) 'navigateLoadedScreen': false,
      if (storeAs.text.trim().isNotEmpty)
        'storeResponseAs': storeAs.text.trim(),
      if (storePath.text.trim().isNotEmpty)
        'storeResponsePath': storePath.text.trim(),
      if (_mapFrom(setData).isNotEmpty) 'setData': _mapFrom(setData),
      if (successMessage.text.trim().isNotEmpty)
        'message': successMessage.text.trim(),
      if (clearForm) 'clearForm': true,
      if (accessTokenPath.text.trim().isNotEmpty)
        'tokens': {
          'accessTokenPath': accessTokenPath.text.trim(),
          if (refreshTokenPath.text.trim().isNotEmpty)
            'refreshTokenPath': refreshTokenPath.text.trim(),
        },
    };
    return {
      'request': {
        'method': method,
        'url': url.text.trim(),
        if (method == 'LINK' && linkConfigUrl.text.trim().isNotEmpty)
          'configUrl': linkConfigUrl.text.trim(),
        if (method == 'LINK' && linkConfigJson.text.trim().isNotEmpty)
          'config': _decodeJson(linkConfigJson.text),
        if (method == 'LINK' && linkInitialJson.text.trim().isNotEmpty)
          'initial': _decodeJson(linkInitialJson.text),
        if (method != 'LINK' && _mapFrom(headers).isNotEmpty)
          'headers': _mapFrom(headers),
        if (method != 'LINK' && _mapFrom(body).isNotEmpty)
          'body': _mapFrom(body),
      },
      'success': success,
      'failure': {
        if (failureMessagePath.text.trim().isNotEmpty)
          'messagePath': failureMessagePath.text.trim(),
        if (failureMessage.text.trim().isNotEmpty)
          'message': failureMessage.text.trim(),
      },
    };
  }

  Map<String, String> _mapFrom(List<_KeyValueDraft> pairs) {
    return {
      for (final pair in pairs)
        if (pair.key.text.trim().isNotEmpty)
          pair.key.text.trim(): pair.value.text,
    };
  }

  dynamic _decodeJson(String source) {
    try {
      return jsonDecode(source);
    } on FormatException {
      return source;
    }
  }

  void dispose() {
    id.dispose();
    url.dispose();
    navigate.dispose();
    screenUrlPath.dispose();
    storeAs.dispose();
    storePath.dispose();
    successMessage.dispose();
    linkConfigUrl.dispose();
    linkConfigJson.dispose();
    linkInitialJson.dispose();
    accessTokenPath.dispose();
    refreshTokenPath.dispose();
    failureMessagePath.dispose();
    failureMessage.dispose();
    for (final pair in [...headers, ...body, ...setData]) {
      pair.dispose();
    }
  }
}

class _KeyValueDraft {
  _KeyValueDraft({String key = '', String value = ''})
    : key = TextEditingController(text: key),
      value = TextEditingController(text: value);

  final TextEditingController key;
  final TextEditingController value;

  void dispose() {
    key.dispose();
    value.dispose();
  }
}
