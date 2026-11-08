import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ministerio_pessoal/core/app_version.dart';
import 'package:ministerio_pessoal/core/update_checker_service.dart';
import 'package:ministerio_pessoal/core/i18n/app_locale_strings.dart';

void main() {
  group('AppVersion Contract & Semver Parser', () {
    test('1. Metadados e versão centralizada estão consistentes', () {
      expect(AppVersion.version, equals('1.2.0'));
      expect(AppVersion.buildNumber, equals(5));
      expect(AppVersion.displayVersion, equals('v1.2.0'));
      expect(AppVersion.userAgent, contains('MinisterioPessoal/1.2.0'));
      expect(AppVersion.liveContainerSourceUrl, startsWith('livecontainer://sources?url='));
      expect(AppVersion.releaseDate, isNotEmpty);
    });

    test('2. Comparador semântico de versões (Semver)', () {
      // Versões iguais
      expect(AppVersion.compare('1.2.0', '1.2.0'), equals(0));
      expect(AppVersion.compare('v1.2.0', '1.2.0'), equals(0));

      // Versão local mais recente que remota
      expect(AppVersion.compare('1.2.0', '1.1.2'), greaterThan(0));
      expect(AppVersion.compare('1.2.0', '1.0.0'), greaterThan(0));
      expect(AppVersion.compare('2.0.0', '1.9.9'), greaterThan(0));
      expect(AppVersion.compare('1.10.0', '1.9.0'), greaterThan(0));

      // Versão remota mais recente que local
      expect(AppVersion.compare('1.2.0', '1.2.1'), lessThan(0));
      expect(AppVersion.compare('1.2.0', '1.3.0'), lessThan(0));
      expect(AppVersion.compare('1.2.0', '2.0.0'), lessThan(0));

      // isNewerThanCurrent
      expect(AppVersion.isNewerThanCurrent('1.2.1'), isTrue);
      expect(AppVersion.isNewerThanCurrent('2.0.0'), isTrue);
      expect(AppVersion.isNewerThanCurrent('1.2.0'), isFalse);
      expect(AppVersion.isNewerThanCurrent('1.1.0'), isFalse);
    });
  });

  group('UpdateCheckerService & AppUpdateInfo', () {
    test('1. AppUpdateInfo.formattedSize calcula MB corretamente', () {
      final info = AppUpdateInfo(
        hasUpdate: true,
        currentVersion: '1.2.0',
        latestVersion: '1.3.0',
        releaseDate: '2026-11-08',
        releaseNotes: 'Notas',
        downloadUrl: 'https://example.com/app.ipa',
        sourceCatalogUrl: 'https://example.com/apps.json',
        sizeBytes: 15 * 1024 * 1024, // 15 MB
      );

      expect(info.formattedSize, equals('15.0 MB'));

      final infoNoSize = AppUpdateInfo(
        hasUpdate: false,
        currentVersion: '1.2.0',
        latestVersion: '1.2.0',
        releaseDate: '2026-11-08',
        releaseNotes: 'Notas',
        downloadUrl: '',
        sourceCatalogUrl: '',
        sizeBytes: null,
      );
      expect(infoNoSize.formattedSize, equals('Tamanho sob consulta'));
    });

    test('2. Consulta ao GitHub Releases detecta nova versão disponível', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == AppVersion.latestReleaseApiUrl) {
          final payload = {
            'tag_name': 'v1.3.0',
            'published_at': '2026-11-15T10:00:00Z',
            'body': 'Nova versão com melhorias e correções.',
            'assets': [
              {
                'name': 'MinisterioPessoal.ipa',
                'browser_download_url': 'https://github.com/releases/download/v1.3.0/MinisterioPessoal.ipa',
                'size': 20971520, // 20 MB
              }
            ],
          };
          return http.Response(jsonEncode(payload), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = UpdateCheckerService(client: mockClient);
      final updateInfo = await service.checkForUpdate(currentVersion: '1.2.0');

      expect(updateInfo.hasUpdate, isTrue);
      expect(updateInfo.latestVersion, equals('1.3.0'));
      expect(updateInfo.releaseNotes, contains('Nova versão'));
      expect(updateInfo.downloadUrl, contains('MinisterioPessoal.ipa'));
      expect(updateInfo.sizeBytes, equals(20971520));
      expect(updateInfo.formattedSize, equals('20.0 MB'));
    });

    test('3. Consulta ao GitHub Releases quando já na versão mais recente', () async {
      final mockClient = MockClient((request) async {
        final payload = {
          'tag_name': 'v1.2.0',
          'published_at': '2026-11-08T10:00:00Z',
          'body': 'Versão atual.',
          'assets': [],
        };
        return http.Response(jsonEncode(payload), 200, headers: {'content-type': 'application/json'});
      });

      final service = UpdateCheckerService(client: mockClient);
      final updateInfo = await service.checkForUpdate(currentVersion: '1.2.0');

      expect(updateInfo.hasUpdate, isFalse);
      expect(updateInfo.latestVersion, equals('1.2.0'));
    });

    test('4. Fallback para apps.json quando GitHub API retorna erro 403 (Rate Limit)', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == AppVersion.latestReleaseApiUrl) {
          return http.Response('API rate limit exceeded', 403);
        }
        if (request.url.toString() == AppVersion.appsJsonUrl) {
          final payload = {
            'name': 'Ministério Pessoal',
            'apps': [
              {
                'name': 'Ministério Pessoal',
                'bundleIdentifier': 'com.ministeriopessoal.territorio',
                'version': '1.2.5',
                'versionDate': '2026-11-12',
                'versionDescription': 'Atualização de emergência via apps.json.',
                'downloadURL': 'https://cdn.example.com/app.ipa',
                'size': 18874368,
              }
            ],
          };
          return http.Response(jsonEncode(payload), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = UpdateCheckerService(client: mockClient);
      final updateInfo = await service.checkForUpdate(currentVersion: '1.2.0');

      expect(updateInfo.hasUpdate, isTrue);
      expect(updateInfo.latestVersion, equals('1.2.5'));
      expect(updateInfo.releaseNotes, contains('Atualização de emergência'));
      expect(updateInfo.downloadUrl, equals('https://cdn.example.com/app.ipa'));
    });

    test('5. Falha de rede resiliente retorna noUpdate sem lançar exceção', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network unreachable / offline');
      });

      final service = UpdateCheckerService(client: mockClient);
      final updateInfo = await service.checkForUpdate(currentVersion: '1.2.0');

      expect(updateInfo.hasUpdate, isFalse);
      expect(updateInfo.currentVersion, equals('1.2.0'));
      expect(updateInfo.latestVersion, equals('1.2.0'));
    });
  });

  group('AppLocaleStrings & i18n Fallback Contract', () {
    test('1. AppLocaleType.fromCode mapeia corretamente e faz fallback para ptBR', () {
      expect(AppLocaleType.fromCode('pt_BR'), equals(AppLocaleType.ptBR));
      expect(AppLocaleType.fromCode('en_US'), equals(AppLocaleType.enUS));
      expect(AppLocaleType.fromCode('es_ES'), equals(AppLocaleType.esES));
      expect(AppLocaleType.fromCode('fr_FR'), equals(AppLocaleType.ptBR));
      expect(AppLocaleType.fromCode(null), equals(AppLocaleType.ptBR));
    });

    test('2. Catálogo em Português (PT-BR) possui todas as strings essenciais', () {
      final strings = AppLocaleStrings.of(AppLocaleType.ptBR);
      expect(strings.appTitle, equals('Ministério Pessoal'));
      expect(strings.navToday, equals('Hoje'));
      expect(strings.navLanguages, equals('Idiomas & Tradução'));
      expect(strings.navTerritoryMaps, equals('Mapas & Territórios'));
      expect(strings.updatesTitle, equals('Atualizações do Aplicativo'));
      expect(strings.territoryCoverageIndex, equals('Índice de Cobertura (IC)'));
      expect(strings.doorstepScheduleTitle, equals('Agendar Retorno na Porta'));
    });

    test('3. Catálogo em Inglês (EN-US) traduz elementos de UI e mantém fallbacks', () {
      final strings = AppLocaleStrings.of(AppLocaleType.enUS);
      expect(strings.appTitle, equals('Field Ministry Assistant'));
      expect(strings.navToday, equals('Today'));
      expect(strings.navStudies, equals('Bible Studies'));
      expect(strings.navLanguages, equals('Languages & Translation'));
      expect(strings.updatesTitle, equals('App Updates'));
      expect(strings.doorstepScheduleTitle, equals('Doorstep Return Visit Booking'));
    });

    test('4. Catálogo em Espanhol (ES-ES) traduz elementos de UI e mantém integridade', () {
      final strings = AppLocaleStrings.of(AppLocaleType.esES);
      expect(strings.appTitle, equals('Ministerio Personal'));
      expect(strings.navToday, equals('Hoy'));
      expect(strings.navStudies, equals('Cursos Bíblicos'));
      expect(strings.navLanguages, equals('Idiomas & Traducción'));
      expect(strings.updatesTitle, equals('Actualizaciones de la Aplicación'));
      expect(strings.doorstepScheduleTitle, equals('Agendar Revisita en la Puerta'));
    });
  });
}
