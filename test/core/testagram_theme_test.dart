import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/testagram_theme.dart';

void main() {
  group('TestagramTheme', () {
    test('light theme exposes the canonical Testagram brand tokens', () {
      final theme = TestagramTheme.light();

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, TestagramTheme.blue);
      expect(theme.scaffoldBackgroundColor, TestagramTheme.lightBackground);
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
    });

    test('dark theme preserves brand contrast and dark surfaces', () {
      final theme = TestagramTheme.dark();

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, TestagramTheme.blueDark);
      expect(theme.scaffoldBackgroundColor, TestagramTheme.darkBackground);
      expect(theme.colorScheme.surface, TestagramTheme.darkSurface);
    });

    test('shared design dimensions remain consistent', () {
      expect(TestagramTheme.contentMaxWidth, 1180);
      expect(TestagramTheme.cardRadius, 20);
      expect(TestagramTheme.controlRadius, 14);
    });
  });
}
