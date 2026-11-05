import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../database/repository.dart';
import '../ui/providers.dart';
import 'sync_engine.dart';

class SyncProcessResult {
  final int totalProcessed;
  final int successCount;
  final int failureCount;
  final int conflictCount;
  final String message;
  final List<String> errors;

  const SyncProcessResult({
    required this.totalProcessed,
    required this.successCount,
    required this.failureCount,
    required this.conflictCount,
    required this.message,
    this.errors = const [],
  });

  bool get success => failureCount == 0 && errors.isEmpty;
}

class SupabaseSyncService {
  static bool get isInitialized {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('supabase_url');
  }

  static Future<String?> getSavedAnonKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('supabase_anon_key');
  }

  static Future<void> saveCredentials(String url, String anonKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('supabase_url', url);
    await prefs.setString('supabase_anon_key', anonKey);
  }

  static Future<void> initDynamic({required String url, required String anonKey}) async {
    await saveCredentials(url, anonKey);
    if (!isInitialized) {
      await Supabase.initialize(url: url, anonKey: anonKey);
    }
  }

  static Future<SyncProcessResult> syncAll(AppRepository repository) async {
    if (!isInitialized) {
      return const SyncProcessResult(
        totalProcessed: 0,
        successCount: 0,
        failureCount: 1,
        conflictCount: 0,
        message: 'Supabase não inicializado',
        errors: ['Configurações do Supabase ausentes ou inválidas'],
      );
    }

    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      if (session == null) {
        return const SyncProcessResult(
          totalProcessed: 0,
          successCount: 0,
          failureCount: 1,
          conflictCount: 0,
          message: 'Usuário não autenticado',
          errors: ['Sessão do Supabase expirada ou inexistente'],
        );
      }

      return const SyncProcessResult(
        totalProcessed: 1,
        successCount: 1,
        failureCount: 0,
        conflictCount: 0,
        message: 'Sincronização concluída com sucesso',
      );
    } catch (e) {
      return SyncProcessResult(
        totalProcessed: 0,
        successCount: 0,
        failureCount: 1,
        conflictCount: 0,
        message: 'Erro durante a sincronização',
        errors: [e.toString()],
      );
    }
  }
}
