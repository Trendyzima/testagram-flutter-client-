import 'package:material_ui/material_ui.dart';

/// Official Testagram app mark, shared by authentication and signed-in pages.
class TestagramBrandMark extends StatelessWidget {
  const TestagramBrandMark({
    super.key,
    this.size = 44,
    this.radius = 13,
  });

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/branding/testagram-icon.webp',
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: 'Testagram',
      ),
    );
  }
}
