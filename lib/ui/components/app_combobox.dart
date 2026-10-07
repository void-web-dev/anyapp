import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppComboboxItem<T> {
  const AppComboboxItem({required this.value, required this.label});

  final T value;
  final String label;
}

class AppCombobox<T> extends StatefulWidget {
  const AppCombobox({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.placeholder = 'Выберите значение',
    this.searchPlaceholder = 'Поиск...',
    this.enabled = true,
    this.onSearch,
    this.searchDebounce = const Duration(milliseconds: 350),
    this.minSearchLength = 0,
  });

  final List<AppComboboxItem<T>> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String placeholder;
  final String searchPlaceholder;
  final bool enabled;
  final Future<List<AppComboboxItem<T>>> Function(String query)? onSearch;
  final Duration searchDebounce;
  final int minSearchLength;

  @override
  State<AppCombobox<T>> createState() => _AppComboboxState<T>();
}

class _AppComboboxState<T> extends State<AppCombobox<T>> {
  AppComboboxItem<T>? _remoteSelected;

  @override
  Widget build(BuildContext context) {
    final localSelected = widget.items
        .where((item) => item.value == widget.value)
        .firstOrNull;
    final selected = localSelected ?? _remoteSelected;
    return Material(
      color: widget.enabled ? context.colors.background : context.colors.muted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: context.colors.input),
      ),
      child: InkWell(
        onTap: widget.enabled ? () => _open(context) : null,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 42,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected?.label ?? widget.placeholder,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected == null
                          ? context.colors.mutedForeground
                          : context.colors.foreground,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.unfold_more,
                  size: 17,
                  color: context.colors.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final selected = await showModalBottomSheet<AppComboboxItem<T>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      builder: (_) => _ComboboxSheet<T>(
        items: widget.items,
        value: widget.value,
        searchPlaceholder: widget.searchPlaceholder,
        onSearch: widget.onSearch,
        searchDebounce: widget.searchDebounce,
        minSearchLength: widget.minSearchLength,
      ),
    );
    if (selected == null) return;
    setState(() => _remoteSelected = selected);
    widget.onChanged(selected.value);
  }
}

class _ComboboxSheet<T> extends StatefulWidget {
  const _ComboboxSheet({
    required this.items,
    required this.value,
    required this.searchPlaceholder,
    required this.onSearch,
    required this.searchDebounce,
    required this.minSearchLength,
  });

  final List<AppComboboxItem<T>> items;
  final T? value;
  final String searchPlaceholder;
  final Future<List<AppComboboxItem<T>>> Function(String query)? onSearch;
  final Duration searchDebounce;
  final int minSearchLength;

  @override
  State<_ComboboxSheet<T>> createState() => _ComboboxSheetState<T>();
}

class _ComboboxSheetState<T> extends State<_ComboboxSheet<T>> {
  final _search = TextEditingController();
  var _query = '';
  var _items = <AppComboboxItem<T>>[];
  var _loading = false;
  String? _error;
  Timer? _debounce;
  var _requestId = 0;

  @override
  void initState() {
    super.initState();
    _items = widget.items;
    if (widget.onSearch != null && widget.minSearchLength == 0) {
      _runSearch('');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      _error = null;
    });
    if (widget.onSearch == null) return;
    _debounce?.cancel();
    if (value.trim().length < widget.minSearchLength) {
      setState(() {
        _items = const [];
        _loading = false;
      });
      return;
    }
    _debounce = Timer(widget.searchDebounce, () => _runSearch(value.trim()));
  }

  Future<void> _runSearch(String query) async {
    final search = widget.onSearch;
    if (search == null) return;
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await search(query);
      if (!mounted || requestId != _requestId) return;
      setState(() => _items = result);
    } catch (exception) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = const [];
        _error = exception.toString();
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.onSearch != null;
    final visible = online
        ? _items
        : widget.items
              .where(
                (item) =>
                    item.label.toLowerCase().contains(_query.toLowerCase()),
              )
              .toList(growable: false);
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Выберите значение',
                style: TextStyle(
                  color: context.colors.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                autofocus: true,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: widget.searchPlaceholder,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _query.trim().length < widget.minSearchLength
                    ? Center(
                        child: Text(
                          'Введите минимум ${widget.minSearchLength} символа',
                          style: TextStyle(
                            color: context.colors.mutedForeground,
                          ),
                        ),
                      )
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.colors.destructive),
                        ),
                      )
                    : !_loading && visible.isEmpty
                    ? Center(
                        child: Text(
                          'Ничего не найдено',
                          style: TextStyle(
                            color: context.colors.mutedForeground,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          final selected = item.value == widget.value;
                          return ListTile(
                            title: Text(item.label),
                            trailing: selected
                                ? const Icon(Icons.check, size: 18)
                                : null,
                            onTap: () => Navigator.of(context).pop(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
