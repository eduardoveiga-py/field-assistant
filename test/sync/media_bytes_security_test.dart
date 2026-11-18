import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/sync/media_bytes_io.dart';
import 'package:path/path.dart' as p;

void main() {
  group(
    'FA-SEC-09: saveMediaBytes path traversal & atomic write hardening',
    () {
      late Directory rootDir;
      late Directory baseDir;

      setUp(() async {
        rootDir = await Directory.systemTemp.createTemp('media_sec_root_');
        baseDir = Directory(p.join(rootDir.path, 'app_docs'));
        await baseDir.create(recursive: true);
      });

      tearDown(() async {
        if (await rootDir.exists()) {
          await rootDir.delete(recursive: true);
        }
      });

      test(
        'bloqueia tentativas de path traversal em fileName e subDir',
        () async {
          final maliciousNames = [
            '../escape.m4a',
            '../../escape.txt',
            r'..\escape.m4a',
            'sub/file.m4a',
            r'sub\file.m4a',
            '/etc/passwd',
            r'C:\Windows\win.ini',
            '.',
            '..',
            'a..b.m4a',
            'evil\x00.m4a',
            'evil\n.m4a',
            'CON',
            'nul.txt',
            '',
            '   ',
          ];

          for (final badName in maliciousNames) {
            await expectLater(
              () => saveMediaBytes(
                baseDir: baseDir.path,
                subDir: 'voice_notes',
                fileName: badName,
                bytes: Uint8List.fromList([1, 2, 3]),
              ),
              throwsArgumentError,
              reason: 'Deve rejeitar fileName malicioso: "$badName"',
            );
          }

          final maliciousSubDirs = [
            '../outside',
            r'..\outside',
            '/abs/dir',
            r'C:\outside',
            'voice_notes/../../outside',
            'dir\x00name',
            '',
            'CON',
          ];

          for (final badSub in maliciousSubDirs) {
            await expectLater(
              () => saveMediaBytes(
                baseDir: baseDir.path,
                subDir: badSub,
                fileName: 'valid.m4a',
                bytes: Uint8List.fromList([1, 2, 3]),
              ),
              throwsArgumentError,
              reason: 'Deve rejeitar subDir malicioso: "$badSub"',
            );
          }

          // Garante que nenhum arquivo escapou para rootDir
          final outsideEntries = rootDir
              .listSync()
              .where(
                (e) => p.canonicalize(e.path) != p.canonicalize(baseDir.path),
              )
              .toList();
          expect(outsideEntries, isEmpty);
        },
      );

      test(
        'grava e substitui atomicamente arquivo válido dentro do subdiretório',
        () async {
          final firstPath = await saveMediaBytes(
            baseDir: baseDir.path,
            subDir: 'documents',
            fileName: 'Estudo Bíblico 01.pdf',
            bytes: Uint8List.fromList([10, 20, 30]),
          );
          expect(firstPath, isNotNull);
          expect(
            p.isWithin(
              p.canonicalize(baseDir.path),
              p.canonicalize(firstPath!),
            ),
            isTrue,
          );
          expect(await File(firstPath).readAsBytes(), [10, 20, 30]);

          // Substituição atômica do mesmo arquivo
          final secondPath = await saveMediaBytes(
            baseDir: baseDir.path,
            subDir: 'documents',
            fileName: 'Estudo Bíblico 01.pdf',
            bytes: Uint8List.fromList([40, 50, 60, 70]),
          );
          expect(secondPath, equals(firstPath));
          expect(await File(secondPath!).readAsBytes(), [40, 50, 60, 70]);

          // Nenhum arquivo temporário residual
          final residual = Directory(p.join(baseDir.path, 'documents'))
              .listSync()
              .where((e) => p.basename(e.path).startsWith('.media_'))
              .toList();
          expect(residual, isEmpty);
        },
      );
    },
  );
}
