typedef GeoCoordinates = ({double latitude, double longitude});

enum GeolocationStatus {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unsupportedPlatform,
  unavailableOrTimeout,
}

class GeolocationResult {
  final GeolocationStatus status;
  final GeoCoordinates? coordinates;
  final String? errorMessage;

  const GeolocationResult({
    required this.status,
    this.coordinates,
    this.errorMessage,
  });

  bool get isSuccess =>
      status == GeolocationStatus.success && coordinates != null;

  String get userMessage {
    if (errorMessage != null && errorMessage!.trim().isNotEmpty) {
      return errorMessage!;
    }
    switch (status) {
      case GeolocationStatus.success:
        return 'Localização GPS obtida com sucesso.';
      case GeolocationStatus.serviceDisabled:
        return 'Serviço de localização (GPS) desativado neste dispositivo.';
      case GeolocationStatus.permissionDenied:
        return 'Permissão de localização negada.';
      case GeolocationStatus.permissionDeniedForever:
        return 'Permissão de localização bloqueada nas configurações do sistema.';
      case GeolocationStatus.unsupportedPlatform:
        return 'GPS nativo indisponível nesta plataforma.';
      case GeolocationStatus.unavailableOrTimeout:
        return 'Não foi possível obter sinal GPS no momento.';
    }
  }
}
