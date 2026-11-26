enum OfficialBlockKind { paragraph, heading, bulletItem, numberedItem, quote }

class OfficialTextRun {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;

  const OfficialTextRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
  });
}

class OfficialDocBlock {
  final OfficialBlockKind kind;
  final int headingLevel;
  final int? numberIndex;
  final List<OfficialTextRun> runs;

  const OfficialDocBlock({
    required this.kind,
    this.headingLevel = 0,
    this.numberIndex,
    required this.runs,
  });

  String get plainText => runs.map((r) => r.text).join();
}

/// Parser determinístico compartilhado entre Preview, PDF e DOCX para o formato
/// do editor WYSIWYG (`**negrito**`, `*itálico*`, `<u>sublinhado</u>`, listas e links limpos).
class OfficialMarkupParser {
  OfficialMarkupParser._();

  static final RegExp _appLinkRx = RegExp(r'\[([^\]]+)\]\((app://[^)]+)\)');
  static final RegExp _webLinkRx = RegExp(r'\[([^\]]+)\]\((https?://[^)]+)\)');
  static final RegExp _inlineHtmlColorSpanRx = RegExp(
    r'<span\b[^>]*>(.*?)</span>',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _tokenRx = RegExp(
    r'(\*\*[^*]+?\*\*|'
    r'__[^_]+?__|'
    r'<u(?:\s+[^>]*)?>[\s\S]*?</u>|'
    r'~~[^~]+?~~|'
    r'\*[^*\n]+?\*|'
    r'_[^_\n]+?_)',
    caseSensitive: false,
  );

  static String cleanLinksForDocument(String input) {
    var out = input.replaceAllMapped(_appLinkRx, (m) => m.group(1) ?? '');
    out = out.replaceAllMapped(_webLinkRx, (m) => m.group(1) ?? '');
    out = out.replaceAllMapped(_inlineHtmlColorSpanRx, (m) => m.group(1) ?? '');
    return out;
  }

  static List<OfficialDocBlock> parseBlocks(String rawMarkup) {
    final normalized = cleanLinksForDocument(
      rawMarkup.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
    );
    final lines = normalized.split('\n');
    final blocks = <OfficialDocBlock>[];

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        // Preserva espaçamento discreto entre parágrafos só via padding de cada bloco
        continue;
      }

      final trimmed = line.trimLeft();
      if (trimmed.startsWith('### ')) {
        blocks.add(
          OfficialDocBlock(
            kind: OfficialBlockKind.heading,
            headingLevel: 3,
            runs: parseInlineRuns(trimmed.substring(4).trim()),
          ),
        );
      } else if (trimmed.startsWith('## ')) {
        blocks.add(
          OfficialDocBlock(
            kind: OfficialBlockKind.heading,
            headingLevel: 2,
            runs: parseInlineRuns(trimmed.substring(3).trim()),
          ),
        );
      } else if (trimmed.startsWith('# ')) {
        blocks.add(
          OfficialDocBlock(
            kind: OfficialBlockKind.heading,
            headingLevel: 1,
            runs: parseInlineRuns(trimmed.substring(2).trim()),
          ),
        );
      } else if (trimmed.startsWith('> ')) {
        blocks.add(
          OfficialDocBlock(
            kind: OfficialBlockKind.quote,
            runs: parseInlineRuns(trimmed.substring(2).trim()),
          ),
        );
      } else if (trimmed.startsWith('- ') ||
          trimmed.startsWith('* ') ||
          trimmed.startsWith('• ')) {
        blocks.add(
          OfficialDocBlock(
            kind: OfficialBlockKind.bulletItem,
            runs: parseInlineRuns(trimmed.substring(2).trim()),
          ),
        );
      } else {
        final numMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
        if (numMatch != null) {
          blocks.add(
            OfficialDocBlock(
              kind: OfficialBlockKind.numberedItem,
              numberIndex: int.tryParse(numMatch.group(1) ?? '1') ?? 1,
              runs: parseInlineRuns((numMatch.group(2) ?? '').trim()),
            ),
          );
        } else {
          blocks.add(
            OfficialDocBlock(
              kind: OfficialBlockKind.paragraph,
              runs: parseInlineRuns(line),
            ),
          );
        }
      }
    }

    if (blocks.isEmpty) {
      blocks.add(
        const OfficialDocBlock(
          kind: OfficialBlockKind.paragraph,
          runs: [OfficialTextRun(text: '')],
        ),
      );
    }
    return blocks;
  }

  static List<OfficialTextRun> parseInlineRuns(
    String input, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strikethrough = false,
  }) {
    if (input.isEmpty) return const [];
    final runs = <OfficialTextRun>[];
    var cursor = 0;

    for (final match in _tokenRx.allMatches(input)) {
      if (match.start > cursor) {
        final plain = input.substring(cursor, match.start);
        if (plain.isNotEmpty) {
          runs.add(
            OfficialTextRun(
              text: plain,
              bold: bold,
              italic: italic,
              underline: underline,
              strikethrough: strikethrough,
            ),
          );
        }
      }

      final token = match.group(0)!;
      if (token.startsWith('**') && token.endsWith('**') && token.length > 4) {
        runs.addAll(
          parseInlineRuns(
            token.substring(2, token.length - 2),
            bold: true,
            italic: italic,
            underline: underline,
            strikethrough: strikethrough,
          ),
        );
      } else if (token.startsWith('__') &&
          token.endsWith('__') &&
          token.length > 4) {
        runs.addAll(
          parseInlineRuns(
            token.substring(2, token.length - 2),
            bold: bold,
            italic: italic,
            underline: true,
            strikethrough: strikethrough,
          ),
        );
      } else if (token.toLowerCase().startsWith('<u')) {
        final closeStart = token.toLowerCase().lastIndexOf('</u>');
        final gt = token.indexOf('>');
        if (gt != -1 && closeStart > gt) {
          final inner = token.substring(gt + 1, closeStart);
          runs.addAll(
            parseInlineRuns(
              inner,
              bold: bold,
              italic: italic,
              underline: true,
              strikethrough: strikethrough,
            ),
          );
        } else {
          runs.add(
            OfficialTextRun(
              text: token,
              bold: bold,
              italic: italic,
              underline: underline,
              strikethrough: strikethrough,
            ),
          );
        }
      } else if (token.startsWith('~~') &&
          token.endsWith('~~') &&
          token.length > 4) {
        runs.addAll(
          parseInlineRuns(
            token.substring(2, token.length - 2),
            bold: bold,
            italic: italic,
            underline: underline,
            strikethrough: true,
          ),
        );
      } else if ((token.startsWith('*') && token.endsWith('*')) ||
          (token.startsWith('_') && token.endsWith('_'))) {
        runs.addAll(
          parseInlineRuns(
            token.substring(1, token.length - 1),
            bold: bold,
            italic: true,
            underline: underline,
            strikethrough: strikethrough,
          ),
        );
      }
      cursor = match.end;
    }

    if (cursor < input.length) {
      runs.add(
        OfficialTextRun(
          text: input.substring(cursor),
          bold: bold,
          italic: italic,
          underline: underline,
          strikethrough: strikethrough,
        ),
      );
    }

    return runs;
  }
}
