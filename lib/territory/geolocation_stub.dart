import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../core/app_logger.dart';
import 'geolocation_types.dart';

Future<GeolocationResult> getPlatformCoordinates() async {
  try {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      return const GeolocationResult(
        status: GeolocationStatus.unsupportedPlatform,
      );
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const GeolocationResult(
        status: GeolocationStatus.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const GeolocationResult(
        status: GeolocationStatus.permissionDenied,
      );
    }
    if (permission == LocationPermission.deniedForever) {
      return const GeolocationResult(
        status: GeolocationStatus.permissionDeniedForever,
      );
    }
    if (permission == LocationPermission.unableToDetermine) {
      return const GeolocationResult(
        status: GeolocationStatus.unavailableOrTimeout,
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    if (!position.latitude.isFinite || !position.longitude.isFinite) {
      return const GeolocationResult(
        status: GeolocationStatus.unavailableOrTimeout,
      );
    }
    return GeolocationResult(
      status: GeolocationStatus.success,
      coordinates: (latitude: position.latitude, longitude: position.longitude),
    );
  } on LocationServiceDisabledException catch (e, st) {
    AppLogger.debug('Serviço de localização desativado: $e', st);
    return const GeolocationResult(status: GeolocationStatus.serviceDisabled);
  } on PermissionDeniedException catch (e, st) {
    AppLogger.debug('Permissão de localização negada: $e', st);
    return const GeolocationResult(status: GeolocationStatus.permissionDenied);
  } on TimeoutException catch (e, st) {
    // Não apresentar uma posição antiga como se fosse a localização atual.
    AppLogger.debug('Tempo esgotado ao obter posição GPS atual: $e', st);
    return const GeolocationResult(
      status: GeolocationStatus.unavailableOrTimeout,
    );
  } on MissingPluginException catch (e, st) {
    AppLogger.debug('Plugin Geolocator indisponível neste ambiente: $e', st);
    return const GeolocationResult(
      status: GeolocationStatus.unsupportedPlatform,
    );
  } on UnimplementedError catch (e, st) {
    AppLogger.debug('Geolocator não implementado nesta plataforma: $e', st);
    return const GeolocationResult(
      status: GeolocationStatus.unsupportedPlatform,
    );
  } on UnsupportedError catch (e, st) {
    AppLogger.debug('Geolocator não suportado nesta plataforma: $e', st);
    return const GeolocationResult(
      status: GeolocationStatus.unsupportedPlatform,
    );
  } on PlatformException catch (e, st) {
    AppLogger.warning('Erro de plataforma ao obter GPS nativo', e, st);
    return GeolocationResult(
      status: GeolocationStatus.unavailableOrTimeout,
      errorMessage: e.message?.trim().isNotEmpty == true
          ? 'Falha ao obter GPS: ${e.message}'
          : null,
    );
  } catch (e, st) {
    AppLogger.warning('Erro inesperado ao obter GPS nativo', e, st);
    return const GeolocationResult(
      status: GeolocationStatus.unavailableOrTimeout,
    );
  }
}

Future<GeoCoordinates?> getBrowserCoordinates() async {
  final res = await getPlatformCoordinates();
  return res.coordinates;
}
