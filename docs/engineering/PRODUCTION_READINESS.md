# CHECKLIST E CLASSIFICAÇÃO DE PRONTIDÃO PARA PRODUÇÃO

## 1. Classificação Atual
**Status Geral: REPROVADO PARA PRODUÇÃO**

### Justificativa Técnica
O aplicativo apresenta **100% de sucesso na suíte de 635 testes automatizados**, **0 issues de análise estática** sob `--fatal-infos` e estabilização completa de persistência, soft delete/tombstones, 3-way merge determinístico, detecção de concorrência na agenda pós-sincronização, parada física aos 30s no áudio, fallback explícito de ditado offline, fluidez no motor cartográfico GIS com cancelamento assíncrono de tiles, isolamento multiplataforma de calendários na Web (eliminando `MissingPluginException` do `device_calendar` e suportando Google OAuth Web nativo), automação de sincronização de agenda em segundo plano via lifecycle e centralização de arquivos .ics em Configurações, além de deploy verificado na instância real do Supabase (`pchwrcwrvnbiywrdsvum`). A publicação final no ecossistema iOS depende exclusivamente das validações externas de ambiente: teste em hardware físico Apple (iPhone/iPad) e geração de archive iOS em runner macOS com conta de desenvolvedor ativa.

---

## 2. Checklist de Aprovação para Produção (Critérios da Seção 12)

- [x] **Todos os P0 resolvidos** *(APROVADO: P0-01 resolvido em U2; P0-02 resolvido em U3; P0-03 resolvido em U1; integridade de tombstones em U3.1 e hardening definitivo em U3.2)*
- [x] **Todos os P1 resolvidos no código** *(APROVADO: P1-01 concorrência na agenda pós-sync resolvido; P1-02 migrações Drift resolvido; P1-03 parada física aos 30s de áudio resolvida; P1-04 fallback de ditado offline e preservação de áudio resolvidos)*
- [x] **Inicialização e configuração de produção validadas** *(APROVADO: Configuração e validação de ambiente na Unidade U1 via `AppConfig`; inicialização desacoplada, resiliente e ciclo de vida Riverpod em `main.dart` concluídos na Unidade U2 via `SupabaseInitializer`; retry de boot em U3.2)*
- [x] **Banco local íntegro** *(APROVADO: Drift v4 com `PRAGMA foreign_keys = ON;`, `journal_mode = WAL;`, suporte IndexedDB via Wasm na Web)*
- [x] **Migrações testadas e rastreáveis** *(APROVADO: `app_database.dart` atualizado na Unidade U3.2 com logging estruturado via `AppLogger.error` e `rethrow` de exceções de DDL, eliminando swallows silenciosos)*
- [x] **Sincronização validada entre dispositivos** *(APROVADO: Schema remoto completo cobrindo todas as 10 tabelas, bucket de áudio de 10 MB, testes de serialização e pull em U3, integridade de soft delete/tombstones em U3.1, e 3-way merge determinístico com snapshot `_base`, normalização profunda por valor de coleções em tags e preservação de áudio em U3.2)*
- [x] **Conflitos tratados explicitamente na Agenda** *(APROVADO: Inserções concorrentes com sobreposição de horários recebidas após sincronização são detectadas pelo `SupabaseSyncService`, marcando status `conflito` e `isProvisional: true` na base local e atualizando a outbox)*
- [x] **RLS e permissões validadas** *(APROVADO: RLS ativo nas 10 tabelas e no bucket privado storage.objects com isolamento estrito por auth.uid() = owner_id e validação de posse da nota de voz em U3.2)*
- [x] **Dados sensíveis adequadamente protegidos** *(APROVADO: Backup AES-256 GCM + PBKDF2; bloqueio ativo de chaves `service_role` em `AppConfig`, mascaramento em logs e `.gitignore` blindado para `.env*`)*
- [x] **Backup e restauração testados com staging seguro** *(APROVADO: Staging em 3 etapas com rollback verificado por `TC-BAK-ADV-01` a `04`)*
- [x] **Agenda validada contra concorrência** *(APROVADO: Cobertura automatizada por `u3_2_integrated_acceptance_test.dart` com cenários de sobreposição, contiguidade e concorrência na outbox)*
- [x] **Áudio validado no código com parada física de 30s** *(APROVADO NO CÓDIGO: Timer de 30s dispara `record.stop()` ativamente no hardware com barreira contra cancelamento e limpeza de arquivos órfãos)*
- [x] **Transcrição documentada corretamente e com fallback** *(APROVADO: Diálogo orienta sobre necessidade do pacote de idioma offline baixado nos Ajustes do iOS e preserva o áudio para reprodução e transcrição manual)*
- [x] **Testes automatizados aprovados** *(APROVADO: 635 testes passando com 100% de sucesso)*
- [x] **Análise estática aprovada** *(APROVADO: `dart analyze lib test --fatal-infos` acusa 0 issues)*
- [x] **Build Release Web aprovado** *(APROVADO: `flutter build web --release` compila com sucesso)*
- [ ] **Archive iOS e instalação real em aparelho físico** *(PENDENTE EXTERNO: Depende de runner macOS e Apple Developer Account)*
- [x] **Deploy e schema Supabase aplicados na nuvem** *(APROVADO: Todas as 4 migrações aplicadas no projeto `pchwrcwrvnbiywrdsvum`, 10 tabelas e bucket `voice_notes` respondendo HTTP 200)*
- [x] **Desempenho e fluidez cartográfica GIS** *(APROVADO: Cancelamento instantâneo de tiles obsoletos ao mudar zoom, ordenação focal pelo viewport e fallback L1/disco eliminando travamentos)*
- [x] **Isolamento de Calendário Web e Google OAuth** *(APROVADO: Zero chamadas nativas ao `device_calendar` no navegador Web, fluxo OAuth Google desacoplado de permissões nativas e UI adaptada com badge "Apenas iOS")*
- [x] **Automação de Sincronização e Limpeza de UI na Agenda** *(APROVADO: Push automático ao salvar/editar e pull automático no retorno ao app (`AppLifecycleState.resumed`), com banner .ics migrado para Ajustes)*
- [x] **Documentação atualizada** *(APROVADO: Documentações de engenharia atualizadas com ADR-010 a ADR-015 e 635 testes)*

---

## 3. Matriz de Bloqueadores e Riscos

### Bloqueadores P0 (Críticos — Bloqueiam Funcionamento Essencial e Segurança)
1. **P0-01: Ausência de Inicialização do Supabase em Runtime**
   - **Arquivo:** `lib/main.dart:9-32`, `lib/core/supabase_initializer.dart`, `lib/sync/supabase_sync_service.dart`
   - **Evidência Original:** `main()` só invocava `WidgetsFlutterBinding.ensureInitialized()` e `runApp()`. `Supabase.initialize()` nunca era executado.
   - **Resolução em U2:** Implementada ordem de boot estrita em `main.dart` com inicialização assíncrona desacoplada (`initializeSupabaseIfConfigured`), orquestrador `SupabaseInitializer` com lock de concorrência, suporte a reconexão automática e resume de ciclo de vida (`WidgetsBindingObserver`), durabilidade garantida da outbox (`AppRepository.getPendingSyncOperations`), backoff exponencial com jitter (clamped a 300s) e pausa em 5 falhas para evitar starvation.
   - **Impacto:** Resolvido com 100% de independência e funcionamento offline garantido para o banco local.
   - **Status:** **RESOLVIDO NA UNIDADE U2**.

2. **P0-02: Migrações SQL Remotas Incompletas (Descompasso de Tabelas e Storage)**
   - **Arquivo:** `supabase/migrations/20261102000000_u3_missing_tables_storage.sql` vs `lib/sync/supabase_sync_service.dart:68-79`
   - **Evidência Original:** `syncTables` sincronizava `voice_notes`, `phone_contacts` e `territory_landmarks`, e fazia upload de mídias para o bucket `voice_notes`. O arquivo de migração original não criava essas 3 tabelas nem o bucket de Storage.
   - **Resolução em U3:** Criada a migração versionada `20261102000000_u3_missing_tables_storage.sql` com DDL completo das 3 tabelas, chaves estrangeiras, índices de auditoria, RLS granular por operação (SELECT, INSERT, UPDATE, DELETE), triggers para `updated_at`/`revision`, bucket privado `voice_notes` de 10 MB e políticas RLS de storage para `storage.objects`.
   - **Impacto:** Descompasso de schema categoricamente eliminado.
   - **Status:** **RESOLVIDO NA UNIDADE U3**.

3. **P0-03: Falha no Mecanismo de Injeção de Variáveis de Ambiente (`.env`)**
   - **Arquivo:** `lib/core/app_config.dart`, `lib/sync/supabase_sync_service.dart`, `scripts/run_web.ps1`
   - **Evidência Original:** O código dependia de `const String.fromEnvironment('SUPABASE_URL')` sem validação, sem fallback offline explícito e sem documentação clara sobre `--dart-define-from-file`.
   - **Resolução em U1:** Implementada a classe imutável `AppConfig` com validação de presença, checagem de URLs/esquemas, bloqueio estrito de credenciais privilegiadas (`service_role`), mascaramento seguro em logs técnicos, suporte automático a `-EnvFile`/`--dart-define-from-file`, templates `.env.example`, `.env.homolog.example`, `.env.prod.example`, e suíte de testes unitários dedicada (`test/core/app_config_test.dart`).
   - **Status:** **RESOLVIDO NA UNIDADE U1**.

---

### Bloqueadores P1 (Alto Risco de Falha, Corrupção ou Inconsistência)
1. **P1-01: Limite de Gravação de Áudio Não Desliga Hardware**
   - **Arquivo:** `lib/voice_notes/audio_recording_service.dart:120-132` e `266-279`
   - **Evidência:** Ao atingir 30 segundos, o código executa apenas `timer.cancel();`, deixando `_isRecording = true` e o gravador ligado.
   - **Impacto:** Gravação contínua em segundo plano, vazamento de memória e espaço em disco, bateria drenada e microfone travado no iOS.

2. **P1-02: Migrações do SQLite Silenciam Exceções com `catch (_) {}`**
   - **Arquivo:** `lib/database/app_database.dart:126, 175, 201`
   - **Evidência:** Funções `_migrateLandmarksColumns()`, `_migrateCustomTablesColumns()` e `_migrateLegacyKvStore()` descartam qualquer exceção silenciosamente.
   - **Impacto:** Se uma migração falhar (ex: tabela bloqueada), o app continua com schema inconsistente, levando a crashes posteriores.

3. **P1-03: Concorrência na Agenda Entre Múltiplos Dispositivos Offline**
   - **Arquivo:** `lib/appointments/availability_engine.dart` e `lib/sync/sync_engine.dart`
   - **Evidência:** `SyncEngine.mergeEntities` só trata conflitos em registros com o mesmo UUID. Dois agendamentos para o mesmo horário criados offline em aparelhos diferentes geram dois UUIDs distintos e sobrepõem-se na agenda sem alerta.
   - **Impacto:** Conflito de compromissos no mundo real sem sinalização para o usuário.

4. **P1-04: Transcrição Declarada como "Offline-First" Sem Garantia**
   - **Arquivo:** `lib/voice_notes/voice_dictation_service.dart:18-70` e `Info.plist:32`
   - **Evidência:** O código usa `speech_to_text` padrão sem verificar se o pacote de idioma pt-BR está instalado localmente no iOS (`supportsOnDeviceRecognition`). Em Web ou sem modelo, o áudio é enviado para servidores da Apple/Google e falha quando offline.
   - **Impacto:** Falha silenciosa ou crash na tentativa de ditar notas no campo sem internet.

---

### Débitos Técnicos P2 (Arquitetura, UX e Documentação)
1. **P2-01: Telas Monolíticas de Alta Complexidade**
   - `person_detail_screen.dart` (7.346 linhas)
   - `appointments_screen.dart` (4.379 linhas)
   - `dashboard_screen.dart` (2.927 linhas)
   - `studies_screen.dart` (2.713 linhas)
   - `contacts_map_screen.dart` (2.362 linhas)
   - `people_screen.dart` (2.054 linhas)
2. **P2-02: Divergências Numéricas na Documentação**
   - `README.md` cita 32 testes e 412 testes; a suíte atual possui 508 testes.
3. **P2-03: Criptografia em Repouso do SQLite Local**
   - Atualmente confiando no Data Protection nativo do iOS. Avaliar SQLCipher sem migração destrutiva.

---

## 4. Recursos Externos Necessários para Homologação Final
1. **Ambiente Apple:**
   - Máquina macOS (local ou GitHub Actions `macos-latest`) com Xcode 15+ instalado.
   - Conta Apple Developer ativa para assinatura de código (Provisioning Profiles / Certificates).
   - Acesso ao Apple TestFlight para distribuição e testes em hardware físico.
   - Dispositivos físicos de referência: iPhone (ex: iPhone XR / iPhone 13+) e iPad (iPad 10/11 ou Pro).
2. **Ambiente Supabase:**
   - **Concluído:** Projeto Supabase `pchwrcwrvnbiywrdsvum` migrado via pooler IPv4 (`aws-0-us-east-1.pooler.supabase.com:5432`). As 4 migrações SQL aplicadas, todas as 10 tabelas sincronizadas e o bucket privado `voice_notes` de 10 MB validados com sucesso.
