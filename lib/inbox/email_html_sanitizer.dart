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
  /// 3. Remove todas as demais tags HTML
  /// 4. Decodifica entidades nomeadas, decimais e hexadecimais
  /// 5. Normaliza espaços múltiplos e quebras de linha excessivas
  static String extractPlainText(String? htmlOrText) {
    if (htmlOrText == null || htmlOrText.trim().isEmpty) {
      return '';
    }

    var text = htmlOrText;

    // 1. Remove blocos inteiros de cabeçalho, estilo, scripts e comentários
    text = text.replaceAll(_headTagRegex, ' ');
    text = text.replaceAll(_styleTagRegex, ' ');
    text = text.replaceAll(_scriptTagRegex, ' ');
    text = text.replaceAll(_htmlCommentRegex, ' ');

    // 2. Converte quebras de bloco para nova linha
    text = text.replaceAll(_lineBreakTagRegex, '\n');

    // 3. Remove todas as outras tags restantes
    text = text.replaceAll(_anyHtmlTagRegex, '');

    // 4. Decodifica entidades nomeadas
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
}
