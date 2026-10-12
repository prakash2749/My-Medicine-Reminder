import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/providers/theme_provider.dart';

void main() {
  group('ThemeProvider', () {
    late ThemeProvider themeProvider;

    setUp(() {
      themeProvider = ThemeProvider();
    });

    test('initial themeMode is system', () {
      expect(themeProvider.themeMode, ThemeMode.system);
      expect(themeProvider.isDarkMode, isFalse);
    });

    test('setThemeMode updates themeMode and notifies listeners', () {
      int notifyCount = 0;
      themeProvider.addListener(() {
        notifyCount++;
      });

      themeProvider.setThemeMode(ThemeMode.dark);

      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(themeProvider.isDarkMode, isTrue);
      expect(notifyCount, 1);

      // Setting to same value does not notify again
      themeProvider.setThemeMode(ThemeMode.dark);
      expect(notifyCount, 1);
    });

    test('toggleTheme toggles between light and dark modes', () {
      themeProvider.setThemeMode(ThemeMode.light);
      expect(themeProvider.themeMode, ThemeMode.light);

      themeProvider.toggleTheme();
      expect(themeProvider.themeMode, ThemeMode.dark);

      themeProvider.toggleTheme();
      expect(themeProvider.themeMode, ThemeMode.light);
    });
  });
}
