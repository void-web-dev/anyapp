# any2app

Название приложения и Dart-пакета — `any2app`. Идентификатор приложения
на iOS, Android, macOS и Linux — `com.olegkurguskin.any2app`.
Схема ссылок — `any2app://open`; прежняя схема `anyapp://` не поддерживается.

Server-driven Flutter-приложение с UI-kit в духе shadcn/ui.

При запуске приложение:

1. показывает splash screen;
2. открывает главный экран any2app с маркетплейсом, URL и QR-сканером;
3. строит экраны и переходы из конфигурации;
4. выполняет описанные HTTP-действия;
5. сохраняет access/refresh token в Keychain или Android Keystore;
6. обновляет токен после `401` и повторяет запрос один раз;
7. защищает вход коротким кодом или биометрией;
8. асинхронно загружает следующие экраны из action-ответов;
9. изолирует runtime data и токены каждого приложения.

Готовая demo-конфигурация расписания поездов Туту с закладками маршрутов
находится в `assets/config/train_demo.json` и доступна в маркетплейсе под
названием «По пути». Приложение также принимает `any2app://open` deep links и
QR с URL либо встроенной конфигурацией и начальными значениями.

Демо делает реальные GET-запросы к опубликованному API Туту через Travelpayouts:
https://suggest.travelpayouts.com/search?service=tutu_trains&term=2000000&term2=2064130
Это справочные данные поездов дальнего следования, не оперативное расписание
электричек. Покупка отсутствует. Закладки сохраняются локально в scope приложения.
Документация: https://support.travelpayouts.com/hc/ru/articles/360020147791

Подробное описание формата: [docs/server-driven-config.md](docs/server-driven-config.md).

В шаблонах доступны `concat(...)`, `sha256(...)` и `success.setData` для
вычисления новых значений. Ответ action может вернуть `nextScreenUrl`, после
чего экран и его actions будут загружены без перезапуска приложения.

## Вход и настройки

При первом запуске any2app предлагает выбрать режим:

- короткий код из 4–6 цифр;
- Face ID, Touch ID или отпечаток пальца;
- открытый режим без дополнительной проверки.

Короткий код сохраняется только как хеш с индивидуальной солью в защищённом
хранилище. При следующих запусках приложение показывает экран разблокировки.
На главном экране доступна вкладка «Настройки»: в ней можно включить светлую
тему, изменить короткий код или выбрать другой режим входа.

## UI-kit

```dart
import 'package:any2app/ui/ui.dart';
```

Установите темы в корне приложения:

```dart
MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  home: const MyPage(),
);
```

## Компоненты

Формы:

- `AppInput`, `AppTextarea`, `AppField`;
- `AppInputGroup`, `AppInputGroupAddon`, `AppInputGroupButton`;
- `AppInputOtp`, `AppSelect`, `AppRadioGroup`;
- `AppDatePicker`, `AppDateRangePicker`;
- `AppCheckbox`, `AppSwitch`, `AppSlider`.

Действия и навигация:

- `AppButton`, `AppButtonGroup`;
- `AppToggle`, `AppToggleGroup`;
- `AppTabs`, `AppAccordion`, `AppBreadcrumb`;
- `AppDropdownMenu`, `AppPagination`.

Контент и обратная связь:

- `AppCard`, `AppAlert`, `AppBadge`, `AppAvatar`;
- `AppDataTable`, `AppItem`, `AppEmpty`, `AppCarousel`;
- `AppPullToRefresh`, `AppRefreshListView`;
- `AppDialog`, `showAppSheet`, `AppTooltip`;
- `AppProgress`, `AppSpinner`, `AppSkeleton`, `AppKbd`;
- `showAppToast`, `AppSeparator`.

Все компоненты экспортируются из `lib/ui/ui.dart`.

```dart
AppButton(
  variant: AppButtonVariant.outline,
  leading: const Icon(Icons.add),
  onPressed: () {},
  child: const Text('Создать'),
);
```

Input Group собирается из поля и аддонов:

```dart
AppInputGroup(
  hint: 'Поиск...',
  addons: [
    const AppInputGroupAddon(
      child: Icon(Icons.search),
    ),
    AppInputGroupAddon(
      alignment: AppInputGroupAddonAlignment.end,
      child: AppInputGroupButton(
        onPressed: () {},
        child: const Text('Найти'),
      ),
    ),
  ],
);
```

## Запуск

В маркетплейсе доступен **Dummy Shop** — пример на реальном API
[DummyJSON](https://dummyjson.com/docs): демо-вход, поиск первых 24 товаров,
карточка товара, профиль через `/auth/me`, pull-to-refresh и выход из аккаунта.
Конфигурация: [dummyjson_demo.json](assets/config/dummyjson_demo.json).
Кнопка «Войти в демо-аккаунт» использует публичные учебные данные
`emilys` / `emilyspass`. Не вводите реальные пароли. Покупок и оплаты нет.
Токены изолированы от других приложений; автоматический refresh в этом примере
выключен, при 401 выполняется выход. Формат — `any2app.flow`, версия 1.
Объект `query` в HTTP-действии кодирует параметры поиска без ручной сборки URL.

```shell
~/dev/flutter/bin/flutter run
```

Основной runtime находится в `lib/server_driven`, UI-компоненты — в `lib/ui`.
