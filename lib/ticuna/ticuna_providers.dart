import 'package:flutter_riverpod/flutter_riverpod.dart';

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
