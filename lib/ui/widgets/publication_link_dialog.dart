import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../publications/publication_link_resolver.dart';

/// Diálogo unificado para exibir referências e links da publicação no JW Library / jw.org.
class PublicationLinkDialog extends StatelessWidget {
  final BibleStudyEntry study;

  const PublicationLinkDialog({super.key, required this.study});

  static Future<void> show(BuildContext context, BibleStudyEntry study) {
    return showDialog(
      context: context,
      builder: (ctx) => PublicationLinkDialog(study: study),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = PublicationLinkResolver.resolve(
      publicationId: study.publicationId,
      languageCode: study.language,
      lesson: study.currentLesson,
      paragraph: study.currentParagraph,
      manualReference: study.manualReference,
    );

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.menu_book, color: AppTheme.primaryBlue),
          SizedBox(width: 8),
          Expanded(child: Text('Abrir no JW Library')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resolved.displayText,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          if (resolved.note != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                resolved.note!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (resolved.url != null) ...[
            Text(
              'Link Oficial Verificado:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              resolved.url!,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.accentTeal,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copiar'),
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: resolved.url ?? resolved.displayText),
            );
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Referência copiada para a área de transferência!',
                ),
              ),
            );
          },
        ),
        if (resolved.url != null)
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Abrir'),
            onPressed: () async {
              final uri = Uri.parse(resolved.url!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else if (resolved.fallbackUrl != null) {
                await launchUrl(
                  Uri.parse(resolved.fallbackUrl!),
                  mode: LaunchMode.externalApplication,
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
          ),
      ],
    );
  }
}
