import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/territory/routing/external_navigation_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExternalNavigationLauncher URI Builder & Encoding Tests', () {
    test('Builds Organic Maps URI without origin (map view)', () {
      final uri = ExternalNavigationLauncher.buildOrganicMapsUri(
        lat: -3.1022,
        lng: -60.0250,
        label: 'Rua São Sebastião, 100',
      );

      expect(uri.scheme, equals('om'));
      expect(uri.host, equals('map'));
      expect(uri.queryParameters['v'], equals('1'));
      expect(uri.queryParameters['ll'], equals('-3.1022,-60.025'));
      expect(uri.queryParameters['n'], equals('Rua São Sebastião, 100'));
      expect(
        uri.toString(),
        contains('n=Rua%20S%C3%A3o%20Sebasti%C3%A3o%2C%20100'),
      );
    });

    test('Builds Organic Maps URI with GPS origin (turn-by-turn route)', () {
      final uri = ExternalNavigationLauncher.buildOrganicMapsUri(
        lat: -3.1022,
        lng: -60.0250,
        label: 'Aldeia São Jerônimo Ticuna #1 & Especial?',
        originLat: -3.1000,
        originLng: -60.0200,
      );

      expect(uri.scheme, equals('om'));
      expect(uri.host, equals('route'));
      expect(uri.queryParameters['sll'], equals('-3.1,-60.02'));
      expect(uri.queryParameters['dll'], equals('-3.1022,-60.025'));
      expect(uri.queryParameters['type'], equals('vehicle'));
      expect(
        uri.queryParameters['dname'],
        equals('Aldeia São Jerônimo Ticuna #1 & Especial?'),
      );
      // Ensures special characters like &, #, ? are percent-encoded
      expect(
        uri.toString(),
        contains(
          'Aldeia%20S%C3%A3o%20Jer%C3%B4nimo%20Ticuna%20%231%20%26%20Especial%3F',
        ),
      );
    });

    test('Builds Apple Maps URI with encoded label', () {
      final uri = ExternalNavigationLauncher.buildAppleMapsUri(
        lat: -23.5505,
        lng: -46.6333,
        label: 'Praça da Sé, Centro',
      );

      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('maps.apple.com'));
      expect(uri.queryParameters['daddr'], equals('-23.5505,-46.6333'));
      expect(uri.queryParameters['q'], equals('Praça da Sé, Centro'));
      expect(
        uri.toString(),
        contains('q=Pra%C3%A7a%20da%20S%C3%A9%2C%20Centro'),
      );
    });

    test('Builds Google Maps URI with destination and optional origin', () {
      final uriNoOrigin = ExternalNavigationLauncher.buildGoogleMapsUri(
        lat: -3.1022,
        lng: -60.0250,
      );
      expect(uriNoOrigin.scheme, equals('https'));
      expect(uriNoOrigin.host, equals('www.google.com'));
      expect(uriNoOrigin.path, equals('/maps/dir/'));
      expect(uriNoOrigin.queryParameters['api'], equals('1'));
      expect(
        uriNoOrigin.queryParameters['destination'],
        equals('-3.1022,-60.025'),
      );

      final uriWithOrigin = ExternalNavigationLauncher.buildGoogleMapsUri(
        lat: -3.1022,
        lng: -60.0250,
        originLat: -3.1000,
        originLng: -60.0200,
      );
      expect(uriWithOrigin.queryParameters['origin'], equals('-3.1,-60.02'));
      expect(
        uriWithOrigin.queryParameters['destination'],
        equals('-3.1022,-60.025'),
      );
    });
  });

  group('ExternalNavigationLauncher Fallback & Execution Tests', () {
    test('Launches Organic Maps directly when app is supported', () async {
      Uri? launchedUri;
      final success = await ExternalNavigationLauncher.launchNavigation(
        app: ExternalNavigationApp.organicMaps,
        lat: -3.1022,
        lng: -60.0250,
        label: 'Destino Teste',
        canLaunchChecker: (uri) async => true,
        urlLauncher: (uri, {mode = LaunchMode.externalApplication}) async {
          launchedUri = uri;
          return true;
        },
      );

      expect(success, isTrue);
      expect(launchedUri, isNotNull);
      expect(launchedUri!.scheme, equals('om'));
    });

    test(
      'Falls back safely to Google Maps when Organic Maps is not installed',
      () async {
        final checkedUris = <Uri>[];
        Uri? launchedUri;

        final success = await ExternalNavigationLauncher.launchNavigation(
          app: ExternalNavigationApp.organicMaps,
          lat: -3.1022,
          lng: -60.0250,
          label: 'Destino Teste',
          canLaunchChecker: (uri) async {
            checkedUris.add(uri);
            // Simula Organic Maps não instalado
            if (uri.scheme == 'om') return false;
            // Google Maps suportado
            return true;
          },
          urlLauncher: (uri, {mode = LaunchMode.externalApplication}) async {
            launchedUri = uri;
            return true;
          },
        );

        // Retorna false indicando que houve fallback
        expect(success, isFalse);
        expect(checkedUris.length, equals(2));
        expect(checkedUris.first.scheme, equals('om'));
        expect(checkedUris.last.host, equals('www.google.com'));
        expect(launchedUri, isNotNull);
        expect(launchedUri!.host, equals('www.google.com'));
      },
    );

    test('Launches Apple Maps directly when supported', () async {
      Uri? launchedUri;
      final success = await ExternalNavigationLauncher.launchNavigation(
        app: ExternalNavigationApp.appleMaps,
        lat: -23.5505,
        lng: -46.6333,
        label: 'São Paulo',
        canLaunchChecker: (uri) async => true,
        urlLauncher: (uri, {mode = LaunchMode.externalApplication}) async {
          launchedUri = uri;
          return true;
        },
      );

      expect(success, isTrue);
      expect(launchedUri, isNotNull);
      expect(launchedUri!.host, equals('maps.apple.com'));
    });
  });

  group('External Navigation ModalBottomSheet UI Tests', () {
    testWidgets(
      'Displays options for Organic Maps and Google Maps in BottomSheet',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () =>
                      ExternalNavigationLauncher.showNavigationSheet(
                        ctx,
                        lat: -3.1022,
                        lng: -60.0250,
                        label: 'Marco Histórico',
                      ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();

        expect(find.text('Navegar até "Marco Histórico"'), findsOneWidget);
        expect(find.byKey(const Key('nav_opt_organic_maps')), findsOneWidget);
        expect(find.text('Organic Maps'), findsOneWidget);
        expect(find.byKey(const Key('nav_opt_google_maps')), findsOneWidget);
        expect(find.text('Google Maps'), findsOneWidget);
      },
    );

    testWidgets(
      'Displays Apple Maps option when isApple is true via showNavigationChooser',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () =>
                      ExternalNavigationLauncher.showNavigationChooser(
                        ctx,
                        lat: -23.5505,
                        lng: -46.6333,
                        label: 'Praça da Sé',
                        isApple: true,
                      ),
                  child: const Text('Abrir Apple'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Apple'));
        await tester.pumpAndSettle();

        expect(find.text('Navegar até "Praça da Sé"'), findsOneWidget);
        expect(find.byKey(const Key('nav_opt_organic_maps')), findsOneWidget);
        expect(find.byKey(const Key('nav_opt_apple_maps')), findsOneWidget);
        expect(find.text('Apple Maps'), findsOneWidget);
        expect(find.byKey(const Key('nav_opt_google_maps')), findsOneWidget);
      },
    );
  });
}
