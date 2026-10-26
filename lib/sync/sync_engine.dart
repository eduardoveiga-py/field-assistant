enum SyncStatus {
  savedLocally,
  syncing,
  synced,
  waitingConnection,
  conflict,
  error,
}

class ConflictItem {
  final String entityType;
  final String entityId;
  final String fieldName;
  final dynamic localValue;
  final dynamic remoteValue;

  ConflictItem({
    required this.entityType,
    required this.entityId,
    required this.fieldName,
    required this.localValue,
    required this.remoteValue,
  });
}

class MergeResult {
  final bool hasConflict;
  final Map<String, dynamic> mergedData;
  final List<ConflictItem> conflicts;

  MergeResult({
    required this.hasConflict,
    required this.mergedData,
    this.conflicts = const [],
  });
}

class SyncEngine {
  /// Algoritmo de mesclagem em nível de campos (Field-Level Merge) com detecção explícita de conflitos.
  ///
  /// Regras:
  /// - Campos alterados em apenas um dos nós são integrados sem perda.
  /// - Campos idênticos não geram conflito.
  /// - Campos conflitantes retêm ambas as opções e sinalizam conflito explícito.
  static MergeResult mergeEntities({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    required Map<String, dynamic> baseData, // Estado comum antes da divergência
  }) {
    final merged = Map<String, dynamic>.from(localData);
    final conflicts = <ConflictItem>[];

    final allKeys = {...localData.keys, ...remoteData.keys};

    for (final key in allKeys) {
      if (key == 'revision' || key == 'updated_at' || key == 'updatedAt') continue;

      final localVal = localData[key];
      final remoteVal = remoteData[key];
      final baseVal = baseData[key];

      final localChanged = localVal != baseVal;
      final remoteChanged = remoteVal != baseVal;

      if (!localChanged && remoteChanged) {
        // Remoto alterou, local não: aceita remoto com segurança
        merged[key] = remoteVal;
      } else if (localChanged && !remoteChanged) {
        // Local alterou, remoto não: mantém local
        merged[key] = localVal;
      } else if (localChanged && remoteChanged) {
        // Ambos alteraram
        if (localVal == remoteVal) {
          // Alterações idênticas: sem conflito
          merged[key] = localVal;
        } else {
          // Conflito em mesmo campo: NÃO sobrescreve cegamente!
          conflicts.add(
            ConflictItem(
              entityType: entityType,
              entityId: entityId,
              fieldName: key,
              localValue: localVal,
              remoteValue: remoteVal,
            ),
          );
        }
      }
    }

    return MergeResult(
      hasConflict: conflicts.isNotEmpty,
      mergedData: merged,
      conflicts: conflicts,
    );
  }
}
