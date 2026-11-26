import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

enum OfficialFontCategory { serif, sans, cursive }

class OfficialFontOption {
  final String id;
  final String displayName;
  final String flutterFamily;
  final String docxFontName;
  final OfficialFontCategory category;
  final String regularAsset;
  final String? boldAsset;
  final String? italicAsset;
  final String? boldItalicAsset;

  const OfficialFontOption({
    required this.id,
    required this.displayName,
    required this.flutterFamily,
    required this.docxFontName,
    required this.category,
    required this.regularAsset,
    this.boldAsset,
    this.italicAsset,
    this.boldItalicAsset,
  });
}

class OfficialPdfFontBundle {
  final pw.Font base;
  final pw.Font bold;
  final pw.Font italic;
  final pw.Font boldItalic;

  const OfficialPdfFontBundle({
    required this.base,
    required this.bold,
    required this.italic,
    required this.boldItalic,
  });

  pw.Font pick({bool isBold = false, bool isItalic = false}) {
    if (isBold && isItalic) return boldItalic;
    if (isBold) return bold;
    if (isItalic) return italic;
    return base;
  }
}

/// Catálogo completo de fontes embutidas (100% SIL OFL 1.1 offline para UI, PDF, PNG e DOCX).
class OfficialDocFonts {
  OfficialDocFonts._();

  static const List<OfficialFontOption> textFonts = [
    OfficialFontOption(
      id: 'pt_serif',
      displayName: 'PT Serif (Clássica · Padrão PDF)',
      flutterFamily: 'PTSerif',
      docxFontName: 'Georgia',
      category: OfficialFontCategory.serif,
      regularAsset: 'assets/fonts/PT_Serif-Regular.ttf',
      boldAsset: 'assets/fonts/PT_Serif-Bold.ttf',
      italicAsset: 'assets/fonts/PT_Serif-Italic.ttf',
      boldItalicAsset: 'assets/fonts/PT_Serif-BoldItalic.ttf',
    ),
    OfficialFontOption(
      id: 'caladea',
      displayName: 'Caladea (Serifada Cambria)',
      flutterFamily: 'Caladea',
      docxFontName: 'Cambria',
      category: OfficialFontCategory.serif,
      regularAsset: 'assets/fonts/Caladea-Regular.ttf',
      boldAsset: 'assets/fonts/Caladea-Bold.ttf',
      italicAsset: 'assets/fonts/Caladea-Italic.ttf',
      boldItalicAsset: 'assets/fonts/Caladea-BoldItalic.ttf',
    ),
    OfficialFontOption(
      id: 'crimson_text',
      displayName: 'Crimson Text (Editorial Clássica)',
      flutterFamily: 'CrimsonText',
      docxFontName: 'Georgia',
      category: OfficialFontCategory.serif,
      regularAsset: 'assets/fonts/CrimsonText-Regular.ttf',
      boldAsset: 'assets/fonts/CrimsonText-Bold.ttf',
      italicAsset: 'assets/fonts/CrimsonText-Italic.ttf',
      boldItalicAsset: 'assets/fonts/CrimsonText-BoldItalic.ttf',
    ),
    OfficialFontOption(
      id: 'pt_sans',
      displayName: 'PT Sans (Moderna · Padrão Cabeçalho)',
      flutterFamily: 'PTSans',
      docxFontName: 'Calibri',
      category: OfficialFontCategory.sans,
      regularAsset: 'assets/fonts/PT_Sans-Regular.ttf',
      boldAsset: 'assets/fonts/PT_Sans-Bold.ttf',
      italicAsset: 'assets/fonts/PT_Sans-Italic.ttf',
      boldItalicAsset: 'assets/fonts/PT_Sans-BoldItalic.ttf',
    ),
    OfficialFontOption(
      id: 'lato',
      displayName: 'Lato (Sans Geométrica)',
      flutterFamily: 'Lato',
      docxFontName: 'Segoe UI',
      category: OfficialFontCategory.sans,
      regularAsset: 'assets/fonts/Lato-Regular.ttf',
      boldAsset: 'assets/fonts/Lato-Bold.ttf',
      italicAsset: 'assets/fonts/Lato-Italic.ttf',
      boldItalicAsset: 'assets/fonts/Lato-BoldItalic.ttf',
    ),
  ];

  static const List<OfficialFontOption> signatureFonts = [
    OfficialFontOption(
      id: 'sacramento',
      displayName: 'Sacramento (Cursiva Fina · Padrão PDF)',
      flutterFamily: 'Sacramento',
      docxFontName: 'Segoe Script',
      category: OfficialFontCategory.cursive,
      regularAsset: 'assets/fonts/Sacramento-Regular.ttf',
    ),
    OfficialFontOption(
      id: 'courgette',
      displayName: 'Courgette (Manuscrita Legível)',
      flutterFamily: 'Courgette',
      docxFontName: 'Segoe Script',
      category: OfficialFontCategory.cursive,
      regularAsset: 'assets/fonts/Courgette-Regular.ttf',
    ),
    OfficialFontOption(
      id: 'great_vibes',
      displayName: 'Great Vibes (Caligrafia Clássica)',
      flutterFamily: 'GreatVibes',
      docxFontName: 'Vivaldi',
      category: OfficialFontCategory.cursive,
      regularAsset: 'assets/fonts/GreatVibes-Regular.ttf',
    ),
    OfficialFontOption(
      id: 'alex_brush',
      displayName: 'Alex Brush (Pincel Refinado)',
      flutterFamily: 'AlexBrush',
      docxFontName: 'French Script MT',
      category: OfficialFontCategory.cursive,
      regularAsset: 'assets/fonts/AlexBrush-Regular.ttf',
    ),
    OfficialFontOption(
      id: 'allura',
      displayName: 'Allura (Caligráfica Fluida)',
      flutterFamily: 'Allura',
      docxFontName: 'Gabriola',
      category: OfficialFontCategory.cursive,
      regularAsset: 'assets/fonts/Allura-Regular.ttf',
    ),
  ];

  static List<OfficialFontOption> get allFonts => [
    ...textFonts,
    ...signatureFonts,
  ];

  static const Map<String, String> _aliases = {
    'ptserif': 'pt_serif',
    'pt_serif': 'pt_serif',
    'lora': 'pt_serif',
    'notoserif': 'pt_serif',
    'georgia': 'pt_serif',
    'times': 'pt_serif',
    'caladea': 'caladea',
    'cambria': 'caladea',
    'crimsontext': 'crimson_text',
    'crimson_text': 'crimson_text',
    'ebgaramond': 'crimson_text',
    'ptsans': 'pt_sans',
    'pt_sans': 'pt_sans',
    'notosans': 'pt_sans',
    'segoeui': 'pt_sans',
    'lato': 'lato',
    'plusjakartasans': 'lato',
    'inter': 'lato',
    'calibri': 'lato',
    'carlito': 'lato',
    'sacramento': 'sacramento',
    'pristina': 'sacramento',
    'courgette': 'courgette',
    'dancingscript': 'courgette',
    'segoescript': 'courgette',
    'greatvibes': 'great_vibes',
    'great_vibes': 'great_vibes',
    'vivaldi': 'great_vibes',
    'alexbrush': 'alex_brush',
    'alex_brush': 'alex_brush',
    'frenchscript': 'alex_brush',
    'allura': 'allura',
    'gabriola': 'allura',
  };

  static String normalizeFontId(String? raw, {String fallback = 'pt_serif'}) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final key = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '');
    if (_aliases.containsKey(key)) return _aliases[key]!;
    final under = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
    if (_aliases.containsKey(under)) return _aliases[under]!;
    return fallback;
  }

  static OfficialFontOption findById(
    String? rawId, {
    String fallbackId = 'pt_serif',
  }) {
    final norm = normalizeFontId(rawId, fallback: fallbackId);
    for (final f in allFonts) {
      if (f.id == norm) return f;
    }
    return textFonts.first;
  }

  static final Map<String, Future<OfficialPdfFontBundle>> _pdfFontCache = {};

  static Future<OfficialPdfFontBundle> loadPdfBundle(String fontId) {
    final opt = findById(fontId);
    return _pdfFontCache.putIfAbsent(opt.id, () async {
      try {
        final regData = await rootBundle.load(opt.regularAsset);
        final reg = pw.Font.ttf(regData);
        final bold = opt.boldAsset != null
            ? pw.Font.ttf(await rootBundle.load(opt.boldAsset!))
            : reg;
        final italic = opt.italicAsset != null
            ? pw.Font.ttf(await rootBundle.load(opt.italicAsset!))
            : reg;
        final boldItalic = opt.boldItalicAsset != null
            ? pw.Font.ttf(await rootBundle.load(opt.boldItalicAsset!))
            : bold;
        return OfficialPdfFontBundle(
          base: reg,
          bold: bold,
          italic: italic,
          boldItalic: boldItalic,
        );
      } catch (_) {
        // Fallback seguro para ambientes de teste sem AssetBundle completo
        return OfficialPdfFontBundle(
          base: opt.category == OfficialFontCategory.serif
              ? pw.Font.times()
              : (opt.category == OfficialFontCategory.cursive
                    ? pw.Font.timesItalic()
                    : pw.Font.helvetica()),
          bold: opt.category == OfficialFontCategory.serif
              ? pw.Font.timesBold()
              : pw.Font.helveticaBold(),
          italic: opt.category == OfficialFontCategory.serif
              ? pw.Font.timesItalic()
              : pw.Font.helveticaOblique(),
          boldItalic: opt.category == OfficialFontCategory.serif
              ? pw.Font.timesBoldItalic()
              : pw.Font.helveticaBoldOblique(),
        );
      }
    });
  }
}
