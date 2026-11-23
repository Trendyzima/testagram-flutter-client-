import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/widgets/testagram_app_bar.dart';

void main() {
  group('TestagramAppBar', () {
    test('uses the shared toolbar height by default', () {
      const appBar = TestagramAppBar(title: 'Home');

      expect(appBar.preferredSize, const Size.fromHeight(64));
    });

    test('includes a supplied bottom navigation height', () {
      const tabs = PreferredSize(
        preferredSize: Size.fromHeight(48),
        child: SizedBox(),
      );
      const appBar = TestagramAppBar(title: 'Knowledge', bottom: tabs);

      expect(appBar.preferredSize, const Size.fromHeight(112));
    });

    testWidgets('allows the navigator to provide the automatic back button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: TestagramAppBar(title: 'Profile', showBrand: false),
          ),
        ),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leading, isNull);
      expect(appBar.automaticallyImplyLeading, isTrue);
    });

    test('supports a compact toolbar when requested', () {
      const appBar = TestagramAppBar(title: 'Notifications', toolbarHeight: 56);

      expect(appBar.preferredSize, const Size.fromHeight(56));
    });
  });
}
