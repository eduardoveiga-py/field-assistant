import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../ui/providers.dart';
import 'models/ticuna_models.dart';
import 'services/ticuna_audio_service.dart';
import 'ticuna_repository.dart';

final ticunaRepositoryProvider = Provider<TicunaRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TicunaRepository(db);
});

final ticunaWordsStreamProvider = StreamProvider<List<TicunaWord>>((ref) {
  final repo = ref.watch(ticunaRepositoryProvider);
  return repo.watchWords();
});

final ticunaPhrasesStreamProvider = StreamProvider<List<TicunaPhrase>>((ref) {
  final repo = ref.watch(ticunaRepositoryProvider);
  return repo.watchPhrases();
});

final ticunaTagsStreamProvider = StreamProvider<List<TicunaTag>>((ref) {
  final repo = ref.watch(ticunaRepositoryProvider);
  return repo.watchTags();
});

final ticunaAudioServiceProvider = Provider<ITicunaAudioService>((ref) {
  final service = TicunaAudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

final languagesStreamProvider = StreamProvider<List<AppLanguageEntry>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchAllLanguages();
});

class ActiveLanguageNotifier extends Notifier<AppLanguageEntry?> {
  @override
  AppLanguageEntry? build() => null;

  @override
  set state(AppLanguageEntry? value) => super.state = value;
  @override
  AppLanguageEntry? get state => super.state;
}

final activeLanguageProvider =
    NotifierProvider<ActiveLanguageNotifier, AppLanguageEntry?>(
  ActiveLanguageNotifier.new,
);

final currentActiveLanguageProvider = Provider<AppLanguageEntry>((ref) {
  final explicit = ref.watch(activeLanguageProvider);
  if (explicit != null) return explicit;
  final languages = ref.watch(languagesStreamProvider).value;
  if (languages != null && languages.isNotEmpty) {
    try {
      return languages.firstWhere((l) => l.isDefault);
    } catch (_) {
      return languages.first;
    }
  }
  return AppLanguageEntry(
    id: 'tca',
    name: 'Ticuna (Magüta)',
    code: 'tca',
    symbol: '🏹',
    diacritics: '["ĩ","ü̃","ü̃́","ũ","ã́","ẽ","Ĩ","Ü̃","Ü̃́","Ũ","Ã́","Ẽ"]',
    isDefault: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
});

List<String> parseLanguageDiacritics(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  final trimmed = raw.trim();
  if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
    try {
      final list = jsonDecode(trimmed) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {}
  }
  return trimmed
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

