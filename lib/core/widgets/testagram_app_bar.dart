import 'package:material_ui/material_ui.dart';

import 'testagram_brand_mark.dart';

/// Consistent top-level page chrome for Testagram's primary destinations.
///
/// Nested detail pages keep the platform's automatic back button; this header
/// is intended for root destinations in the signed-in navigation shell.
class TestagramAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TestagramAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.bottom,
    this.showBrand = true,
    this.toolbarHeight = 64,
  });

  final String title;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final bool showBrand;
  final double toolbarHeight;

  @override
  Size get preferredSize => Size.fromHeight(
        toolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) => AppBar(
        toolbarHeight: toolbarHeight,
        leadingWidth: showBrand ? 56 : null,
        leading: showBrand
            ? const Padding(
                padding: EdgeInsets.only(left: 12, top: 8, bottom: 8),
                child: TestagramBrandMark(size: 36, radius: 11),
              )
            : null,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: actions,
        bottom: bottom,
      );
}
