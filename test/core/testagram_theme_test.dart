import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/core/testagram_theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('light and dark themes share the Testagram evergreen identity', () {
    final light = TestagramTheme.light();
    final dark = TestagramTheme.dark();

    expect(light.colorScheme.primary, const Color(0xFF148A68));
    expect(dark.colorScheme.primary, const Color(0xFF45C79A));
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.useMaterial3, isTrue);
    expect(dark.useMaterial3, isTrue);
  });
}
