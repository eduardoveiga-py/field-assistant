import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../database/app_database.dart';
import '../../../territory/geocoding/offline_geocoding_service.dart';

/// Modal bottom sheet para busca geográfica e de entidades 100% offline no mapa.
///
/// Utiliza o índice SQLite FTS5 com tokenizer `unicode61 remove_diacritics 2`,
/// garantindo correspondência tolerante a acentos para o português e diacríticos Ticuna.
class OfflineSearchModal extends StatefulWidget {
  final AppDatabase? db;
  final void Function(LocalSearchResult result) onSelectResult;

  const OfflineSearchModal({
    super.key,
    required this.db,
    required this.onSelectResult,
  });

  /// Exibe o modal na árvore de widgets.
  static Future<void> show(
    BuildContext context, {
    required AppDatabase? db,
    required void Function(LocalSearchResult result) onSelectResult,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          OfflineSearchModal(db: db, onSelectResult: onSelectResult),
    );
  }

  @override
  State<OfflineSearchModal> createState() => _OfflineSearchModalState();
}

class _OfflineSearchModalState extends State<OfflineSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  List<LocalSearchResult> _results = [];
  bool _isLoading = false;
  String _selectedFilter = 'Todos'; // 'Todos', 'Contatos', 'Marcos', 'Setores'
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), _executeSearch);
  }

  Future<void> _executeSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    final rawResults = await OfflineGeocodingService.searchOffline(
      query: query,
      db: widget.db,
    );

    if (mounted) {
      setState(() {
        _results = rawResults;
        _isLoading = false;
      });
    }
  }

  List<LocalSearchResult> get _filteredResults {
    if (_selectedFilter == 'Todos') return _results;
    if (_selectedFilter == 'Contatos') {
      return _results.where((r) => r.type == LocalResultType.contact).toList();
    }
    if (_selectedFilter == 'Marcos') {
      return _results.where((r) => r.type == LocalResultType.landmark).toList();
    }
    if (_selectedFilter == 'Setores') {
      return _results.where((r) => r.type == LocalResultType.sector).toList();
    }
    return _results;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.travel_explore, color: AppTheme.primaryTeal),
                const SizedBox(width: 8),
                Text(
                  'Buscar no Território (Offline)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Digite contato, rua, marco ou aldeia...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _results = []);
                        },
                      )
                    : null,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('Todos', Icons.dashboard_outlined),
                const SizedBox(width: 8),
                _buildFilterChip('Contatos', Icons.people_outline),
                const SizedBox(width: 8),
                _buildFilterChip('Marcos', Icons.place_outlined),
                const SizedBox(width: 8),
                _buildFilterChip('Setores', Icons.map_outlined),
              ],
            ),
          ),

          const Divider(height: 16),

          // Results list or Empty states
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchController.text.isEmpty
                ? _buildInitialState(theme)
                : _filteredResults.isEmpty
                ? _buildEmptyState(theme)
                : _buildResultsList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : null),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedFilter = label);
      },
      selectedColor: AppTheme.primaryTeal,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildInitialState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 48,
              color: theme.hintColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Busca 100% Offline',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pesquise contatos, endereços, marcos territoriais e setores mesmo em modo avião ou sem sinal de celular.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sentiment_dissatisfied_outlined,
              size: 48,
              color: theme.hintColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhum resultado encontrado',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Não localizamos registros com "${_searchController.text}". Verifique a grafia ou o filtro selecionado.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(ThemeData theme) {
    final list = _filteredResults;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = list[index];
        IconData itemIcon;
        Color iconColor;

        switch (item.type) {
          case LocalResultType.contact:
            itemIcon = Icons.person_pin_circle;
            iconColor = AppTheme.primaryTeal;
            break;
          case LocalResultType.landmark:
            itemIcon = Icons.place;
            iconColor = Colors.orange;
            break;
          case LocalResultType.sector:
            itemIcon = Icons.crop_free;
            iconColor = Colors.purple;
            break;
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          leading: CircleAvatar(
            backgroundColor: iconColor.withValues(alpha: 0.15),
            child: Icon(itemIcon, color: iconColor),
          ),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: item.subtitle != null
              ? Text(
                  item.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: item.hasCoordinates
              ? Tooltip(
                  message: 'Localização disponível no mapa',
                  child: Icon(
                    Icons.navigation_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                )
              : null,
          onTap: () {
            Navigator.pop(context);
            widget.onSelectResult(item);
          },
        );
      },
    );
  }
}
