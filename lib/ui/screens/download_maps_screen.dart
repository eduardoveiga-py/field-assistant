import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../territory/mbtiles/mbtiles_service.dart';
import '../widgets/screen_hero_accent_band.dart';

class DownloadMapsScreen extends StatefulWidget {
  const DownloadMapsScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DownloadMapsScreen(),
      ),
    );
  }

  @override
  State<DownloadMapsScreen> createState() => _DownloadMapsScreenState();
}

class _DownloadMapsScreenState extends State<DownloadMapsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isUpdatingAll = false;
  String? _updatingRegionName;

  @override
  void initState() {
    super.initState();
    MBTilesService.instance.init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<MBTileRegion>>(
      stream: MBTilesService.instance.regionsStream,
      initialData: MBTilesService.instance.currentRegions,
      builder: (context, snapshot) {
        final allRegions = snapshot.data ?? MBTilesService.instance.currentRegions;
        final query = _searchController.text.trim().toLowerCase();

        final filteredRegions = allRegions.where((r) {
          if (query.isEmpty) return true;
          return r.name.toLowerCase().contains(query) ||
              r.state.toLowerCase().contains(query) ||
              r.country.toLowerCase().contains(query) ||
              r.description.toLowerCase().contains(query);
        }).toList();

        final installedRegions = filteredRegions.where((r) => r.isInstalled).toList();
        final availableRegions = filteredRegions.where((r) => !r.isInstalled).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Baixar Mapas',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              if (installedRegions.isNotEmpty)
                TextButton.icon(
                  onPressed: _isUpdatingAll
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          setState(() => _isUpdatingAll = true);
                          await MBTilesService.instance.updateAll(
                            onProgress: (name, p) {
                              if (mounted) {
                                setState(() => _updatingRegionName = name);
                              }
                            },
                          );
                          if (mounted) {
                            setState(() {
                              _isUpdatingAll = false;
                              _updatingRegionName = null;
                            });
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Todos os mapas foram atualizados com sucesso!'),
                                backgroundColor: AppTheme.successGreen,
                              ),
                            );
                          }
                        },
                  icon: _isUpdatingAll
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(
                    _isUpdatingAll
                        ? 'Atualizando...'
                        : 'Atualizar tudo',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              ScreenHeroAccentBand.territory(),
              // Campo de busca: Localizar mapa
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Localizar mapa',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              if (_isUpdatingAll && _updatingRegionName != null)
                Container(
                  width: double.infinity,
                  color: AppTheme.accentTeal.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Atualizando: $_updatingRegionName...',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    // Seção: Baixado (X MB)
                    if (installedRegions.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Text(
                              'Baixado (${MBTilesService.instance.formattedTotalDownloadedSize})',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.offline_pin,
                              color: AppTheme.accentTeal,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      ...installedRegions.map((r) => _buildInstalledRegionCard(r, isDark)),
                      const SizedBox(height: 16),
                    ],

                    // Seção: Catálogo Disponível
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Mapas Regionais Disponíveis',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    if (availableRegions.isEmpty && installedRegions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(
                          child: Text('Nenhum mapa encontrado com este nome.'),
                        ),
                      )
                    else if (availableRegions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            'Todos os pacotes regionais catalogados já estão instalados!',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      )
                    else
                      ...availableRegions.map((r) => _buildAvailableRegionCard(r, isDark)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstalledRegionCard(MBTileRegion region, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.accentTeal.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.map_outlined, color: AppTheme.accentTeal),
        ),
        title: Text(
          region.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${region.country} > ${region.state} • ${region.formattedSize}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            if (region.downloadProgress > 0 && region.downloadProgress < 1.0) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: region.downloadProgress,
                color: AppTheme.accentTeal,
                backgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
              ),
            ],
          ],
        ),
        trailing: IconButton(
          tooltip: 'Excluir mapa baixado',
          icon: Icon(
            Icons.delete_outline,
            color: Colors.red.shade400,
            size: 20,
          ),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Excluir Mapa Offline?'),
                content: Text(
                  'Deseja remover o pacote "${region.name}" (${region.formattedSize}) do dispositivo?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await MBTilesService.instance.deleteRegion(region.id);
            }
          },
        ),
      ),
    );
  }

  Widget _buildAvailableRegionCard(MBTileRegion region, bool isDark) {
    final isDownloading = region.downloadProgress > 0.0 && region.downloadProgress < 1.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        region.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${region.country} > ${region.state} • ${region.formattedSize}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDownloading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => MBTilesService.instance.downloadRegion(region.id),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Baixar', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              region.description,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            if (isDownloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: region.downloadProgress,
                color: AppTheme.accentTeal,
                backgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(region.sizeBytes * region.downloadProgress / (1024 * 1024)).toStringAsFixed(1)} MB de ${region.formattedSize}',
                    style: const TextStyle(fontSize: 10),
                  ),
                  Text(
                    '${(region.downloadProgress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentTeal,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
