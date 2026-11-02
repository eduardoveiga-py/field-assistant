# CHECKLIST E CLASSIFICAÇÃO DE PRONTIDÃO PARA PRODUÇÃO

## 1. Classificação Atual
**Status Geral: REPROVADO PARA PRODUÇÃO**

### Justificativa Técnica
Apesar de o aplicativo apresentar **100% de sucesso na suíte de 508 testes automatizados**, **0 issues de análise estática** e estabilização de staging de backup, cursor determinístico e integridade de chaves estrangeiras, a publicação para produção está estritamente **bloqueada** por 3 falhas de severidade **P0**, 4 falhas de severidade **P1** e a ausência de validação em hardware físico Apple (iPhone/iPad).

---

## 2. Checklist de Aprovação para Produção (Critérios da Seção 12)

- [ ] **Todos os P0 resolvidos** *(REPROVADO: Falha P0-02 ativa; P0-01 e P0-03 resolvidos nas Unidades U1 e U2)*
- [ ] **Todos os P1 resolvidos ou formalmente aceitos** *(REPROVADO: Falhas P1-01, P1-02, P1-03 e P1-04 ativas)*
- [x] **Inicialização e configuração de produção validadas** *(APROVADO: Configuração e validação de ambiente na Unidade U1 via `AppConfig`; inicialização desacoplada, resiliente e ciclo de vida Riverpod em `main.dart` concluídos na Unidade U2 via `SupabaseInitializer`)*
- [x] **Banco local íntegro** *(APROVADO: Drift v4 com `PRAGMA foreign_keys = ON;`, `journal_mode = WAL;`, suporte IndexedDB via Wasm na Web)*
- [ ] **Migrações testadas e rastreáveis** *(REPROVADO: `app_database.dart` possui blocos `catch (_) {}` que silenciam falhas de DDL)*
- [ ] **Sincronização validada entre dispositivos** *(REPROVADO: Migração SQL remota não contém tabelas `voice_notes`, `phone_contacts`, `territory_landmarks` nem storage bucket)*
- [ ] **Conflitos tratados explicitamente na Agenda** *(REPROVADO: Inserções concorrentes de horários idênticos em nós offline distintos geram sobreposição silenciosa pós-sync)*
- [ ] **RLS e permissões validadas** *(PARCIAL: RLS ativo nas 7 primeiras tabelas, ausente nas tabelas e storage omitidos)*
- [x] **Dados sensíveis adequadamente protegidos** *(APROVADO: Backup AES-256 GCM + PBKDF2; bloqueio ativo de chaves `service_role` em `AppConfig`, mascaramento em logs e `.gitignore` blindado para `.env*`)*
- [x] **Backup e restauração testados com staging seguro** *(APROVADO: Staging em 3 etapas com rollback verificado por `TC-BAK-ADV-01` a `04`)*
- [ ] **Agenda validada contra concorrência** *(REPROVADO: Pendente detecção de colisões remotas)*
- [ ] **Áudio validado em dispositivo real** *(REPROVADO: Timer de 30s não encerra o hardware de gravação; requer teste físico no iOS)*
- [ ] **Transcrição documentada corretamente** *(REPROVADO: Descrita como "offline-first" no código, mas pode exigir rede no iOS/Web)*
- [x] **Testes automatizados aprovados** *(APROVADO: 534 testes passando com 100% de sucesso)*
- [x] **Análise estática aprovada** *(APROVADO: `dart analyze lib test --fatal-infos` acusa 0 issues)*
- [x] **Build Release Web aprovado** *(APROVADO: `flutter build web --release` compila com sucesso)*
- [ ] **Archive iOS e instalação real validados** *(PENDENTE: Depende de runner macOS e Apple Developer Account)*
- [ ] **Auditoria independente aprovada** *(PENDENTE: Aguardando correção dos itens P0 e P1)*
- [x] **Documentação atualizada** *(APROVADO: Documentações de engenharia atualizadas com ADR-010, ADR-011 e 534 testes)*

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
   - **Arquivo:** `supabase/migrations/20261026000000_initial_schema.sql` vs `lib/sync/supabase_sync_service.dart:52-63`
   - **Evidência:** `syncTables` sincroniza `voice_notes`, `phone_contacts` e `territory_landmarks`, e faz upload de mídias para o bucket `voice_notes`. O arquivo de migração não cria essas 3 tabelas nem o bucket de Storage.
   - **Impacto:** Erro HTTP 404 / PostgREST `42P01` (relação não existe) e falha total no envio/recepção de notas de voz, contatos e pontos de território.
   - **Status:** **PENDENTE (Alvo da Unidade U3)**.

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
   - Projeto Supabase dedicado para Homologação/Produção com execução das migrações SQL atualizadas e bucket `voice_notes` configurado.
