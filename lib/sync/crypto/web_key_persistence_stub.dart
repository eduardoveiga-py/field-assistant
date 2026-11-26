import 'web_key_persistence.dart';

/// Implementação padrão para plataformas não-Web (Android/iOS/Windows/Linux/macOS).
WebKeyPersistenceAdapter createPlatformWebKeyPersistence({
  WebKeyPersistenceAdapter? override,
}) {
  return override ?? MemoryWebKeyPersistenceAdapter();
}
