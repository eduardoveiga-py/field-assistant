import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_logger.dart';
import '../core/supabase_initializer.dart';
import '../database/app_database.dart';
import '../database/repository.dart';

/// Resultado de operações de autenticação do Supabase.
class AuthActionResult {
  final bool success;
  final String? message;
  final User? user;
  final String? error;

  const AuthActionResult({
    required this.success,
    this.message,
    this.user,
    this.error,
  });

  factory AuthActionResult.ok({String? message, User? user}) =>
      AuthActionResult(success: true, message: message, user: user);

  factory AuthActionResult.fail(String error) =>
      AuthActionResult(success: false, error: error);
}

/// Serviço de Autenticação Supabase com gestão segura de identidade (`owner_id = auth.uid()`).
class SupabaseAuthService {
  final SupabaseClient? clientOverride;

  SupabaseAuthService({this.clientOverride});

  /// Retorna o cliente Supabase disponível (injetado via teste ou inicializado globalmente).
  SupabaseClient? get client {
    if (clientOverride != null) return clientOverride;
    return SupabaseInitializer.clientOrNull;
  }

  /// Retorna `true` se o cliente Supabase estiver configurado e disponível.
  bool get isConfigured => client != null;

  /// Retorna o usuário autenticado atualmente, ou `null` se não houver sessão ativa.
  User? get currentUser => client?.auth.currentUser;

  /// Retorna o UID do usuário autenticado (`auth.uid()`).
  String? get currentUserId => currentUser?.id;

  /// Retorna o email do usuário autenticado.
  String? get currentUserEmail => currentUser?.email;

  /// Retorna `true` se houver usuário autenticado no momento.
  bool get isAuthenticated => currentUser != null;

  /// Retorna a sessão ativa atual.
  Session? get currentSession => client?.auth.currentSession;

  /// Stream reativo para observar mudanças no estado de autenticação (login, logout, token refresh).
  Stream<AuthState> get authStateChanges {
    final c = client;
    if (c == null) {
      return const Stream.empty();
    }
    return c.auth.onAuthStateChange;
  }

  /// Realiza login com e-mail e senha.
  Future<AuthActionResult> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      return AuthActionResult.fail('E-mail e senha são obrigatórios.');
    }

    final c = client;
    if (c == null) {
      return AuthActionResult.fail('Serviço de autenticação não configurado ou offline.');
    }

    try {
      final response = await c.auth.signInWithPassword(
        email: trimmedEmail,
        password: password,
      );
      if (response.user != null) {
        AppLogger.info('SupabaseAuth: login realizado com sucesso para o usuário ${response.user!.id}');
        return AuthActionResult.ok(
          message: 'Login realizado com sucesso.',
          user: response.user,
        );
      }
      return AuthActionResult.fail('Não foi possível autenticar o usuário.');
    } on AuthException catch (e) {
      AppLogger.warning('SupabaseAuth: falha na autenticação (${e.statusCode}): ${e.message}');
      return AuthActionResult.fail(e.message);
    } catch (e, st) {
      AppLogger.error('SupabaseAuth: erro inesperado durante o login', e, st);
      return AuthActionResult.fail('Erro de conexão ou serviço indisponível: $e');
    }
  }

  /// Realiza cadastro de nova conta com e-mail e senha.
  Future<AuthActionResult> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      return AuthActionResult.fail('E-mail e senha são obrigatórios.');
    }

    if (password.length < 6) {
      return AuthActionResult.fail('A senha deve ter pelo menos 6 caracteres.');
    }

    final c = client;
    if (c == null) {
      return AuthActionResult.fail('Serviço de autenticação não configurado ou offline.');
    }

    try {
      final response = await c.auth.signUp(
        email: trimmedEmail,
        password: password,
      );
      if (response.user != null) {
        AppLogger.info('SupabaseAuth: cadastro realizado para o usuário ${response.user!.id}');
        return AuthActionResult.ok(
          message: 'Cadastro realizado com sucesso! Verifique seu e-mail caso a confirmação seja necessária.',
          user: response.user,
        );
      }
      return AuthActionResult.fail('Não foi possível concluir o cadastro.');
    } on AuthException catch (e) {
      AppLogger.warning('SupabaseAuth: falha no cadastro: ${e.message}');
      return AuthActionResult.fail(e.message);
    } catch (e, st) {
      AppLogger.error('SupabaseAuth: erro inesperado no cadastro', e, st);
      return AuthActionResult.fail('Erro de conexão ou serviço indisponível: $e');
    }
  }

  /// Encerra a sessão do usuário atual.
  Future<AuthActionResult> signOut() async {
    final c = client;
    if (c == null) {
      return AuthActionResult.ok(message: 'Sessão encerrada localmente.');
    }

    try {
      await c.auth.signOut();
      AppLogger.info('SupabaseAuth: logout realizado com sucesso.');
      return AuthActionResult.ok(message: 'Desconectado com sucesso.');
    } on AuthException catch (e) {
      AppLogger.warning('SupabaseAuth: erro no logout: ${e.message}');
      return AuthActionResult.fail(e.message);
    } catch (e, st) {
      AppLogger.error('SupabaseAuth: exceção ao deslogar', e, st);
      return AuthActionResult.fail('Erro ao encerrar sessão: $e');
    }
  }

  /// Envia link de recuperação/redefinição de senha para o e-mail informado.
  Future<AuthActionResult> resetPasswordForEmail(String email) async {
    final c = client;
    if (c == null) {
      return AuthActionResult.fail('Serviço de autenticação não configurado ou offline.');
    }

    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      return AuthActionResult.fail('Informe o e-mail cadastrado.');
    }

    try {
      await c.auth.resetPasswordForEmail(trimmedEmail);
      AppLogger.info('SupabaseAuth: link de redefinição de senha solicitado para $trimmedEmail');
      return AuthActionResult.ok(
        message: 'Link de recuperação enviado para seu e-mail se cadastrado.',
      );
    } on AuthException catch (e) {
      AppLogger.warning('SupabaseAuth: falha ao solicitar redefinição: ${e.message}');
      return AuthActionResult.fail(e.message);
    } catch (e, st) {
      AppLogger.error('SupabaseAuth: exceção na recuperação de senha', e, st);
      return AuthActionResult.fail('Erro ao solicitar redefinição de senha: $e');
    }
  }

  /// Verifica se existem registros criados no banco de dados local antes do login.
  Future<int> countPreLoginRecords(AppDatabase db) async {
    int total = 0;
    try {
      final studies = await (db.select(db.bibleStudies)
            ..where((t) => t.ownerId.equals('local_user') & t.deletedAt.isNull()))
          .get();
      total += studies.length;

      final people = await (db.select(db.people)
            ..where((t) => t.deletedAt.isNull()))
          .get();
      total += people.length;

      final visits = await (db.select(db.visits)
            ..where((t) => t.deletedAt.isNull()))
          .get();
      total += visits.length;
    } catch (e) {
      AppLogger.warning('SupabaseAuth: erro ao contar registros pré-login: $e');
    }
    return total;
  }

  /// Associa os registros criados pré-login ao usuário autenticado (`userId`).
  /// Atualiza o `ownerId` em tabelas com a coluna de ownership e enfileira
  /// operações pendentes de outbox para envio ao Supabase com `owner_id = userId`.
  Future<int> associatePreLoginData({
    required AppRepository repository,
    required String userId,
  }) async {
    final db = repository.db;
    int associatedCount = 0;

    await db.transaction(() async {
      // 1. Atualiza BibleStudies com ownerId local_user
      final updatedStudies = await (db.update(db.bibleStudies)
            ..where((t) => t.ownerId.equals('local_user')))
          .write(
        BibleStudiesCompanion(
          ownerId: drift.Value(userId),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
      associatedCount += updatedStudies;

      // 2. Reenfileira todas as operações pendentes ou com falha na syncQueue
      final failedOps = await (db.select(db.syncQueue)
            ..where((t) => t.status.equals('failed')))
          .get();
      for (final op in failedOps) {
        await (db.update(db.syncQueue)..where((t) => t.id.equals(op.id))).write(
          const SyncQueueCompanion(
            status: drift.Value('pending'),
            attempts: drift.Value(0),
          ),
        );
      }
    });

    AppLogger.info('SupabaseAuth: $associatedCount registros pré-login associados ao usuário $userId');
    return associatedCount;
  }

  /// Descarta com segurança os registros locais criados previamente (modo clean-slate)
  /// para carregar puramente a conta remota autenticada do usuário.
  Future<void> discardPreLoginData(AppDatabase db) async {
    await db.transaction(() async {
      await db.delete(db.syncQueue).go();
      await db.delete(db.studySessions).go();
      await db.delete(db.studyParticipants).go();
      await db.delete(db.studentManualOrder).go();
      await db.delete(db.bibleStudies).go();
      await db.delete(db.visits).go();
      await db.delete(db.appointments).go();
      await db.delete(db.activityRecords).go();
      await db.delete(db.voiceNotes).go();
      await db.delete(db.phoneContacts).go();
      await db.delete(db.territoryLandmarks).go();
      await db.delete(db.familyTies).go();
      await db.delete(db.ministryExperiences).go();
      await db.delete(db.personPhotos).go();
      await db.delete(db.personPublications).go();
      await db.delete(db.researchArticles).go();
      await db.delete(db.researchTags).go();
      await db.delete(db.territorySectors).go();
      await db.delete(db.people).go();
    });
    AppLogger.info('SupabaseAuth: dados pré-login descartados para inicialização limpa.');
  }
}

/// Provider do serviço de autenticação Supabase
final supabaseAuthServiceProvider = Provider<SupabaseAuthService>((ref) {
  return SupabaseAuthService();
});

/// StreamProvider reativo do usuário autenticado no Supabase
final currentUserStreamProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(supabaseAuthServiceProvider);
  return authService.authStateChanges.map((state) => state.session?.user);
});
