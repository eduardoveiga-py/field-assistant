import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/ui/widgets/pin_auth_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BiometricAuthService - Zero Bypass & PIN Security', () {
    late BiometricAuthService authService;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      authService = BiometricAuthService();
    });

    test('Sessão inicia estritamente bloqueada', () {
      expect(authService.isSessionUnlocked, isFalse);
    });

    test('authenticate() rejeita acesso sem biometria e sem contexto UI (sem bypass)', () async {
      final result = await authService.authenticate(
        localizedReason: 'Tentativa sem biometria e sem contexto',
      );
      expect(result, isFalse, reason: 'Zero bypass: sem biometria e sem contexto deve retornar false.');
      expect(authService.isSessionUnlocked, isFalse);
    });

    test('hasPin() retorna false quando nenhum PIN foi cadastrado', () async {
      expect(await authService.hasPin(), isFalse);
    });

    test('setPin() rejeita PINs com tamanho menor que 4 ou maior que 8 dígitos', () async {
      expect(() => authService.setPin('123'), throwsArgumentError);
      expect(() => authService.setPin('123456789'), throwsArgumentError);
    });

    test('setPin() persiste hash e salt seguros e desbloqueia a sessão', () async {
      final success = await authService.setPin('2580');
      expect(success, isTrue);
      expect(await authService.hasPin(), isTrue);
      expect(authService.isSessionUnlocked, isTrue);

      const storage = FlutterSecureStorage();
      final salt = await storage.read(key: 'app_security_pin_salt');
      final hash = await storage.read(key: 'app_security_pin_hash');

      expect(salt, isNotNull);
      expect(salt!.length, equals(32)); // 16 bytes em hex = 32 chars
      expect(hash, isNotNull);
      expect(hash!.length, equals(64)); // SHA-256 = 64 hex chars
      expect(hash, isNot(contains('2580'))); // O PIN nunca deve estar em texto claro
    });

    test('verifyPin() valida com precisão e rejeita PIN incorreto', () async {
      await authService.setPin('4321');
      authService.lockSession();
      expect(authService.isSessionUnlocked, isFalse);

      final wrongResult = await authService.verifyPin('9999');
      expect(wrongResult, isFalse);
      expect(authService.isSessionUnlocked, isFalse);

      final rightResult = await authService.verifyPin('4321');
      expect(rightResult, isTrue);
      expect(authService.isSessionUnlocked, isTrue);
    });

    test('lockSession() revoga imediatamente o acesso da sessão', () async {
      await authService.setPin('1234');
      expect(authService.isSessionUnlocked, isTrue);

      authService.lockSession();
      expect(authService.isSessionUnlocked, isFalse);
    });

    test('changePin() altera com sucesso quando PIN atual é fornecido', () async {
      await authService.setPin('1111');
      authService.lockSession();

      final failChange = await authService.changePin(currentPin: '0000', newPin: '2222');
      expect(failChange, isFalse);

      final successChange = await authService.changePin(currentPin: '1111', newPin: '2222');
      expect(successChange, isTrue);

      authService.lockSession();
      expect(await authService.verifyPin('1111'), isFalse);
      expect(await authService.verifyPin('2222'), isTrue);
    });

    test('Proteção contra força bruta: 5 tentativas incorretas acionam PinLockoutException', () async {
      await authService.setPin('1234');
      authService.lockSession();

      for (int i = 0; i < 5; i++) {
        final res = await authService.verifyPin('000$i');
        expect(res, isFalse);
      }

      expect(() => authService.verifyPin('1234'), throwsA(isA<PinLockoutException>()));
    });
  });

  group('PinAuthDialog & PinSetupDialog UI Flow', () {
    late BiometricAuthService authService;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      authService = BiometricAuthService();
    });

    testWidgets('PinSetupDialog cadastra PIN com sucesso', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await PinSetupDialog.show(context, biometricAuth: authService);
              },
              child: const Text('Open Setup'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Setup'));
      await tester.pumpAndSettle();

      expect(find.text('Criar PIN de Segurança'), findsOneWidget);

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.at(0), '5678');
      await tester.enterText(textFields.at(1), '5678');
      await tester.pump();

      await tester.tap(find.text('Salvar PIN'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(await authService.hasPin(), isTrue);
      expect(authService.isSessionUnlocked, isTrue);
    });

    testWidgets('PinAuthDialog valida PIN cadastrado e desbloqueia', (tester) async {
      await authService.setPin('7890');
      authService.lockSession();

      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await PinAuthDialog.show(context, biometricAuth: authService);
              },
              child: const Text('Open Auth'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Auth'));
      await tester.pumpAndSettle();

      expect(find.text('PIN de Segurança'), findsOneWidget);

      final pinInput = find.byType(TextField);
      await tester.enterText(pinInput, '7890');
      await tester.pump();

      await tester.tap(find.text('Desbloquear'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(authService.isSessionUnlocked, isTrue);
    });
  });
}
