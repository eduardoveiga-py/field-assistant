import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../providers.dart';
import 'person_detail_screen.dart';

enum NextActionCategory {
  overdue('Atrasadas', Icons.warning_amber_rounded, AppTheme.alertRed),
  today('Hoje', Icons.today, AppTheme.accentTeal),
  upcoming('Próximos dias', Icons.calendar_month, AppTheme.primaryBlue),
  unscheduled('Sem data definida', Icons.help_outline, Color(0xFFD97706));

  final String label;
  final IconData icon;
  final Color color;
  const NextActionCategory(this.label, this.icon, this.color);
}

class CategorizedNextActionItem {
  final String id;
  final String personId;
  final String personName;
  final String? note;
  final DateTime? scheduledDate;
  final NextActionCategory category;
  final String status;
  final String? address;

  CategorizedNextActionItem({
    required this.id,
    required this.personId,
    required this.personName,
    this.note,
    this.scheduledDate,
    required this.category,
    required this.status,
    this.address,
  });
}

class NextActionsScreen extends ConsumerStatefulWidget {
  const NextActionsScreen({super.key});

  @override
  ConsumerState<NextActionsScreen> createState() => _NextActionsScreenState();
}

class _NextActionsScreenState extends ConsumerState<NextActionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static List<CategorizedNextActionItem> categorize(List<PersonEntry> people) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final items = <CategorizedNextActionItem>[];

    for (final p in people) {
      if (p.deletedAt != null || p.status == 'revisita_passada' || p.status == 'revisita_encerrada') {
        continue;
      }

      final date = p.nextActionAt;
      final NextActionCategory cat;

      if (date == null) {
        // Sem data definida se tiver nota de próxima ação ou estiver ativo
        if ((p.nextActionNote != null && p.nextActionNote!.trim().isNotEmpty) ||
            p.status == 'revisita' ||
            p.status == 'estudo' ||
            p.status == 'interessado') {
          cat = NextActionCategory.unscheduled;
        } else {
          continue;
        }
      } else if (date.isBefore(todayStart)) {
        cat = NextActionCategory.overdue;
      } else if (!date.isAfter(todayEnd)) {
        cat = NextActionCategory.today;
      } else {
        cat = NextActionCategory.upcoming;
      }

      items.add(
        CategorizedNextActionItem(
          id: p.id,
          personId: p.id,
          personName: p.name,
          note: p.nextActionNote,
          scheduledDate: date,
          category: cat,
          status: p.status,
          address: p.address,
        ),
      );
    }

    // Ordenar itens
    items.sort((a, b) {
      if (a.scheduledDate != null && b.scheduledDate != null) {
        return a.scheduledDate!.compareTo(b.scheduledDate!);
      }
      if (a.scheduledDate != null) return -1;
      if (b.scheduledDate != null) return 1;
      return a.personName.compareTo(b.personName);
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return peopleAsync.when(
      data: (people) {
        final allItems = categorize(people);
        final overdueList = allItems.where((i) => i.category == NextActionCategory.overdue).toList();
        final todayList = allItems.where((i) => i.category == NextActionCategory.today).toList();
        final upcomingList = allItems.where((i) => i.category == NextActionCategory.upcoming).toList();
        final unscheduledList = allItems.where((i) => i.category == NextActionCategory.unscheduled).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Próximas Ações & Retornos'),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppTheme.primaryBlue,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.alertRed),
                      const SizedBox(width: 6),
                      Text('Atrasadas (${overdueList.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.today, size: 16, color: AppTheme.accentTeal),
                      const SizedBox(width: 6),
                      Text('Hoje (${todayList.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month, size: 16, color: AppTheme.primaryBlue),
                      const SizedBox(width: 6),
                      Text('Próximos dias (${upcomingList.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.help_outline, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text('Sem data (${unscheduledList.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildCategoryList(context, overdueList, NextActionCategory.overdue, isDark),
              _buildCategoryList(context, todayList, NextActionCategory.today, isDark),
              _buildCategoryList(context, upcomingList, NextActionCategory.upcoming, isDark),
              _buildCategoryList(context, unscheduledList, NextActionCategory.unscheduled, isDark),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Próximas Ações & Retornos')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Próximas Ações & Retornos')),
        body: Center(child: Text('Erro: $err')),
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    List<CategorizedNextActionItem> items,
    NextActionCategory category,
    bool isDark,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, size: 56, color: category.color.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                'Nenhuma ação em "${category.label}"',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Todas as ações desta categoria estão concluídas ou em dia.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: category.color.withValues(alpha: 0.12),
              child: Icon(category.icon, color: category.color, size: 20),
            ),
            title: Text(item.personName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.note != null && item.note!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(item.note!, style: const TextStyle(fontSize: 13)),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (item.scheduledDate != null)
                      Text(
                        'Data: ${AppDateUtils.formatDate(item.scheduledDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: category == NextActionCategory.overdue ? AppTheme.alertRed : AppTheme.textMuted,
                        ),
                      )
                    else
                      const Text(
                        'Sem data definida',
                        style: TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                      ),
                    if (item.address != null && item.address!.isNotEmpty) ...[
                      const Text(' • ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      Expanded(
                        child: Text(
                          item.address!,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PersonDetailScreen(personId: item.personId)),
              );
            },
          ),
        );
      },
    );
  }
}
