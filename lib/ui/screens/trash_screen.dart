import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../providers.dart';

class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registros Excluídos (Lixeira)'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.getDeletedItems(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_sweep_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'A lixeira está vazia',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nenhum contato, visita, estudo ou compromisso excluído logicamente no momento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final type = item['type'] as String;
              final id = item['id'] as String;
              final title = item['title'] as String;
              final subtitle = item['subtitle'] as String;
              final deletedAt = item['deletedAt'] as DateTime?;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                    child: Icon(_getIconForType(type), color: isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade700, size: 20),
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '$subtitle • Excluído em: ${AppDateUtils.formatDateTime(deletedAt)}',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore, color: AppTheme.primaryBlue),
                        tooltip: 'Restaurar',
                        onPressed: () async {
                          await repo.restoreDeletedItem(type, id);
                          setState(() {});
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('"$title" restaurado com sucesso!')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: AppTheme.alertRed),
                        tooltip: 'Excluir Definitivamente',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Exclusão Definitiva'),
                              content: Text('Tem certeza de que deseja apagar permanentemente "$title"? Esta ação não pode ser desfeita.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Excluir Definitivamente'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await repo.permanentlyDeleteItem(type, id);
                            setState(() {});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('"$title" excluído permanentemente.')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'people':
        return Icons.person;
      case 'visits':
        return Icons.repeat;
      case 'bible_studies':
        return Icons.menu_book;
      case 'appointments':
        return Icons.calendar_today;
      case 'activity_records':
        return Icons.timer;
      default:
        return Icons.article;
    }
  }
}
