import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_logger.dart';

/// Preset de gradiente atmosférico para capa de nota (estilo Foto 3) e exportação PDF.
class NoteCoverGradientPreset {
  final String id;
  final String label;
  final Color startColor;
  final Color endColor;
  final Color accentTint;

  const NoteCoverGradientPreset({
    required this.id,
    required this.label,
    required this.startColor,
    required this.endColor,
    required this.accentTint,
  });

  LinearGradient toLinearGradient() => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [startColor, endColor],
  );
}

/// Opção curada de ícone decorativo de fundo (marca d'água) com `IconData` estático
/// compatível com icon tree-shaking no build Web/iOS/Windows.
class NoteCoverIconOption {
  final String id;
  final String label;
  final IconData? icon;

  const NoteCoverIconOption({
    required this.id,
    required this.label,
    required this.icon,
  });
}

/// Configuração de capa da nota armazenada em `KnowledgeNotes.propertiesJson['cover']`,
/// mantendo compatibilidade retroativa sem alteração de schema nem quebra da sincronização E2EE.
class NoteCoverConfig {
  final String? presetId;
  final String? iconId;
  final String? imageBase64;

  const NoteCoverConfig({this.presetId, this.iconId, this.imageBase64});

  static const int maxCoverBytes = 180 * 1024;

  static const List<NoteCoverGradientPreset> presets = [
    NoteCoverGradientPreset(
      id: 'aurora_indigo',
      label: 'Índigo Noturno',
      startColor: Color(0xFF1E2B6E),
      endColor: Color(0xFF0F172A),
      accentTint: Color(0xFF818CF8),
    ),
    NoteCoverGradientPreset(
      id: 'ocean_teal',
      label: 'Oceano Profundo',
      startColor: Color(0xFF0F5E63),
      endColor: Color(0xFF0B2239),
      accentTint: Color(0xFF2DD4BF),
    ),
    NoteCoverGradientPreset(
      id: 'royal_purple',
      label: 'Púrpura Real',
      startColor: Color(0xFF5B21B6),
      endColor: Color(0xFF1E1B4B),
      accentTint: Color(0xFFC084FC),
    ),
    NoteCoverGradientPreset(
      id: 'forest_sage',
      label: 'Oliveira & Floresta',
      startColor: Color(0xFF14532D),
      endColor: Color(0xFF062C22),
      accentTint: Color(0xFF4ADE80),
    ),
    NoteCoverGradientPreset(
      id: 'warm_terracotta',
      label: 'Ouro & Terracota',
      startColor: Color(0xFF9A3412),
      endColor: Color(0xFF3B1506),
      accentTint: Color(0xFFFBBF24),
    ),
    NoteCoverGradientPreset(
      id: 'sky_ministry',
      label: 'Céu Ministerial',
      startColor: Color(0xFF0369A1),
      endColor: Color(0xFF172554),
      accentTint: Color(0xFF38BDF8),
    ),
    NoteCoverGradientPreset(
      id: 'rose_dusk',
      label: 'Crepúsculo',
      startColor: Color(0xFF831843),
      endColor: Color(0xFF2E1065),
      accentTint: Color(0xFFF472B6),
    ),
    NoteCoverGradientPreset(
      id: 'slate_amber',
      label: 'Ardósia & Âmbar',
      startColor: Color(0xFF334155),
      endColor: Color(0xFF451A03),
      accentTint: Color(0xFFF59E0B),
    ),
  ];

  static const List<NoteCoverIconOption> iconOptions = [
    NoteCoverIconOption(id: 'none', label: 'Sem ícone', icon: null),
    NoteCoverIconOption(
      id: 'bible',
      label: 'Bíblia',
      icon: Icons.menu_book_rounded,
    ),
    NoteCoverIconOption(
      id: 'auto_stories',
      label: 'Estudo',
      icon: Icons.auto_stories_rounded,
    ),
    NoteCoverIconOption(
      id: 'lightbulb',
      label: 'Pérola',
      icon: Icons.lightbulb_outline_rounded,
    ),
    NoteCoverIconOption(
      id: 'explore',
      label: 'Território',
      icon: Icons.explore_outlined,
    ),
    NoteCoverIconOption(
      id: 'favorite',
      label: 'Pastoreio',
      icon: Icons.favorite_border_rounded,
    ),
    NoteCoverIconOption(
      id: 'public',
      label: 'Obra',
      icon: Icons.public_rounded,
    ),
    NoteCoverIconOption(
      id: 'psychology',
      label: 'Meditação',
      icon: Icons.psychology_alt_outlined,
    ),
    NoteCoverIconOption(
      id: 'mic',
      label: 'Discurso',
      icon: Icons.mic_none_rounded,
    ),
    NoteCoverIconOption(
      id: 'edit_note',
      label: 'Esboço',
      icon: Icons.edit_note_rounded,
    ),
    NoteCoverIconOption(
      id: 'award',
      label: 'Meta',
      icon: Icons.workspace_premium_outlined,
    ),
    NoteCoverIconOption(
      id: 'spa',
      label: 'Esperança',
      icon: Icons.spa_outlined,
    ),
  ];

  bool get hasPhoto => imageBase64 != null && imageBase64!.trim().isNotEmpty;

  bool get hasCustomCover =>
      (presetId != null && presetId!.isNotEmpty) ||
      (iconId != null && iconId!.isNotEmpty && iconId != 'none') ||
      hasPhoto;

  NoteCoverGradientPreset? get resolvedPreset {
    if (presetId == null || presetId!.isEmpty) return null;
    for (final p in presets) {
      if (p.id == presetId) return p;
    }
    return null;
  }

  IconData? get resolvedIconData {
    if (iconId == null || iconId!.isEmpty || iconId == 'none') return null;
    for (final opt in iconOptions) {
      if (opt.id == iconId) return opt.icon;
    }
    return null;
  }

  Uint8List? decodeImageBytes() {
    final raw = imageBase64?.trim() ?? '';
    if (raw.isEmpty) return null;
    try {
      final commaIdx = raw.indexOf('base64,');
      final payload = commaIdx >= 0 ? raw.substring(commaIdx + 7) : raw;
      final bytes = base64Decode(payload);
      return bytes.isEmpty ? null : bytes;
    } catch (e, st) {
      AppLogger.debug('Falha ao decodificar foto de capa da nota: $e', st);
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    if (presetId != null && presetId!.isNotEmpty) 'presetId': presetId,
    if (iconId != null && iconId!.isNotEmpty && iconId != 'none')
      'iconId': iconId,
    if (imageBase64 != null && imageBase64!.isNotEmpty)
      'imageBase64': imageBase64,
  };

  static NoteCoverConfig? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final preset = raw['presetId']?.toString().trim();
    final icon = raw['iconId']?.toString().trim();
    final img = raw['imageBase64']?.toString().trim();
    final cfg = NoteCoverConfig(
      presetId: preset?.isNotEmpty == true ? preset : null,
      iconId: icon?.isNotEmpty == true ? icon : null,
      imageBase64: img?.isNotEmpty == true ? img : null,
    );
    return cfg.hasCustomCover ? cfg : null;
  }

  static NoteCoverConfig? fromPropertiesJson(String rawPropertiesJson) {
    if (rawPropertiesJson.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(rawPropertiesJson);
      if (decoded is Map) {
        return fromJson(decoded['cover']);
      }
    } catch (e, st) {
      AppLogger.debug('Falha ao ler capa em propertiesJson: $e', st);
    }
    return null;
  }

  static Map<String, dynamic> decodePropertiesMap(String rawPropertiesJson) {
    if (rawPropertiesJson.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(rawPropertiesJson);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e, st) {
      AppLogger.debug('Falha ao ler propertiesJson da nota: $e', st);
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic> mergeCoverIntoPropertiesMap(
    Map<String, dynamic> existingProps,
    NoteCoverConfig? cover,
  ) {
    final next = Map<String, dynamic>.from(existingProps);
    if (cover == null || !cover.hasCustomCover) {
      next.remove('cover');
    } else {
      next['cover'] = cover.toJson();
    }
    return next;
  }

  /// Valida e redimensiona uma imagem escolhida pelo usuário para manter a capa
  /// leve (`<= 180 KB`) em todas as plataformas (Web, iOS, Android, Windows).
  static Future<String?> compressImageForCover(
    Uint8List rawBytes, {
    int maxBytes = maxCoverBytes,
  }) async {
    if (rawBytes.isEmpty) return null;
    // Se o arquivo original (ex.: JPEG otimizado) já couber no limite, valida decodificação e preserva
    if (rawBytes.lengthInBytes <= maxBytes &&
        rawBytes.lengthInBytes >= 4 &&
        rawBytes[0] == 0xFF &&
        rawBytes[1] == 0xD8) {
      try {
        final codec = await ui.instantiateImageCodec(rawBytes);
        final frame = await codec.getNextFrame();
        frame.image.dispose();
        codec.dispose();
        return base64Encode(rawBytes);
      } catch (e, st) {
        AppLogger.debug('Falha ao validar JPEG de capa: $e', st);
      }
    }

    for (final width in const [960, 720, 520, 360]) {
      try {
        final codec = await ui.instantiateImageCodec(
          rawBytes,
          targetWidth: width,
        );
        final frame = await codec.getNextFrame();
        final img = frame.image;
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        img.dispose();
        codec.dispose();
        if (byteData == null) continue;
        final pngBytes = byteData.buffer.asUint8List();
        if (pngBytes.lengthInBytes <= maxBytes || width == 360) {
          if (pngBytes.lengthInBytes <= maxBytes) {
            return base64Encode(pngBytes);
          }
        }
      } catch (e, st) {
        AppLogger.debug(
          'Falha ao redimensionar capa para largura $width: $e',
          st,
        );
        return null;
      }
    }

    if (rawBytes.lengthInBytes <= maxBytes) {
      return base64Encode(rawBytes);
    }
    return null;
  }
}
