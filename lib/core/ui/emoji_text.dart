import 'package:flutter/material.dart';

/// Hearts that some web fonts draw as a plain black symbol (U+2764 is also
/// in black-and-white symbol fonts, which the browser may pick before the
/// colour emoji font). They are drawn as a real red heart instead.
const _hearts = {'❤️', '❤', '♥️', '♥'};

const _heartRed = Color(0xFFE5243B);

/// One emoji, always in colour.
class EmojiGlyph extends StatelessWidget {
  const EmojiGlyph(this.emoji, {this.size = 18, super.key});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (_hearts.contains(emoji)) {
      return Semantics(
        label: 'red heart',
        child: SizedBox(
          width: size * 1.15,
          height: size * 1.2,
          child: Icon(Icons.favorite, size: size * 1.05, color: _heartRed),
        ),
      );
    }
    return Text(emoji, style: TextStyle(fontSize: size, height: 1.2));
  }
}

/// Text in which every heart emoji is drawn in red (big emoji-only chat
/// messages); everything else stays as text in [style].
class EmojiText extends StatelessWidget {
  const EmojiText(this.text, {required this.style, super.key});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (!_hearts.any(text.contains)) return Text(text, style: style);
    final size = style.fontSize ?? 15;
    final spans = <InlineSpan>[];
    var plain = StringBuffer();
    for (final ch in text.characters) {
      if (_hearts.contains(ch)) {
        if (plain.isNotEmpty) {
          spans.add(TextSpan(text: plain.toString()));
          plain = StringBuffer();
        }
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: EmojiGlyph(ch, size: size),
          ),
        );
      } else {
        plain.write(ch);
      }
    }
    if (plain.isNotEmpty) spans.add(TextSpan(text: plain.toString()));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
