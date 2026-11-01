import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings_manager.dart';

enum FeatureCategory {
  organization('Organização'),
  tracking('Acompanhamento'),
  tools('Ferramentas');

  final String title;
  const FeatureCategory(this.title);
}

enum AppFeature {
  today(
    id: 'today',
    title: 'Hoje',
    description: 'Visão geral do dia, atalhos rápidos e resumo de atividades ministeriais',
    icon: Icons.today,
    category: FeatureCategory.organization,
    isEssential: true,
  ),
  people(
    id: 'people',
    title: 'Pessoas',
    description:
        'Gestão de contatos, histórico de visitas, revisitas e notas pastorais',
    icon: Icons.people,
    category: FeatureCategory.organization,
    isEssential: true,
  ),
  phones(
    id: 'phones',
    title: 'Telefones',
    description: 'Contatos telefônicos rápidos, WhatsApp e conversão em pessoas de interesse',
    icon: Icons.phone,
    category: FeatureCategory.organization,
    isEssential: false,
  ),
  agenda(
    id: 'agenda',
    title: 'Agenda',
    description: 'Compromissos ministeriais, disponibilidade e sincronização com calendários externos',
    icon: Icons.calendar_month,
    category: FeatureCategory.organization,
    isEssential: false,
  ),
  studies(
    id: 'studies',
    title: 'Estudos Bíblicos',
    description: 'Acompanhamento do manual Seja Feliz Para Sempre!, sessões, lições e frequência',
    icon: Icons.school,
    category: FeatureCategory.tracking,
    isEssential: false,
  ),
  dashboard(
    id: 'dashboard',
    title: 'Estatísticas & Progresso',
    description: 'Relatório oficial de campo, métricas de estudos, pioneiro e horas dedicadas',
    icon: Icons.analytics,
    category: FeatureCategory.tracking,
    isEssential: false,
  ),
  experiences(
    id: 'experiences',
    title: 'Experiências de Campo',
    description:
        'Registro de ocasiões marcantes no ministério com mídias, fotos e tags',
    icon: Icons.auto_stories,
    category: FeatureCategory.tracking,
    isEssential: false,
  ),
  notesResearch(
    id: 'notes_research',
    title: 'Anotações & Pesquisas',
    description: 'Respostas bíblicas, pesquisas teocráticas, artigos de referência e rascunhos',
    icon: Icons.note_alt_outlined,
    category: FeatureCategory.tools,
    isEssential: false,
  ),
  territoryMaps(
    id: 'territory_maps',
    title: 'Mapas & Territórios',
    description: 'Gestão de setores de campo, marcos territoriais e visualização no mapa',
    icon: Icons.map_outlined,
    category: FeatureCategory.tools,
    isEssential: false,
  );

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final FeatureCategory category;
  final bool isEssential;

  const AppFeature({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.isEssential,
  });

  static AppFeature? fromId(String id) {
    for (final f in AppFeature.values) {
      if (f.id == id) return f;
    }
    return null;
  }
}

class FeatureRegistry {
  static const String prefix = 'feature_enabled_';

  static String settingKey(AppFeature feature) => '$prefix${feature.id}';
  static String settingKeyFromId(String featureId) => '$prefix$featureId';

  static bool isFeatureEnabled(String featureId, Map<String, String> settings) {
    final feature = AppFeature.fromId(featureId);
    if (feature == null) return false;
    if (feature.isEssential) return true;

    final key = settingKeyFromId(featureId);
    final val = settings[key];
    // Por padrão todos os recursos vêm habilitados
    if (val == null) return true;
    return val.toLowerCase() != 'false' && val != '0';
  }

  static Future<void> setFeatureEnabled(
    WidgetRef ref,
    AppFeature feature,
    bool enabled,
  ) async {
    if (feature.isEssential) return;
    final key = settingKey(feature);
    await ref
        .read(appSettingsNotifierProvider.notifier)
        .setString(key, enabled.toString());
  }
}

/// Provider que expõe o conjunto de funcionalidades ativas no app
final activeFeaturesProvider = Provider<List<AppFeature>>((ref) {
  final settings = ref.watch(appSettingsNotifierProvider);
  return AppFeature.values
      .where((f) => FeatureRegistry.isFeatureEnabled(f.id, settings))
      .toList();
});

/// Provider auxiliar para verificar se uma funcionalidade específica está ativa
final isFeatureEnabledProvider = Provider.family<bool, AppFeature>((
  ref,
  feature,
) {
  if (feature.isEssential) return true;
  final settings = ref.watch(appSettingsNotifierProvider);
  return FeatureRegistry.isFeatureEnabled(feature.id, settings);
});
