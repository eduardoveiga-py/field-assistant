import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_auth_service.dart';

void main() {
  group('SupabaseAuthService - Isolamento de Identidade e Migração Pré-Login', () {
    late AppDatabase db;
    late AppRepository repo;
    late SupabaseAuthService unconfiguredAuthService;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      unconfiguredAuthService = SupabaseAuthService();
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Retorna falha graciosa e descritiva quando não configurado', () async {
      expect(unconfiguredAuthService.isConfigured, isFalse);
      expect(unconfiguredAuthService.isAuthenticated, isFalse);
      expect(unconfiguredAuthService.currentUser, isNull);
      expect(unconfiguredAuthService.currentUserId, isNull);

      final signInRes = await unconfiguredAuthService.signInWithEmailPassword(
        email: 'test@example.com',
        password: 'password123',
      );
      expect(signInRes.success, isFalse);
      expect(signInRes.error, contains('não configurado'));

      final signUpRes = await unconfiguredAuthService.signUpWithEmailPassword(
        email: 'test@example.com',
        password: 'password123',
      );
      expect(signUpRes.success, isFalse);
      expect(signUpRes.error, contains('não configurado'));

      final resetRes = await unconfiguredAuthService.resetPasswordForEmail(
        'test@example.com',
      );
      expect(resetRes.success, isFalse);
      expect(resetRes.error, contains('não configurado'));
    });

    test('2. Validação de inputs obrigatórios (e-mail, senha mínima)', () async {
      final resEmpty = await unconfiguredAuthService.signInWithEmailPassword(
        email: '',
        password: '',
      );
      expect(resEmpty.success, isFalse);

      final resShortPw = await unconfiguredAuthService.signUpWithEmailPassword(
        email: 'valid@example.com',
        password: '123',
      );
      expect(resShortPw.success, isFalse);
      expect(resShortPw.error, contains('pelo menos 6 caracteres'));
    });

    test('3. Contagem e associação de registros locais pré-login ao usuário autenticado', () async {
      // 1. Cria dados locais em modo offline (pré-login)
      final person = await repo.createPerson(name: 'Maria Oliveira');
      await repo.createVisit(
        personId: person.id,
        dateTime: DateTime.now(),
        contactType: 'revisita',
        result: 'contato',
      );
      final study = await repo.createStudy(
        title: 'Estudo de Gênesis',
        publicationId: 'lff-book',
        participantPersonIds: [person.id],
      );

      // Verifica que o ownerId padrão é local_user
      expect(study.ownerId, equals('local_user'));

      final preCount = await unconfiguredAuthService.countPreLoginRecords(db);
      expect(preCount, greaterThanOrEqualTo(3));

      // 2. Simula login do usuário "auth-uid-456" e associação dos dados
      const newUserId = 'auth-uid-456';
      final associatedCount = await unconfiguredAuthService.associatePreLoginData(
        repository: repo,
        userId: newUserId,
      );
      expect(associatedCount, greaterThanOrEqualTo(1));

      // Verifica que o estudo agora pertence a auth-uid-456
      final updatedStudy = await repo.getStudyById(study.id);
      expect(updatedStudy?.ownerId, equals(newUserId));
    });

    test('4. Descarte limpo (clean-slate) de registros pré-login para novo usuário', () async {
      final person = await repo.createPerson(name: 'Carlos Santos');
      await repo.createStudy(
        title: 'Estudo Efêmero',
        publicationId: 'lff-book',
        participantPersonIds: [person.id],
      );

      final preCount = await unconfiguredAuthService.countPreLoginRecords(db);
      expect(preCount, greaterThanOrEqualTo(2));

      // Descarta dados locais
      await unconfiguredAuthService.discardPreLoginData(db);

      final postCount = await unconfiguredAuthService.countPreLoginRecords(db);
      expect(postCount, equals(0));

      final allPeople = await repo.getAllPeople();
      expect(allPeople, isEmpty);
    });
  });
}
