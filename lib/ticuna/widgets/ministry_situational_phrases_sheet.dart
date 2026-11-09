import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../models/multilingual_models.dart';
import '../services/multilingual_assistant_service.dart';

import '../../ui/widgets/adaptive_ministry_sheet.dart';

/// Modal e Painel Interativo de Frases Situacionais para o Ministério e Comparador Multilíngue
class MinistrySituationalPhrasesSheet extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const MinistrySituationalPhrasesSheet({super.key, this.isEmbedded = false});

  static Future<void> show(BuildContext context) {
    return showAdaptiveMinistrySheet(
      context: context,
      title: 'Frases Situacionais do Ministério',
      subtitle: '6 Momentos-Chave • Ticuna, Português & Español',
      titleLeading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF059669).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('🏹', style: TextStyle(fontSize: 22)),
      ),
      builder: (ctx, _) => const MinistrySituationalPhrasesSheet(isEmbedded: true),
    );
  }

  @override
  ConsumerState<MinistrySituationalPhrasesSheet> createState() =>
      _MinistrySituationalPhrasesSheetState();
}

class _MinistrySituationalPhrasesSheetState
    extends ConsumerState<MinistrySituationalPhrasesSheet> {
  MinistryMoment? _selectedMoment;
  final TextEditingController _searchController = TextEditingController();
  String _selectedComparisonLang = 'spa'; // Default comparison: Español
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    final history = await ref
        .read(multilingualAssistantServiceProvider)
        .getSearchHistory();
    if (mounted) {
      setState(() {
        _recentSearches = history;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = _searchController.text.trim();

    List<SituationalPhrase> phrases = query.isNotEmpty
        ? MinistryPhrasesCatalog.search(query)
        : (_selectedMoment != null
            ? MinistryPhrasesCatalog.byMoment(_selectedMoment!)
            : MinistryPhrasesCatalog.phrases);

    final content = Column(
      children: [
        if (!widget.isEmbedded) ...[
          // Handle bar
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('🏹', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Frases Situacionais do Ministério',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '6 Momentos-Chave • Ticuna, Português & Español',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          const SizedBox(height: 12),
        ],

        // Search Bar & Language Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Pesquisar frases, momentos, textos bíblicos...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  setState(() {});
                },
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    ref
                        .read(multilingualAssistantServiceProvider)
                        .addSearchTerm(val);
                    _loadSearchHistory();
                  }
                },
              ),
            ),
            const SizedBox(height: 10),

            // Search History Chips (if available)
            if (_recentSearches.isNotEmpty && _searchController.text.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _recentSearches.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (ctx, i) {
                      final term = _recentSearches[i];
                      return ActionChip(
                        avatar: const Icon(Icons.history, size: 14),
                        label: Text(term, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          _searchController.text = term;
                          setState(() {});
                        },
                      );
                    },
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // 6 Moments Filter Chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      selected: _selectedMoment == null,
                      label: const Text('Todos (6 Momentos)'),
                      onSelected: (sel) {
                        setState(() {
                          _selectedMoment = null;
                        });
                      },
                    ),
                  ),
                  ...MinistryMoment.values.map((m) {
                    final isSel = _selectedMoment == m;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: isSel,
                        label: Text('${m.iconEmoji} ${m.title}'),
                        selectedColor:
                            const Color(0xFF059669).withValues(alpha: 0.25),
                        onSelected: (sel) {
                          setState(() {
                            _selectedMoment = sel ? m : null;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Comparison Language Selector bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'Comparar com:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('🇪🇸 Español'),
                    selected: _selectedComparisonLang == 'spa',
                    onSelected: (sel) {
                      if (sel) setState(() => _selectedComparisonLang = 'spa');
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('🌿 Guajajara'),
                    selected: _selectedComparisonLang == 'gub',
                    onSelected: (sel) {
                      if (sel) setState(() => _selectedComparisonLang = 'gub');
                    },
                  ),
                  const Spacer(),
                  Text(
                    '${phrases.length} frase(s)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            // Phrases List
            Expanded(
              child: phrases.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off,
                              size: 48,
                              color: isDark ? Colors.grey[600] : Colors.grey[400]),
                          const SizedBox(height: 8),
                          const Text(
                            'Nenhuma frase encontrada para esta busca.',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: phrases.length,
                      itemBuilder: (ctx, idx) {
                        final p = phrases[idx];
                        return _buildPhraseCard(context, p, isDark);
                      },
                    ),
            ),
          ],
        );

    if (widget.isEmbedded) {
      return content;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: content,
      ),
    );
  }

  Widget _buildPhraseCard(
      BuildContext context, SituationalPhrase p, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top tag & title
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${p.moment.iconEmoji} ${p.moment.title}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
                if (p.bibleVerse != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '📖 ${p.bibleVerse}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  p.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Golden Ticuna Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        '🏹 TICUNA (MAGÜTA)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    p.ticuna,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.volume_up,
                          size: 14, color: Color(0xFF0D9488)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Pronúncia: ${p.phonetics}',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Portuguese Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🇧🇷 PORTUGUÊS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    p.portuguese,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Comparison Language Box (Español or Guajajara)
            if (_selectedComparisonLang == 'spa')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🇪🇸 ESPAÑOL (FRONTERA)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      p.spanish,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              )
            else if (_selectedComparisonLang == 'gub')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🌿 GUAJAJARA (TENETEHARA)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      p.guajajara ?? 'Tradução em pesquisa de campo.',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: p.guajajara == null
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 10),

            // Cultural notes
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    p.culturalNotes,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
