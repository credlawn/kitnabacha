import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

enum TimeFormat { h12, h24 }

enum DecimalFormat { none, one, two }

enum DefaultPage { ledger, expense }

SharedPreferences? _cachedPrefs;

void cachePrefs(SharedPreferences prefs) {
  _cachedPrefs = prefs;
}

class AppSettings {
  final AppThemeMode themeMode;
  final TimeFormat timeFormat;
  final DecimalFormat decimalFormat;
  final DefaultPage defaultPage;

  const AppSettings({
    this.themeMode = AppThemeMode.light,
    this.timeFormat = TimeFormat.h12,
    this.decimalFormat = DecimalFormat.two,
    this.defaultPage = DefaultPage.ledger,
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    TimeFormat? timeFormat,
    DecimalFormat? decimalFormat,
    DefaultPage? defaultPage,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      timeFormat: timeFormat ?? this.timeFormat,
      decimalFormat: decimalFormat ?? this.decimalFormat,
      defaultPage: defaultPage ?? this.defaultPage,
    );
  }

  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  int get decimalDigits {
    switch (decimalFormat) {
      case DecimalFormat.none:
        return 0;
      case DecimalFormat.one:
        return 1;
      case DecimalFormat.two:
        return 2;
    }
  }

  int get defaultTabIndex {
    switch (defaultPage) {
      case DefaultPage.ledger:
        return 0;
      case DefaultPage.expense:
        return 1;
    }
  }
}

AppSettings _loadSettings() {
  final p = _cachedPrefs;
  if (p == null) return const AppSettings();

  final themeModeStr = p.getString('themeMode') ?? 'light';
  final timeFormatStr = p.getString('timeFormat') ?? 'h12';
  final decimalFormatStr = p.getString('decimalFormat') ?? 'two';
  final defaultPageStr = p.getString('defaultPage') ?? 'ledger';

  return AppSettings(
    themeMode: AppThemeMode.values.firstWhere(
      (e) => e.name == themeModeStr,
      orElse: () => AppThemeMode.light,
    ),
    timeFormat: TimeFormat.values.firstWhere(
      (e) => e.name == timeFormatStr,
      orElse: () => TimeFormat.h12,
    ),
    decimalFormat: DecimalFormat.values.firstWhere(
      (e) => e.name == decimalFormatStr,
      orElse: () => DecimalFormat.two,
    ),
    defaultPage: DefaultPage.values.firstWhere(
      (e) => e.name == defaultPageStr,
      orElse: () => DefaultPage.ledger,
    ),
  );
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    return _loadSettings();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final p = _cachedPrefs!;
    await p.setString('themeMode', mode.name);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setTimeFormat(TimeFormat format) async {
    final p = _cachedPrefs!;
    await p.setString('timeFormat', format.name);
    state = state.copyWith(timeFormat: format);
  }

  Future<void> setDecimalFormat(DecimalFormat format) async {
    final p = _cachedPrefs!;
    await p.setString('decimalFormat', format.name);
    state = state.copyWith(decimalFormat: format);
  }

  Future<void> setDefaultPage(DefaultPage page) async {
    final p = _cachedPrefs!;
    await p.setString('defaultPage', page.name);
    state = state.copyWith(defaultPage: page);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

final decimalDigitsProvider = Provider<int>((ref) => ref.watch(settingsProvider).decimalDigits);

final defaultTabProvider = Provider<int>((ref) => ref.watch(settingsProvider).defaultTabIndex);
