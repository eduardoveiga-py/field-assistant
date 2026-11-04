import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../dashboard/counting_rules.dart';
import '../../screens/person_detail_screen.dart';

/// Card apresentando contatos, revisitas e estudos bíblicos que precisam de atenção.
class AttentionItemsCard extends StatelessWidget {
  final List<AttentionItem> attentionItems;
  final Color headingColor;
  final Color bodyColor;
  final Color mutedColor;
  final bool isDark;

  const AttentionItemsCard({
    super.key,
    required this.attentionItems,
    required this.headingColor,
    required this.bodyColor,
    required this.mutedColor,
    required this.isDark,
  });

  static Color getAttentionColor(String category) {
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

  static IconData getAttentionIcon(String category) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Precisam de Atenção',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: headingColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: attentionItems.isNotEmpty
                    ? AppTheme.alertRed.withValues(alpha: 0.1)
                    : AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${attentionItems.length} pendência(s)',
                style: TextStyle(
                  color: attentionItems.isNotEmpty
                      ? AppTheme.alertRed
                      : AppTheme.successGreen,
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
                  const Icon(
                    Icons.verified,
                    color: AppTheme.successGreen,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Excelente! Nenhum contato ou estudo precisa de atenção imediata no momento.',
                      style: TextStyle(color: mutedColor),
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
                    backgroundColor: getAttentionColor(item.category)
                        .withValues(alpha: 0.1),
                    child: Icon(
                      getAttentionIcon(item.category),
                      color: getAttentionColor(item.category),
                    ),
                  ),
                  title: Text(
                    item.personName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    item.reason,
                    style: TextStyle(fontSize: 12, color: bodyColor),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PersonDetailScreen(personId: item.personId),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
