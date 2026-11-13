import 'dart:ui' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_logger.dart';
import '../../database/app_database.dart';
import '../../ui/providers.dart' as global_providers;

/// Suporte a idiomas internacionais na aplicação Ministério Pessoal.
enum AppLocaleType {
  ptBR('pt_BR', 'Português (Brasil)', '🇧🇷'),
  enUS('en_US', 'English (US)', '🇺🇸'),
  esES('es_ES', 'Español', '🇪🇸');

  final String code;
  final String label;
  final String flagEmoji;

  const AppLocaleType(this.code, this.label, this.flagEmoji);

  Locale get toLocale {
    switch (this) {
      case AppLocaleType.enUS:
        return const Locale('en', 'US');
      case AppLocaleType.esES:
        return const Locale('es', 'ES');
      case AppLocaleType.ptBR:
        return const Locale('pt', 'BR');
    }
  }

  static AppLocaleType fromCode(String? code) {
    if (code == null) return AppLocaleType.ptBR;
    for (final loc in AppLocaleType.values) {
      if (loc.code == code || loc.name == code) return loc;
    }
    return AppLocaleType.ptBR;
  }
}

/// Catálogo tipado e seguro de textos do aplicativo com fallback transparente para PT-BR.
abstract class AppLocaleStrings {
  const AppLocaleStrings();

  // General / Actions
  String get appTitle => 'Ministério Pessoal';
  String get confirm => 'Confirmar';
  String get cancel => 'Cancelar';
  String get save => 'Salvar';
  String get edit => 'Editar';
  String get delete => 'Excluir';
  String get close => 'Fechar';
  String get search => 'Pesquisar...';
  String get loading => 'Carregando...';
  String get success => 'Operação concluída com sucesso!';
  String get error => 'Ocorreu um erro';
  String get offlineMode => 'Modo Offline (Sem Conta)';

  // Navigation / Tabs
  String get navToday => 'Hoje';
  String get navPeople => 'Pessoas';
  String get navPhones => 'Telefones';
  String get navAgenda => 'Agenda';
  String get navStudies => 'Estudos Bíblicos';
  String get navDashboard => 'Estatísticas & Progresso';
  String get navExperiences => 'Experiências';
  String get navNotes => 'Anotações & Pesquisas';
  String get navLanguages => 'Idiomas & Tradução';
  String get navTerritoryMaps => 'Mapas & Territórios';
  String get navSettings => 'Ajustes';

  // Greeting Contextual
  String get greetingMorning => 'Bom dia, irmão! Que Jeová abençoe seu ministério nesta manhã.';
  String get greetingAfternoon => 'Boa tarde! Renove suas forças no serviço de campo.';
  String get greetingEvening => 'Boa noite! Hora de revisar as bênçãos e revisitas do dia.';
  String get greetingGeneral => 'Bom ministério de campo!';

  // Updates
  String get updatesTitle => 'Atualizações do Aplicativo';
  String get updatesCheckBtn => 'Verificar Atualizações';
  String get updatesChecking => 'Verificando atualizações no GitHub...';
  String get updatesUpToDate => 'Seu aplicativo está totalmente atualizado.';
  String get updatesAvailable => 'Nova Atualização Disponível!';
  String get updatesInstallBtn => 'Atualizar Agora';
  String get updatesReleaseNotes => 'Notas do Lançamento';
  String get updatesLiveContainerHint =>
      'No iOS/LiveContainer, tocar em atualizar abrirá o instalador com a versão mais recente.';

  // Territory & Smart Map
  String get territoryCoverageIndex => 'Índice de Cobertura (IC)';
  String get territoryForgottenZones => 'Zonas Esquecidas (>90 dias)';
  String get territoryImportExport => 'Importar / Exportar Território';
  String get territoryExportKml => 'Exportar KML';
  String get territoryExportGeoJson => 'Exportar GeoJSON';
  String get territoryExportCsv => 'Exportar CSV';
  String get territoryImportFile => 'Importar Arquivo (KML/GeoJSON/CSV)';
  String get territoryDuplicateAlert => 'Endereço Possivelmente Duplicado';

  // Proximity Scheduling
  String get doorstepScheduleTitle => 'Agendar Retorno na Porta';
  String get doorstepSuggestedSlots => 'Horários Recomendados por Proximidade';
  String get doorstepConflictAlert => 'Conflito com outro compromisso na agenda';
  String get doorstepConfirmBooking => 'Confirmar Agendamento';

  // Language & Translation Assistant
  String get languageAssistantTitle => 'Assistente Linguístico & Tradução';
  String get languageSituationalPhrases => 'Frases Situacionais do Ministério';
  String get languageCompareMode => 'Comparador Multilíngue';
  String get languageFlashcards => 'Modo Flashcards (SRS)';
  String get languageSearchHistory => 'Histórico de Pesquisas';

  /// Fábrica para obter a instância apropriada do catálogo.
  factory AppLocaleStrings.of(AppLocaleType locale) {
    switch (locale) {
      case AppLocaleType.enUS:
        return _AppLocaleStringsEn();
      case AppLocaleType.esES:
        return _AppLocaleStringsEs();
      case AppLocaleType.ptBR:
        return _AppLocaleStringsPt();
    }
  }
}

/// Implementação padrão em Português do Brasil (Golden Master)
class _AppLocaleStringsPt extends AppLocaleStrings {}

/// Implementação em Inglês com fallback automático para Português
class _AppLocaleStringsEn extends AppLocaleStrings {
  @override
  String get appTitle => 'Field Ministry Assistant';
  @override
  String get confirm => 'Confirm';
  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get edit => 'Edit';
  @override
  String get delete => 'Delete';
  @override
  String get close => 'Close';
  @override
  String get search => 'Search...';
  @override
  String get loading => 'Loading...';
  @override
  String get success => 'Operation completed successfully!';
  @override
  String get error => 'An error occurred';
  @override
  String get offlineMode => 'Offline Mode (No Account)';

  @override
  String get navToday => 'Today';
  @override
  String get navPeople => 'People';
  @override
  String get navPhones => 'Phone Contacts';
  @override
  String get navAgenda => 'Schedule';
  @override
  String get navStudies => 'Bible Studies';
  @override
  String get navDashboard => 'Progress & Reports';
  @override
  String get navExperiences => 'Field Experiences';
  @override
  String get navNotes => 'Notes & Research';
  @override
  String get navLanguages => 'Languages & Translation';
  @override
  String get navTerritoryMaps => 'Maps & Territories';
  @override
  String get navSettings => 'Settings';

  @override
  String get greetingMorning => 'Good morning, brother! May Jehovah bless your morning ministry.';
  @override
  String get greetingAfternoon => 'Good afternoon! Renew your energy in field service.';
  @override
  String get greetingEvening => 'Good evening! Time to count blessings and return visits.';
  @override
  String get greetingGeneral => 'Have a wonderful field ministry!';

  @override
  String get updatesTitle => 'App Updates';
  @override
  String get updatesCheckBtn => 'Check for Updates';
  @override
  String get updatesChecking => 'Checking GitHub for updates...';
  @override
  String get updatesUpToDate => 'Your app is fully up to date.';
  @override
  String get updatesAvailable => 'New Update Available!';
  @override
  String get updatesInstallBtn => 'Update Now';
  @override
  String get updatesReleaseNotes => 'Release Notes';
  @override
  String get updatesLiveContainerHint =>
      'On iOS/LiveContainer, tapping update will open the source catalog with the latest IPA.';

  @override
  String get territoryCoverageIndex => 'Coverage Index (CI)';
  @override
  String get territoryForgottenZones => 'Forgotten Zones (>90 days)';
  @override
  String get territoryImportExport => 'Import / Export Territory';
  @override
  String get territoryExportKml => 'Export KML';
  @override
  String get territoryExportGeoJson => 'Export GeoJSON';
  @override
  String get territoryExportCsv => 'Export CSV';
  @override
  String get territoryImportFile => 'Import File (KML/GeoJSON/CSV)';
  @override
  String get territoryDuplicateAlert => 'Possibly Duplicate Address';

  @override
  String get doorstepScheduleTitle => 'Doorstep Return Visit Booking';
  @override
  String get doorstepSuggestedSlots => 'Proximity Recommended Slots';
  @override
  String get doorstepConflictAlert => 'Conflict with another schedule event';
  @override
  String get doorstepConfirmBooking => 'Confirm Booking';

  @override
  String get languageAssistantTitle => 'Linguistic & Translation Assistant';
  @override
  String get languageSituationalPhrases => 'Ministry Situational Phrases';
  @override
  String get languageCompareMode => 'Multilingual Comparator';
  @override
  String get languageFlashcards => 'Flashcards Mode (SRS)';
  @override
  String get languageSearchHistory => 'Search History';
}

/// Implementação em Espanhol com fallback automático para Português
class _AppLocaleStringsEs extends AppLocaleStrings {
  @override
  String get appTitle => 'Ministerio Personal';
  @override
  String get confirm => 'Confirmar';
  @override
  String get cancel => 'Cancelar';
  @override
  String get save => 'Guardar';
  @override
  String get edit => 'Editar';
  @override
  String get delete => 'Eliminar';
  @override
  String get close => 'Cerrar';
  @override
  String get search => 'Buscar...';
  @override
  String get loading => 'Cargando...';
  @override
  String get success => '¡Operación realizada con éxito!';
  @override
  String get error => 'Ocurrió un error';
  @override
  String get offlineMode => 'Modo Offline (Sin Cuenta)';

  @override
  String get navToday => 'Hoy';
  @override
  String get navPeople => 'Personas';
  @override
  String get navPhones => 'Teléfonos';
  @override
  String get navAgenda => 'Agenda';
  @override
  String get navStudies => 'Cursos Bíblicos';
  @override
  String get navDashboard => 'Progreso & Informes';
  @override
  String get navExperiences => 'Experiencias de Campo';
  @override
  String get navNotes => 'Notas & Investigaciones';
  @override
  String get navLanguages => 'Idiomas & Traducción';
  @override
  String get navTerritoryMaps => 'Mapas & Territorios';
  @override
  String get navSettings => 'Configuración';

  @override
  String get greetingMorning => '¡Buenos días, hermano! Que Jehová bendiga su ministerio matutino.';
  @override
  String get greetingAfternoon => '¡Buenas tardes! Renueve sus fuerzas en el servicio del campo.';
  @override
  String get greetingEvening => '¡Buenas noches! Tiempo de repasar las bendiciones y revisitas del día.';
  @override
  String get greetingGeneral => '¡Excelente ministerio del campo!';

  @override
  String get updatesTitle => 'Actualizaciones de la Aplicación';
  @override
  String get updatesCheckBtn => 'Buscar Actualizaciones';
  @override
  String get updatesChecking => 'Buscando actualizaciones en GitHub...';
  @override
  String get updatesUpToDate => 'Tu aplicación está completamente actualizada.';
  @override
  String get updatesAvailable => '¡Nueva Actualización Disponible!';
  @override
  String get updatesInstallBtn => 'Actualizar Ahora';
  @override
  String get updatesReleaseNotes => 'Notas del Lanzamiento';
  @override
  String get updatesLiveContainerHint =>
      'En iOS/LiveContainer, tocar actualizar abrirá el catálogo con la versión más reciente.';

  @override
  String get territoryCoverageIndex => 'Índice de Cobertura (IC)';
  @override
  String get territoryForgottenZones => 'Zonas Olvidadas (>90 días)';
  @override
  String get territoryImportExport => 'Importar / Exportar Territorio';
  @override
  String get territoryExportKml => 'Exportar KML';
  @override
  String get territoryExportGeoJson => 'Exportar GeoJSON';
  @override
  String get territoryExportCsv => 'Exportar CSV';
  @override
  String get territoryImportFile => 'Importar Archivo (KML/GeoJSON/CSV)';
  @override
  String get territoryDuplicateAlert => 'Dirección Posiblemente Duplicada';

  @override
  String get doorstepScheduleTitle => 'Agendar Revisita en la Puerta';
  @override
  String get doorstepSuggestedSlots => 'Horarios Recomendados por Proximidad';
  @override
  String get doorstepConflictAlert => 'Conflicto con otro compromiso en la agenda';
  @override
  String get doorstepConfirmBooking => 'Confirmar Cita';

  @override
  String get languageAssistantTitle => 'Asistente Lingüístico & Traducción';
  @override
  String get languageSituationalPhrases => 'Frases Situacionales del Ministerio';
  @override
  String get languageCompareMode => 'Comparador Multilingüe';
  @override
  String get languageFlashcards => 'Modo Fichas (SRS)';
  @override
  String get languageSearchHistory => 'Historial de Búsquedas';
}

/// Provider para gerenciar e observar o idioma selecionado
final appLocaleTypeProvider =
    NotifierProvider<AppLocaleNotifier, AppLocaleType>(
  AppLocaleNotifier.new,
);

class AppLocaleNotifier extends Notifier<AppLocaleType> {
  static const String kvKey = 'app_user_locale';

  @override
  AppLocaleType build() {
    _loadSavedLocale();
    return AppLocaleType.ptBR;
  }

  Future<void> _loadSavedLocale() async {
    try {
      final db = ref.read(global_providers.databaseProvider);
      final row = await (db.select(db.appKvStore)
            ..where((t) => t.key.equals(kvKey)))
          .getSingleOrNull();
      if (row != null && row.value.isNotEmpty) {
        state = AppLocaleType.fromCode(row.value);
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao carregar idioma salvo de app_kv_store', e, st);
    }
  }

  Future<void> setLocale(AppLocaleType locale) async {
    state = locale;
    try {
      final db = ref.read(global_providers.databaseProvider);
      await db.into(db.appKvStore).insertOnConflictUpdate(
        AppKvStoreCompanion.insert(
          key: kvKey,
          value: locale.code,
        ),
      );
    } catch (e, st) {
      AppLogger.warning('Falha ao persistir idioma selecionado em app_kv_store', e, st);
    }
  }
}

/// Provider que fornece o catálogo de strings atual baseado no idioma selecionado
final appStringsProvider = Provider<AppLocaleStrings>((ref) {
  final locale = ref.watch(appLocaleTypeProvider);
  return AppLocaleStrings.of(locale);
});
