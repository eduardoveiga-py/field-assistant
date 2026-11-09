# Auditoria Técnica — Field Assistant (Ministério Pessoal)

**Data:** 2026-11-09 · **Commit auditado:** `acd17b4a4fae08cb49a1f14fdc4d12a68f077bd2` (branch `arena/c1134163-field-assistant`) · **Escopo:** `lib/`, `pubspec.yaml`, `android/`, `web/`, `.github/workflows/`, `docs/`
**Método:** análise estática profunda (leitura direta do código; Flutter SDK não disponível no ambiente de auditoria — nenhum código foi compilado nem executado). Todas as citações `arquivo:linha` referem-se ao commit acima.

---

## 1. Resumo Executivo da Saúde do Código

O Field Assistant tem **fundação melhor que a média de apps offline-first** (backup com AES-256-GCM + PBKDF2, merge a nível de campo no `SyncEngine`, cache de tiles com controle de concorrência conforme política do OSM, `AppSettingsManager` com fila serializada FIFO, suíte de testes com 46 arquivos). Porém, a camada de sincronização — o coração do produto — contém **falhas que destroem dados silenciosamente**:

1. **A fila de sync é um beco sem saída:** `markSyncOperationFailed()` move a operação para `status='failed'`, mas `getPendingSyncOperations()` só seleciona `'pending' | 'in_progress'`. Nada nunca devolve uma op para `'pending'`. Uma única falha transitória (rede, token, 5xx) **órfã a mutação para sempre** — e todo o retry com backoff exponencial em `processQueue()` é código morto. O usuário vê "salvo localmente" e os dados nunca chegam à nuvem nem em outro dispositivo.
2. **O push sobrescreve o remoto às cegas:** `upsert(remotePayload)` sem comparar revisão/`updated_at` remoto. Como `_runSync()` faz **push antes de pull**, as alterações de outro dispositivo são destruídas *antes* que o merge a nível de campo tenha chance de rodar. O merge existe, mas roda tarde demais.
3. **Na Web, o app pode "funcionar" com um banco de dados falso:** se o WASM não carregar (MIME type, CSP, navegador), `_FallbackWebQueryExecutor` aceita toda escrita e descarta tudo silenciosamente — o usuário digita por horas e **perde 100% dos dados sem nenhum erro**.

**Veredito:** o app é funcional para uso single-device offline, mas **não está seguro para distribuição multi-dispositivo nem para a Web** no estado atual. Os 5 problemas CRÍTICOS da seção 3 devem ser corrigidos antes de qualquer release pública.

### Placar de severidade

| Severidade | Qtd | Tema predominante |
|---|---|---|
| `[CRÍTICO]` | 5 | Integridade da sincronização e perda silenciosa de dados |
| `[ALTO]` | 10 | Supply chain de atualização, vazamento/pior caso de armazenamento, vazamento de widgets, queries inline |
| `[MÉDIO]` | 13 | Timestamps triplos, error-swallowing sistêmico, PII/identificadores hardcoded, dívida estrutural |

---

## 2. Formato das entradas

Cada problema traz: **Localização** (arquivo → classe/método), **Diagnóstico técnico** (mecanismo exato), **Refatoração** (antes/depois). Itens marcados com ⚠️ encadeiam-se: corrigir na ordem indicada na seção 5.

---

## 3. `[CRÍTICO]` — Perda silenciosa de dados

### C1. ⚠️ Fila de sincronização: operação `failed` nunca retorna — retry/backoff é código morto

**Localização:** `lib/database/repository.dart` → `getPendingSyncOperations()` (l. 1465), `markSyncOperationFailed()` (l. 1484); `lib/sync/supabase_sync_service.dart` → `processQueue()` (l. 1585, backoff em l. 1632–1645)

**Diagnóstico:**
```dart
// repository.dart:1465 — só PENDING ou IN_PROGRESS são retornados:
(tbl) => tbl.status.equals('pending') | tbl.status.equals('in_progress'),

// repository.dart:1491 — ao falhar, o status vira FAILED para SEMPRE:
SyncQueueCompanion(status: const Value('failed'), attempts: Value(op.attempts + 1), ...)
```
Nenhuma linha do código transiciona `failed → pending` (verificado por busca global em `lib/`). Consequência: **qualquer erro transitório** (DNS, timeout de 5s do PostgREST, refresh de token, 413 de payload grande, 5xx do Supabase) marca a op como `failed`, ela sai da fila de vez, e os dados ficam apenas no SQLite local para sempre. O backoff exponencial (`pow(2, attempts)`) e o limite de 5 tentativas em `processQueue()` são **inalcançáveis** — `pendingOps` nunca contém uma op com `attempts > 0`. Ademais, o cálculo de backoff usa `now.difference(op.createdAt)` em vez do horário da última tentativa, o que seria errado mesmo se alcançável.

**Cenário de produção:** publicador em campo com 2G/3G intermitente edita um contato; um único pacote falha → `failed` → 45 dias depois o contato ainda não sincronizou com o iPad de casa, e a UI mostra "salvo localmente" sem distinção.

**Refatoração:**
```dart
// ── ANTES (repository.dart) ──────────────────────────────
Future<void> markSyncOperationFailed(String id, String error) async {
  final op = await (db.select(db.syncQueue)..where((t) => t.id.equals(id))).getSingleOrNull();
  if (op != null) {
    await (db.update(db.syncQueue)..where((t) => t.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value('failed'),               // ← beco sem saída
        attempts: Value(op.attempts + 1),
        lastError: Value(error),
      ),
    );
  }
}

// ── DEPOIS ───────────────────────────────────────────────
static const int maxSyncAttempts = 8;
static const Duration baseBackoff = Duration(seconds: 15);

static Duration backoffFor(int attempts) =>
    Duration(seconds: (baseBackoff.inSeconds * pow(2, attempts)).clamp(15, 1800).toInt());

Future<void> markSyncOperationFailed(String id, String error) async {
  final op = await (db.select(db.syncQueue)..where((t) => t.id.equals(id))).getSingleOrNull();
  if (op == null) return;
  final attempts = op.attempts + 1;
  final deadLetter = attempts >= maxSyncAttempts;
  await (db.update(db.syncQueue)..where((t) => t.id.equals(id))).write(
    SyncQueueCompanion(
      // Permanece 'pending' com backoff exponencial; só vira 'failed' (dead-letter)
      // após o limite — e aí a UI DEVE exibir o erro e oferecer "tentar novamente".
      status: Value(deadLetter ? 'failed' : 'pending'),
      attempts: Value(attempts),
      lastError: Value(error),
      lastAttemptAt: Value(DateTime.now()),   // ← nova coluna (schema v5) ou reutilizar updatedAt do row
    ),
  );
}

// getPendingSyncOperations passa a respeitar o backoff:
Future<List<SyncQueueEntry>> getPendingSyncOperations() {
  final now = DateTime.now();
  return (db.select(db.syncQueue)
        ..where((t) =>
            (t.status.equals('pending') | t.status.equals('in_progress')) &
            (t.lastAttemptAt.isNull() |
             t.lastAttemptAt.isSmallerOrEqualValue(now.subtract(backoffForLastAttempt(t)))))
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
      .get();
}
```
Mudanças mínimas no schema (v5): `ALTER TABLE sync_queue ADD COLUMN last_attempt_at INTEGER NULL;` + bloco `if (from < 5)` na `MigrationStrategy` propagando erros (não silenciando). Adicionar em Configurações uma entrada "Alterações não sincronizadas: N — tentar novamente" lendo `SELECT count(*) FROM sync_queue WHERE status='failed'`.

---

### C2. ⚠️ Push destrói alterações remotas: `upsert` cego sem verificação de revisão (pull acontece tarde demais)

**Localização:** `lib/sync/supabase_sync_service.dart` → `_runSync()` (l. ~1436) e `processQueue()` (l. 1660)

**Diagnóstico:** o ciclo é `processQueue()` (push) → `fetchRemoteChanges()` (pull). O push executa
```dart
await client.from(tableName).upsert(remotePayload);   // l. 1660 — sem WHERE, sem comparar revision
```
Nenhum passo do push consulta o estado remoto. Cenário multi-dispositivo:
1. Dispositivo A e B ambos com pessoa `p` na revisão 3 (revision só incrementa localmente).
2. A edita `phone` offline → revisão local 4 → push: upsert cego → remoto vira A@4. ✔
3. B edita `address` offline → revisão local 4 → push: upsert cego com o snapshot completo de B (que contém o `phone` **antigo**) → **o telefone corrigido por A é sobrescrito silenciosamente pelo valor antigo de B**. Sem conflito, sem merge, sem erro.
4. No pull posterior, B não tem mais a op pendente (já foi marcada `synced`), então o `SyncEngine.mergeEntities` nunca testemunha a divergência.

O `SyncEngine` (field-level merge com `_base`) só é aplicado em `_applyRemoteRecord()` quando **há operação pendente na fila** — ou seja, o merge existe mas nunca protege a janela entre o push de B e o pull de B. Tombstones: o DELETE remoto também é um `delete().eq('id', ...)` cego (l. 1697), apagando a linha remota mesmo que outro dispositivo a tenha atualizado depois.

**Refatoração (duas camadas):**
```dart
// ── Camada 1 (app): pré-check de revisão no push ──────────────────────────
if (operation == 'INSERT' || operation == 'UPDATE') {
  final remoteRow = await client
      .from(tableName)
      .select('revision, updated_at')
      .eq('id', op.entityId)
      .maybeSingle();

  final remoteRev = (remoteRow?['revision'] as num?)?.toInt() ?? 0;
  final localRev  = remotePayload['revision'] as int? ?? 1;

  if (remoteRow != null && remoteRev > localRev) {
    // Remoto divergiu: merge 3-way com a base antes de sobrescrever.
    final fullRemote = await client.from(tableName).select().eq('id', op.entityId).single();
    final baseData = _baseOf(op);                       // normalizeRemotePayload(payload['_base'])
    final merged = SyncEngine.mergeEntities(
      entityType: op.entityType, entityId: op.entityId,
      localData: normalizeRemotePayload(remotePayload),
      remoteData: normalizeRemotePayload(fullRemote),
      baseData: baseData,
    );
    if (merged.hasConflict) {
      await repository.markSyncOperationConflict(op.id, merged.conflicts); // status 'conflict' + UI
      continue;
    }
    remotePayload
      ..addAll(toRemotePayload(op.entityType, merged.mergedData))
      ..['revision'] = (remoteRev + 1);
  }
  await client.from(tableName).upsert(remotePayload);
  ...
}

// ── Camada 2 (servidor, robusta): upsert condicional via RPC ──────────────
// Supabase RPC `sync_upsert(p_table text, p_payload jsonb)`:
//   INSERT ... ON CONFLICT (id) DO UPDATE
//   SET ...   WHERE people.revision <= (p_payload->>'revision')::int;
// Se 0 linhas afetadas → falha otimista → app enfileira merge, nunca sobrescreve às cegas.
```
DELETE: trocar `delete().eq('id')` por tombstone (`update deleted_at`) ou no mínimo `delete().eq('id', id).lte('revision', localRev)`.

---

### C3. ⚠️ Web: `_FallbackWebQueryExecutor` — banco SQLite falso que descarta 100% das escritas em silêncio

**Localização:** `lib/database/connection/connection_web.dart` → `constructDb()` (l. 167), classes `_FallbackWebQueryExecutor`/`_FallbackWebTransactionExecutor` (l. 172–279)

**Diagnóstico:** quando o WASM não carrega (servidor sem `Content-Type: application/wasm`, CSP restringindo `wasm-eval`/`unsafe-eval`, navegador antigo), o código "degrada graciosamente" para um executor no-op:
```dart
Future<int> runInsert(...) async => 0;         // escreve? não escreve. retorna sucesso.
Future<List<Map<String, Object?>>> runSelect(...) async => [];  // lê? retorna vazio.
Future<void> runCustom(...) async {}           // migrações? não acontecem.
```
Consequência: o app abre, renderiza, aceita cadastros, mostra formulários — e **nada persiste**. Sem exceção, sem log obrigatório, sem banner. O usuário perde horas de cadastro de campo achando que está offline-first. É o oposto exato do objetivo do projeto (`offline-first`).

**Refatoração:** nunca degradar persistência silenciosamente. Falhar alto e bloquear o uso:
```dart
// connection_web.dart — remover _FallbackWebQueryExecutor por completo.
// Ao final da cadeia de tentativas:
throw StateError(
  'Banco local indisponível: o navegador bloqueou o carregamento de sqlite3.wasm / '
  'drift_worker.js. Verifique o cabeçalho Content-Type: application/wasm e a CSP '
  '(script-src/wasm-unsafe-eval) e recarregue. Nenhum dado foi perdido — nada foi salvo.',
);

// main.dart — capturar e exibir tela fatal visível (em vez de runApp(app quebrado)):
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseSyncService.initialize();
  } catch (e) {
    AppLogger.error('Supabase init: $e (seguindo offline-first)');
  }
  // O provider de banco (repositoryProvider/databaseProvider) propaga o StateError;
  // envolver o MaterialApp em um guardião que renderiza tela de erro de persistência:
  runApp(const ProviderScope(child: MinisterioPessoalApp()));
}
// + em ErrorWidget.builder / em um DbHealthGate no topo da árvore:
//   se LazyDatabase lançar StateError → Scaffold(body: FatalPersistenceScreen(message))
```
Teste de regressão recomendado: `test/database/web_fallback_test.dart` simulando MIME inválido e assertando que `constructDb()` lança em vez de retornar executor no-op.

---

### C4. ⚠️ Comparação de `updatedAt` na recepção remota usa `DateTime.tryParse` sobre **milliseconds-since-epoch** → sempre `null` → degrada para revisão

**Localização:** `lib/sync/supabase_sync_service.dart` → `_applyRemoteRecord()` (l. 1387–1410)

**Diagnóstico:** `_getLocalMap()` (l. ~1050) retorna `row.toJson()`. O serializer padrão do drift escreve `DateTime` como **inteiro em milissegundos** (`serializeDateTimeValuesAsString: false` — confirmado no fonte do drift: `_DefaultValueSerializer`). Então `localMap['updatedAt']` é `1731052800000` (int). O código faz:
```dart
final localUpdatedAtStr = localMap['updatedAt']?.toString();          // "1731052800000"
final localUpdated = DateTime.tryParse(localUpdatedAtStr);            // ← null! "1731..." não é ISO
final isRemoteNewer = remoteUpdated != null && localUpdated != null
    ? (remoteUpdated.isAfter(localUpdated) || ...)
    : remoteRev >= localRev;                                          // ← sempre este ramo
```
`DateTime.tryParse("1731052800000")` retorna `null` → a comparação por timestamp **nunca executa** → a decisão de aplicar revisão remota degrada para `remoteRev >= localRev`. Revisões locais e remotas frequentemente são iguais (cada nó incrementa a própria), logo `remoteRev >= localRev` é `true` em empate → **o remoto sobrescreve dados locais mais novos sem nenhum sinal**. E quando o remoto está de fato atrás (rev menor), a alteração remota legítima é ignorada — divergência permanente.

Agravante: `localMap` carrega timestamps como ms, enquanto o lado remoto é ISO-8601 — duas encodings no mesmo comparador. O mesmo padrão (`tryParse` sobre valor que pode ser int) aparece em `retryPendingMediaDownloads` e nas comparações de `last_synced_at_*` (estas últimas funcionam porque `appKvStore` grava ISO, mas o contrato é implícito).

**Refatoração:**
```dart
/// Ponto único de parse de timestamp aceitando TODOS os formatos em trânsito:
/// int (ms ou s), double, ISO-8601 com/sem 'Z', ou DateTime.
static DateTime? _parseTimestamp(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toUtc();
  if (v is int) {
    // Heurística: > 1e12 → ms; entre 1e9 e 1e12 → s (datas entre 2001 e 33658).
    final ms = v > 1000000000000 ? v : v * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
  if (v is double) return _parseTimestamp(v.toInt());
  final s = v.toString();
  return DateTime.tryParse(s) ??
      (() { final n = int.tryParse(s); return n == null ? null : _parseTimestamp(n); })();
}

// No bloco problemático:
final localUpdated  = _parseTimestamp(localMap['updatedAt']);
final remoteUpdated = _parseTimestamp(normalized['updatedAt'] ?? normalized['updated_at']);
final isRemoteNewer = (remoteUpdated != null && localUpdated != null)
    ? !remoteUpdated.isBefore(localUpdated)
    : (remoteUpdated != null) || remoteRev >= localRev;
```
Bônus: fazer `_getLocalMap` devolver os timestamps já normalizados (via `_isoString(row.updatedAt)`) em vez de depender de `toJson()` — elimina a ambiguidade na origem.

---

### C5. ⚠️ Restauração de backup injeta payloads com DateTime em ms na fila de sync → PostgREST rejeita → ops presas

**Localização:** `lib/settings/backup_service.dart` → `_reconstituteSyncQueue()` (l. 691–713) e `commitRestore()` (l. 864+); em cadeia com `toRemotePayload()` (`supabase_sync_service.dart`, l. ~166) e com **C1**

**Diagnóstico:** o backup serializa entradas com `entry.toJson()` (l. 308+), que escreve `DateTime` como **inteiro de ms** via o serializer padrão do drift (ex.: `"firstContactAt": 1731052800000`). Na restauração, `_reconstituteSyncQueue` enfileira **o item cru do backup** como payload:
```dart
await repository.db.into(repository.db.syncQueue).insert(
  SyncQueueCompanion.insert(
    entityType: entityType, entityId: entityId, operation: operation,
    payload: jsonEncode(payload),   // ← payload['firstContactAt'] == 1731052800000 (int)
    ...
  ),
);
```
No próximo `sync()`, `processQueue()` chama `toRemotePayload()`, que apenas faz snake_case — `first_contact_at: 1731052800000` é enviado ao PostgREST, cuja coluna é `timestamptz`. O servidor responde **400 / 22008 (invalid datetime format)** → `markSyncOperationFailed` → com **C1**, a operação nunca mais sai de `failed`. Ou seja: **restaurar um backup em um dispositivo novo e sincronizar = 100% das operações reconstituídas ficam presas para sempre**, exatamente no cenário em que o restore mais importa.

Adicionalmente, os itens do backup não incluem `firstContactAt`/`createdAt` normalizados para o caminho de UPDATE de `people` (que omite `firstContactAt` — ver M10), então o upsert pode também violar `NOT NULL` no caminho de insert-com-conflito.

**Refatoração:** normalizar o payload no ponto de reenfileiramento (reutilizando a mesma lógica do export):
```dart
// backup_service.dart
static const _datePayloadKeys = {
  'firstContactAt','lastContactAt','nextActionAt','dateTimeField','createdAt',
  'updatedAt','deletedAt','startedAt','lastSessionAt','nextPlannedAt','date',
  'suggestedReturnDate','lastReviewedAt',
};

Map<String, dynamic> _normalizeBackupPayload(Map<String, dynamic> item) {
  final out = Map<String, dynamic>.from(item);
  out.forEach((k, v) {
    if (v is int && (_datePayloadKeys.contains(k) ||
        k.endsWith('At') || k.endsWith('_at'))) {
      // Backup em ms → ISO-8601 UTC esperado pelo PostgREST
      final ms = v > 1000000000000 ? v : v * 1000;
      out[k] = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
    }
  });
  return out;
}

Future<void> _reconstituteSyncQueue(
  String entityType, String entityId, String operation, Map<String, dynamic> payload,
) async {
  if (!_shouldReconstituteSyncQueue) return;
  try {
    final normalized = _normalizeBackupPayload(payload);
    await repository.db.into(repository.db.syncQueue).insert(
      SyncQueueCompanion.insert(
        id: _uuid.v4(),
        entityType: entityType, entityId: entityId, operation: operation,
        payload: jsonEncode(normalized),
        createdAt: DateTime.now(),
        status: const Value('pending'),
      ),
    );
  } catch (e) {
    AppLogger.warning('Reenfileiramento de sync falhou para $entityType/$entityId: $e');
  }
}
```
Teste de regressão: `restore → sync()` com servidor fake (clientOverride) assertando que o payload enviado ao PostgREST contém ISO strings (`expect(payload['first_contact_at'], matches(RegExp(r'^\d{4}-')))`).

---

## 4. `[ALTO]` — Segurança, vazamento de recursos e performance estrutural

### A1. Release Android assinado com keystore de DEBUG; updater in-app instala APK/IPA sem verificar assinatura

**Localização:** `android/app/build.gradle.kts` → `buildTypes.release` (l. 33–37), `applicationId`/`namespace` (l. 12, 19); `.github/workflows/ci.yml` → `build_android_and_web` / `publish_release`; `lib/core/update_checker_service.dart` → `launchUpdate()` (l. ~300); `lib/core/app_version.dart`

**Diagnóstico:**
```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        signingConfig = signingConfigs.getByName("debug")   // ← build "release" público
    }
}
```
O CI publica `app-arm64-v8a-release.apk` em GitHub Releases, e o updater in-app baixa e abre esse APK via `launchUrl` sem **nenhuma verificação**: sem SHA-256, sem assinatura, sem pin de certificado, sem confirmação de integridade após download. Como a chave de debug é a chave pública padrão do Android SDK (a mesma para todos os desenvolvedores do mundo), qualquer atacante que (a) comprometa o repositório/CI, (b) suba um asset malicioso na release, ou (c) faça MITM em um canal não-pinado entrega código arbitrário ao parque instalado — e o usuário instala "porque o app mandou". No iOS o IPA é unsigned por design (LiveContainer), o que já impede verificação — mas no Android não há essa desculpa. Agravantes: `applicationId = "com.example.ministerio_pessoal"` e `namespace com.example.ministerio_pessoal` (rejeitado pela Play Store; colide com qualquer outro app `com.example.*`); o workflow copia ícones iOS com nomes errados para dentro do `Runner.app` empacotado (funciona por acidente, quebra a cada mudança de asset).

**Refatoração:**
```kotlin
// android/app/build.gradle.kts
signingConfigs {
    create("release") {
        storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH") ?: "release.keystore")
        storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
        keyAlias = System.getenv("ANDROID_KEY_ALIAS")
        keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
    }
}
buildTypes { release { signingConfig = signingConfigs.getByName("release"); isMinifyEnabled = true } }
// applicationId: registrar "br.com.ministeriopessoal.campo" (ou o domínio do projeto) e atualizar namespace.
```
CI: injetar `ANDROID_KEYSTORE_PATH`/`*_PASSWORD` via GitHub Secrets + `keytool`-decoded do secret. Updater (Android): baixar com `DownloadManager` → calcular SHA-256 → comparar com `apps.json` (campo novo `sha256`) → só então abrir o instalador; se divergir, recusar com mensagem. No `apps.json`, adicionar `"sha256": "..."` por versão (o CI calcula no mesmo job que gera o APK). iOS: manter unsigned documentado em `docs/SECURITY.md`, mas deixar explícito na UI de update que o IPA não é verificável.

---

### A2. "Silent backup" pré-restauração: chave de criptografia em texto puro no **mesmo banco** que os dados; fallback legado AES-CBC sem MAC

**Localização:** `lib/settings/backup_service.dart` → `_getOrCreateSilentBackupKey()` (l. 1430), `commitRestore()` (l. 725–763), `_deriveKeyV1()` (l. 226), `previewBackup()` (ramo v1, l. ~408)

**Diagnóstico:** a chave do snapshot de segurança (o "backup silencioso" criado antes de cada restore) é gerada aleatoriamente — bom — mas é persistida em `appKvStore` (`_silentBackupKeySecret`), **o mesmo SQLite** que o atacante/backup contém. Quem copia `ministerio_pessoal.sqlite` (ou o IndexedDB na Web) tem ciphertext + chave juntos: a criptografia AES-256-GCM é inócua; serve só para ofuscar contra cópia casual do arquivo de snapshot sem o DB — cenário improvável. Na Web, `commitRestore` grava o snapshot inteiro sob `last_safety_snapshot_data` no mesmo `appKvStore` (l. 743): um dump do navegador expõe o snapshot completo dos dados (nome, telefone, endereço, notas de todos os contatos + áudios por hash). Agravante legado: o ramo v1 usa `AES` em **modo CBC sem autenticação** com salt fixo `'ministerio_pessoal_salt_v1'` hardcoded — ciphertext v1 é maleável e a senha é o único segredo; não há detecção de adulteração. O próprio v2 usa `iterations: 1000` para o snapshot silencioso (reduzido demais vs. os 100k do caminho público).

**Refatoração:**
```dart
// Chave do snapshot em secure storage (Keychain/Keystore), nunca no SQLite/KV:
final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

Future<String> _getOrCreateSilentBackupKey() async {
  var key = await _secureStorage.read(key: 'silent_backup_key_v1');
  if (key != null && key.isNotEmpty) return key;
  key = base64Encode(_generateSecureRandom(32));
  await _secureStorage.write(key: 'silent_backup_key_v1', value: key);
  return key;
}
```
- Web: não gravar `last_safety_snapshot_data` no KV. Opções: (a) materializar via download para o usuário com senha derivada de sessão, ou (b) não gerar snapshot silencioso na Web e exigir export manual antes de restore (mensagem clara).
- Snapshot silencioso com `iterations: 100000` (mesmo custo do export público).
- Restringir a descriptografia v1: exigir flag explícita `allowLegacyV1: true` no restore, exibindo aviso "backup antigo sem verificação de integridade (AES-CBC)"; rejeitar v1 por padrão.

---

### A3. Fotos de pessoas como base64 TEXT no SQLite — e sincronizadas por upsert para o PostgREST/Storage

**Localização:** `lib/database/tables.dart` → `PersonPhotos.imageData` (l. 332); `lib/media/person_photos_manager.dart`; `lib/sync/supabase_sync_service.dart` → `_insertLocalEntry/_updateLocalEntry` (`person_photos`), `toRemotePayload`

**Diagnóstico:** `image_data TEXT` guarda a imagem decodificada em base64 (+33% sobre o binário) **dentro do SQLite**. Para uma foto de 3 MB (comum vinda de `image_picker` sem `maxWidth`), a linha tem ~4 MB; `PersonPhotoEntry.fromJson`/`toJson` e `row.toJson()` materializam tudo em memória a cada map; o backup JSON embute todas as fotos base64 (o arquivo de backup explode); a sincronização envia `image_data` como campo do upsert PostgREST — row de megabytes, sujeito a limites de payload do PostgREST/Supabase (e a estouros de memória no device), e **sem caminho incremental**: alterar a legenda da foto reenvia a foto inteira. Na Web (IndexedDB), o DB inteiro carrega no processo JS: poucos MB de fotos degradam o app inteiro.

**Refatoração:** arquivos no disco (como as voice notes já fazem) + referência por caminho:
```dart
// tables.dart (schema v5):
class PersonPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get personId => text().named('person_id')();
  TextColumn get photoType => text().named('photo_type')();
  TextColumn get filePath => text().named('file_path').nullable()(); // ← novo
  // imageData mantido apenas para migração; novos inserts gravam arquivo
  TextColumn get imageData => text().named('image_data').withDefault(const Constant(''))();
  ...
}
// Migração v5: para cada linha com imageData != '', decodificar base64 → gravar em
// getApplicationDocumentsDirectory()/person_photos/<id>.jpg → filePath = path, imageData=''.
// Sync: foto nova = linha com file_path; binário sobe para bucket `person_photos/<uid>/<id>.jpg`
// via uploadBinary (mesmo padrão de _uploadVoiceNoteAudio); coluna remota guarda só a key.
// Backup: embutir bytes (já faz para voz) em vez de base64 dentro do JSON do DB dump.
```
Enquanto a migração não sai: impor `maxWidth: 1280, imageQuality: 80` no `image_picker` (corte imediato de 10–20× no tamanho).

---

### A4. ⚠️ Vazamento sistemático de `TextEditingController` em diálogos (144 ocorrências em `lib/`)

**Localização:** `lib/ui/screens/person_detail_screen.dart` (ex.: `_showTagsDialog` l. 892, `_showAddNoteDialog` l. 1011, editor de pessoa l. 1386–1406, JW Library l. 3805 — 0 chamadas a `dispose()` no arquivo inteiro), `lib/ui/screens/contacts_map_screen.dart` → `_showAddLandmarkModal` (l. 451–455), `lib/ui/screens/appointments_screen.dart`, `lib/ui/screens/today_screen.dart`, `lib/ui/screens/studies_screen.dart`, `lib/ui/screens/ticuna_screen.dart`…

**Diagnóstico:** os controllers são criados em **métodos helper** (`void _showXxxDialog(BuildContext context)`) que retornam imediatamente após `showDialog`; ninguém retém referência nem chama `dispose()`. A cada abertura do diálogo, N controllers ficam órfãos: o `TextField` registra listeners; o `EditableText` mantém o controller vivo enquanto o widget tree existir; após `Navigator.pop`, os controllers vazam (memória + listeners). Em sessão longa no iPad (o caso de uso real do app), centenas de controllers se acumulam; a cada rebuild do diálogo via `StatefulBuilder`, valores antigos podem reaparecer em campos errados (o builder captura os controllers por closure). É o padrão exato que o Flutter documenta como proibido ("Controllers created in State must be disposed").

**Refatoração (padrão único para todo o app):**
```dart
// ANTES (contacts_map_screen.dart)
void _showAddLandmarkModal(BuildContext context) {
  final nameController = TextEditingController();   // ← nunca disposto
  final notesController = TextEditingController();  // ← nunca disposto
  showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
    return AlertDialog(... TextField(controller: nameController) ...);
  }));
}

// DEPOIS — transformar o diálogo em StatefulWidget descartável:
class AddLandmarkDialog extends StatefulWidget {
  const AddLandmarkDialog({super.key, required this.onSaved});
  final void Function(LandmarkDraft) onSaved;
  @override State<AddLandmarkDialog> createState() => _AddLandmarkDialogState();
}
class _AddLandmarkDialogState extends State<AddLandmarkDialog> {
  final _name = TextEditingController();
  final _notes = TextEditingController();
  @override void dispose() { _name.dispose(); _notes.dispose(); super.dispose(); }
  ...
}
// e o call site: showDialog(context: context, builder: (_) => AddLandmarkDialog(onSaved: ...));
```
Ação mecânica: para os ~40 diálogos helper, aplicar codemod manual na ordem de peso (`person_detail_screen.dart` 7594 linhas → 30+ diálogos). Meta: `grep -c 'TextEditingController(' lib | soma` == número de `dispose()` correspondentes.

---

### A5. `FutureBuilder` com `future:` criado inline no `build()` — re-queries em todo rebuild (dashboard, detalhe da pessoa, estudos, lixeira, busca global)

**Localização:**
- `lib/ui/screens/dashboard_screen.dart` → body `FutureBuilder<List<dynamic>>(future: Future.wait([...3 queries]))` (l. 527)
- `lib/ui/screens/person_detail_screen.dart` → `build()` (l. 3515): `future: repo.getPersonById(widget.personId)` recriado a cada build quando `person == null`
- `lib/ui/screens/studies_screen.dart` → card de estudo (l. 2434): `future: ref.read(repositoryProvider).getParticipantsForStudy(study.id)` **por card por rebuild** (N+1)
- `lib/ui/screens/settings_screen.dart` (l. 915), `lib/ui/screens/trash_screen.dart` (l. 23), `lib/ui/screens/global_search_screen.dart` (l. 130: `_performSearch(...)` em cada build a cada tecla)

**Diagnóstico:** `FutureBuilder` não memoiza: cada `build()` cria um `Future` novo → dispara queries Drift novas → `.then` agenda setState interno → novo build → novo `Future`… Na prática: o dashboard re-executa 3 queries + rebuild completo da árvore a cada notificação de qualquer provider assistido (ex.: qualquer `peopleStreamProvider` emite → `build()` → 3 queries). O `studies_screen` executa 1 query por estudo por rebuild (20 estudos × 3 rebuilds por segundo durante digitação = 60 queries/s). `global_search_screen` roda a busca FTS-like completa a cada tecla, em paralelo com o debounce inexistente. Além de jank, infla o uso de CPU/GPU na Web (SQLite compilado em WASM no mesmo isolate da UI).

**Refatoração:**
```dart
// ── dashboard_screen.dart ──
class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final Future<List<dynamic>> _dashboardFuture = Future.wait([
    ref.read(repositoryProvider).getAllSessions(),
    ref.read(repositoryProvider).getAllVisits(),
    ref.read(repositoryProvider).db.select(ref.read(repositoryProvider).db.studyParticipants).get(),
  ]);
  ...
  body: FutureBuilder(future: _dashboardFuture, ...),
}

// ── studies_screen.dart — eliminar N+1 com o stream já existente ──
final allParticipants = ref.watch(studyParticipantsStreamProvider).value ?? [];
final partsByStudy = <String, List<StudyParticipantEntry>>{};
for (final p in allParticipants) { partsByStudy.putIfAbsent(p.studyId, () => []).add(p); }
// dentro do card: final parts = partsByStudy[study.id] ?? const [];  (zero queries)

// ── global_search_screen.dart — debounce + memo ──
// manter _lastQuery/_lastFuture como campos; só recomputar se cleanQuery mudou;
// ou migrar para Riverpod: final globalSearchProvider = FutureProvider.autoDispose.family<List<GlobalSearchResultItem>, String>(...)
```
Regra de guarda (adicionar ao lint interno / code review): **`FutureBuilder(` é proibido com `future:` chamando repositório diretamente fora de `initState` ou provider**; usar `FutureProvider[.family]` ou campo `late final`.

---

### A6. Efeitos colaterais dentro de `build()`: rede + escrita no banco disparados durante renderização (mapa de contatos)

**Localização:** `lib/ui/screens/contacts_map_screen.dart` → `_buildInteractiveVisualMap()` (l. ~2095–2135)

**Diagnóstico:** dentro do método de construção do mapa, o código (a) calcula listas com `sort()` a cada rebuild, (b) atribui a campos de estado (`_selectedPinPerson ??= highlightPerson`, `_activeCenterLat/Lng`) — mutação durante build — e (c) quando o contato destacado não tem GPS mas tem endereço, dispara **geocodificação de rede + `repo.updatePerson()`** (que por sua vez enfileira operação de sync) dentro de um `addPostFrameCallback` registrado **em todo build que atender a condição**. `_geocodedPersonIds` mitiga reentrância por id, mas não impede: N contatos sem GPS → N chamadas Nominatim automáticas (política de uso justo: 1 req/s; o app não rate-limita) → cada uma enfileira um UPDATE na sync queue → push subsequente. Toda essa cadeia é disparada apenas por o widget ter sido reconstruído (ex.: toggle de tema, scroll, notificação de timer de sync). Efeito colateral em `build()` é a fonte clássica de loops de rebuild em Flutter (updatePerson → stream → rebuild → condição ainda verdadeira? não, por causa do Set — mas o padrão é frágil e invisível em code review).

Agravante de produto: o centro padrão do mapa é São Paulo (`-23.5505, -46.6333`, l. ~2123), mas o app é calibrado para Santo Antônio do Içá/AM (`-3.1022, -67.9397` em `geolocation_helper.dart`) — o mapa "abre" 2.700 km longe do território do usuário na primeira execução sem dados.

**Refatoração:**
```dart
// Mover para o ciclo de vida do state (não para o build):
class _ContactsMapScreenState extends ConsumerState<ContactsMapScreen> {
  bool _geocodeTriggered = false;

  @override
  void didUpdateWidget(...) / dispose { super.didUpdateWidget(oldWidget) / super.dispose(); }

  // Chamado a partir de initState/postFrame E de didChangeDependencies — nunca do build:
  void _maybeGeocodeHighlight() {
    if (_geocodeTriggered) return;
    final p = _highlightedPersonWithoutGps;
    if (p == null) return;
    _geocodeTriggered = true;
    GeocodingService.geocodeAddress(p.address!).then((res) async {
      if (res == null || !mounted) return;
      await ref.read(repositoryProvider).updatePerson(
        p.copyWith(latitude: drift.Value(res.latitude), longitude: drift.Value(res.longitude)),
      );
    });
  }
}
// No build: apenas LER estado; nenhuma escrita, nenhum I/O.
// Centro padrão: usar GeolocationHelper.defaultLat/defaultLng (Içá) em vez de São Paulo.
// Rate-limit: uma geocodificação automática por vez, fila com 1s de espaçamento.
```
Complementar (estrutural): `contacts_map_screen.dart` (3303 linhas), `appointments_screen.dart` (4570), `person_detail_screen.dart` (7594) são God Widgets — UI + regras de negócio + persistência + rede no mesmo arquivo. Extrair (1) `TerritoryMapController` (estado do viewport, zoom, tiles, seleção), (2) `PersonFormController`/`VisitFormController` (validação + persistência), (3) widgets puros. Isso também destrava testes de unidade para a lógica que hoje só existe dentro de callbacks de botão.

---

### A7. `searchPeople` e o filtro em `people_screen`: varreduras O(n×m) por tecla digitada

**Localização:** `lib/database/repository.dart` → `searchPeople()` (l. 70); `lib/ui/screens/people_screen.dart` → data branch do `peopleAsync.when` (l. 654–700)

**Diagnóstico:** dois caminhos redundantes com o mesmo defeito. (1) Repositório: carrega **todas** as pessoas + **todos** os estudos + **todos** os participantes, e para cada participante faz `studies.where((s) => s.id == p.studyId).firstOrNull` — O(P × S). Chamado por `global_search_screen`/telas que buscam "sob demanda". (2) Tela: reconstrói o mapa `personStudies` com o mesmo duplo loop **a cada rebuild** (dentro do `when` no `build`), e o filtro textual roda todos os `contains` sobre todos os contatos a cada caractere.

**Refatoração:**
```dart
// Opção A (mínima, no build): memoizar o mapa de estudos uma única vez por emissão de stream
final personStudies = useMemoizedOrField(() {
  final map = <String, List<BibleStudyEntry>>{};
  final studiesById = {for (final s in allStudies) s.id: s};
  for (final part in allParticipants) {
    final s = studiesById[part.studyId];
    if (s != null && s.deletedAt == null) map.putIfAbsent(part.personId, () => []).add(s);
  }
  return map;
}, [allStudies, allParticipants]);

// Opção B (correta, repositório): LIKE no SQLite + EXISTS para estudo vinculado
Future<List<PersonEntry>> searchPeople(String query) async {
  final lower = query.trim().toLowerCase();
  if (lower.isEmpty) return getAllPeople();
  final like = '%$lower%';
  return customSelect(
    '''SELECT p.* FROM people p
       WHERE p.deleted_at IS NULL AND (
         lower(p.name) LIKE ?1 OR lower(coalesce(p.phone,'')) LIKE ?1 OR
         lower(coalesce(p.address,'')) LIKE ?1 OR lower(coalesce(p.general_notes,'')) LIKE ?1 OR
         lower(coalesce(p.next_action_note,'')) LIKE ?1 OR lower(p.tags) LIKE ?1 OR
         lower(coalesce(p.preferred_schedule,'')) LIKE ?1 OR
         EXISTS (
           SELECT 1 FROM study_participants sp
           JOIN bible_studies bs ON bs.id = sp.study_id AND bs.deleted_at IS NULL
           WHERE sp.person_id = p.id AND sp.deleted_at IS NULL AND
             (lower(bs.title) LIKE ?1 OR lower(bs.publication_id) LIKE ?1)
         )
       ) ORDER BY p.name''',
    variables: [Variable.withString(like)],
    readsFrom: {db.people, db.studyParticipants, db.bibleStudies},
  ).map((row) => db.people.map(row)).get();
}
// + índice: CREATE INDEX IF NOT EXISTS idx_people_name ON people(name COLLATE NOCASE);
```

---

### A8. Notas de voz: upload de áudio **nunca funciona na Web** (e, via C1, envenena a fila para sempre)

**Localização:** `lib/sync/supabase_sync_service.dart` → `_uploadVoiceNoteAudio()` (l. ~1004), `_uploadTicunaAudio()`, `_downloadVoiceNoteAudio()`; `lib/voice_notes/audio_recording_service.dart` (paths em Web são apenas o nome do arquivo)

**Diagnóstico:** o serviço importa `dart:io` e faz `File(vn.audioFilePath!)`. Na Web, `audioFilePath` é um nome de arquivo relativo (`voice_note_x.m4a`, definido em `audio_recording_service.dart` sob `kIsWeb`) e `File(...).exists()` lança `UnsupportedError` (dart:io inexistente no browser). O `catch` adiciona erro → `markSyncOperationFailed` → com **C1**, a op jamais sai de `failed`. Resultado: **na Web, toda nota de voz fica permanentemente fora da nuvem**, e toda tentativa consome uma das 5 "tentativas" fantasmas. O mesmo padrão vale para `_downloadVoiceNoteAudio` e `_uploadTicunaAudio` (biometria de dados: `File(audioPath)` com caminho do IndexedDB/OPFS).

**Refatoração:**
```dart
Future<bool> _uploadVoiceNoteAudio(String id, SupabaseClient client, List<String> errors) async {
  try {
    final vn = await (db.select(db.voiceNotes)..where((t) => t.id.equals(id))).getSingleOrNull();
    final path = vn?.audioFilePath;
    if (path == null || path.isEmpty) return true;   // nada a enviar

    final bytes = await readMediaBytes(path);        // ← helper condicional
    if (bytes == null || bytes.isEmpty) { errors.add('Áudio $id indisponível localmente'); return false; }
    final userFolder = _resolveStorageFolder(client);
    await client.storage.from('voice_notes').uploadBinary(
      '$userFolder/$id.m4a', bytes, fileOptions: const FileOptions(upsert: true));
    return true;
  } catch (e) { errors.add('Falha no upload de áudio $id: $e'); return false; }
}

// media_bytes.dart (export) + media_bytes_io.dart (File.readAsBytes)
//                            + media_bytes_web.dart (XFile/bytes já capturados na gravação,
//                              ou download do IndexedDB via drift BLOB; NUNCA dart:io)
```
Na gravação Web, guardar os bytes em um campo/cache (`Uint8List`) no serviço de gravação e recuperar no momento do upload — elimina a dependência de `File` por completo no caminho de upload.

---

### A9. Dupla fonte de verdade para schema: managers criam tabelas em SQL cru com datas TEXT; Drift tipa as mesmas tabelas esperando unix-seconds — leituras tipadas explodem

**Localização:** `lib/experiences/experience_manager.dart` (`CREATE TABLE IF NOT EXISTS ministry_experiences ... date_time TEXT, created_at TEXT`, l. 105), `lib/family/family_ties_manager.dart` (l. 68), `lib/media/person_photos_manager.dart` (l. 64), `lib/publications/person_publications_manager.dart`, `lib/research/research_manager.dart`, `lib/territory/sector_manager.dart`, `lib/ticuna/ticuna_repository.dart` (l. 94/116/133), vs. `@DriftDatabase(tables: [...])` em `lib/database/app_database.dart` e `_migrateCustomTablesColumns()` (l. 130)

**Diagnóstico (mecanismo exato de falha):** drift **não** armazena `DateTime` como texto ISO por padrão: armazena `millisecondsSinceEpoch ~/ 1000` (int segundos) e, na leitura, faz `int.parse(sqlValue.toString())` — qualquer valor TEXT ISO-8601 nessas colunas lança `FormatException` (confirmado no fonte do drift: `_readDateTime` → `read(DriftSqlType.int, sqlValue)` → `int.parse`). Os managers legados gravam/escrevem **ISO-8601 TEXT** em `created_at`/`updated_at`/`deleted_at`/`date_time` (ex.: `insertOnConflictUpdate(... Variable.withString(now.toIso8601String()))`). A migração `_migrateCustomTablesColumns` tenta consertar adicionando `updated_at INTEGER` — mas executa `UPDATE $tbl SET updated_at = created_at`, **copiando o TEXT ISO para a coluna INTEGER** (SQLite aceita por tipagem dinâmica) — e permanece `catch (_) {}` engolindo qualquer falha. Resultado real: tabelas com as duas convenções misturadas na mesma coluna; qualquer leitura tipada do Drift sobre essas tabelas (usada pelo sync: `_getLocalMap`/`_insertLocalEntry`/`_updateLocalEntry` em `research_articles`, `ministry_experiences`, `person_photos`, `person_publications`, `family_ties`, `territory_sectors`, `research_tags`) lança `FormatException` → `_applyRemoteRecord` captura → registro remoto nunca aplicado; `watch()` tipado dessas tabelas emite erro → telas que dependem delas ficam vazias **sem mensagem** (os `.value ?? []` no UI convertem erro em lista vazia). O mesmo para `ticuna_words`/`ticuna_phrases` (criadas e migradas por SQL cru dentro do repository Ticuna, fora do `schemaVersion` — sem `if (from < N)`).

**Refatoração:**
```dart
// 1) schemaVersion 5 — conversão irreversível de uma vez, na MigrationStrategy:
if (from < 5) {
  for (final t in ['family_ties','ministry_experiences','person_photos','person_publications',
                   'research_articles','research_tags','territory_sectors','student_manual_order']) {
    for (final col in ['created_at','updated_at','deleted_at']) {
      await customStatement(
        "UPDATE $t SET $col = CAST(strftime('%s', $col) AS INTEGER) "
        "WHERE typeof($col) = 'text';");   // '2026-11-08T...' → unix seconds
    }
  }
  // ticuna: criar via Drift de verdade (adicionar TicunaWords/TicunaPhrases em @DriftDatabase)
  // com blocos if (from < 5) idempotentes; remover CREATE TABLE IF NOT EXISTS dos repositories.
}
// 2) _migrateCustomTablesColumns / _migrateLandmarksColumns: PROPAGAR erro (como já faz
//    _migrateCalendarEventLinksPendingResolution), nunca catch(_){}.
// 3) Toda escrita nova via typed companions (nunca withString(iso) em colunas dateTime).
```
Validar com `test/database_migration_test.dart`: banco v4 com fixtures ISO legadas → migração → `db.select(db.ministryExperiences).get()` não pode lançar; `updatedAt` deve ser `DateTime` correto.

---

### A10. Canal de atualização "floating": `apps.json` no CDN `@master` — tag móvel; qualquer push em `master` troca o catálogo de update de todos os usuários

**Localização:** `lib/core/app_version.dart` (`appsJsonUrl`, l. ~33; `latestReleaseApiUrl`), `apps.json` (raiz), `lib/core/update_checker_service.dart`, `.github/workflows/ci.yml` (job `publish_release` → `purge.jsdelivr.net`)

**Diagnóstico:** `https://cdn.jsdelivr.net/gh/eduardoveiga-py/field-assistant@master/apps.json` aponta para o branch `master` — **móvel**. Qualquer commit em `master` (ou um force-push) altera instantaneamente o que "a última versão" significa para todo dispositivo instalado; o purge de cache no CI confirma que o fluxo depende dessa mutação. Não há assinatura do `apps.json`, nem pin de `version` imutável. Somado a A1 (APK de debug sem verificação), o canal de auto-update inteiro confia na integridade do branch master + CDN. `apps.json` também está sempre 1 release defasado manualmente (duplicação manual de versão em `pubspec.yaml` `1.2.1+6`, `AppVersion.version`, `apps.json.version`) — sem checagem de consistência no CI.

**Refatoração:** servir o catálogo de uma **tag imutável** (`@v1.2.1/apps.json`) ou Release asset; o `publish_release` deve atualizar o ponteiro de forma atômica e versionada; adicionar job `version_consistency` no CI que falha se `pubspec.yaml::version` ≠ `app_version.dart::version` ≠ `apps.json::apps[0].version`; assinar `apps.json` (ou no mínimo versionar sha256 do IPA/APK por release, ver A1) e verificar na leitura.

---

## 5. `[MÉDIO]` — Dívida técnica, privacidade e robustez de borda

### M1. Três encodings de timestamp coexistindo: unix-seconds (SQL do drift), ms-since-epoch (`toJson` do drift), ISO-8601 (payloads de sync/backup/managers legados)
**Localização:** `tables.dart` (dateTime → sqlite INTEGER s), `app_database.g.dart` (`toJson` → ms int), `supabase_sync_service._prepareEntryMap/_isoString` (ISO), `backup_service` (ms no export), `ticuna_repository.dart` (ISO TEXT).
**Diagnóstico:** não há um único codec de timestamp no projeto. Cada fronteira (DB ↔ JSON ↔ fila de sync ↔ PostgREST ↔ backup) escolhe a sua; qualquer novo código que compare timestamps de dois lados erra silenciosamente (foi exatamente a causa de C4 e C5). **Correção:** criar `lib/core/sync_timestamp.dart` com `parseTimestamp()` (o de C4) e `toIsoUtc()`; banir `DateTime.tryParse` cru em código de sync/backup; migrar payloads para ISO-8601 UTC sempre.

### M2. 155 ocorrências de `catch (_) {}` em `lib/` — erros persistentes engolidos sem rastro
**Localização (exemplos representativos):** `lib/database/app_database.dart:126,175,201` (migrações), `lib/settings/backup_service.dart` (dezenas), `lib/experiences/experience_manager.dart` (l. 56, 67, 117, 202…), `lib/ticuna/ticuna_repository.dart`, `lib/core/i18n/app_locale_strings.dart:368`.
**Diagnóstico:** o padrão predominante é catch vazio (nem log). Falhas de: migração de schema, escrita em KV, parse de tags JSON, download de áudio — tudo vira "segue a vida". Em combinação com `.value ?? []` no UI, o app **apaga evidências de corrupção**. **Correção:** substituir por `catch (e, st) { AppLogger.warning('<contexto>: $e'); }` (AppLogger já existe em `lib/core/app_logger.dart`); em migrações e backup, **propagar**; adicionar regra de análise (plugin custom ou `custom_lint`) bloqueando `catch (_) {}` vazio; meta: 0 ocorrências em caminhos de persistência.

### M3. User-Agent com e-mail pessoal do desenvolvedor enviado a OpenStreetMap/Nominatim em cada tile/geocode
**Localização:** `lib/core/app_version.dart:52`; usado em `tile_cache_native.dart`, `geocoding_service.dart`.
**Diagnóstico:** `'MinisterioPessoal/1.2.1 (https://github.com/eduardoveiga-py/field-assistant; eduardofaturistatuper@gmail.com)'` — PII do desenvolvedor vaza para servidores de terceiros a cada requisição de mapa; também infla o risco de o IP do usuário ser associado a um identificador pessoal em logs de terceiros. **Correção:** `'MinisterioPessoal/1.2.1 (+https://github.com/eduardoveiga-py/field-assistant)'` (sem e-mail).

### M4. Identificadores reais hardcoded em fonte/CI: URL+publishable key do Supabase (com `defaultValue` em `String.fromEnvironment`), Google Web Client ID em 4 lugares, `.env.example` com ID real
**Localização:** `lib/sync/supabase_config.dart` (URL `pchwrcwrvnbiywrdsvum.supabase.co` + `sb_publishable_...` como default), `lib/appointments/google_calendar_provider.dart:38-39` (defaultValue com o client ID real `424960288105-...`), `ios/Runner/Info.plist`, `web/index.html`, `.env.example:21`, `pubspec.yaml`.
**Diagnóstico:** publishable key e OAuth client ID **não são segredos** por design (RLS/allowlist os protege) — porém (a) commitá-los com `defaultValue` faz o app funcionar "de graça" apontando para o projeto de produção de uma pessoa, impossibilitando troca sem rebuild e convidando forks a dependerem dele; (b) `.env.example` deveria conter placeholders, não IDs reais; (c) não há evidência no repo de que as policies RLS dos buckets `voice_notes`/`ticuna_audio` restringem por `owner_id` — o fallback "upload no bucket voice_notes se ticuna_audio falhar" mascara misconfiguração. **Correção:** remover defaults (`String.fromEnvironment` sem `defaultValue` + fail-fast com mensagem na inicialização se ausente), `.env.example` com placeholders (`424960288105-YOUR...`), documentar no `docs/SECURITY.md` as policies RLS exigidas (e o teste manual: usuário A não lista objetos do usuário B).

### M5. DELETE remoto cego (`delete().eq('id')`) sem checagem de revisão — apaga linha que outro dispositivo atualizou depois
**Localização:** `lib/sync/supabase_sync_service.dart` (l. ~1697).
**Diagnóstico:** espelho do C2 para exclusões: o dispositivo que apagou localmente dispara `DELETE` remoto incondicional. Se outro dispositivo havia editado o registro depois, a edição remota some sem conflito. **Correção:** tombstone remoto (`update ... deleted_at`) ou `delete().eq('id', id).lte('revision', localRevision)` com verificação de "0 linhas" → registrar conflito.

### M6. Detecção de dados de demonstração por nomes hardcoded no auto-sync
**Localização:** `lib/ui/main_navigation_shell.dart` (`demoNames`, l. 82–88; `demoTitles` logo abaixo); `lib/core/demo_data.dart`.
**Diagnóstico:** o auto-sync aborta silenciosamente a sincronização se encontrar os 4 nomes demo exatos no banco — qualquer renomeação/tradução/variante ("Carlos Pereira (Demo.)", dados demo antigos com outro nome) desativa a proteção; e o usuário real chamado "Maria Oliveira (Demo)" nunca sincronizaria. **Correção:** `DemoDataGenerator.populateDemoData()` grava `demo_mode=true` em `appKvStore`; o shell verifica a flag; `clearDemoData()` a remove. (Manter checagem de nomes apenas como defesa em profundidade.)

### M7. Web: PII em IndexedDB sem criptografia nem CSP; SQLite via WASM no mesmo isolate da UI
**Localização:** `web/index.html` (sem `Content-Security-Policy`), `lib/database/connection/connection_web.dart` (`IndexedDbFileSystem`), fotos/notas/PII em claro (A2, A3).
**Diagnóstico:** qualquer XSS (dependência comprometida no `pubspec`, ex.: `google_fonts` carregando de CDN, ou injeção futura) lê o banco inteiro — nomes, telefones, endereços, anotações ministeriais (dado religioso = categoria especial na LGPD). Sem CSP, `script-src` é aberto. **Correção:** adicionar CSP meta (`default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; connect-src 'self' *.supabase.co https://tile.openstreetmap.org https://*.tile.openstreetmap.fr https://nominatim.openstreetmap.org https://api.github.com https://cdn.jsdelivr.net; img-src 'self' data: blob: https://*.tile.openstreetmap*; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; object-src 'none'; base-uri 'self'`), e documentar em `docs/SECURITY.md` que a Web não é alvo de alta sigilosidade (recomendado: Field Notes na Web = somente visualização, ou exigir senha de app).

### M8. `atualizar_app.ps1` — script auto-modificável com código-fonte embutido em base64
**Localização:** raiz do repositório (`atualizar_app.ps1`).
**Diagnóstico:** executa `git checkout e2caf14 -- <arquivos>` (volta no tempo 3 arquivos sem commit) e **sobrescreve** `lib/appointments/google_calendar_provider.dart`, `lib/territory/geolocation_helper.dart` etc. com blobs base64 embutidos — código-fonte completo dentro de um script, sem revisão, sem diff, invisível para a auditoria de mudanças (`.gitignore` não o exclui; ele é commitado). Isso invalida toda a cadeia "o código no Git é o código que roda". **Correção:** deletar o arquivo; o fluxo de atualização já é coberto pelo CI; se necessário manter um script de release, mover para `tools/` escrito em Dart/Shell legível com `git diff --exit-code` de guarda.

### M9. `main()` engole falha de inicialização do Supabase em `catch (_) {}` — falha de rede vira "modo offline" invisível
**Localização:** `lib/main.dart` (l. 11–16).
**Diagnóstico:** se o Supabase falhar no boot (DNS, cert, 5xx do serviço), o app continua normalmente como se fosse intencionalmente offline; o usuário não distingue "configurou offline" de "sync quebrado há 3 dias". Combinado com C1, a divergência acumula. **Correção mínima:** `catch (e) { AppLogger.error(...); }` + expor `SupabaseSyncService.isInitialized` no banner de status (a UI de sync já existe em Configurações — adicionar dot de aviso quando `!isInitialized && !offline_mode_enabled`).

### M10. `updatePerson` enfileira payload **incompleto** (omite `firstContactAt`, `createdAt`, `deletedAt`) — upsert depende de ordem da fila
**Localização:** `lib/database/repository.dart` → `updatePerson()` (l. 200–234).
**Diagnóstico:** o payload de UPDATE tem ~14 dos ~17 campos necessários para um upsert seguro; `first_contact_at` (NOT NULL na tabela remota presumida) só existe no payload de INSERT. Se a fila for reconstituída fora de ordem (ex.: restore parcial + edição antes do primeiro push — ver C5) ou se o INSERT original nunca tiver ido (ex.: registro criado antes de a sync existir, ou op antiga purgada), o upsert remoto 400/NOT NULL → op presa (C1). **Correção:** ao enfileirar UPDATE, incluir snapshot completo (reusar `updated.toJson()` como base, convertendo DateTimes para ISO — o mesmo caminho de `_reconstituteSyncQueue` normalizado).

### M11. `pubspec.yaml`: dependência marcada EOL e versões desalinhadas entre 4 fontes
**Localização:** `pubspec.yaml` (`sqlite3_flutter_libs: ^0.6.0+eol` — sufixo **EOL** publicado pelo autor do pacote), `environment.sdk: ^3.13.7` (Dart 3.13); duplicação de versão: `pubspec.yaml` `1.2.1+6`, `lib/core/app_version.dart` `1.2.1`/`6`, `apps.json` `1.2.1`, `ios`/`android` (via pubspec) — **sem verificação automática**; CI não confere consistência.
**Diagnóstico:** `+eol` sinaliza que `sqlite3_flutter_libs` não receberá mais fixes (a linha continuou apenas por compatibilidade); o caminho suportado é o pacote `sqlite3`/`sqlite3_flutter_libs` substituído por `sqlite3` + `NativeDatabase` com bundled libs — ou migrar para `drift` + `sqlite3_flutter_libs` novo namespace quando anunciado; hoje basta fixar e agendar. A versão tripla facilita release com `apps.json` defasado (o updater dos usuários passa a oferecer/não-oferecer updates errados). **Correção:** job CI `version_consistency` (awk/grep entre `pubspec.yaml`, `app_version.dart`, `apps.json`) falhando o build; criar issue de tracking para substituir `sqlite3_flutter_libs` assim que o sucessor oficial for publicado; CI também deveria validar `flutter pub outdated` com `--no-dev-dependencies` em warn-mode.

### M12. `_resolveStorageFolder()` grava em pasta `00000000-0000-0000-0000-000000000000` quando deslogado
**Localização:** `lib/sync/supabase_sync_service.dart` (l. ~1018, usada por uploads/downloads de áudio).
**Diagnóstico:** sem `currentUser`, o app faz upload para uma **pasta compartilhada e previsível** no bucket; dependendo das policies (que niether o repo nem o `docs/SECURITY.md` demonstra como estritas), isso vaza áudio (conteúdo de conversas ministeriais) para um namespace comum a todos os usuários deslogados — ou, pior, funciona porque a policy está permissiva demais. Falha também não é distinguida de erro transitório. **Correção:** fail-fast: `if (uid == null) { errors.add('Upload de áudio $id: sessão ausente'); return false; }` — o áudio permanece local e será enviado após login, nunca para pasta compartilhada.

### M13. Sync silencioso: erros e conflitos nunca chegam à UI; `ConflictItem` é calculado e descartado
**Localização:** `lib/sync/supabase_sync_service.dart` → `ConflictItem`/`MergeResult` (sync_engine.dart), `SyncProcessResult.errors`; busca em `lib/ui/` não encontra consumidor de `statusStream` além do dot de status.
**Diagnóstico:** quando `mergeEntities` detecta conflito, a entidade recebe `status='conflict'` na fila e uma string de erro é agregada — mas nenhuma tela lista conflitos, nenhuma ação "resolver: manter local / manter remoto" existe; o usuário não tem como saber que `people/123` perdeu alterações. **Correção:** nova seção "Sincronização" em Configurações lendo `syncQueue` (status conflict/failed) com ações: ver diff campo-a-campo local/remoto (os valores já estão no payload) e botões "manter local" (re-enfileira UPDATE com revision remote+1) / "manter remoto" (aplica remoto via `_applyRemoteRecord`). O campo `ConflictItem.localValue/remoteValue` já contém tudo que a UI precisa.

---

## 6. Pontos fortes (para calibrar a resposta)

- **Backup v2 sólido:** AES-256-GCM autenticado + PBKDF2-HMAC-SHA256 (100k iterações), checksum SHA-256 do payload, snapshot de segurança obrigatório com abortar-restore em caso de falha, staging + swap atômico de áudios com validação de hash antes de tocar o destino (`commitRestore`). Melhor que a média de apps desse porte.
- **`AppSettingsManager`** (fila FIFO serializada + dirty-keys + cache) é exatamente como configurações devem ser persistidas.
- **`SyncEngine.mergeEntities`** é a arquitetura certa (3-way field-level); o problema é só *quando* é invocada (C2) e o parse (C4).
- **Tile cache OSM** com limite de 2 downloads simultâneos, User-Agent identificado, fallback OSM-France e detecção de tiles de bloqueio 403 — boa cidadania com o provedor.
- **Sync em transação + `_recordSyncOperation` dentro da `db.transaction`** (padrão usado consistentemente no `repository.dart`) — atomicidade correta entre mutação e enfileiramento.
- **Web WASM**: detecção de MIME e fallback ArrayBuffer são corretos; só o elo final (C3) é inaceitável.

---

## 7. Plano de Ação Priorizado (Roadmap de Refatoração)

Ordenação por **(ganho de estabilidade) / (risco de regressão × esforço)**:

| # | Item | Tipo | Esforço | Risco | Critério de pronto |
|---|---|---|---|---|---|
| 1 | **C1** — fila `failed→pending` com backoff real + dead-letter visível | correção | S (½–1 dia) | baixo | contagem de ops presas cai a 0; teste unitário do ciclo fail→retry→synced |
| 2 | **C4** — `_parseTimestamp` + `_getLocalMap` normalizado | correção | XS (2–4 h) | baixo | teste unitário: `updatedAt` int ms / ISO / null |
| 3 | **C3** — remover `_FallbackWebQueryExecutor`; erro fatal visível | correção | XS (2 h) | baixo | web build com MIME inválido mostra tela de erro, não app vazio |
| 4 | **C5** — `_normalizeBackupPayload` no reenfileiramento | correção | S | baixo | teste restore→push com server fake: payload ISO |
| 5 | **C2** — pré-check de revisão no push + tombstone/`lte` no DELETE | correção | M (2–3 dias) | **médio** (toca caminho quente do sync) | teste 2-dispositivos simulados: B não sobrescreve A; conflito vira `status='conflict'` |
| 6 | **A2** — silent key → `flutter_secure_storage`; v1 atrás de flag | segurança | S | baixo | snapshot silencioso ilegível com só o `.sqlite` |
| 7 | **A1** — signingConfig release (CI secrets) + `applicationId` real + SHA-256 no `apps.json` | segurança/release | M | baixo | APK assinado com chave própria; updater recusa SHA-256 errado |
| 8 | **A9** — schema v5: conversão TEXT→int das datas legadas + ticuna em Drift + migrations propagam erro | migração | M–G | **médio-alto** (migração de dados) | teste de migração v4→v5 com fixtures legadas; `watch()` sem erro |
| 9 | **A8** — bytes de mídia condicionais (sem `dart:io` no web) | correção | M | baixo | upload de nota de voz na Web funciona (mock Storage) |
| 10 | **A5 + A7** — `FutureBuilder` fora do build; índice/mapa memoizado na busca | performance | M | baixo | dashboard com 0 queries por rebuild; busca sem lag de 300ms |
| 11 | **A6** — side effects para fora do build (+ centro do mapa = Içá) | refatoração UI | M | baixo | `build()` do mapa 100% puro; sem rede no frame |
| 12 | **A4** — codemod de 144 controllers → Widgets descartáveis | higiene | M (mecânico) | baixo (com testes existentes) | `grep` de controllers órfãos = 0 |
| 13 | **A3** — fotos como arquivo + `file_path` (schema v5 incluso) | refatoração | G | médio | backup 10–50× menor; sync de foto por referência |
| 14 | **A10 + M11** — canal de update versionado por tag + job de consistência de versão | CI/CD | S | baixo | CI falha se versões divergirem |
| 15 | **M1–M13** | higiene/segurança | incremental | baixo | CI com `custom_lint` barrando `catch (_) {}` vazio |

**Sequência recomendada:** 1 → 2 → 3 → 4 (elimina a classe inteira de perda silenciosa; ~2 dias, baixo risco) → **congelar releases** → 5 (teste de 2 dispositivos antes de mergear) → 6 → 7 (só então cortar a 1.3.0) → 8 → 9 → 10/11/12/13 → 14/15.

**Testes de regressão a adicionar junto:** `sync_queue_retry_test.dart`, `restore_then_sync_test.dart`, `web_db_unavailable_test.dart`, `push_revision_guard_test.dart`, `migration_v4_to_v5_test.dart`. A suíte atual (46 arquivos) já cobre backup e sync em nível unitário — estender, não substituir.

**Riscos de regressão a observar:** (i) item 5 muda a ordem de decisão do push — rodar a suíte `supabase_sync_service_test.dart` completa + teste manual com Supabase de staging; (ii) item 8 reescreve dados — rodar em cópia de um DB real antes; (iii) item 13 altera o payload de fotos — coordenar com bump de schema e update obrigatório do app ou versionamento de payload (`payloadVersion: 2`).

---

## 8. Metodologia e limitações

- Análise **estática** (leitura integral dos ~75 kLOC de `lib/` excluindo `app_database.g.dart`; leitura de CI, manifests e configs). Flutter SDK não está disponível no sandbox — nenhuma asserção depende de execução, e **nenhuma correção foi aplicada ao código** (esta auditoria é um relatório; as refatorações estão especificadas para implementação).
- Evidência de mecanismo (ex.: formato de `toJson`, `int.parse` em `_readDateTime`) verificada contra o fonte publicado do drift (`simolus3/drift`, ref `7b664a1`), referenciado inline.
- Não foi possível auditar (a) as policies RLS do projeto Supabase de produção, (b) o conteúdo do bucket `voice_notes`/`ticuna_audio`, (c) o keystore real usado hoje (ausente do repo — ver A1/M4). Recomenda-se pentest de RLS antes da 1.3.0.
- `docs/engineering/KNOWN_ISSUES.md` lista problemas históricos como "RESOLVIDO E TESTADO" — **nenhum** dos itens desta auditoria (C1–C5, A1–A10, M1–M13) consta lá; a matriz cobre um eixo diferente (backup/calendar/migração pontual) e suas resoluções se sustentam.
