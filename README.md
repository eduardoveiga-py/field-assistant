# Ministério Pessoal — Gestão Pessoal do Ministério de Campo

Aplicativo multiplataforma (**Web**, **iPhone XR** e **iPad 11 A16**) desenvolvido em **Flutter** e arquitetura **Offline-First**, projetado para organização do ministério de campo pessoal com privacidade total, alta legibilidade sob luz solar, agendamento sem colisões e contagem rigorosa de atividades.

---

## 🏛️ Princípios Arquiteturais e Invioláveis

1. **Separação Rígida de Entidades**:
   - `BibleStudy` ≠ `StudySession` ≠ `Participant` ≠ `Visit`.
   - Um estudo com múltiplos participantes (ex: casal) conta como **exatamente 1 estudo bíblico ativo**.
   - Uma sessão realizada com 3 participantes conta como **1 sessão de estudo realizada**.
   - Sessões canceladas ou não realizadas **NÃO** contam como sessões de estudo.
   - Revisitas agendadas para o futuro **NÃO** contam como revisitas realizadas.
   - Tentativas sem contato no território **NÃO** contam como conversas realizadas.

2. **Agenda Estilo Consultório Médico (`AvailabilityEngine`)**:
   - Detecção em tempo real de colisões de horário antes de salvar.
   - Bloqueio de sobreposições parciais ou totais.
   - Encaixes imediatamente consecutivos são permitidos quando não houver buffer configurado.
   - Sugestão automática de próximos horários livres no mesmo dia.

3. **Offline-First Verdadeiro com Drift**:
   - **Mobile / Desktop**: SQLite nativo via `sqlite3_flutter_libs`.
   - **Web**: Drift WebAssembly (`WasmDatabase` / IndexedDB).
   - Fila persistente de mutações (`SyncQueue`) gravada atomicamente na mesma transação local.
   - Detecção explícita de conflitos em nível de campos individuais (sem "last-write-wins" cego em anotações).

4. **Backup Criptografado de Ponta a Ponta (`BackupService`)**:
   - Criptografia **AES-256 GCM** com derivação de chave **PBKDF2** (100.000 iterações).
   - Checksum de integridade **SHA-256**.
   - Pré-visualização com detecção de diferenças antes de confirmar a restauração.
   - Restauração idempotente baseada em chaves primárias UUID e timestamp de revisão.

5. **Links Oficiais para Publicações (`PublicationLinkResolver`)**:
   - Mapeamento direto verificado para o livro *Seja Feliz para Sempre!* nos idiomas Português (`pt`), Libras (`bzs`) e Ticuna (`tca`).
   - Deep links honestos: fallback seguro para página inicial da publicação ou jw.org quando a lição direta não for suportada na língua de sinais.

6. **Design e Acessibilidade Sob Luz Solar (`mobile-ux-accessibility`)**:
   - Contraste elevado (WCAG AAA para textos de dados e status).
   - Alvos de toque amplos (mínimo de 48dp).
   - Layout responsivo adaptativo: `NavigationBar` ergonômica para iPhone XR (414x896) e `NavigationRail` lateral para iPad / Desktop (larguras ≥ 768px).

---

## 📁 Estrutura de Diretórios e Documentação

```
docs/
  ├── ARCHITECTURE.md           # Visão geral de arquitetura e camadas
  ├── DATA_MODEL.md             # Esquema das tabelas e regras de contagem
  ├── SYNC_PROTOCOL.md          # Protocolo da fila de sincronização e merge
  ├── SECURITY.md               # Políticas RLS, telemetria zero e privacidade
  ├── JW_LIBRARY_LINKS.md       # Catálogo e limitações de deep links
  ├── TEST_PLAN.md              # Matriz completa de casos de teste
  └── DECISIONS.md              # ADRs (Architectural Decision Records 001 a 005)
lib/
  ├── core/                     # Tema acessível, utilitários de data e gerador demo
  ├── database/                 # Drift tables, repositório transacional e conexões
  ├── appointments/             # Motor de disponibilidade e colisão de agenda
  ├── dashboard/                # Regras de contagem e inteligência de pendências
  ├── publications/             # Catálogo de publicações e resolvedor de links
  ├── settings/                 # Backup criptografado e exportação/importação
  ├── sync/                     # Motor de merge e detecção de conflitos
  └── ui/                       # Telas (Hoje, Pessoas, Agenda, Estudos, Dashboard, Atividades, Lixeira, Ajustes)
scripts/                        # Scripts para inicialização web e execução de testes no Windows
supabase/                       # Migrações PostgreSQL e políticas RLS para sincronização
test/                           # Suíte automatizada com 586 testes cobrindo todos os módulos
```

---

## 🚀 Como Executar o Projeto Localmente

### Atalhos Prontos para Windows (PowerShell / Prompt)
- Para rodar a versão Web no Chrome com abertura automática e fallback:
  ```powershell
  .\scripts\run_web.ps1 -Server
  ```
  *(detecta automaticamente o arquivo `.env` local caso exista)*
- Para rodar especificando um arquivo de ambiente (ex: homologação):
  ```powershell
  .\scripts\run_web.ps1 -Server -EnvFile .env.homolog
  ```
- Para rodar a análise estática estrita (`--fatal-infos`) e todos os testes:
  ```powershell
  .\scripts\run_tests.ps1
  ```

### Pré-requisitos Manuais
- **Flutter SDK**: Versão 3.27+ (Dart 3.13+) instalado.
- **Google Chrome** ou **Microsoft Edge** para testes em Web.

### 1. Configuração de Variáveis de Ambiente
O aplicativo adota a arquitetura **Offline-First**:
- Sem nenhuma configuração, o app opera 100% offline com persistência local em SQLite/IndexedDB.
- Para habilitar sincronização com o Supabase, configure o arquivo `.env` a partir do template:
  ```bash
  cp .env.example .env
  ```
  *(Consulte [docs/ENVIRONMENT_CONFIGURATION.md](docs/ENVIRONMENT_CONFIGURATION.md) para detalhes completos)*

### 2. Instalação das Dependências
```bash
flutter pub get
```

### 3. Execução no Navegador (Web)
```bash
# Modo com injeção de variáveis de ambiente:
flutter run -d chrome --dart-define-from-file=.env

# Modo puramente offline:
flutter run -d chrome
```

### 4. Compilação para Produção (Web & iOS Release)
```bash
# Web Release:
flutter build web --release --dart-define-from-file=.env.prod

# iOS Release (IPA):
flutter build ipa --release --dart-define-from-file=.env.prod
```

---

## 🧪 Suíte de Testes Automatizados

Para executar todos os **586 testes automatizados** unitários, transacionais, adversariais e de interface:
```bash
flutter test
```

Para validar a integridade estática do código (zero erros, zero warnings, zero infos):
```bash
dart analyze lib test --fatal-infos
```

### Cobertura de Testes (586 Testes Aprovados com 100% de Sucesso)
- `test/sync/supabase_hardening_u3_2_test.dart`: Preservação de snapshot `_base` e incremento atômico de `revision` nos managers (`phone_contacts`, `landmarks`, `voice_notes`), 3-way merge determinístico sem sobrescrita cega no inbound sync, preservação de caminho local de áudio (`audioFilePath`), normalização de tags JSONB e booleans no payload Supabase, requeue de outbox atômico e com clamping de tentativas, recuperação resiliente de boot (`retryInitialization`), e validação de regras de migração SQL/Storage RLS.
- `test/sync/supabase_soft_delete_test.dart`: Eliminação de exclusões físicas no Supabase, propagação incremental via tombstones (`deleted_at`), barreira contra ressurreição por upserts antigos no cliente e no PostgreSQL (trigger function), idempotência, resiliência a falhas transitórias de rede, cursor incremental sem perda de tombstones simultâneos, zero loop de outbox e validação em todas as 10 tabelas sincronizadas.
- `test/sync/supabase_u3_schema_storage_test.dart`: DDL SQL remota e integridade de schema das 3 tabelas faltantes (`voice_notes`, `phone_contacts`, `territory_landmarks`), bucket privado `voice_notes` (10 MB, m4a/mp4/aac), contratos RLS positivo/negativo/anônimo, isolamento de Storage, serialização/sanitização snake_case, 3-way merge inbound no Drift e reprocessamento seguro da outbox via `requeueFailedSyncOperations()`.
- `test/core/app_config_test.dart`: Validação centralizada de ambiente (dev/homolog/prod), bloqueio de chaves privilegiadas (`service_role`), URLs válidas, mascaramento de segredos em logs e modo offline resiliente.
- `test/core/supabase_initializer_test.dart`: Inicialização idempotente desacoplada, lock de concorrência com Completer, sanitização de credenciais em logs, probe ativo de conectividade (/rest/v1/), preservação de `authenticationRequired`, proteção contra `AssertionError` em `clientOrNull` e reatividade Riverpod Notifiers.
- `test/sync/supabase_lifecycle_test.dart`: Boot 100% offline sem exceções, durabilidade da outbox em falhas transitórias de rede, limite de 5 retentativas sem starvation/loop infinito, algoritmo de backoff exponencial com jitter, recuperação pós-reconexão, resume em background via `WidgetsBindingObserver`, transações simultâneas na outbox, trava de reentrância `isSyncing`, resiliência a falhas de rede sem queima de tentativas subsequentes, 3-way merge para failed ops e auto-reconexão via stream.
- `test/counting_rules_test.dart`: Regras de contagem de estudos com múltiplos participantes, sessões, visitas, ações pendentes e contatos recentes.
- `test/availability_engine_test.dart`: Detecção de sobreposição, contenção, horários consecutivos, buffers, sugestões inteligentes e status realizado.
- `test/publication_link_resolver_test.dart`: Resolução de links em Português, Libras e fallback seguro.
- `test/repository_database_test.dart`: Transações atômicas com `SyncQueue`, busca offline, reagendamento com histórico (`previousAppointmentId`), atualização de visitas e lixeira com restauração.
- `test/sync_engine_test.dart`: Mesclagem em campos distintos, conflitos sem sobrescrita cega e idempotência.
- `test/supabase_sync_service_test.dart`: Despachante da fila de sincronização, backoff exponencial, status honesto offline/online e mapeamento de tabelas.
- `test/backup_service_test.dart` & `test/lff_and_priority_test.dart`: Envelope PBKDF2-HMAC-SHA256 (100k iter.) + AES-256 GCM, detecção de adulteração, compatibilidade v1/v2, chave de dispositivo e 10 tabelas sincronizáveis.
- `test/voice_notes_test.dart`: Parser determinístico puro Dart (ordinais, números, nomes, empatia), persistência Drift tipada, transação atômica multi-tabela e alvos ergonômicos >= 48dp.
- `test/pioneer_pace_adversarial_test.dart` & `test/pioneer_pace_card_adversarial_test.dart`: Desafios adversariais de calendário, anos bissextos, metas extremas, estresse de renderização 320px com TextScaler 2.0x e persistência concorrente.
- `test/doorstep_briefing_adversarial_test.dart`: Briefing na porta, sementes recentes, textos ultra-longos e acessibilidade sob sol.
- `test/widget_test.dart`: Navegação responsiva iPad (`NavigationRail`) e iPhone XR (`NavigationBar`), sem vazamentos de layout.


---

## 🎮 Modo de Demonstração (Demo Offline)

Para experimentar o aplicativo imediatamente sem necessidade de criar contas ou conectar ao backend:
1. Abra a tela **Hoje** ou **Ajustes**.
2. Clique no card **Carregar Dados de Demonstração**.
3. O sistema gerará pessoas com diferentes situações (Interessados, Revisitas, Estudos), compromissos do dia, sessões de estudo em andamento e histórico de visitas.
4. Todos os dados fictícios ficam isolados no banco local e podem ser removidos a qualquer momento.
