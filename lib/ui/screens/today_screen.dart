import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../core/demo_data.dart';
import '../providers.dart';

class TodayScreen extends ConsumerWidget {
  final Function(int) onTabChange;

  const TodayScreen({super.key, required this.onTabChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final appointmentsAsync = ref.watch(appointmentsStreamProvider);
    final peopleAsync = ref.watch(peopleStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoje no Ministério'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.offline_pin, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Salvo Localmente',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Data atual com cabeçalho acolhedor
            Text(
              '${AppDateUtils.formatDate(now)} • Foco do Dia',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),

            // Atalhos rápidos em cards com toque amplo
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.person_add_alt_1,
                    label: 'Nova Pessoa',
                    color: AppTheme.primaryBlue,
                    onTap: () => onTabChange(1), // Aba Pessoas
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.calendar_today,
                    label: 'Ver Agenda',
                    color: AppTheme.accentTeal,
                    onTap: () => onTabChange(2), // Aba Agenda
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.menu_book,
                    label: 'Estudos',
                    color: const Color(0xFF7C3AED),
                    onTap: () => onTabChange(3), // Aba Estudos
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Seção: Próximos Compromissos de Hoje
            const Text(
              'Próximos Compromissos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 8),
            appointmentsAsync.when(
              data: (appts) {
                final todayAppts = appts
                    .where((a) =>
                        a.startTime.day == now.day &&
                        a.startTime.month == now.month &&
                        a.startTime.year == now.year &&
                        a.status != 'cancelado' &&
                        a.status != 'reagendado')
                    .toList();

                if (todayAppts.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.event_available, color: Colors.grey.shade400, size: 36),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Nenhum compromisso marcado para hoje. Toque em Agenda para agendar.',
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: todayAppts.map((a) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AppDateUtils.formatTime(a.startTime),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                        title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Duração: ${a.durationMinutes} min • Status: ${a.status}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: a.isProvisional
                            ? const Chip(
                                label: Text('Provisório', style: TextStyle(fontSize: 11)),
                                backgroundColor: Color(0xFFFEF3C7),
                              )
                            : const Icon(Icons.chevron_right),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Erro ao carregar agenda: $err'),
            ),
            const SizedBox(height: 24),

            // Seção: Retornos e Ações Pendentes
            const Text(
              'Ações e Revisitas Pendentes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 8),
            peopleAsync.when(
              data: (people) {
                final pending = people
                    .where((p) => p.nextActionAt != null && p.nextActionAt!.isBefore(now.add(const Duration(days: 1))))
                    .toList();

                if (pending.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 36),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Todas as revisitas e ações combinadas estão em dia!',
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: pending.map((p) {
                    final isOverdue = p.nextActionAt!.isBefore(now);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isOverdue ? AppTheme.alertRed.withValues(alpha: 0.1) : AppTheme.accentTeal.withValues(alpha: 0.1),
                          child: Icon(
                            isOverdue ? Icons.warning_amber_rounded : Icons.schedule,
                            color: isOverdue ? AppTheme.alertRed : AppTheme.accentTeal,
                          ),
                        ),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${p.nextActionNote ?? "Sem anotação"} • Data: ${AppDateUtils.formatDate(p.nextActionAt)}',
                          style: TextStyle(
                            color: isOverdue ? AppTheme.alertRed : AppTheme.textMuted,
                            fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => onTabChange(1), // Direciona para pessoas
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Erro ao carregar contatos: $err'),
            ),
            const SizedBox(height: 24),

            // Card informativo de Demonstração Isolada
            Card(
              color: const Color(0xFFEFF6FF),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.science, color: AppTheme.primaryBlue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Modo de Demonstração Disponível',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Você pode popular o sistema com dados demonstrativos fictícios para testar sem conectar ao Supabase.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_to_photos, size: 18),
                      label: const Text('Carregar Dados de Demonstração'),
                      onPressed: () async {
                        final repo = ref.read(repositoryProvider);
                        await DemoDataGenerator.populateDemoData(repo);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Dados de demonstração gerados com sucesso!')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
