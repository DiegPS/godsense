import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../shared/coach_surface.dart';

/// The same renderer is used for partial and finished assistant messages.
class CoachMessageBody extends StatelessWidget {
  const CoachMessageBody({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(
      color: CoachColors.primaryText,
      fontSize: 14,
      height: 1.5,
    );
    return MarkdownBody(
      data: text,
      selectable: true,
      fitContent: true,
      // Model output must not trigger remote image requests or read local files.
      imageBuilder: (uri, title, alt) => Text(alt ?? title ?? 'Imagen'),
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: body,
        strong: body.copyWith(fontWeight: FontWeight.w700),
        em: body.copyWith(fontStyle: FontStyle.italic),
        h1: body.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
        h2: body.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
        h3: body.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        listBullet: body,
        blockSpacing: 10,
        listIndent: 22,
        code: body.copyWith(fontFamily: 'monospace', fontSize: 13),
        codeblockDecoration: BoxDecoration(
          color: CoachColors.elevated,
          borderRadius: BorderRadius.circular(6),
        ),
        blockquote: body.copyWith(color: CoachColors.secondaryText),
      ),
    );
  }
}
