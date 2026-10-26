import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/publications/publication_link_resolver.dart';

void main() {
  group('Resolvedor de Links e Deep Links de Publicações (PublicationLinkResolver)', () {
    test('TC-PUB-01: Resolução de Lição válida do livro Seja Feliz para Sempre em Português', () {
      final resolved = PublicationLinkResolver.resolve(
        publicationId: 'lff-book',
        languageCode: 'pt',
        lesson: 5,
        paragraph: 3,
      );

      expect(resolved.precision, equals(LinkPrecision.directLesson));
      expect(resolved.url, contains('jw.org/finder?srcid=jwlshare'));
      expect(resolved.url, contains('pub=lff'));
      expect(resolved.url, contains('lesson=5'));
      expect(resolved.fallbackUrl, contains('licao-05'));
      // Transparência: o deep link direto para o número do parágrafo NÃO é prometido
      expect(resolved.isDirectParagraphSupported, isFalse);
      expect(resolved.note, contains('Lição 5'));
    });

    test('TC-PUB-02: Resolução para idioma Libras respeita características de línguas de sinais', () {
      final resolved = PublicationLinkResolver.resolve(
        publicationId: 'lff-book',
        languageCode: 'bzs',
        lesson: 2,
        paragraph: 1, // Não aplicável em Libras
      );

      expect(resolved.isSignLanguage, isTrue);
      expect(resolved.url, contains('jw.org/bzs'));
      expect(resolved.note, contains('Libras'));
      expect(resolved.note, contains('vídeos'));
      expect(resolved.isDirectParagraphSupported, isFalse);
    });

    test('TC-PUB-03: Resolução para publicação desconhecida fornece fallback seguro sem falhar', () {
      final resolved = PublicationLinkResolver.resolve(
        publicationId: 'unknown-id',
        languageCode: 'pt',
        manualReference: 'Bíblia, Salmo 23',
      );

      expect(resolved.precision, equals(LinkPrecision.referenceOnly));
      expect(resolved.displayText, contains('Salmo 23'));
    });
  });
}
