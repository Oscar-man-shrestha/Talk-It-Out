import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/ui/brand.dart';

/// Privacy policy, terms and account deletion, readable before signing in
/// (`/legal/privacy`, `/legal/terms`, `/legal/delete-account`). The same
/// Markdown is served by the backend for Google Play (`API.md` 62).
class LegalScreen extends StatefulWidget {
  const LegalScreen({required this.page, super.key});

  static const pages = {'privacy', 'terms', 'delete-account'};

  final String page;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  // Loaded once: a new Future on every build would restart the load.
  late final Future<String> _text = LegalScreen.pages.contains(widget.page)
      ? rootBundle.loadString('assets/legal/${widget.page}.md', cache: false)
      : Future.value('# Not found\n\nThis page does not exist.');

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hPad = width > 860 ? (width - 760) / 2 : 16.0;
    return Scaffold(
      backgroundColor: Brand.canvas,
      appBar: AppBar(
        backgroundColor: Brand.canvas,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/login'),
        ),
      ),
      body: FutureBuilder<String>(
        future: _text,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load this page.'));
          }
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 40),
            children: [for (final block in parseLegal(snap.data!)) block],
          );
        },
      ),
    );
  }
}

/// Renders the small Markdown subset of the legal pages: # and ## headings,
/// paragraphs, "- " lists and **bold**.
List<Widget> parseLegal(String md) {
  final out = <Widget>[];
  final para = <String>[];
  void flush() {
    if (para.isEmpty) return;
    out.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text.rich(
          _inline(para.join(' ')),
          style: const TextStyle(fontSize: 14.5, height: 1.5, color: Brand.ink),
        ),
      ),
    );
    para.clear();
  }

  for (final raw in md.split('\n')) {
    final line = raw.trimRight();
    if (line.startsWith('# ')) {
      flush();
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            line.substring(2),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Brand.ink,
            ),
          ),
        ),
      );
    } else if (line.startsWith('## ')) {
      flush();
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            line.substring(3),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Brand.ink,
            ),
          ),
        ),
      );
    } else if (line.startsWith('- ')) {
      flush();
      out.add(
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: TextStyle(fontSize: 14.5, height: 1.5)),
              Expanded(
                child: Text.rich(
                  _inline(line.substring(2)),
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: Brand.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (line.isEmpty) {
      flush();
    } else {
      para.add(line);
    }
  }
  flush();
  return out;
}

TextSpan _inline(String text) {
  final parts = text.split('**');
  return TextSpan(
    children: [
      for (var i = 0; i < parts.length; i++)
        TextSpan(
          text: parts[i],
          style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null,
        ),
    ],
  );
}
