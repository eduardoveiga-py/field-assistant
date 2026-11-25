import 'package:url_launcher/url_launcher.dart';

import '../database/app_database.dart';
import '../inbox/email_html_sanitizer.dart';
import 'doorstep_briefing_helper.dart';

class PersonHandOffHelper {
  static String formatHandOffMessage({
    required PersonEntry person,
    String? language,
    String? additionalNotes,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🌐 *ENCAMINHAMENTO DE CONTATO / LÍNGUA ESTRANGEIRA* 🌐');
    buffer.writeln('------------------------------------------');
    buffer.writeln('👤 *Nome:* ${person.name}');

    if (language != null && language.trim().isNotEmpty) {
      buffer.writeln('🗣️ *Idioma / Língua:* $language');
    }

    if (person.phone != null && person.phone!.trim().isNotEmpty) {
      buffer.writeln('📞 *Telefone:* ${person.phone}');
    }

    if (person.address != null && person.address!.trim().isNotEmpty) {
      buffer.writeln('📍 *Endereço:* ${person.address}');
    }

    if (person.latitude != null && person.longitude != null) {
      buffer.writeln(
        '🗺️ *Localização no Mapa:* https://www.google.com/maps/search/?api=1&query=${person.latitude},${person.longitude}',
      );
    }

    if (person.preferredSchedule != null &&
        person.preferredSchedule!.trim().isNotEmpty) {
      buffer.writeln('⏰ *Melhor Horário:* ${person.preferredSchedule}');
    }

    final plainNotes = DoorstepBriefingHelper.extractPlainNotesSummary(
      person.generalNotes,
    );
    if (plainNotes.isNotEmpty) {
      buffer.writeln('📝 *Observações / Assunto:* $plainNotes');
    }

    if (additionalNotes != null && additionalNotes.trim().isNotEmpty) {
      final cleanExtra = EmailHtmlSanitizer.stripMarkdown(
        additionalNotes.trim(),
      );
      if (cleanExtra.isNotEmpty) {
        buffer.writeln('📌 *Detalhes Adicionais:* $cleanExtra');
      }
    }

    buffer.writeln('------------------------------------------');
    buffer.writeln('_Enviado via Ministério Pessoal_');
    return buffer.toString();
  }

  static Future<bool> sendViaWhatsApp({
    required PersonEntry person,
    String? language,
    String? additionalNotes,
  }) async {
    final message = formatHandOffMessage(
      person: person,
      language: language,
      additionalNotes: additionalNotes,
    );
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/?text=$encoded');
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
