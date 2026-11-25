import 'package:flutter/foundation.dart';

import '../core/feature_registry.dart';

/// Intenção de navegação entre abas e módulos disparada por referências cruzadas.
class AppNavigationRequest {
  final int requestId;
  final AppFeature feature;
  final int? subTabIndex;
  final String? focusItemId;

  const AppNavigationRequest({
    required this.requestId,
    required this.feature,
    this.subTabIndex,
    this.focusItemId,
  });
}

/// Controlador reativo que permite saltar para qualquer aba/item do app
/// a partir de leitores popup de referências cruzadas.
class AppNavigationController extends ChangeNotifier {
  int _counter = 0;
  AppNavigationRequest? _pendingRequest;

  AppNavigationRequest? get pendingRequest => _pendingRequest;

  /// Solicita navegação direta para [feature], com aba interna e item opcional.
  void navigateTo(AppFeature feature, {int? subTabIndex, String? focusItemId}) {
    _counter++;
    _pendingRequest = AppNavigationRequest(
      requestId: _counter,
      feature: feature,
      subTabIndex: subTabIndex,
      focusItemId: focusItemId,
    );
    notifyListeners();
  }

  /// Limpa a solicitação pendente após consumo pela tela de destino.
  void clearIfHandled(int requestId) {
    if (_pendingRequest?.requestId == requestId) {
      _pendingRequest = null;
    }
  }
}
