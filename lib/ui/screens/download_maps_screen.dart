import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/app_logger.dart';
import '../../core/app_theme.dart';
import '../../territory/mbtiles/mbtiles_service.dart';
import '../widgets/managed_text_controllers.dart';
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
    MBTilesService.instance.init().catchError((Object e, StackTrace st) {
      AppLogger.warning('Falha ao inicializar mapas offline.', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível acessar os mapas offline.')),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _importLocalMbtilesFile({String? targetRegionId}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (kIsWeb) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Importação de arquivos .mbtiles locais requer o aplicativo Desktop ou Mobile (iOS/Android).',
          ),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    try {
      final res = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (res.isEmpty) return;

      final picked = res.first;
      final path = picked.path;
      if (path == null || path.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Não foi possível acessar o caminho do arquivo selecionado.'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
        return;
      }

      if (!picked.name.toLowerCase().endsWith('.mbtiles')) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Selecione um arquivo válido com extensão .mbtiles.'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
        return;
      }

      final installed = await MBTilesService.instance.importLocalMbtiles(
        regionId: targetRegionId,
        sourceFilePath: path,
      );
      if (mounted) {
        setState(() {});
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Pacote "${installed.name}" (${installed.formattedSize}) validado (SQLite + tiles) e instalado!',
            ),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao importar arquivo .mbtiles local', e, st);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Arquivo .mbtiles inválido ou erro na importação: $e'),
            backgroundColor: AppTheme.alertRed,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _showBaseCatalogUrlDialog() async {
    final initial = MBTilesService.instance.customBaseUrl ?? '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: [initial],
        builder: (ctx, ctrls) {
          final urlCtrl = ctrls[0];
          String? errorText;
          return StatefulBuilder(
            builder: (ctx, setDlgState) => AlertDialog(
              title: const Text('URL Base do Catálogo .mbtiles'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'O catálogo padrão aponta para releases/download/mbtiles-v1/<id>.mbtiles. '
                    'Configure abaixo uma URL base própria (ex: https://cdn.seudominio.org/mbtiles) ou deixe em branco para restaurar o padrão.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtrl,
                    decoration: InputDecoration(
                      labelText: 'URL Base (https://...)',
                      hintText: 'https://servidor.exemplo/mbtiles',
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await MBTilesService.instance.setBaseCatalogUrl(null);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) setState(() {});
                  },
                  child: const Text('Restaurar Padrão'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await MBTilesService.instance.setBaseCatalogUrl(urlCtrl.text);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('URL base de mapas offline salva localmente.'),
                            backgroundColor: AppTheme.successGreen,
                          ),
                        );
                      }
                    } catch (e) {
                      setDlgState(() => errorText = e.toString());
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showRegionCustomUrlDialog(MBTileRegion region) async {
    final initial = MBTilesService.instance.getRegionCustomUrl(region.id) ?? '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: [initial],
        builder: (ctx, ctrls) {
          final urlCtrl = ctrls[0];
          String? errorText;
          return StatefulBuilder(
            builder: (ctx, setDlgState) => AlertDialog(
              title: Text('URL de "${region.name}"'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'URL efetiva atual:\n${MBTilesService.instance.resolveDownloadUrl(region)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtrl,
                    decoration: InputDecoration(
                      labelText: 'URL direta do arquivo .mbtiles',
                      hintText: 'https://servidor.exemplo/${region.id}.mbtiles',
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _importLocalMbtilesFile(targetRegionId: region.id);
                  },
                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                  label: const Text('Importar arquivo'),
                ),
                TextButton(
                  onPressed: () async {
                    await MBTilesService.instance.setRegionCustomUrl(region.id, null);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) setState(() {});
                  },
                  child: const Text('Usar Padrão'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await MBTilesService.instance.setRegionCustomUrl(
                        region.id,
                        urlCtrl.text,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('URL personalizada salva para "${region.name}".'),
                            backgroundColor: AppTheme.successGreen,
                          ),
                        );
                      }
                    } catch (e) {
                      setDlgState(() => errorText = e.toString());
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            ),
          );
        },
      ),
    );
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
              IconButton(
                tooltip: 'Importar arquivo .mbtiles local',
                icon: const Icon(Icons.file_upload_outlined),
                onPressed: () => _importLocalMbtilesFile(),
              ),
              IconButton(
                tooltip: 'Configurar URL base de catálogo .mbtiles',
                icon: const Icon(Icons.link_rounded),
                onPressed: _showBaseCatalogUrlDialog,
              ),
              if (installedRegions.isNotEmpty)
                TextButton.icon(
                  onPressed: _isUpdatingAll
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          setState(() => _isUpdatingAll = true);
                          final failed = await MBTilesService.instance.updateAll(
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
                            if (failed.isEmpty) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Todos os mapas foram atualizados com sucesso!'),
                                  backgroundColor: AppTheme.successGreen,
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Falha ao atualizar ${failed.length} mapa(s): ${failed.join(", ")}',
                                  ),
                                  backgroundColor: AppTheme.alertRed,
                                ),
                              );
                            }
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
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'A disponibilidade do catálogo padrão não é garantida. '
                  'Para uso offline, importe um arquivo MBTiles raster licenciado '
                  'com cobertura e níveis de zoom da sua área e teste sem internet.',
                ),
              ),
              // Campo de busca: Localizar mapa
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    TextField(
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _importLocalMbtilesFile(),
                          icon: const Icon(Icons.folder_open_outlined, size: 16),
                          label: const Text('Importar .mbtiles local', style: TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton.icon(
                          onPressed: _showBaseCatalogUrlDialog,
                          icon: const Icon(Icons.settings_ethernet_rounded, size: 16),
                          label: Text(
                            MBTilesService.instance.customBaseUrl != null
                                ? 'URL Base Personalizada'
                                : 'Configurar URL Catálogo',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                    // Seção: Baixado (X MB) — Estilo Orgânico com contagem de regiões
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
                      // Card resumo do País no topo com total de mapas instalados (ex: Brasil 1 de 23)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.sync_rounded, color: Colors.amber),
                          ),
                          title: const Text(
                            'Brasil',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(
                            'Mapas: ${installedRegions.length} de ${allRegions.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          trailing: Text(
                            MBTilesService.instance.formattedTotalDownloadedSize,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentTeal,
                              fontSize: 13,
                            ),
                          ),
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
          bottomNavigationBar: installedRegions.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Atualizar mapas',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${MBTilesService.instance.formattedTotalDownloadedSize} instalados',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _isUpdatingAll
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  setState(() => _isUpdatingAll = true);
                                  final failed = await MBTilesService.instance.updateAll(
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
                                    if (failed.isEmpty) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Todos os mapas foram atualizados com sucesso!'),
                                          backgroundColor: AppTheme.successGreen,
                                        ),
                                      );
                                    } else {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Falha ao atualizar ${failed.length} mapa(s): ${failed.join(", ")}',
                                          ),
                                          backgroundColor: AppTheme.alertRed,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: _isUpdatingAll
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.sync_rounded, size: 16),
                          label: Text(_isUpdatingAll ? 'Atualizando...' : 'Atualizar tudo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentTeal,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
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
    final isDownloading = MBTilesService.instance.isDownloading(region.id) ||
        (region.downloadProgress > 0.0 && region.downloadProgress < 1.0);

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
                        '${region.country} > ${region.state} • ${region.formattedSize}'
                        '${MBTilesService.instance.getRegionCustomUrl(region.id) != null ? " • URL personalizada" : ""}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opções do pacote',
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (choice) {
                    if (choice == 'custom_url') {
                      _showRegionCustomUrlDialog(region);
                    } else if (choice == 'import_local') {
                      _importLocalMbtilesFile(targetRegionId: region.id);
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                      value: 'import_local',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.file_upload_outlined, size: 18),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Importar .mbtiles local',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'custom_url',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link_rounded, size: 18),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'URL personalizada',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isDownloading)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: AppTheme.alertRed),
                        tooltip: 'Cancelar download',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => MBTilesService.instance.cancelDownload(region.id),
                      ),
                    ],
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
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await MBTilesService.instance.downloadRegion(region.id);
                        if (context.mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Mapa "${region.name}" instalado com sucesso!'),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Erro ao baixar "${region.name}": $e'),
                              backgroundColor: AppTheme.alertRed,
                              duration: const Duration(seconds: 6),
                              action: SnackBarAction(
                                label: 'URL / Importar',
                                textColor: Colors.white,
                                onPressed: () => _showRegionCustomUrlDialog(region),
                              ),
                            ),
                          );
                        }
                      }
                    },
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
