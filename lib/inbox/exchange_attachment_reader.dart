import 'dart:typed_data';

import 'package:eas_client/eas_client.dart' as eas;

import 'exchange_service.dart';

/// Leitor experimental apenas de rede. Não grava arquivos nem aciona o servidor
/// automaticamente. O consumidor deve gravar em arquivo temporário e só
/// publicar após concluir o stream; se falhar, descartar o temporário.
class ExchangeAttachmentReader {
  ExchangeAttachmentReader._();

  static const int chunkSize = 256 * 1024;
  // O protocolo da biblioteca aceita índices até 999999999 (inclusive).
  static const int maximumFileSize = 1000000000;

  static Stream<Uint8List> read({
    required String reference,
    required Future<eas.ItemOperationsResult> Function(String reference, int start, int end) fetch,
    int maxBytes = maximumFileSize,
  }) async* {
    if (reference.isEmpty || maxBytes < 0 || maxBytes > maximumFileSize) {
      throw ArgumentError('Referência ou limite de anexo inválido.');
    }
    int? total;
    var offset = 0;
    while (true) {
      // Consulte mesmo quando maxBytes == 0 para reconhecer um arquivo vazio.
      final end = (offset + chunkSize - 1).clamp(0, maximumFileSize - 1);
      final response = await fetch(reference, offset, end);
      if (response.fileReference != null && response.fileReference != reference) {
        throw const ExchangeException('Exchange retornou outro anexo; arquivo não salvo.');
      }
      // Status 10 significa arquivo vazio; somente no primeiro pedido.
      if (response.status == 10 && offset == 0 && (response.total == null || response.total == 0) &&
          (response.data == null || response.data!.isEmpty)) {
        return;
      }
      if (response.status != 1 || response.data == null || response.total == null || response.byteRange == null) {
        throw const ExchangeException('Exchange retornou anexo incompleto ou sem intervalo verificável.');
      }
      final size = response.total!;
      final range = response.byteRange!;
      final bytes = response.data!;
      if (size <= 0 || size > maxBytes || size > maximumFileSize ||
          (total != null && size != total) || range.start != offset ||
          range.end < range.start || range.end > end || range.end >= size ||
          bytes.length != range.end - range.start + 1) {
        throw const ExchangeException('Exchange retornou intervalo ou tamanho inconsistente; arquivo não salvo.');
      }
      total = size;
      offset = range.end + 1;
      yield bytes;
      if (offset == size) return;
    }
  }
}
