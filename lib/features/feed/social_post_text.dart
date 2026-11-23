import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// Renders Testagram handles and hashtags as accessible, tappable inline links.
/// Resolution and visibility checks stay with the Backend via the callbacks.
class SocialPostText extends StatefulWidget {
  const SocialPostText({
    super.key,
    required this.text,
    required this.style,
    required this.onHashtagTap,
    required this.onMentionTap,
    this.onTextTap,
  });

  final String text;
  final TextStyle? style;
  final ValueChanged<String> onHashtagTap;
  final ValueChanged<String> onMentionTap;
  final VoidCallback? onTextTap;

  @override
  State<SocialPostText> createState() => _SocialPostTextState();
}

class _SocialPostTextState extends State<SocialPostText> {
  static final RegExp _tokens = RegExp(
    r'(?<![\p{L}\p{N}_])([#@])([\p{L}\p{N}_.]{1,64})',
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
      final prefix = match.group(1)!;
      final value = match.group(2)!;
      final isHashtag = prefix == '#';
      final valid = isHashtag
          ? value.length <= 64
          : RegExp(r'^[A-Za-z0-9_.]{2,30}$').hasMatch(value);
      final callback = isHashtag ? widget.onHashtagTap : widget.onMentionTap;
      TapGestureRecognizer? recognizer;
      if (valid) {
        recognizer = TapGestureRecognizer()..onTap = () => callback(value);
        _recognizers.add(recognizer);
      }
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
    return InkWell(
      onTap: widget.onTextTap,
      child: Text.rich(TextSpan(style: widget.style, children: spans)),
    );
  }
}
