import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../../dashboard/counting_rules.dart';
import '../providers.dart';
import 'person_detail_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final DateTime _periodStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final DateTime _periodEnd = DateTime(DateTime.now().year, DateTime.now().month + 1, 0, 23, 59, 59);

  @override
  Widget build(BuildContext context) {
    final studies = ref.watch(studiesStreamProvider).value ?? [];
    final people = ref.watch(peopleStreamProvider).value ?? [];
    final appointments = ref.watch(appointmentsStreamProvider).value ?? [];
    final activities = ref.watch(activitiesStreamProvider).value ?? [];

    final repo = ref.watch(repositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estatísticas e Análise'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          repo.getAllSessions(),
          repo.getAllVisits(),
          repo.db.select(repo.db.studyParticipants).get(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = snapshot.data![0] as List<StudySessionEntry>;
          final visits = snapshot.data![1] as List<VisitEntry>;
          final participants = snapshot.data![2] as List<StudyParticipantEntry>;

          final metrics = DashboardCalculator.calculate(
            studies: studies,
            sessions: sessions,
            visits: visits,
            appointments: appointments,
            activities: activities,
            periodStart: _periodStart,
            periodEnd: _periodEnd,
          );

          final attentionItems = DashboardCalculator.getAttentionItems(
            people: people,
            studies: studies,
            participants: participants,
            appointments: appointments,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seletor de período do relatório
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calendar_month, color: AppTheme.primaryBlue),
                            SizedBox(width: 8),
                            Text(
                              'Período Atual: Este Mês',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          '${AppDateUtils.formatDate(_periodStart)} - ${AppDateUtils.formatDate(_periodEnd)}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Indicadores Principais (Grid 2x4)
                const Text(
                  'Indicadores do Ministério',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.6,
                  children: [
                    _MetricCard(
                      label: 'Estudos Ativos',
                      value: '${metrics.activeStudiesCount}',
                      icon: Icons.menu_book,
                      color: const Color(0xFF7C3AED),
                      subtitle: '${metrics.pausedStudiesCount} pausados',
                    ),
                    _MetricCard(
                      label: 'Sessões no Mês',
                      value: '${metrics.heldSessionsCount}',
                      icon: Icons.school,
                      color: AppTheme.primaryBlue,
                      subtitle: '${metrics.uniqueParticipantsCount} participantes',
                    ),
                    _MetricCard(
                      label: 'Revisitas Feitas',
                      value: '${metrics.heldVisitsCount}',
                      icon: Icons.repeat,
                      color: AppTheme.accentTeal,
                      subtitle: 'Conversas reais',
                    ),
                    _MetricCard(
                      label: 'Revisitas Agendadas',
                      value: '${metrics.scheduledVisitsCount}',
                      icon: Icons.event,
                      color: const Color(0xFF0284C7),
                      subtitle: '${metrics.overdueVisitsCount} vencidas',
                    ),
                    _MetricCard(
                      label: 'Horas de Atividade',
                      value: AppDateUtils.formatDuration(metrics.totalActivitySeconds),
                      icon: Icons.access_time,
                      color: const Color(0xFF059669),
                      subtitle: 'Tempo dedicado',
                    ),
                    _MetricCard(
                      label: 'Compromissos',
                      value: '${metrics.completedAppointmentsCount}',
                      icon: Icons.check_circle,
                      color: AppTheme.successGreen,
                      subtitle: '${metrics.notHeldAppointmentsCount} não realizados',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Gráfico de Distribuição Visual dos Contatos
                const Text(
                  'Distribuição de Contatos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Classificação Atual dos Interessados',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 160,
                          child: people.isEmpty
                              ? const Center(child: Text('Nenhum contato cadastrado'))
                              : Row(
                                  children: [
                                    Expanded(
                                      child: PieChart(
                                        PieChartData(
                                          sectionsSpace: 2,
                                          centerSpaceRadius: 30,
                                          sections: [
                                            PieChartSectionData(
                                              value: people.where((p) => p.status == 'interessado').length.toDouble(),
                                              color: AppTheme.primaryBlue,
                                              title: '${people.where((p) => p.status == 'interessado').length}',
                                              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            PieChartSectionData(
                                              value: people.where((p) => p.status == 'revisita').length.toDouble(),
                                              color: AppTheme.accentTeal,
                                              title: '${people.where((p) => p.status == 'revisita').length}',
                                              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            PieChartSectionData(
                                              value: people.where((p) => p.status == 'estudo').length.toDouble(),
                                              color: const Color(0xFF7C3AED),
                                              title: '${people.where((p) => p.status == 'estudo').length}',
                                              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _LegendItem(color: AppTheme.primaryBlue, label: 'Interessados'),
                                        SizedBox(height: 6),
                                        _LegendItem(color: AppTheme.accentTeal, label: 'Revisitas'),
                                        SizedBox(height: 6),
                                        _LegendItem(color: Color(0xFF7C3AED), label: 'Estudos Bíblicos'),
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Lista Crítica: PRECISAM DE ATENÇÃO
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Precisam de Atenção',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: attentionItems.isNotEmpty ? AppTheme.alertRed.withValues(alpha: 0.1) : AppTheme.successGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${attentionItems.length} pendência(s)',
                        style: TextStyle(
                          color: attentionItems.isNotEmpty ? AppTheme.alertRed : AppTheme.successGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (attentionItems.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.verified, color: AppTheme.successGreen, size: 36),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Excelente! Nenhum contato ou estudo precisa de atenção imediata no momento.',
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: attentionItems.map((item) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getAttentionColor(item.category).withValues(alpha: 0.1),
                            child: Icon(
                              _getAttentionIcon(item.category),
                              color: _getAttentionColor(item.category),
                            ),
                          ),
                          title: Text(item.personName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            item.reason,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PersonDetailScreen(personId: item.personId),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getAttentionColor(String category) {
    switch (category) {
      case 'overdue_action':
      case 'unresolved_appointment':
        return AppTheme.alertRed;
      case 'inactive_study':
        return AppTheme.alertAmber;
      case 'no_next_action':
      default:
        return Colors.orange;
    }
  }

  IconData _getAttentionIcon(String category) {
    switch (category) {
      case 'overdue_action':
        return Icons.timer_off;
      case 'inactive_study':
        return Icons.hourglass_empty;
      case 'unresolved_appointment':
        return Icons.event_busy;
      case 'no_next_action':
      default:
        return Icons.help_outline;
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textDark)),
      ],
    );
  }
}
