import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:testagram/features/feed/social_post_text.dart';

void main() {
  testWidgets('hashtags and valid handles are independently actionable', (tester) async {
    String? hashtag;
    String? mention;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SocialPostText(
          text: 'Follow #KenyaTech and say hello to @alice_01.',
          style: const TextStyle(fontSize: 16),
          onHashtagTap: (value) => hashtag = value,
          onMentionTap: (value) => mention = value,
        ),
      ),
    ));

    final richText = tester.widget<RichText>(find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText().contains('#KenyaTech'),
    ).first);
    final spans = (richText.text as TextSpan).children!.whereType<TextSpan>();
    final hashtagSpan = spans.firstWhere((span) => span.text == '#KenyaTech');
    final mentionSpan = spans.firstWhere((span) => span.text == '@alice_01');

    (hashtagSpan.recognizer as TapGestureRecognizer).onTap!();
    (mentionSpan.recognizer as TapGestureRecognizer).onTap!();

    expect(hashtag, 'KenyaTech');
    expect(mention, 'alice_01');
  });

  testWidgets('email addresses and malformed short handles are not linked', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SocialPostText(
          text: 'Email person@example.com and avoid @x or @@alice.',
          style: const TextStyle(fontSize: 16),
          onHashtagTap: (_) {},
          onMentionTap: (_) {},
        ),
      ),
    ));

    final richText = tester.widget<RichText>(find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText().contains('person@example.com'),
    ).first);
    final spans = (richText.text as TextSpan).children!.whereType<TextSpan>();
    expect(spans.where((span) => span.recognizer != null), isEmpty);
  });
}
