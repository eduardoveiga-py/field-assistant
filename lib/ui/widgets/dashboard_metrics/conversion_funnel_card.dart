import 'package:flutter/material.dart';

import '../../../dashboard/counting_rules.dart';

/// Card apresentando o funil de conversão espiritual e progresso da obra:
/// Interessados -> 1ª Revisita -> Estudo Iniciado -> Parte 3 Livro -> Estudos Encerrados.
class ConversionFunnelCard extends StatelessWidget {
  final DashboardMetrics metrics;
  final Color headingColor;
  final Color bodyColor;
  final Color mutedColor;
  final bool isDark;

  const ConversionFunnelCard({
    super.key,
    required this.metrics,
    required this.headingColor,
    required this.bodyColor,
    required this.mutedColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final stages = [
      (
        label: '1. Interessados',
        count: metrics.funnelInterestedCount,
        color: const Color(0xFF2563EB),
        icon: Icons.person_search,
        desc: 'Pessoas com interesse identificado',
      ),
      (
        label: '2. 1ª Revisita',
        count: metrics.funnelFirstReturnVisitCount,
        color: const Color(0xFF0891B2),
        icon: Icons.mark_chat_read,
        desc: 'Revisita realizada com diálogo',
      ),
      (
        label: '3. Estudo Iniciado',
        count: metrics.funnelStartedStudyCount,
        color: const Color(0xFF7C3AED),
        icon: Icons.menu_book,
        desc: 'Estudo bíblico ativo ou iniciado',
      ),
      (
        label: '4. Parte 3 Livro (Lição 34+)',
        count: metrics.funnelReachedPart3Count,
        color: const Color(0xFF059669),
        icon: Icons.emoji_events,
        desc: 'Avançaram além da Lição 33 do "Seja Feliz"',
      ),
      (
        label: '5. Estudos Encerrados',
        count: metrics.funnelDroppedOutCount,
        color: const Color(0xFFDC2626),
        icon: Icons.cancel_outlined,
        desc: 'Estudos descontinuados ou encerrados',
      ),
    ];

    final maxVal = stages.map((s) => s.count).fold(1, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progresso da Obra',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: headingColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Progresso Espiritual',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: stages.map((st) {
                final ratio = maxVal > 0
                    ? (st.count / maxVal).clamp(0.0, 1.0)
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(st.icon, size: 16, color: st.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              st.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: st.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${st.count}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: st.color,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: isDark
                              ? Colors.white10
                              : Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(st.color),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        st.desc,
                        style: TextStyle(fontSize: 10, color: mutedColor),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
