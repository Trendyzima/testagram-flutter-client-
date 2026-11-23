import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// Renders Testagram handles and hashtags as accessible, tappable inline links.
/// Identity resolution and visibility checks remain authoritative in Backend.
class SocialPostText extends StatefulWidget {
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

  @override
  State<SocialPostText> createState() => _SocialPostTextState();
}

class _SocialPostTextState extends State<SocialPostText> {
  static final RegExp _tokens = RegExp(
    r'(?<![\\p{L}\\p{N}_@#])(#([\\p{L}\\p{N}_]{1,64})|@([A-Za-z0-9_][A-Za-z0-9_.]{0,28}[A-Za-z0-9_]))',
    unicode: true,
  );

  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in _tokens.allMatches(widget.text)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: widget.text.substring(offset, match.start)));
      }
      final token = match.group(1)!;
      final isHashtag = token.startsWith('#');
      final value = isHashtag ? match.group(2)! : match.group(3)!;
      final prefix = isHashtag ? '#' : '@';
      final callback = isHashtag ? widget.onHashtagTap : widget.onMentionTap;
      TapGestureRecognizer? recognizer;
      recognizer = TapGestureRecognizer()..onTap = () => callback(value);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: '$prefix$value',
        style: widget.style?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
        recognizer: recognizer,
      ));
      offset = match.end;
    }
    if (offset < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(offset)));
    }
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}
