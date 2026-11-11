import 'dart:typed_data';

import 'media_bytes_web.dart' if (dart.library.io) 'media_bytes_io.dart' as impl;

/// Carrega bytes de mídia (áudio, foto ou documento) de forma segura em todas as plataformas
/// (sem depender de `dart:io` no navegador Web).
Future<Uint8List?> readMediaBytes(String pathOrUrl) =>
    impl.readMediaBytes(pathOrUrl);

/// Persiste bytes de mídia baixados no dispositivo (disco no Nativo; data URI na Web).
Future<String?> saveMediaBytes({
  required String baseDir,
  required String subDir,
  required String fileName,
  required Uint8List bytes,
  String mimeType = 'application/octet-stream',
}) => impl.saveMediaBytes(
  baseDir: baseDir,
  subDir: subDir,
  fileName: fileName,
  bytes: bytes,
  mimeType: mimeType,
);

/// Verifica se uma mídia existe localmente (disco no Nativo; data/blob/http URI na Web).
Future<bool> localMediaExists(String pathOrUrl) =>
    impl.localMediaExists(pathOrUrl);

/// Resolve o diretório base padrão de documentos da aplicação (string vazia na Web).
Future<String> resolveDefaultDocumentsDir() => impl.resolveDefaultDocumentsDir();
