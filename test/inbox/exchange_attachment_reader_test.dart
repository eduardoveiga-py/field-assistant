import 'dart:typed_data';

import 'package:eas_client/eas_client.dart' as eas;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/inbox/exchange_attachment_reader.dart';
import 'package:ministerio_pessoal/inbox/exchange_service.dart';

void main() {
  test('recupera intervalos sequenciais até o total confirmado', () async {
    final requests = <int>[];
    final bytes = Uint8List.fromList(
      List.generate(ExchangeAttachmentReader.chunkSize + 7, (i) => i % 251),
    );
    final result = <int>[];
    await for (final part in ExchangeAttachmentReader.read(
      reference: 'ref',
      fetch: (ref, start, end) async {
        requests.add(start);
        final last = end < bytes.length ? end : bytes.length - 1;
        return eas.ItemOperationsResult(
          status: 1,
          fileReference: ref,
          range: '$start-$last',
          total: bytes.length,
          data: Uint8List.sublistView(bytes, start, last + 1),
        );
      },
    )) {
      result.addAll(part);
    }
    expect(result, bytes);
    expect(requests, [0, ExchangeAttachmentReader.chunkSize]);
  });

  test(
    'aceita resposta menor que pedido quando intervalo real é contínuo',
    () async {
      final seen = <int>[];
      final result = await ExchangeAttachmentReader.read(
        reference: 'ref',
        fetch: (ref, start, end) async {
          seen.add(start);
          final last = start == 0 ? 1 : 2;
          return eas.ItemOperationsResult(
            status: 1,
            range: '$start-$last',
            total: 3,
            data: Uint8List.fromList(start == 0 ? [1, 2] : [3]),
          );
        },
      ).toList();
      expect(seen, [0, 2]);
      expect(result.expand((x) => x), [1, 2, 3]);
    },
  );

  test(
    'rejeita intervalos quebrados, dados ausentes e total alterado',
    () async {
      Future<List<Uint8List>> broken(
        eas.ItemOperationsResult Function(int start) answer,
      ) => ExchangeAttachmentReader.read(
        reference: 'ref',
        fetch: (ref, start, end) async => answer(start),
      ).toList();
      await expectLater(
        broken(
          (start) =>
              const eas.ItemOperationsResult(status: 1, range: '1-1', total: 2),
        ),
        throwsA(isA<ExchangeException>()),
      );
      await expectLater(
        broken(
          (start) => eas.ItemOperationsResult(
            status: 1,
            range: '0-1',
            total: 2,
            data: Uint8List(1),
          ),
        ),
        throwsA(isA<ExchangeException>()),
      );
      await expectLater(
        broken(
          (start) => start == 0
              ? eas.ItemOperationsResult(
                  status: 1,
                  range: '0-0',
                  total: 2,
                  data: Uint8List(1),
                )
              : eas.ItemOperationsResult(
                  status: 1,
                  range: '1-1',
                  total: 3,
                  data: Uint8List(1),
                ),
        ),
        throwsA(isA<ExchangeException>()),
      );
      await expectLater(
        broken(
          (start) => eas.ItemOperationsResult(
            status: 1,
            range: '0-0',
            total: 2,
            data: Uint8List(1),
            fileReference: 'outro',
          ),
        ),
        throwsA(isA<ExchangeException>()),
      );
    },
  );

  test(
    'arquivo vazio e limite de tamanho são tratados sem falso sucesso',
    () async {
      expect(
        await ExchangeAttachmentReader.read(
          reference: 'ref',
          maxBytes: 0,
          fetch: (ref, start, end) async =>
              const eas.ItemOperationsResult(status: 10),
        ).toList(),
        isEmpty,
      );
      await expectLater(
        ExchangeAttachmentReader.read(
          reference: 'ref',
          maxBytes: 1,
          fetch: (ref, start, end) async => eas.ItemOperationsResult(
            status: 1,
            range: '0-1',
            total: 2,
            data: Uint8List(2),
          ),
        ).toList(),
        throwsA(isA<ExchangeException>()),
      );
    },
  );

  test('dados inline base64 inválidos não são convertidos em bytes falsos', () {
    eas.WbxmlElement node(
      String tag, {
      String? text,
      List<eas.WbxmlElement>? children,
    }) => eas.WbxmlElement(
      namespace: 'ItemOperations',
      tag: tag,
      text: text,
      children: children,
      codePageIndex: 20,
    );
    final result = node(
      'Fetch',
      children: [
        node('Status', text: '1'),
        node('Properties', children: [node('Data', text: '%não-base64%')]),
      ],
    );
    expect(
      () => eas.ItemOperationsResult.fromFetch(result),
      throwsFormatException,
    );
  });
  test(
    'ItemOperations envia somente Fetch e decodifica anexo binário',
    () async {
      eas.WbxmlElement node(
        String tag, {
        String ns = 'ItemOperations',
        int page = 20,
        String? text,
        List<eas.WbxmlElement>? children,
      }) => eas.WbxmlElement(
        namespace: ns,
        tag: tag,
        text: text,
        children: children,
        codePageIndex: page,
      );
      final body = eas.WbxmlEncoder().encode(
        eas.WbxmlDocument(
          root: node(
            'ItemOperations',
            children: [
              node('Status', text: '1'),
              node(
                'Response',
                children: [
                  node(
                    'Fetch',
                    children: [
                      node('Status', text: '1'),
                      node(
                        'FileReference',
                        ns: 'AirSyncBase',
                        page: 17,
                        text: 'ref',
                      ),
                      node(
                        'Properties',
                        children: [
                          node('Range', text: '0-1'),
                          node('Total', text: '2'),
                          node('Data', text: 'AQI='),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      final client = MockClient((request) async {
        expect(request.url.queryParameters['Cmd'], 'ItemOperations');
        final root = eas.WbxmlDecoder().decode(request.bodyBytes).root;
        expect(root.children.where((e) => e.tag == 'Fetch'), hasLength(1));
        expect(
          root.children.where(
            (e) => e.tag == 'EmptyFolderContents' || e.tag == 'Move',
          ),
          isEmpty,
        );
        final fetch = root.children.firstWhere((e) => e.tag == 'Fetch');
        expect(fetch.findChild('AirSyncBase', 'FileReference')?.text, 'ref');
        expect(
          fetch
              .findChild('ItemOperations', 'Options')
              ?.childText('ItemOperations', 'Range'),
          '0-1',
        );
        return http.Response.bytes(body, 200);
      });
      final session = ExchangeProtocolSession(
        host: 'mail.example.org',
        username: 'user',
        password: 'secret',
        deviceId: 'd',
        httpClient: client,
      );
      final result = await session.readAttachmentRange('ref', 0, 1);
      expect(result.status, 1);
      expect(result.data, [1, 2]);
      expect(result.range, '0-1');
      expect(result.total, 2);
      session.close();
    },
  );

  test('erro geral não é mascarado por Fetch aparentemente bem-sucedido', () {
    eas.WbxmlElement node(
      String tag, {
      String? text,
      List<eas.WbxmlElement>? children,
    }) => eas.WbxmlElement(
      namespace: 'ItemOperations',
      tag: tag,
      text: text,
      children: children,
      codePageIndex: 20,
    );
    final response = eas.WbxmlDocument(
      root: node(
        'ItemOperations',
        children: [
          node('Status', text: '3'),
          node(
            'Response',
            children: [
              node(
                'Fetch',
                children: [
                  node('Status', text: '1'),
                  node('Properties', children: [node('Data', text: 'AQI=')]),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    final result = eas.FetchAttachmentCommand(fileReference: 'ref')
        .parseResponse(response);
    expect(result.status, 3);
    expect(result.data, isNull);
  });

  test('resposta ambígua com múltiplos Fetch não é aceita', () {
    eas.WbxmlElement node(
      String tag, {
      String? text,
      List<eas.WbxmlElement>? children,
    }) => eas.WbxmlElement(
      namespace: 'ItemOperations',
      tag: tag,
      text: text,
      children: children,
      codePageIndex: 20,
    );
    final response = eas.WbxmlDocument(
      root: node(
        'ItemOperations',
        children: [
          node('Status', text: '1'),
          node(
            'Response',
            children: [
              node('Fetch', children: [node('Status', text: '1')]),
              node('Fetch', children: [node('Status', text: '1')]),
            ],
          ),
        ],
      ),
    );
    expect(
      eas.FetchAttachmentCommand(fileReference: 'ref')
          .parseResponse(response)
          .status,
      2,
    );
  });

  test('status global inválido 10 não é interpretado como arquivo vazio', () {
    final root = eas.WbxmlElement(
      namespace: 'ItemOperations',
      tag: 'ItemOperations',
      codePageIndex: 20,
      children: [
        eas.WbxmlElement(
          namespace: 'ItemOperations',
          tag: 'Status',
          text: '10',
          codePageIndex: 20,
        ),
      ],
    );
    final result = eas.FetchAttachmentCommand(fileReference: 'ref')
        .parseResponse(eas.WbxmlDocument(root: root));
    expect(result.status, 2);
  });
}
