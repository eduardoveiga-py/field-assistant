import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../ticuna/models/multilingual_models.dart';
import '../../ticuna/models/ticuna_models.dart';
import '../../ticuna/ticuna_providers.dart';
import '../../ticuna/ticuna_unicode_helper.dart';
import '../../ticuna/widgets/ticuna_audio_player_widget.dart';
import '../../ticuna/widgets/ticuna_diacritics_bar.dart';
import '../../ticuna/widgets/ministry_situational_phrases_sheet.dart';
import '../providers.dart';
import '../widgets/adaptive_ministry_sheet.dart';
import '../widgets/managed_text_controllers.dart';
import '../widgets/screen_hero_accent_band.dart';

class TicunaScreen extends ConsumerStatefulWidget {
  const TicunaScreen({super.key});

  @override
  ConsumerState<TicunaScreen> createState() => _TicunaScreenState();
}

class _TicunaScreenState extends ConsumerState<TicunaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedTag;
  bool _onlyFavorites = false;
  String? _selectedGrammarClass;
  String? _selectedCategory;
  bool _showSearchDiacritics = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wordsAsync = ref.watch(ticunaWordsStreamProvider);
    final phrasesAsync = ref.watch(ticunaPhrasesStreamProvider);
    final tagsAsync = ref.watch(ticunaTagsStreamProvider);
    final languagesAsync = ref.watch(languagesStreamProvider);
    final activeLang = ref.watch(currentActiveLanguageProvider);

    final allWords = wordsAsync.value ?? [];
    final allPhrases = phrasesAsync.value ?? [];
    final allTags = tagsAsync.value ?? [];
    final allLanguages = languagesAsync.value ?? [activeLang];
    final activeDiacritics = parseLanguageDiacritics(activeLang.diacritics);

    // Filtrar pelo idioma ativo
    final langWords = allWords.where((w) {
      if (activeLang.id == 'tca') {
        return w.languageId == null || w.languageId == 'tca';
      }
      return w.languageId == activeLang.id;
    }).toList();

    final langPhrases = allPhrases.where((p) {
      if (activeLang.id == 'tca') {
        return p.languageId == null || p.languageId == 'tca';
      }
      return p.languageId == activeLang.id;
    }).toList();

    // Filtros aplicados
    final searchQuery = _searchController.text.trim().toLowerCase();

    final filteredWords = langWords.where((w) {
      if (_onlyFavorites && !w.isFavorite) return false;
      if (_selectedTag != null &&
          _selectedTag != 'Todos' &&
          !w.tags.contains(_selectedTag)) {
        return false;
      }
      if (_selectedGrammarClass != null &&
          _selectedGrammarClass != 'Todas' &&
          w.grammaticalClass != _selectedGrammarClass) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        return w.word.toLowerCase().contains(searchQuery) ||
            w.translation.toLowerCase().contains(searchQuery) ||
            (w.phonetics?.toLowerCase().contains(searchQuery) ?? false) ||
            (w.exampleSentence?.toLowerCase().contains(searchQuery) ?? false) ||
            (w.exampleTranslation?.toLowerCase().contains(searchQuery) ?? false) ||
            (w.notes?.toLowerCase().contains(searchQuery) ?? false);
      }
      return true;
    }).toList();

    final filteredPhrases = langPhrases.where((p) {
      if (_onlyFavorites && !p.isFavorite) return false;
      if (_selectedTag != null &&
          _selectedTag != 'Todos' &&
          !p.tags.contains(_selectedTag)) {
        return false;
      }
      if (_selectedCategory != null &&
          _selectedCategory != 'Todas' &&
          p.category != _selectedCategory) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        return p.phrase.toLowerCase().contains(searchQuery) ||
            p.translation.toLowerCase().contains(searchQuery) ||
            (p.phonetics?.toLowerCase().contains(searchQuery) ?? false) ||
            (p.notes?.toLowerCase().contains(searchQuery) ?? false) ||
            (p.category?.toLowerCase().contains(searchQuery) ?? false);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => _showLanguageSelectorModal(context, allLanguages, activeLang),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF0D9488).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  activeLang.symbol,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              activeLang.id == 'tca' ? 'Língua Ticuna' : activeLang.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: Color(0xFF0D9488),
                          ),
                        ],
                      ),
                      Text(
                        'Dicionário & Frases de Campo',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Botão Seletor / Gerenciador de Idiomas
          IconButton(
            tooltip: 'Gerenciar Idiomas & + Novo Idioma',
            icon: const Icon(Icons.language_rounded, color: Color(0xFF0D9488)),
            onPressed: () => _showLanguageSelectorModal(context, allLanguages, activeLang),
          ),
          // Botão Frases Situacionais & Comparador Multilíngue
          IconButton(
            tooltip: 'Frases Situacionais do Ministério & Comparador',
            icon: const Icon(Icons.forum_outlined, color: Color(0xFF0D9488)),
            onPressed: () => MinistrySituationalPhrasesSheet.show(context),
          ),
          // Botão Treinar / Flashcards (AnkiDroid)
          IconButton(
            tooltip: 'Modo Flashcards (Treinar Vocabulário)',
            icon: const Icon(Icons.school_outlined, color: Color(0xFF0D9488)),
            onPressed: () {
              if (langWords.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cadastre palavras em ${activeLang.name} para treinar!'),
                  ),
                );
                return;
              }
              _showFlashcardStudyModal(context, langWords);
            },
          ),
          // Botão Importar / Exportar
          IconButton(
            tooltip: 'Importar / Exportar Banco de Dados',
            icon: const Icon(Icons.import_export_rounded),
            onPressed: () => _showImportExportModal(context),
          ),
          // Botão Gerenciar Tags
          IconButton(
            tooltip: 'Gerenciar Tags',
            icon: const Icon(Icons.label_outline),
            onPressed: () => _showManageTagsModal(context, allTags),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF0D9488),
          labelColor: const Color(0xFF0D9488),
          unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.menu_book, size: 18),
                  const SizedBox(width: 8),
                  Text('Dicionário (${langWords.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.forum_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('Frases Úteis (${langPhrases.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          _tabController.index == 0 ? 'Novo Termo' : 'Nova Frase',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          if (_tabController.index == 0) {
            _showWordFormDialog(
              context,
              allTags: allTags,
              activeLang: activeLang,
              activeDiacritics: activeDiacritics,
            );
          } else {
            _showPhraseFormDialog(
              context,
              allTags: allTags,
              activeLang: activeLang,
              activeDiacritics: activeDiacritics,
            );
          }
        },
      ),
      body: Column(
        children: [
          ScreenHeroAccentBand.languages(),
          // Barra de Pesquisa e Filtros
          _buildSearchAndFilterHeader(
            context,
            allTags: allTags,
            isDark: isDark,
            activeLang: activeLang,
            activeDiacritics: activeDiacritics,
          ),

          // Visualização de Conteúdo pelas Abas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Aba 1: Dicionário
                _buildDictionaryTab(filteredWords, isDark: isDark),

                // Aba 2: Frases Úteis
                _buildPhrasesTab(filteredPhrases, isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BARRA DE PESQUISA E FILTROS CHIP
  // ==========================================

  Widget _buildSearchAndFilterHeader(
    BuildContext context, {
    required List<TicunaTag> allTags,
    required bool isDark,
    required AppLanguageEntry activeLang,
    required List<String> activeDiacritics,
  }) {
    return Container(
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo de busca
          TextField(
            controller: _searchController,
            style: TicunaUnicodeHelper.textStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
            inputFormatters: const [TicunaInputFormatter()],
            decoration: InputDecoration(
              hintText: _tabController.index == 0
                  ? 'Buscar termo em ${activeLang.name} ou tradução...'
                  : 'Buscar frases ou expressões em ${activeLang.name}...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                        });
                      },
                    ),
                  if (activeDiacritics.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        _showSearchDiacritics
                            ? Icons.keyboard_hide_outlined
                            : Icons.keyboard_outlined,
                        size: 20,
                        color: _showSearchDiacritics
                            ? const Color(0xFF0D9488)
                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      tooltip: activeLang.id == 'tca'
                          ? 'Teclado Especial Ticuna'
                          : 'Teclado Especial (${activeLang.name})',
                      onPressed: () {
                        setState(() {
                          _showSearchDiacritics = !_showSearchDiacritics;
                        });
                      },
                    ),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_showSearchDiacritics && activeDiacritics.isNotEmpty) ...[
            const SizedBox(height: 8),
            TicunaDiacriticsBar(
              controller: _searchController,
              compact: true,
              diacritics: activeDiacritics,
              label: 'Inserir Caractere Especial na Pesquisa:',
              onCharacterInserted: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 6),

          // Atalho rápido para Frases Situacionais e Comparador Multilíngue
          InkWell(
            onTap: () => MinistrySituationalPhrasesSheet.show(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0D9488).withValues(alpha: isDark ? 0.25 : 0.12),
                    const Color(0xFF059669).withValues(alpha: isDark ? 0.20 : 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_stories, size: 16, color: Color(0xFF0D9488)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '6 Frases Situacionais do Ministério & Comparador Multilíngue',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF0D9488)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Linha de Chips de Filtro
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Filtro Favoritos
                FilterChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.amber),
                      SizedBox(width: 4),
                      Text('Favoritos'),
                    ],
                  ),
                  selected: _onlyFavorites,
                  selectedColor: Colors.amber.withValues(alpha: 0.25),
                  checkmarkColor: Colors.amber.shade900,
                  onSelected: (val) => setState(() => _onlyFavorites = val),
                ),
                const SizedBox(width: 6),

                // Filtro Todas as Tags
                FilterChip(
                  label: const Text('Todas as Tags'),
                  selected: _selectedTag == null || _selectedTag == 'Todos',
                  onSelected: (_) => setState(() => _selectedTag = 'Todos'),
                ),
                const SizedBox(width: 6),

                // Tags individuais
                ...allTags.map((tag) {
                  final isSelected = _selectedTag == tag.name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(tag.name),
                      selected: isSelected,
                      selectedColor: const Color(0xFF0D9488).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF0D9488),
                      onSelected: (val) {
                        setState(() {
                          _selectedTag = val ? tag.name : 'Todos';
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ABA DICIONÁRIO (FLASHCARDS / ANKI)
  // ==========================================

  Widget _buildDictionaryTab(List<TicunaWord> words, {required bool isDark}) {
    if (words.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.menu_book,
                size: 54,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              const Text(
                'Nenhum termo encontrado',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Toque em "+ Novo Termo" para registrar uma nova palavra no vocabulário.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final item = words[index];
        return _buildWordCard(item, isDark: isDark);
      },
    );
  }

  Widget _buildWordCard(TicunaWord item, {required bool isDark}) {
    final repo = ref.read(ticunaRepositoryProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha superior: Palavra Ticuna, Fonética, Classe e Ações
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.word,
                              style: TicunaUnicodeHelper.textStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0D9488),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: 'Copiar termo Ticuna',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: item.word));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Termo "${item.word}" copiado!'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      if (item.phonetics != null && item.phonetics!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '[ ${item.phonetics} ]',
                            style: TicunaUnicodeHelper.textStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (item.grammaticalClass != null &&
                    item.grammaticalClass!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.grammaticalClass!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    item.isFavorite ? Icons.star : Icons.star_border,
                    color: item.isFavorite ? Colors.amber : Colors.grey,
                  ),
                  onPressed: () => repo.toggleWordFavorite(item.id),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showWordFormDialog(
                        context,
                        wordToEdit: item,
                        allTags: ref.read(ticunaTagsStreamProvider).value ?? [],
                      );
                    } else if (val == 'delete') {
                      _confirmDeleteWord(context, item);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Excluir', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tradução em Português
            Text(
              item.translation,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            // Áudio de Pronúncia Ticuna (Player leve ou Botão de Gravar)
            TicunaAudioPlayerWidget(
              id: item.id,
              title: item.word,
              audioPath: item.audioPath,
              audioDurationSeconds: item.audioDurationSeconds,
              isPhrase: false,
              compact: true,
            ),

            // Exemplo de frase
            if (item.exampleSentence != null && item.exampleSentence!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ex: "${item.exampleSentence}"',
                      style: TicunaUnicodeHelper.textStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF0D9488),
                      ),
                    ),
                    if (item.exampleTranslation != null &&
                        item.exampleTranslation!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '→ ${item.exampleTranslation}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Notas adicionais
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Nota: ${item.notes}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Rodapé do Cartão: Tags e Estado de Revisão Anki
            Row(
              children: [
                // Tags
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: item.tags.map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Badge de Nível de Revisão Anki
                _buildAnkiReviewBadge(item, isDark: isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnkiReviewBadge(TicunaWord item, {required bool isDark}) {
    String levelText;
    Color levelColor;

    if (item.reviewLevel == 0) {
      levelText = 'Novo';
      levelColor = Colors.blue;
    } else if (item.reviewLevel <= 2) {
      levelText = 'Aprendendo';
      levelColor = Colors.orange;
    } else if (item.reviewLevel <= 4) {
      levelText = 'Revisando';
      levelColor = const Color(0xFF0D9488);
    } else {
      levelText = 'Dominado';
      levelColor = Colors.green;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        _showFlashcardStudyModal(context, [item]);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: levelColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: levelColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.repeat, size: 12, color: levelColor),
            const SizedBox(width: 4),
            Text(
              '$levelText (${item.reviewCount}x)',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: levelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ABA FRASES ÚTEIS
  // ==========================================

  Widget _buildPhrasesTab(List<TicunaPhrase> phrases, {required bool isDark}) {
    if (phrases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 54,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              const Text(
                'Nenhuma frase encontrada',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Toque em "+ Nova Frase" para cadastrar expressões do ministério.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: phrases.length,
      itemBuilder: (context, index) {
        final phrase = phrases[index];
        return _buildPhraseCard(phrase, isDark: isDark);
      },
    );
  }

  Widget _buildPhraseCard(TicunaPhrase item, {required bool isDark}) {
    final repo = ref.read(ticunaRepositoryProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topo da frase: Categoria e Ações
            Row(
              children: [
                if (item.category != null && item.category!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.category!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copiar frase Ticuna',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: item.phrase));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Frase copiada para a área de transferência!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    item.isFavorite ? Icons.star : Icons.star_border,
                    color: item.isFavorite ? Colors.amber : Colors.grey,
                  ),
                  onPressed: () => repo.togglePhraseFavorite(item.id),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showPhraseFormDialog(
                        context,
                        phraseToEdit: item,
                        allTags: ref.read(ticunaTagsStreamProvider).value ?? [],
                      );
                    } else if (val == 'delete') {
                      _confirmDeletePhrase(context, item);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Excluir', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Frase em Ticuna
            Text(
              item.phrase,
              style: TicunaUnicodeHelper.textStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D9488),
              ),
            ),

            if (item.phonetics != null && item.phonetics!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '[ ${item.phonetics} ]',
                style: TicunaUnicodeHelper.textStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Tradução em Português
            Text(
              item.translation,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            // Áudio de Pronúncia Ticuna da Frase
            TicunaAudioPlayerWidget(
              id: item.id,
              title: item.phrase,
              audioPath: item.audioPath,
              audioDurationSeconds: item.audioDurationSeconds,
              isPhrase: true,
              compact: true,
            ),

            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Nota: ${item.notes}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],

            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: item.tags.map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DIÁLOGO CADASTRO / EDIÇÃO DE TERMO
  // ==========================================

  void _showWordFormDialog(
    BuildContext context, {
    TicunaWord? wordToEdit,
    required List<TicunaTag> allTags,
    AppLanguageEntry? activeLang,
    List<String>? activeDiacritics,
  }) {
    final AppLanguageEntry lang =
        activeLang ?? ref.read(currentActiveLanguageProvider);
    final diacritics = activeDiacritics ?? parseLanguageDiacritics(lang.diacritics);

    String selectedClass = wordToEdit?.grammaticalClass ?? 'Substantivo';
    final selectedTags = List<String>.from(wordToEdit?.tags ?? []);
    final String targetId =
        wordToEdit?.id ?? 'word_${DateTime.now().millisecondsSinceEpoch}';
    String? formAudioPath = wordToEdit?.audioPath;
    int? formAudioDuration = wordToEdit?.audioDurationSeconds;
    int activeFieldIndex = 0;

    showDialog(
      context: context,
      builder: (dialogCtx) => ManagedTextControllers(
        initialTexts: [
          wordToEdit?.word ?? '',
          wordToEdit?.translation ?? '',
          wordToEdit?.phonetics ?? '',
          wordToEdit?.exampleSentence ?? '',
          wordToEdit?.exampleTranslation ?? '',
          wordToEdit?.notes ?? '',
        ],
        builder: (dialogCtx, ctrls) {
          final wordController = ctrls[0];
          final translationController = ctrls[1];
          final phoneticsController = ctrls[2];
          final exampleController = ctrls[3];
          final exampleTransController = ctrls[4];
          final notesController = ctrls[5];

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final activeController = ctrls[activeFieldIndex];
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.menu_book, color: Color(0xFF0D9488)),
                    const SizedBox(width: 8),
                    Text(
                      wordToEdit != null
                          ? (lang.id == 'tca' ? 'Editar Termo Ticuna' : 'Editar Termo (${lang.name})')
                          : (lang.id == 'tca' ? 'Novo Termo Ticuna' : 'Novo Termo (${lang.name})'),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // BARRA DE CARACTERES ESPECIAIS DO IDIOMA
                        if (diacritics.isNotEmpty) ...[
                          TicunaDiacriticsBar(
                            controller: activeController,
                            diacritics: diacritics,
                            label: 'Teclas Especiais (${lang.name}):',
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Termo no idioma
                        TextField(
                          controller: wordController,
                          autofocus: true,
                          style: TicunaUnicodeHelper.textStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          inputFormatters: const [TicunaInputFormatter()],
                          decoration: InputDecoration(
                            labelText: lang.id == 'tca'
                                ? 'Palavra ou Termo em Ticuna *'
                                : 'Palavra ou Termo (${lang.name}) *',
                            hintText: 'Ex: Taemãẽ, Tamaü, Tupana, Duü̃...',
                          ),
                          onTap: () => setDialogState(() => activeFieldIndex = 0),
                        ),
                        const SizedBox(height: 10),

                        // Tradução em Português
                        TextField(
                          controller: translationController,
                          decoration: const InputDecoration(
                            labelText: 'Tradução em Português *',
                            hintText: 'Ex: Obrigado, Olá, Deus, Pessoa...',
                          ),
                          onTap: () =>
                              setDialogState(() => activeFieldIndex = 1),
                        ),
                        const SizedBox(height: 10),

                        // Pronúncia / Fonética & Classe Gramatical
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: phoneticsController,
                                style: TicunaUnicodeHelper.textStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                inputFormatters: const [TicunaInputFormatter()],
                                decoration: const InputDecoration(
                                  labelText: 'Pronúncia / Tons (Opcional)',
                                  hintText: 'Ex: ta-e-mã-ẽ [tom alto]',
                                ),
                                onTap: () => setDialogState(
                                  () => activeFieldIndex = 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: selectedClass,
                                decoration: const InputDecoration(
                                  labelText: 'Classe',
                                ),
                                items: const [
                                  'Substantivo',
                                  'Verbo',
                                  'Adjetivo',
                                  'Advérbio',
                                  'Pronome',
                                  'Saudação',
                                  'Interjeição',
                                  'Outro',
                                ].map((c) {
                                  return DropdownMenuItem(value: c, child: Text(c));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => selectedClass = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Frase de Exemplo em Ticuna
                        TextField(
                          controller: exampleController,
                          style: TicunaUnicodeHelper.textStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          inputFormatters: const [TicunaInputFormatter()],
                          decoration: const InputDecoration(
                            labelText: 'Exemplo de Frase em Ticuna',
                            hintText: 'Ex: Taemãẽ Tupana',
                          ),
                          onTap: () =>
                              setDialogState(() => activeFieldIndex = 3),
                        ),
                        const SizedBox(height: 10),

                        // Tradução da Frase de Exemplo
                        TextField(
                          controller: exampleTransController,
                          decoration: const InputDecoration(
                            labelText: 'Tradução da Frase de Exemplo',
                            hintText: 'Ex: Muito obrigado a Deus',
                          ),
                          onTap: () => setDialogState(
                            () => activeFieldIndex = 4,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Observações / Contexto
                        TextField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Observações / Contexto Teocrático',
                            hintText: 'Ex: Usar com respeito ao falar sobre o Reino...',
                          ),
                          onTap: () =>
                              setDialogState(() => activeFieldIndex = 5),
                        ),
                    const SizedBox(height: 12),

                    // Pronúncia em Áudio Ticuna
                    const Text(
                      'Pronúncia em Áudio (Opcional):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TicunaAudioPlayerWidget(
                      id: targetId,
                      title: wordController.text.isNotEmpty
                          ? wordController.text
                          : 'Termo Ticuna',
                      audioPath: formAudioPath,
                      audioDurationSeconds: formAudioDuration,
                      isPhrase: false,
                      compact: false,
                      onAudioUpdated: (newPath, durationSeconds) {
                        setDialogState(() {
                          formAudioPath = newPath;
                          formAudioDuration = durationSeconds;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Seleção de Tags
                    const Text(
                      'Tags / Categorias:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: allTags.map((t) {
                        final isChosen = selectedTags.contains(t.name);
                        return FilterChip(
                          label: Text(t.name),
                          selected: isChosen,
                          selectedColor:
                              const Color(0xFF0D9488).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFF0D9488),
                          onSelected: (val) {
                            setDialogState(() {
                              if (val) {
                                selectedTags.add(t.name);
                              } else {
                                selectedTags.remove(t.name);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final word = wordController.text.trim();
                  final translation = translationController.text.trim();
                  if (word.isEmpty || translation.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Preencha ao menos o termo em Ticuna e a tradução.',
                        ),
                      ),
                    );
                    return;
                  }

                  final repo = ref.read(ticunaRepositoryProvider);
                  if (wordToEdit == null) {
                    await repo.addWord(
                      word: word,
                      translation: translation,
                      phonetics: phoneticsController.text.trim(),
                      grammaticalClass: selectedClass,
                      exampleSentence: exampleController.text.trim(),
                      exampleTranslation: exampleTransController.text.trim(),
                      notes: notesController.text.trim(),
                      tags: selectedTags,
                      audioPath: formAudioPath,
                      audioDurationSeconds: formAudioDuration,
                      languageId: lang.id,
                    );
                  } else {
                    await repo.updateWord(
                      wordToEdit.copyWith(
                        word: word,
                        translation: translation,
                        phonetics: phoneticsController.text.trim(),
                        grammaticalClass: selectedClass,
                        exampleSentence: exampleController.text.trim(),
                        exampleTranslation: exampleTransController.text.trim(),
                        notes: notesController.text.trim(),
                        tags: selectedTags,
                        audioPath: formAudioPath,
                        audioDurationSeconds: formAudioDuration,
                        updatedAt: DateTime.now(),
                      ),
                    );
                  }

                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Termo "$word" salvo com sucesso!'),
                      ),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      );
        },
      ),
    );
  }

  // ==========================================
  // DIÁLOGO CADASTRO / EDIÇÃO DE FRASE
  // ==========================================

  void _showPhraseFormDialog(
    BuildContext context, {
    TicunaPhrase? phraseToEdit,
    required List<TicunaTag> allTags,
    AppLanguageEntry? activeLang,
    List<String>? activeDiacritics,
  }) {
    final AppLanguageEntry lang =
        activeLang ?? ref.read(currentActiveLanguageProvider);
    final diacritics = activeDiacritics ?? parseLanguageDiacritics(lang.diacritics);

    String selectedCategory = phraseToEdit?.category ?? 'Ministério de Casa em Casa';
    final selectedTags = List<String>.from(phraseToEdit?.tags ?? []);
    final String targetId =
        phraseToEdit?.id ?? 'phrase_${DateTime.now().millisecondsSinceEpoch}';
    String? formAudioPath = phraseToEdit?.audioPath;
    int? formAudioDuration = phraseToEdit?.audioDurationSeconds;
    int activeFieldIndex = 0;

    showDialog(
      context: context,
      builder: (dialogCtx) => ManagedTextControllers(
        initialTexts: [
          phraseToEdit?.phrase ?? '',
          phraseToEdit?.translation ?? '',
          phraseToEdit?.phonetics ?? '',
          phraseToEdit?.notes ?? '',
        ],
        builder: (dialogCtx, ctrls) {
          final phraseController = ctrls[0];
          final translationController = ctrls[1];
          final phoneticsController = ctrls[2];
          final notesController = ctrls[3];

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final activeController = ctrls[activeFieldIndex];
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.forum_outlined, color: Color(0xFF0D9488)),
                    const SizedBox(width: 8),
                    Text(
                      phraseToEdit != null
                          ? (lang.id == 'tca' ? 'Editar Frase Útil Ticuna' : 'Editar Frase Útil (${lang.name})')
                          : (lang.id == 'tca' ? 'Nova Frase Útil Ticuna' : 'Nova Frase Útil (${lang.name})'),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // BARRA DE CARACTERES ESPECIAIS DO IDIOMA
                        if (diacritics.isNotEmpty) ...[
                          TicunaDiacriticsBar(
                            controller: activeController,
                            diacritics: diacritics,
                            label: 'Teclas Especiais (${lang.name}):',
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Frase no idioma
                        TextField(
                          controller: phraseController,
                          autofocus: true,
                          maxLines: 2,
                          style: TicunaUnicodeHelper.textStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          inputFormatters: const [TicunaInputFormatter()],
                          decoration: InputDecoration(
                            labelText: lang.id == 'tca'
                                ? 'Frase em Ticuna *'
                                : 'Frase em ${lang.name} *',
                            hintText: 'Ex: Tamaü! Ku meã pe\'ĩ?',
                          ),
                          onTap: () =>
                              setDialogState(() => activeFieldIndex = 0),
                        ),
                        const SizedBox(height: 10),

                        // Tradução em Português
                        TextField(
                          controller: translationController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Tradução em Português *',
                            hintText: 'Ex: Olá! Você está bem?',
                          ),
                          onTap: () => setDialogState(
                            () => activeFieldIndex = 1,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Categoria da Frase
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Tópico / Categoria de Ministério',
                          ),
                          items: const [
                            'Saudação & Conversa',
                            'Ministério de Casa em Casa',
                            'Leitura Bíblica',
                            'Perguntas de Ponto de Vista',
                            'Oferecer Estudo',
                            'Revisita',
                            'Despedida & Gratidão',
                            'Outra',
                          ].map((c) {
                            return DropdownMenuItem(value: c, child: Text(c));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedCategory = val);
                            }
                          },
                        ),
                        const SizedBox(height: 10),

                        // Pronúncia sugerida
                        TextField(
                          controller: phoneticsController,
                          style: TicunaUnicodeHelper.textStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          inputFormatters: const [TicunaInputFormatter()],
                          decoration: const InputDecoration(
                            labelText: 'Pronúncia / Guia de Tons (Opcional)',
                            hintText: 'Ex: ta-ma-ü! ku me-ã pe-ĩ?',
                          ),
                          onTap: () => setDialogState(
                            () => activeFieldIndex = 2,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Observações / Texto Bíblico
                        TextField(
                          controller: notesController,
                          decoration: const InputDecoration(
                            labelText: 'Observação / Texto Bíblico de Referência',
                            hintText: 'Ex: Usar com Salmo 37:29...',
                          ),
                          onTap: () =>
                              setDialogState(() => activeFieldIndex = 3),
                        ),
                    const SizedBox(height: 12),

                    // Pronúncia em Áudio Ticuna
                    const Text(
                      'Pronúncia em Áudio (Opcional):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TicunaAudioPlayerWidget(
                      id: targetId,
                      title: phraseController.text.isNotEmpty
                          ? phraseController.text
                          : 'Frase Ticuna',
                      audioPath: formAudioPath,
                      audioDurationSeconds: formAudioDuration,
                      isPhrase: true,
                      compact: false,
                      onAudioUpdated: (newPath, durationSeconds) {
                        setDialogState(() {
                          formAudioPath = newPath;
                          formAudioDuration = durationSeconds;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Tags
                    const Text(
                      'Tags / Marcadores:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: allTags.map((t) {
                        final isChosen = selectedTags.contains(t.name);
                        return FilterChip(
                          label: Text(t.name),
                          selected: isChosen,
                          selectedColor:
                              const Color(0xFF0D9488).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFF0D9488),
                          onSelected: (val) {
                            setDialogState(() {
                              if (val) {
                                selectedTags.add(t.name);
                              } else {
                                selectedTags.remove(t.name);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final phrase = phraseController.text.trim();
                  final translation = translationController.text.trim();
                  if (phrase.isEmpty || translation.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Preencha a frase e sua tradução.'),
                      ),
                    );
                    return;
                  }

                  final repo = ref.read(ticunaRepositoryProvider);
                  if (phraseToEdit == null) {
                    await repo.addPhrase(
                      phrase: phrase,
                      translation: translation,
                      category: selectedCategory,
                      phonetics: phoneticsController.text.trim(),
                      notes: notesController.text.trim(),
                      tags: selectedTags,
                      audioPath: formAudioPath,
                      audioDurationSeconds: formAudioDuration,
                      languageId: lang.id,
                    );
                  } else {
                    await repo.updatePhrase(
                      phraseToEdit.copyWith(
                        phrase: phrase,
                        translation: translation,
                        category: selectedCategory,
                        phonetics: phoneticsController.text.trim(),
                        notes: notesController.text.trim(),
                        tags: selectedTags,
                        audioPath: formAudioPath,
                        audioDurationSeconds: formAudioDuration,
                        updatedAt: DateTime.now(),
                      ),
                    );
                  }

                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Frase salva com sucesso!'),
                      ),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      );
        },
      ),
    );
  }

  // ==========================================
  // FLASHCARD STUDY MODE (ANKIDROID STYLE)
  // ==========================================

  void _showFlashcardStudyModal(
    BuildContext context,
    List<TicunaWord> wordsToStudy,
  ) {
    int currentIndex = 0;
    bool isAnswerRevealed = false;
    final repo = ref.read(ticunaRepositoryProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (studyCtx) => StatefulBuilder(
        builder: (ctx, setStudyState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          if (currentIndex >= wordsToStudy.length) {
            // Sessão de estudo concluída!
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.celebration, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Sessão Concluída!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Parabéns! Você revisou todos os cartões desta rodada.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Total revisado: ${wordsToStudy.length} palavras.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(studyCtx),
                  child: const Text('Concluir'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setStudyState(() {
                      currentIndex = 0;
                      isAnswerRevealed = false;
                    });
                  },
                  child: const Text('Revisar Novamente'),
                ),
              ],
            );
          }

          final word = wordsToStudy[currentIndex];

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school, color: Color(0xFF0D9488)),
                    const SizedBox(width: 8),
                    Text('Cartão ${currentIndex + 1} de ${wordsToStudy.length}'),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(studyCtx),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Barra de progresso
                    LinearProgressIndicator(
                      value: (currentIndex + 1) / wordsToStudy.length,
                      backgroundColor: Colors.grey.shade300,
                      color: const Color(0xFF0D9488),
                    ),
                    const SizedBox(height: 18),

                    // FRENTE DO CARTÃO (Termo Ticuna)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            word.word,
                            textAlign: TextAlign.center,
                            style: TicunaUnicodeHelper.textStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0D9488),
                            ),
                          ),
                          if (word.audioPath != null && word.audioPath!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            TicunaAudioPlayerWidget(
                              id: word.id,
                              title: word.word,
                              audioPath: word.audioPath,
                              audioDurationSeconds: word.audioDurationSeconds,
                              compact: true,
                            ),
                          ],
                          if (word.phonetics != null && word.phonetics!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              '[ ${word.phonetics} ]',
                              style: TicunaUnicodeHelper.textStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                          if (word.grammaticalClass != null &&
                              word.grammaticalClass!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                word.grammaticalClass!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D9488),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // VERSO DO CARTÃO (Tradução e Exemplos)
                    if (!isAnswerRevealed) ...[
                      const Text(
                        'Pense no significado e toque em "Mostrar Resposta":',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.visibility),
                        label: const Text(
                          'Mostrar Resposta',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          setStudyState(() => isAnswerRevealed = true);
                        },
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.amber.shade50.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tradução em Português:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              word.translation,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (word.exampleSentence != null &&
                                word.exampleSentence!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              const Divider(),
                              Text(
                                'Exemplo: "${word.exampleSentence}"',
                                style: TicunaUnicodeHelper.textStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0D9488),
                                ),
                              ),
                              if (word.exampleTranslation != null &&
                                  word.exampleTranslation!.isNotEmpty)
                                Text(
                                  '→ ${word.exampleTranslation}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                            if (word.notes != null && word.notes!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Nota: ${word.notes}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Como foi sua lembrança? (Avaliação Anki)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),

                      // Botões de Classificação Anki (Errei, Bom, Fácil)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () async {
                                await repo.recordWordReview(word.id, 1);
                                setStudyState(() {
                                  currentIndex++;
                                  isAnswerRevealed = false;
                                });
                              },
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Errei',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text('De novo', style: TextStyle(fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9488),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () async {
                                await repo.recordWordReview(word.id, 2);
                                setStudyState(() {
                                  currentIndex++;
                                  isAnswerRevealed = false;
                                });
                              },
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Bom',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text('+1 nível', style: TextStyle(fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green,
                                side: const BorderSide(color: Colors.green),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () async {
                                await repo.recordWordReview(word.id, 3);
                                setStudyState(() {
                                  currentIndex++;
                                  isAnswerRevealed = false;
                                });
                              },
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Fácil',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text('+2 níveis', style: TextStyle(fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // MODAL DE IMPORTAÇÃO E EXPORTAÇÃO
  // ==========================================

  void _showImportExportModal(BuildContext context) {
    final repo = ref.read(ticunaRepositoryProvider);
    bool replaceExisting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => ManagedTextControllers(
        initialTexts: const [''],
        builder: (sheetCtx, ctrls) {
          final jsonController = ctrls[0];
          return SafeArea(
            child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.import_export, color: Color(0xFF0D9488)),
                            SizedBox(width: 8),
                            Text(
                              'Importar / Exportar Ticuna',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // SEÇÃO DE EXPORTAÇÃO
                    const Text(
                      'Exportar Banco de Dados:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Exportar JSON Completo'),
                            onPressed: () async {
                              final jsonStr = await repo.exportToJson();
                              await Clipboard.setData(ClipboardData(text: jsonStr));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Banco Ticuna copiado em formato JSON para a área de transferência!',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.table_chart, size: 16),
                            label: const Text('Copiar CSV Dicionário'),
                            onPressed: () async {
                              final csv = await repo.exportToCsv(TicunaEntryType.word);
                              await Clipboard.setData(ClipboardData(text: csv));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('CSV do Dicionário copiado!'),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.table_chart, size: 16),
                            label: const Text('Copiar CSV Frases'),
                            onPressed: () async {
                              final csv = await repo.exportToCsv(TicunaEntryType.phrase);
                              await Clipboard.setData(ClipboardData(text: csv));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('CSV de Frases copiado!'),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 28),

                    // SEÇÃO DE IMPORTAÇÃO
                    const Text(
                      'Importar Banco de Dados (JSON / Backup ou CSV):',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: jsonController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText:
                            'Cole aqui o conteúdo JSON de backup ou linhas em CSV (palavras/frases)...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Substituir dados atuais (se desmarcado, mescla)',
                        style: TextStyle(fontSize: 12.5),
                      ),
                      value: replaceExisting,
                      onChanged: (val) {
                        setSheetState(() => replaceExisting = val ?? false);
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.file_download),
                        label: const Text('Importar Agora'),
                        onPressed: () async {
                          final text = jsonController.text.trim();
                          if (text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cole o JSON ou CSV para importar.'),
                              ),
                            );
                            return;
                          }

                          final result = await repo.importAuto(
                            text,
                            replace: replaceExisting,
                            defaultType: _tabController.index == 0
                                ? TicunaEntryType.word
                                : TicunaEntryType.phrase,
                          );

                          if (result.success) {
                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Sucesso! Importados: ${result.wordsCount} palavras, ${result.phrasesCount} frases e ${result.tagsCount} tags.',
                                  ),
                                ),
                              );
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.red,
                                  content: Text('Erro ao importar: ${result.errorMessage}'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
        },
      ),
    );
  }

  // ==========================================
  // MODAL DE GERENCIAMENTO DE TAGS
  // ==========================================

  void _showManageTagsModal(BuildContext context, List<TicunaTag> tags) {
    final repo = ref.read(ticunaRepositoryProvider);

    showDialog(
      context: context,
      builder: (tagCtx) => ManagedTextControllers(
        initialTexts: const [''],
        builder: (tagCtx, ctrls) {
          final newTagController = ctrls[0];

          return StatefulBuilder(
            builder: (ctx, setTagState) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.label, color: Color(0xFF0D9488)),
                    SizedBox(width: 8),
                    Text('Gerenciar Tags Ticuna'),
                  ],
                ),
                content: SizedBox(
                  width: 400,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: newTagController,
                                decoration: const InputDecoration(
                                  labelText: 'Nova Tag',
                                  hintText: 'Ex: Animais, Alimentos, Oração...',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9488),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                final name = newTagController.text.trim();
                                if (name.isNotEmpty) {
                                  await repo.addTag(name);
                                  newTagController.clear();
                                  if (tagCtx.mounted) Navigator.pop(tagCtx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Tag "$name" adicionada!')),
                                    );
                                  }
                                }
                              },
                              child: const Text('Adicionar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const Text(
                          'Tags Cadastradas:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...tags.map((t) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.label_outline,
                              size: 18,
                              color: Color(0xFF0D9488),
                            ),
                            title: Text(t.name),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () async {
                                await repo.deleteTag(t.id);
                                if (tagCtx.mounted) Navigator.pop(tagCtx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Tag "${t.name}" removida!')),
                                  );
                                }
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(tagCtx),
                    child: const Text('Fechar'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDeleteWord(BuildContext context, TicunaWord word) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Termo'),
        content: Text('Deseja excluir a palavra "${word.word}" do dicionário?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(ticunaRepositoryProvider).deleteWord(word.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Termo "${word.word}" excluído.')),
                );
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePhrase(BuildContext context, TicunaPhrase phrase) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Frase'),
        content: const Text('Deseja realmente excluir esta frase útil?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(ticunaRepositoryProvider).deletePhrase(phrase.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Frase excluída.')),
                );
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // GESTÃO DINÂMICA DE IDIOMAS (DRIFT REGRA 11)
  // ==========================================

  void _showLanguageSelectorModal(
    BuildContext context,
    List<AppLanguageEntry> languages,
    AppLanguageEntry currentLang,
  ) {
    showAdaptiveMinistrySheet(
      context: context,
      title: 'Idiomas do Ministério',
      subtitle: 'Selecione o idioma ativo ou cadastre um novo',
      titleLeading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0D9488).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('🏹', style: TextStyle(fontSize: 22)),
      ),
      builder: (ctx, scrollController) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return ListView(
          controller: scrollController,
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(
                  '+ Novo Idioma',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAddLanguageDialog(context);
                },
              ),
            ),
            const Divider(),
            ...languages.map((lang) {
              final isCurrent = lang.id == currentLang.id;
              final diacriticsList = parseLanguageDiacritics(lang.diacritics);
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF0D9488).withValues(alpha: isDark ? 0.2 : 0.1)
                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrent
                        ? const Color(0xFF0D9488)
                        : (isDark ? Colors.white12 : Colors.grey.shade300),
                    width: isCurrent ? 1.5 : 1.0,
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.15),
                    child: Text(
                      lang.symbol,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        lang.name,
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      if (lang.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Padrão',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${lang.code.toUpperCase()} • ${diacriticsList.isNotEmpty ? "${diacriticsList.length} caracteres especiais" : "Sem diacríticos"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCurrent)
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF0D9488),
                          size: 24,
                        ),
                      if (!lang.isDefault && !isCurrent)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          tooltip: 'Excluir idioma',
                          onPressed: () => _confirmDeleteLanguage(context, lang),
                        ),
                    ],
                  ),
                  onTap: () {
                    ref.read(activeLanguageProvider.notifier).selectLanguage(lang);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Idioma ativo: ${lang.symbol} ${lang.name}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _showAddLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => ManagedTextControllers(
        initialTexts: const ['', '', '', ''],
        builder: (dialogCtx, ctrls) {
          final nameCtrl = ctrls[0];
          final codeCtrl = ctrls[1];
          final symbolCtrl = ctrls[2];
          final diacriticsCtrl = ctrls[3];

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              void applyPreset(LanguageMetadata preset) {
                setDialogState(() {
                  nameCtrl.text = '${preset.name} (${preset.nativeName})';
                  codeCtrl.text = preset.code;
                  symbolCtrl.text = preset.symbol;
                  diacriticsCtrl.text = preset.diacritics.join(', ');
                });
              }

              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.add_circle, color: Color(0xFF0D9488)),
                    SizedBox(width: 8),
                    Text('+ Novo Idioma no Drift'),
                  ],
                ),
                content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Atalhos Pré-Catalogados (1-Toque):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ActionChip(
                              avatar: const Text('🌿'),
                              label: const Text('Guajajara (Tenetehara)'),
                              onPressed: () => applyPreset(LanguageRegistry.guajajara),
                            ),
                            ActionChip(
                              avatar: const Text('🌳'),
                              label: const Text('Yanomami (Yanomamõ)'),
                              onPressed: () => applyPreset(LanguageRegistry.yanomami),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome do Idioma *',
                            hintText: 'Ex: Guajajara, Yanomami, Wapichana',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: codeCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Código ISO *',
                                  hintText: 'Ex: gub, yan',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: symbolCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Símbolo / Emoji',
                                  hintText: 'Ex: 🌿',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: diacriticsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Caracteres Especiais / Diacríticos (separados por vírgula)',
                            hintText: 'Ex: à, è, ì, ò, ù, ỹ, \'',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final code = codeCtrl.text.trim().toLowerCase();
                      final symbol = symbolCtrl.text.trim().isEmpty ? '🌐' : symbolCtrl.text.trim();
                      final diacriticsText = diacriticsCtrl.text.trim();

                      if (name.isEmpty || code.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Preencha o nome e o código do idioma.'),
                          ),
                        );
                        return;
                      }

                      final messenger = ScaffoldMessenger.of(context);
                      final dialogNav = Navigator.of(dialogCtx);
                      final repo = ref.read(repositoryProvider);
                      await repo.createLanguage(
                        id: code,
                        name: name,
                        code: code,
                        symbol: symbol,
                        diacritics: diacriticsText.isNotEmpty ? diacriticsText : null,
                        isDefault: false,
                      );

                      final newEntry = AppLanguageEntry(
                        id: code,
                        name: name,
                        code: code,
                        symbol: symbol,
                        diacritics: diacriticsText,
                        isDefault: false,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      await ref.read(activeLanguageProvider.notifier).selectLanguage(newEntry);

                      dialogNav.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Idioma "$symbol $name" criado e ativado com sucesso!'),
                        ),
                      );
                    },
                    child: const Text('Cadastrar Idioma'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDeleteLanguage(BuildContext context, AppLanguageEntry lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Idioma?'),
        content: Text('Deseja excluir "${lang.symbol} ${lang.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final dialogNav = Navigator.of(ctx);
              final sheetNav = Navigator.of(context);
              await ref.read(repositoryProvider).deleteLanguage(lang.id);
              final current = ref.read(activeLanguageProvider);
              if (current?.id == lang.id) {
                ref.read(activeLanguageProvider.notifier).state = null;
              }
              dialogNav.pop();
              sheetNav.pop();
              messenger.showSnackBar(
                SnackBar(content: Text('Idioma ${lang.name} removido.')),
              );
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
