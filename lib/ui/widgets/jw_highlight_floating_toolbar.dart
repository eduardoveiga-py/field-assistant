import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'highlight_text_helper.dart';

/// Controlador de barra flutuante estilo JW Library para sublinhado/marcação.
/// Exibe automaticamente uma pílula escura com os 6 círculos coloridos e botão
/// "Remover marcação" assim que o usuário seleciona uma palavra ou frase.
class JwHighlightFloatingController {
  OverlayEntry? _entry;
  bool _disposed = false;

  Offset? _lastPointerDownGlobal;
  Offset? _lastPointerUpGlobal;
  GlobalKey? _activeAnchorKey;
  String _activeKeyPrefix = 'inline';
  ValueChanged<String?>? _onPickColor;

  void recordPointerDown(Offset globalPosition) {
    _lastPointerDownGlobal = globalPosition;
    _lastPointerUpGlobal = globalPosition;
  }

  void recordPointerUp(Offset globalPosition) {
    _lastPointerUpGlobal = globalPosition;
    if (_entry != null) {
      _refreshEntry();
    }
  }

  /// Exibe ou atualiza a pílula flutuante JW Library perto da seleção atual.
  void show({
    required BuildContext context,
    required String keyPrefix,
    required ValueChanged<String?> onPickColor,
    GlobalKey? anchorKey,
  }) {
    if (_disposed || !context.mounted) return;
    _activeKeyPrefix = keyPrefix;
    _onPickColor = onPickColor;
    _activeAnchorKey = anchorKey;

    if (_entry != null) {
      _refreshEntry();
      return;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _entry = OverlayEntry(
      builder: (overlayCtx) => _buildPositionedPill(overlayCtx),
    );

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && _entry != null && context.mounted) {
          Overlay.maybeOf(context, rootOverlay: true)?.insert(_entry!);
        }
      });
    } else {
      overlay.insert(_entry!);
    }
  }

  void _refreshEntry() {
    if (_disposed || _entry == null) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) _entry?.markNeedsBuild();
      });
    } else {
      _entry?.markNeedsBuild();
    }
  }

  /// Remove a pílula flutuante imediatamente (ex.: seleção limpa, toque fora ou dispose).
  void hide() {
    final existing = _entry;
    _entry = null;
    if (existing != null) {
      try {
        existing.remove();
      } catch (_) {}
    }
  }

  void dispose() {
    _disposed = true;
    hide();
  }

  Widget _buildPositionedPill(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final screenH = media.size.height;
    const pillWidth = 264.0;
    const pillHeight = 46.0;

    double targetCenterX = screenW / 2;
    double targetTopY = screenH * 0.25;

    final box =
        _activeAnchorKey?.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.attached) {
      final boxTopLeft = box.localToGlobal(Offset.zero);
      targetCenterX = boxTopLeft.dx + box.size.width / 2;
      targetTopY = boxTopLeft.dy - pillHeight - 10;
      if (targetTopY < media.padding.top + 12) {
        targetTopY = boxTopLeft.dy + 8;
      }
    }

    if (_lastPointerUpGlobal != null && _lastPointerDownGlobal != null) {
      final down = _lastPointerDownGlobal!;
      final up = _lastPointerUpGlobal!;
      final pointerInsideAnchor =
          box == null ||
          !box.hasSize ||
          Rect.fromLTWH(
            box.localToGlobal(Offset.zero).dx - 24,
            box.localToGlobal(Offset.zero).dy - 24,
            box.size.width + 48,
            box.size.height + 48,
          ).contains(up);
      if (pointerInsideAnchor) {
        targetCenterX = (down.dx + up.dx) / 2;
        final topMost = down.dy < up.dy ? down.dy : up.dy;
        targetTopY = topMost - pillHeight - 18;
        if (targetTopY < media.padding.top + 12) {
          final bottomMost = down.dy > up.dy ? down.dy : up.dy;
          targetTopY = bottomMost + 18;
        }
      }
    }

    final left = (targetCenterX - pillWidth / 2).clamp(
      12.0,
      (screenW - pillWidth - 12.0).clamp(12.0, screenW),
    );
    final top = targetTopY.clamp(
      media.padding.top + 8.0,
      (screenH - pillHeight - 16.0).clamp(12.0, screenH),
    );

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: pillHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF28282F),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in HighlightTextHelper.colors)
                Tooltip(
                  message: 'Marcar (${c.label})',
                  child: InkWell(
                    key: Key('btn_${_activeKeyPrefix}_hl_${c.id}'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      final cb = _onPickColor;
                      hide();
                      cb?.call(c.hex);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 4,
                      ),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: c.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: Colors.white.withValues(alpha: 0.16),
              ),
              Tooltip(
                message: 'Remover marcação',
                child: InkWell(
                  key: Key('btn_${_activeKeyPrefix}_hl_clear'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    final cb = _onPickColor;
                    hide();
                    cb?.call(null);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(
                      Icons.format_clear,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
