import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/publications/publication_link_resolver.dart';

void main() {
  group(
    'Resolvedor de Links e Deep Links de Publicações (PublicationLinkResolver)',
    () {
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
        expect(resolved.url, contains('docid=1102021205'));
        expect(resolved.url, contains('par=3'));
        expect(resolved.fallbackUrl, contains('parte-1/licao-05/#p3'));
        expect(resolved.isDirectParagraphSupported, isTrue);
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

      test('TC-PUB-04: Navegação direta com parâmetro de lição e parágrafo/ponto', () {
        final resolved = PublicationLinkResolver.resolve(
          publicationId: 'lff-book',
          languageCode: 'pt',
          lesson: 8,
          paragraph: 3,
        );

        expect(resolved.url, contains('pub=lff'));
        expect(resolved.url, contains('lesson=8'));
        expect(resolved.url, contains('docid=1102021208'));
        expect(resolved.url, contains('par=3'));
        expect(resolved.fallbackUrl, contains('parte-1/licao-08/#p3'));
        expect(resolved.displayText, contains('Lição 8, § 3'));
        expect(resolved.isDirectParagraphSupported, isTrue);
      });

      test('TC-PUB-05: Lições em outras partes mapeiam corretamente as seções canônicas', () {
        final resPart2 = PublicationLinkResolver.resolve(
          publicationId: 'lff-book',
          languageCode: 'pt',
          lesson: 15,
          paragraph: 2,
        );
        expect(resPart2.url, contains('docid=1102021215'));
        expect(resPart2.fallbackUrl, contains('parte-2/licao-15/#p2'));

        final resPart3 = PublicationLinkResolver.resolve(
          publicationId: 'lff-book',
          languageCode: 'pt',
          lesson: 35,
          paragraph: 4,
        );
        expect(resPart3.url, contains('docid=1102021235'));
        expect(resPart3.fallbackUrl, contains('parte-3/licao-35/#p4'));

        final resPart4 = PublicationLinkResolver.resolve(
          publicationId: 'lff-book',
          languageCode: 'pt',
          lesson: 50,
          paragraph: 1,
        );
        expect(resPart4.url, contains('docid=1102021250'));
        expect(resPart4.fallbackUrl, contains('parte-4/licao-50/#p1'));
      });
    },
  );
}
