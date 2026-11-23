/// Utilitário central de higienização de HTML, decodificação de entidades
/// e extração elegante de remetentes de e-mails para o Field Assistant.
class EmailHtmlSanitizer {
  EmailHtmlSanitizer._();

  static final RegExp _headTagRegex = RegExp(
    r'<head[^>]*>[\s\S]*?<\/head>',
    caseSensitive: false,
  );
  static final RegExp _styleTagRegex = RegExp(
    r'<style[^>]*>[\s\S]*?<\/style>',
    caseSensitive: false,
  );
  static final RegExp _scriptTagRegex = RegExp(
    r'<script[^>]*>[\s\S]*?<\/script>',
    caseSensitive: false,
  );
  static final RegExp _htmlCommentRegex = RegExp(
    r'<!--[\s\S]*?-->',
    caseSensitive: false,
  );
  static final RegExp _lineBreakTagRegex = RegExp(
    r'<(?:br\s*\/?>|\/?(?:p|div|tr|li|h[1-6]|table|tbody|thead|ul|ol)[^>]*>)',
    caseSensitive: false,
  );
  static final RegExp _anyHtmlTagRegex = RegExp(r'<[^>]+>');
  static final RegExp _hexEntityRegex = RegExp(
    r'&#x([0-9a-fA-F]+);',
    caseSensitive: false,
  );
  static final RegExp _decimalEntityRegex = RegExp(r'&#([0-9]+);');
  static final RegExp _multiSpaceRegex = RegExp(r'[ \t]+');
  static final RegExp _multiNewlineRegex = RegExp(r'\n{3,}');
  static final RegExp _msoConditionalBlockRegex = RegExp(
    r'<!\[if[^\]]*\]>[\s\S]*?<!\[endif\]>|<!\[if[^\]]*\][\s\S]*?<!\[endif\]>',
    caseSensitive: false,
  );
  static final RegExp _msoConditionalTagRegex = RegExp(
    r'<!--\[if[^\]]*\]>|<!\[endif\]-->|<!\[if[^\]]*\]>|<!\[endif\]>|<!--\[if[^\]]*\]|\[endif\]-->',
    caseSensitive: false,
  );
  static final RegExp _looseCssPropertyBlockRegex = RegExp(
    r"""(?:^|[\n;}])\s*[a-zA-Z0-9_\-\.\# \t\+\>\:\*\,\~\[\]\=\^"'()]+\s*\{[^{}]*(?:background|mix-blend-mode|font-size|display|color|margin|padding|border|width|height)\s*:[^}]*\}""",
    caseSensitive: false,
  );
  static final RegExp _emptyCssBlockRegex = RegExp(
    r"""(?:^|[\n;}])\s*[a-zA-Z0-9_\-\.\# \t\+\>\:\*\,\~\[\]\=\^"'()]+\s*\{\s*\}""",
    caseSensitive: false,
  );
  static final RegExp _strayHtmlCommentEndRegex = RegExp(
    r'^\s*-->\s*$',
    multiLine: true,
  );

  static final RegExp _markdownTableDividerRegex = RegExp(
    r'^\s*\|(?:\s*:?-+:?\s*\|)+\s*$',
    multiLine: true,
  );
  static final RegExp _markdownHeadingRegex = RegExp(
    r'^\s*#{1,6}\s+',
    multiLine: true,
  );
  static final RegExp _markdownLinkRegex = RegExp(r'\[([^\]]+)\]\([^\)]+\)');
  static final RegExp _markdownImageRegex = RegExp(r'!\[([^\]]*)\]\([^\)]+\)');

  /// Mapeamento de entidades HTML nomeadas comuns
  static const Map<String, String> _namedEntities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&apos;': "'",
    '&#39;': "'",
    '&copy;': '©',
    '&reg;': '®',
    '&trade;': '™',
    '&bull;': '•',
    '&mdash;': '—',
    '&ndash;': '–',
    '&hellip;': '…',
    '&laquo;': '«',
    '&raquo;': '»',
    '&cent;': '¢',
    '&pound;': '£',
    '&yen;': '¥',
    '&euro;': '€',
  };

  /// Converte código HTML em texto puro legível:
  /// 1. Remove blocos inteiros `<style>`, `<script>`, `<head>` e comentários `<!-- -->`
  /// 2. Converte tags de quebra (`<br>`, `</p>`, `</div>`, `</tr>`, `</li>`, etc.) em `\n`
  /// 3. Remove todas as demais tags HTML e vazamentos de regras CSS
  /// 4. Decodifica entidades nomeadas, decimais e hexadecimais
  /// 5. Opcionalmente limpa sintaxe de Markdown se [cleanMarkdown] for true
  /// 6. Normaliza espaços múltiplos e quebras de linha excessivas
  static String extractPlainText(
    String? htmlOrText, {
    bool cleanMarkdown = false,
  }) {
    if (htmlOrText == null || htmlOrText.trim().isEmpty) {
      return '';
    }

    var text = htmlOrText;

    // 1. Remove blocos inteiros de cabeçalho, estilo, scripts e comentários
    text = text.replaceAll(_headTagRegex, ' ');
    text = text.replaceAll(_styleTagRegex, ' ');
    text = text.replaceAll(_scriptTagRegex, ' ');
    text = text.replaceAll(_htmlCommentRegex, ' ');
    text = text.replaceAll(_msoConditionalBlockRegex, ' ');
    text = text.replaceAll(_msoConditionalTagRegex, ' ');

    // 2. Converte quebras de bloco para nova linha
    text = text.replaceAll(_lineBreakTagRegex, '\n');

    // 3. Remove todas as outras tags restantes e regras CSS residuais
    text = text.replaceAll(_anyHtmlTagRegex, '');
    text = text.replaceAll(_looseCssPropertyBlockRegex, ' ');
    text = text.replaceAll(_emptyCssBlockRegex, ' ');
    text = text.replaceAll(_strayHtmlCommentEndRegex, '');

    // 4. Limpeza opcional de sintaxe Markdown
    if (cleanMarkdown) {
      text = text.replaceAll(_markdownTableDividerRegex, '');
      text = text.replaceAll(_markdownImageRegex, '');
      text = text.replaceAllMapped(_markdownLinkRegex, (m) => m.group(1) ?? '');
      text = text.replaceAll(_markdownHeadingRegex, '');
      text = text.replaceAllMapped(
        RegExp(r'\*\*([^\*\n]+)\*\*'),
        (m) => m.group(1) ?? '',
      );
      text = text.replaceAllMapped(
        RegExp(r'(?<!\*)\*([^\*\n]+)\*(?!\*)'),
        (m) => m.group(1) ?? '',
      );
      text = text.replaceAllMapped(
        RegExp(r'__([^_\n]+)__'),
        (m) => m.group(1) ?? '',
      );
      text = text.replaceAllMapped(
        RegExp(r'~~([^~\n]+)~~'),
        (m) => m.group(1) ?? '',
      );
    }

    // 5. Decodifica entidades nomeadas
    _namedEntities.forEach((entity, replacement) {
      text = text.replaceAll(entity, replacement);
    });

    // 5. Decodifica entidades decimais (ex.: &#8220; -> “)
    text = text.replaceAllMapped(_decimalEntityRegex, (match) {
      try {
        final code = int.parse(match.group(1)!);
        return String.fromCharCode(code);
      } catch (_) {
        return match.group(0)!;
      }
    });

    // 6. Decodifica entidades hexadecimais (ex.: &#x2014; -> —)
    text = text.replaceAllMapped(_hexEntityRegex, (match) {
      try {
        final code = int.parse(match.group(1)!, radix: 16);
        return String.fromCharCode(code);
      } catch (_) {
        return match.group(0)!;
      }
    });

    // 7. Normaliza espaços não-quebráveis e múltiplos espaços horizontais
    text = text.replaceAll('\u00A0', ' ');
    final lines = text.split('\n');
    final cleanedLines = lines.map(
      (l) => l.replaceAll(_multiSpaceRegex, ' ').trim(),
    );
    text = cleanedLines.join('\n');

    // 8. Normaliza quebras de linha triplas ou maiores
    text = text.replaceAll(_multiNewlineRegex, '\n\n');

    return text.trim();
  }

  /// Extrai o nome de exibição amigável do remetente.
  /// Exemplos:
  /// - `"Eduardo Veiga" <eduveiga@hotmail.com>` -> `Eduardo Veiga`
  /// - `OneDrive <photos@onedrive.com>` -> `OneDrive`
  /// - `superintendente@jw.org` -> `superintendente@jw.org`
  static String displaySenderName(String? rawFrom) {
    if (rawFrom == null || rawFrom.trim().isEmpty) {
      return '(Sem remetente)';
    }

    final trimmed = rawFrom.trim();

    // Se estiver no formato Nome <email> ou "Nome" <email>
    final bracketIndex = trimmed.indexOf('<');
    if (bracketIndex > 0) {
      var name = trimmed.substring(0, bracketIndex).trim();
      // Remove aspas envolventes se houver
      if ((name.startsWith('"') && name.endsWith('"')) ||
          (name.startsWith("'") && name.endsWith("'"))) {
        name = name.substring(1, name.length - 1).trim();
      }
      if (name.isNotEmpty) {
        return name;
      }
    }

    // Se tiver apenas email, ou nome vazio antes do bracket
    if (bracketIndex != -1) {
      final closingBracket = trimmed.indexOf('>', bracketIndex);
      if (closingBracket > bracketIndex) {
        final innerEmail = trimmed
            .substring(bracketIndex + 1, closingBracket)
            .trim();
        if (innerEmail.isNotEmpty) {
          return innerEmail;
        }
      }
    }

    return trimmed;
  }

  /// Extrai exclusivamente o endereço de e-mail (sem o nome de exibição).
  /// Exemplo: `"Eduardo" <edu@exemplo.com>` -> `edu@exemplo.com`
  static String extractEmailAddress(String? rawFrom) {
    if (rawFrom == null || rawFrom.trim().isEmpty) {
      return '';
    }
    final trimmed = rawFrom.trim();
    final start = trimmed.indexOf('<');
    if (start != -1) {
      final end = trimmed.indexOf('>', start);
      if (end != -1 && end > start) {
        return trimmed.substring(start + 1, end).trim();
      }
    }
    return trimmed;
  }

  /// Gera as iniciais do remetente para exibição em CircleAvatar (1 ou 2 letras maiúsculas).
  static String senderInitials(String? rawFrom) {
    final name = displaySenderName(rawFrom);
    if (name.isEmpty || name == '(Sem remetente)') return '?';

    // Se o nome for um email puro (ex.: joao.silva@exemplo.com), pega o prefixo
    final baseText = name.contains('@') ? name.split('@').first : name;
    final parts = baseText
        .split(RegExp(r'[\s._\-]+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final word = parts.first;
      return word.length >= 2
          ? word.substring(0, 2).toUpperCase()
          : word[0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Higieniza o HTML para exibição rica segura no widget HTML:
  /// - Remove tags de script, iframe, embed, object
  /// - Remove handlers de evento `on...`
  static String sanitizeHtmlForDisplay(String rawHtml) {
    if (rawHtml.trim().isEmpty) return '';

    var html = rawHtml;
    // Remove scripts, iframes e objetos
    html = html.replaceAll(_scriptTagRegex, '');
    html = html.replaceAll(
      RegExp(r'<iframe[^>]*>[\s\S]*?<\/iframe>', caseSensitive: false),
      '',
    );
    html = html.replaceAll(
      RegExp(r'<object[^>]*>[\s\S]*?<\/object>', caseSensitive: false),
      '',
    );
    html = html.replaceAll(
      RegExp(r'<embed[^>]*>[\s\S]*?<\/embed>', caseSensitive: false),
      '',
    );

    // Remove event handlers (ex.: onload, onclick, onerror)
    html = html.replaceAll(
      RegExp(
        r'''\s+on[a-z]+\s*=\s*(?:'[^']*'|"[^"]*"|[^\s>]+)''',
        caseSensitive: false,
      ),
      '',
    );

    // Remove javascript: URLs em href/src
    html = html.replaceAll(
      RegExp(
        r'''(href|src)\s*=\s*['"]?javascript:[^'"]*['"]?''',
        caseSensitive: false,
      ),
      r'$1="#"',
    );

    return html;
  }

  /// Substitui referências `src="cid:..."` por `data:<mime>;base64,...`
  /// quando o anexo correspondente tiver base64/contentId disponível.
  static String resolveInlineCidImages(
    String html,
    List<Map<String, dynamic>> attachments,
  ) {
    if (html.isEmpty || attachments.isEmpty) return html;
    final cidMap = <String, String>{};
    for (final att in attachments) {
      final rawCid = (att['contentId'] ?? att['content_id'] ?? att['cid'])
          ?.toString()
          .trim();
      final b64 = (att['base64'] ?? att['data'] ?? att['content'])
          ?.toString()
          .trim();
      if (rawCid == null || rawCid.isEmpty || b64 == null || b64.isEmpty) {
        continue;
      }
      final cleanCid = rawCid.replaceAll(RegExp(r'^<|>$'), '').toLowerCase();
      final mime =
          (att['mimeType'] ??
                  att['mime_type'] ??
                  att['contentType'] ??
                  att['content_type'] ??
                  att['mime'] ??
                  'image/png')
              .toString()
              .trim();
      final cleanB64 = b64.replaceAll(RegExp(r'\s+'), '');
      cidMap[cleanCid] = 'data:$mime;base64,$cleanB64';
    }
    if (cidMap.isEmpty) return html;
    return html.replaceAllMapped(
      RegExp(r'''src\s*=\s*(['"])cid:([^'"]+)\1''', caseSensitive: false),
      (match) {
        final quote = match.group(1)!;
        final cid = match.group(2)!.trim().toLowerCase();
        final dataUri = cidMap[cid];
        if (dataUri == null) return match.group(0)!;
        return 'src=$quote$dataUri$quote';
      },
    );
  }

  /// Converte texto formatado do compositor (com **negrito**, *itálico*, __sublinhado__, etc.)
  /// para HTML limpo bem-formatado para envio de e-mails.
  static String markdownToCleanHtml(String text) {
    if (text.trim().isEmpty) return '';

    final lower = text.trim().toLowerCase();
    if (lower.startsWith('<html') || lower.startsWith('<!doctype')) {
      return sanitizeHtmlForDisplay(text);
    }

    var s = text;

    // Negrito: **texto**
    s = s.replaceAllMapped(
      RegExp(r'\*\*([^\*\n]+)\*\*'),
      (m) => '<b>${m.group(1)}</b>',
    );

    // Itálico: *texto* (não adjacente a outro *)
    s = s.replaceAllMapped(
      RegExp(r'(?<!\*)\*([^\*\n]+)\*(?!\*)'),
      (m) => '<i>${m.group(1)}</i>',
    );

    // Sublinhado: __texto__
    s = s.replaceAllMapped(
      RegExp(r'__([^_\n]+)__'),
      (m) => '<u>${m.group(1)}</u>',
    );

    // Links: [texto](url)
    s = s.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\((https?://[^\)]+)\)'),
      (m) => '<a href="${m.group(2)}">${m.group(1)}</a>',
    );

    // Quebras de linha
    s = s.replaceAll('\r\n', '\n');
    s = s.replaceAll('\n', '<br>');

    return s;
  }

  /// Remove marcadores Markdown do texto sem deixar asteriscos crus
  static String markdownToCleanPlainText(String text) {
    return extractPlainText(text, cleanMarkdown: true);
  }
}
