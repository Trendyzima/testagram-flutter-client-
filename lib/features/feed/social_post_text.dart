import 'package:material_ui/material_ui.dart';

/// Renders Testagram handles and hashtags as accessible, tappable inline links.
/// Resolution and visibility checks stay with the Backend via the callbacks.
class SocialPostText extends StatelessWidget {
  const SocialPostText({
    super.key,
    required this.text,
    required this.style,
    required this.onHashtagTap,
    required this.onMentionTap,
  });

  final String text;
  final TextStyle? style;
  final ValueChanged<String> onHashtagTap;
  final ValueChanged<String> onMentionTap;

  static final RegExp _tokens = RegExp(
    r'(?<![\\p{L}\\p{N}_])([#@])([\\p{L}\\p{N}_.]{1,64})',
    unicode: true,
  );

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in _tokens.allMatches(text)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      final prefix = match.group(1)!;
      final value = match.group(2)!;
      final isHashtag = prefix == '#';
      final valid = isHashtag
          ? value.length <= 64
          : RegExp(r'^[A-Za-z0-9_.]{2,30}$').hasMatch(value);
      final callback = isHashtag ? onHashtagTap : onMentionTap;
      spans.add(TextSpan(
        text: '$prefix$value',
        style: style?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
        recognizer: valid
            ? (TapGestureRecognizer()..onTap = () => callback(value))
            : null,
      ));
      offset = match.end;
    }
    if (offset < text.length) {
      spans.add(TextSpan(text: text.substring(offset)));
    }
    return SelectableText.rich(
      TextSpan(style: style, children: spans),
    );
  }
}
