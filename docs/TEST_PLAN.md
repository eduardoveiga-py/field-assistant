# Plano de Testes Automatizados e Matriz de Integridade: Ministério Pessoal

## 1. Estratégia de Testes e Governança da Qualidade
O projeto adota uma pirâmide de testes rigorosa com execução contínua em CI/CD, garantindo **zero regressão funcional**, fidelidade às regras teocráticas de contagem ministerial e resiliência offline-first em todas as plataformas (Android, iOS, Web/WASM e Desktop).

### 1.1 Estatísticas da Suíte de Testes
- **Total de Testes Automatizados:** **635 testes** (100% de taxa de aprovação, 0 falhas, 0 erros, 0 skips não justificados).
- **Cobertura de Código:** > 90% em regras de negócio, cálculo de ritmo de pioneiro, persistência Drift e motor de sincronização.
- **Ambientes de Verificação:** SQLite nativo com chaves estrangeiras (`NativeDatabase.memory()`), Web WASM simulado, e PostgreSQL remoto com Supabase RLS real e emuladores de rede.

### 1.2 Pirâmide de Testes
1. **Testes Unitários & Regras de Negócio Puras:** Regras teocráticas de contagem (`counting_rules_test.dart`), motor de disponibilidade e colisões de agenda (`availability_engine_test.dart`), ritmo de pioneiro (`pioneer_pace_calculator_test.dart`), timer autocorretivo (`auto_corrective_timer_test.dart`), doorstep briefing (`doorstep_briefing_test.dart`), sementes recentes (`recent_seeds_test.dart`) e resolução canônica de links (`publication_link_resolver_test.dart`).
2. **Testes de Banco de Dados, Esquema e Migrações:** Banco Drift com 22 tabelas fortemente tipadas (`tables.dart`), migrações incrementais seguras v1 $\rightarrow$ v2 $\rightarrow$ v3 $\rightarrow$ v4 (`database_migration_test.dart`), integridade referencial com `PRAGMA foreign_keys = ON;` (`database_integrity_test.dart`) e repositório com mixins de domínio (`repository_database_test.dart`).
3. **Testes de Criptografia, Backup e Restauração:** Cifragem AES-256-GCM + PBKDF2-HMAC-SHA256 v2, inventário exaustivo de 22 tabelas, staging em 3 etapas para restauração de áudios, rollback atômico e recusa de `Directory.systemTemp` (`backup_service_test.dart`, `complete_backup_test.dart`).
4. **Testes de Sincronização, Resiliência e Backend Supabase:** Sincronização de 10 tabelas, outbox transacional, algoritmo de 3-way merge determinístico (`sync_engine_test.dart`), cursor incremental composto, tombstones de soft delete e barreira anti-ressurreição (`supabase_soft_delete_test.dart`), ciclo de vida e instabilidade de rede (`supabase_lifecycle_test.dart`), e hardening U3.2 (`supabase_hardening_u3_2_test.dart`, `u3_2_integrated_acceptance_test.dart`).
5. **Testes de Interface (Widgets, Layout e Acessibilidade):** Formulários com preservação de estado, responsividade em telas estreitas (320px) e escala extrema de texto (TextScaler 2.0x), modo de alto contraste para sol (`sunModeTheme`), alvos de toque $\ge 48\times 48$ dp, canvas cartográfico interativo e abas de detalhes (`widget_test.dart`, `person_detail_tabs_test.dart`, `layout_fixes_and_map_highlight_test.dart`).
6. **Suíte End-to-End (E2E) em 4 Tiers:** 60 testes cobrindo requisitos de ponta a ponta (R1 a R5), testes de borda extremos, fluxos combinados cross-feature e simulação realista de jornadas no ministério (`test/e2e/`).

---

## 2. Matriz de Casos de Teste Obrigatórios

### 2.1 Regras de Contagem Ministerial (Dashboard & Indicadores)
- [x] **TC-COUNT-01:** Um estudo bíblico compartilhado com múltiplos participantes distintos conta como **EXATAMENTE 1 estudo ativo**.
- [x] **TC-COUNT-02:** Uma sessão de estudo realizada com múltiplos presentes conta como **1 única sessão realizada**.
- [x] **TC-COUNT-03:** Sessão com status `cancelada` ou `nao_realizada` **NÃO** é contabilizada nas sessões realizadas do mês.
- [x] **TC-COUNT-04:** Uma revisita agendada para o futuro **NÃO** conta como revisita realizada no relatório.
- [x] **TC-COUNT-05:** Uma tentativa sem contato (`tentativa_sem_contato`) **NÃO** conta como conversa realizada no dashboard.
- [x] **TC-COUNT-06:** Contagem de Ações Pendentes e Contatos sem Contato Recente (> 30 dias).
- [x] **TC-COUNT-07:** Contagem e extração de assistência em sessões de estudo com notas `[Assistência: X]`.

### 2.2 Agenda, Disponibilidade e Conflitos de Horário
- [x] **TC-SCHED-01:** Detecção de sobreposição parcial de horários (ex: 14h00-14h30 colidindo com 14h20-14h50).
- [x] **TC-SCHED-02:** Detecção de compromisso totalmente contido em outro intervalo de horário (14h00-15h00 vs 14h15-14h45).
- [x] **TC-SCHED-03:** Permissão de agendamentos rigorosamente consecutivos quando não houver buffer/intervalo obrigatório configurado.
- [x] **TC-SCHED-04:** Respeito a intervalos e buffer de deslocamento entre visitas configurado pelo usuário.
- [x] **TC-SCHED-05:** Ignora compromissos cancelados ou reagendados para fins de detecção de colisão.
- [x] **TC-SCHED-06:** Ignora compromissos marcados com exclusão lógica (`deletedAt != null`).
- [x] **TC-SCHED-07:** Sugestões de horários alternativos são validadas contra todos os compromissos existentes e nunca colidem.
- [x] **TC-SCHED-08:** Ignora compromissos com status `realizado` para bloqueio de disponibilidade futura.
- [x] **TC-SCHED-09:** Preservação de histórico ao reagendar (registro original mantido como `reagendado`, novo criado).
- [x] **TC-SCHED-10:** Eventos de calendários externos (Google/Apple) bloqueiam disponibilidade sem contaminar metadados pastorais.

### 2.3 Sincronização Offline-First e Mesclagem
- [x] **TC-SYNC-01:** Gravação offline cria registro no banco local e operação correspondente na outbox (`sync_queue`).
- [x] **TC-SYNC-02:** Alteração de campos distintos em nós concorrentes (Nó A altera telefone, Nó B altera endereço) mescla perfeitamente sem perda.
- [x] **TC-SYNC-03:** Alteração divergente do mesmo campo sinaliza conflito real baseado em snapshot `_base` e exige resolução.
- [x] **TC-SYNC-04:** Reenvio de lote de mutações na outbox é idempotente e não gera duplicações de entidades locais.
- [x] **TC-SYNC-05:** Exclusão lógica (`deleted_at`) sincronizada é propagada como tombstone e sobrepõe edições obsoletas.

### 2.4 Persistência, Integridade e Backup
- [x] **TC-BAK-01:** Exportação de backup criptografado com envelope v2 (PBKDF2-HMAC-SHA256 + AES-256-GCM) e restauração integral.
- [x] **TC-BAK-02:** Rejeição segura de tentativa de restauração com senha incorreta ou dados corrompidos.
- [x] **TC-BAK-03:** Reimportar o mesmo backup é idempotente e não duplica registros devido ao uso de UUIDs v4 primários.
- [x] **TC-BAK-04:** Pré-visualização da restauração computa precisamente adições, atualizações e registros inalterados para todas as entidades.
- [x] **TC-BAK-05:** Inventário completo e exaustivo das 22 tabelas do banco Drift no backup.
- [x] **TC-BAK-06:** Exportação e restauração da tabela `syncQueue` (22ª tabela) preservando estado da sincronização offline.
- [x] **TC-BAK-07:** Backup com integridade SHA-256 e detecção automática de arquivos de áudio corrompidos.
- [x] **TC-BAK-08:** Prevenção de sobrescrita: registros locais mais recentes nunca são substituídos por dados antigos do backup.
- [x] **TC-BAK-09:** Snapshot de segurança prévio gerado compulsoriamente antes de iniciar a restauração.
- [x] **TC-BAK-10:** Rejeição imediata de arquivos de backup truncados ou com checksum SHA-256 divergente.
- [x] **TC-BAK-11:** `previewBackup()` detecta corrupção de arquivos de áudio via verificação SHA-256 sem injeção manual.
- [x] **TC-BAK-12:** Falha na geração do snapshot de segurança aborta a restauração imediatamente com `RestoreAbortedException`.
- [x] **TC-BAK-13:** Rollback transacional restaura o banco ao estado anterior e desfaz criação de arquivos de mídia caso ocorra falha.
- [x] **TC-BAK-14:** Snapshot de segurança durável persistido em disco e caminho/dados registrados no `AppKvStore`.

### 2.5 Resolvedor de Links Canônicos JW.org (`PublicationLinkResolver`)
- [x] **TC-PUB-01:** Resolução de lição e parágrafo para o livro *Seja Feliz para Sempre!* (lff) em Português gera URL canônica oficial JW.org.
- [x] **TC-PUB-02:** Resolução para idioma Libras (Língua Brasileira de Sinais) gera link de vídeo oficial sem quebra por ausência de parágrafos.
- [x] **TC-PUB-03:** Mecanismo de fallback gracioso para navegador web e cópia de citação caso deep links diretos não estejam disponíveis.

### 2.6 Notas de Voz, Ditado e Transações Atômicas (`VoiceNotesManager`)
- [x] **TC-VN-01:** Gravação de áudio e recuperação rápida vinculada a `personId`.
- [x] **TC-VN-02:** Exclusão lógica (`deletedAt != null`) mantendo rastreabilidade histórica.
- [x] **TC-VN-03:** Fluxo unificado atômico `saveQuickVisitFromVoiceNote` grava visita, nota e atualiza estudo/briefing sob transação única.
- [x] **TC-VN-04:** Prevenção de sobrescrita obsoleta de `lastContactAt` e `revision` em cenários concorrentes.
- [x] **TC-VN-05:** Diálogo responsivo em telas de 320px com escala de texto TextScaler 2.0x sem estouro de RenderFlex.

### 2.7 Sincronização Supabase Offline-First (`SupabaseSyncService`)
- [x] **TC-SYNC-SUPA-01:** Relato honesto de conectividade: informa `waitingConnection` / `savedLocally` quando offline ou unconfigured, sem falso `synced`.
- [x] **TC-SYNC-SUPA-02:** Fila de sincronização despacha mutações com backoff exponencial ($(2^{\text{attempts}} \le 300\text{s}) + \text{jitter de até } 25\%$) e limite de 5 tentativas.
- [x] **TC-SYNC-SUPA-03:** Sanitização de payload para entidades sensíveis (caminhos absolutos locais de áudio não são enviados para a nuvem).
- [x] **TC-SYNC-SUPA-04:** Mapeamento bidirecional rigoroso entre tabelas locais Drift e tabelas PostgreSQL remotas protegidas por RLS (`owner_id`).

### 2.8 Ritmo de Campo e Metas de Pioneiro (`PioneerPaceCalculator` & `PioneerPaceCard`)
- [x] **TC-PACE-01:** Cálculo exato de saídas restantes no mês e ritmo por saída para metas de 50h (regular), 30h e 15h (auxiliar).
- [x] **TC-PACE-02:** Invariantes de calendário para anos bissextos (fevereiro com 29 dias) e filtragem de dias designados da semana.
- [x] **TC-PACE-03:** Diálogo de configuração rápida com alvos de toque ergonômicos $\ge 48\times 48$ dp.
- [x] **TC-PACE-04:** Reatividade imediata sob alternância de temas (Claro, Escuro, Modo Sol) e persistência dual-write no `app_kv_store`.

---

## 3. Catálogo das Suítes Avançadas de Integridade (`TC-*-ADV-*`)

| Identificador | Módulo / Suíte | Descrição do Teste Avançado | Arquivo Fonte de Teste |
|---|---|---|---|
| **TC-BAK-ADV-01** | Backup & Restauração | **Staging e Rollback Seguro:** Sobrescrita de arquivo de áudio existente com falha injetada na transação do banco comprova que o arquivo original pré-existente é restaurado intacto a partir da pasta de segurança. | `test/backup_service_test.dart` (L692) |
| **TC-BAK-ADV-02** | Backup & Restauração | **Limpeza Transitória de Staging:** Qualquer falha antes, durante ou após a restauração não deixa diretórios temporários ou arquivos transitórios órfãos no disco. | `test/backup_service_test.dart` (L806) |
| **TC-BAK-ADV-03** | Backup & Restauração | **Recusa de Fallback para `systemTemp`:** Lança `StorageUnavailableException` e `RestoreAbortedException` quando o armazenamento seguro persistente de documentos não pode ser obtido, proibindo estritamente o uso de `Directory.systemTemp`. | `test/backup_service_test.dart` (L893) |
| **TC-BAK-ADV-04** | Backup & Restauração | **Snapshot Durável em KV Store:** Validação de que snapshot pré-restauração é gravado e recuperável via `getLastSafetySnapshotData` em ambientes Web e móveis. | `test/backup_service_test.dart` (L920) |
| **TC-SYNC-ADV-01** | Sincronização Supabase | **Cursor Incremental Determinístico:** Lote massivo com 120 registros remotos possuindo exatamente o mesmo timestamp `updated_at` é puxado na íntegra sem perdas através do desempate por `.order('updated_at').order('id')`. | `test/supabase_sync_service_test.dart` (L668) |
| **TC-SYNC-ADV-02** | Sincronização Supabase | **Resiliência em Upload de Áudio:** Upload de mídia para Supabase Storage não confirmado ou com falha de rede mantém a operação na outbox como `failed` sem marcar falso sucesso. | `test/supabase_sync_service_test.dart` (L743) |
| **TC-SYNC-ADV-03** | Sincronização Supabase | **Fila de Download de Mídia Pendente:** Falha no download de binário de áudio registra pendência na tabela local e permite recuperação automática por `retryPendingMediaDownloads()`. | `test/supabase_sync_service_test.dart` (L826) |
| **TC-SYNC-ADV-04** | Repositório / Outbox | **Enfileiramento Atômico de Mutações Indiretas:** A criação de uma visita (`createVisit`) que atualiza dados da pessoa vinculada gera atomicamente uma operação de `UPDATE` para `people` na `syncQueue` com snapshot `baseData`. | `test/repository_database_test.dart` (L332) |
| **TC-APPLE-ADV-01** | Integração Apple EventKit | **Proteção contra Exclusão Parcial Truncada:** Resposta do EventKit devolvendo fração anormalmente reduzida de eventos (> 25% de ausência súbita) preserva registros locais e bloqueia deleção em lote acidental. | `test/appointments/calendar_sync_test.dart` (L1291) |
| **TC-APPLE-ADV-02** | Integração Calendário | **Fingerprint SHA-256 com Regra de Recorrência:** Alteração de regra de recorrência (RRULE) modifica o fingerprint do evento externo e dispara atualização determinística da agenda local. | `test/appointments/calendar_sync_test.dart` (L1348) |
| **TC-DB-ADV-01** | Banco Drift / SQLite | **Integridade de Chaves Estrangeiras:** `PRAGMA foreign_keys = ON;` ativado impede fisicamente inserção de registros órfãos ao rejeitar chaves estrangeiras inexistentes. | `test/database_integrity_test.dart` (L27) |
| **TC-DB-ADV-02** | Banco Drift / SQLite | **Verificação Ativa de Chaves Estrangeiras na Conexão:** Consulta direta `PRAGMA foreign_keys;` na conexão ativa do SQLite retorna 1, validando a integridade da inicialização do driver. | `test/database_integrity_test.dart` (L69) |

---

## 4. Resiliência de Boot, Ciclo de Vida e Instabilidade de Rede

A suíte `test/sync/supabase_lifecycle_test.dart` (18 testes) e os testes de infraestrutura (`test/core/app_config_test.dart` e `test/core/supabase_initializer_test.dart`) garantem estabilidade absoluta sob condições adversas:
1. **Modo Offline Total no Boot:** Inicialização sem conexão de rede e sem configuração Supabase (`AppConfig.unconfigured`); SQLite local Drift e repositório operam com 100% de capacidade, com zero exceções de asserção (*zero AssertionError*).
2. **Preservação da Outbox em Quedas Transitórias:** Simulação de `SocketException` ou respostas HTTP 503 / 57P01 do PostgREST; a outbox preserva intactas todas as operações pendentes e não queima tentativas indevidamente.
3. **Backoff Exponencial com Jitter:** Algoritmo calcula tempo de espera $(2^{\text{attempts}} \text{ clamped em } 300\text{s}) + \text{jitter de até } 25\%$, prevenindo tempestades de reconexão (*thundering herd problem*).
4. **Teto de 5 Tentativas e Reenfileiramento Seguro:** Operações que atingem 5 falhas consecutivas são pausadas na outbox como `failed`, podendo ser reenfileiradas de forma controlada via `requeueFailedSyncOperations()`.
5. **Auto-Reconexão e Retomada em Segundo Plano:** Observadores de ciclo de vida (`WidgetsBindingObserver` e `stateStream`) detectam o retorno do aplicativo ao primeiro plano (`handleAppResume`) ou a recuperação da internet (`handleReconnection`), disparando automaticamente o esvaziamento da outbox.
6. **Exclusão Mútua de Sincronização (`isSyncing`):** Chamadas simultâneas a `processQueue` aguardam a conclusão da sincronização ativa em andamento, impedindo concorrência, corridas de dados ou duplicidade de requisições HTTP.
7. **Bloqueio de Falsos Indicadores de Sincronização:** Quando o aplicativo estiver offline ou sem backend configurado, chamadas a `sync()` nunca emitem status `synced`, reportando honestamente a suspensão temporária do envio.

---

## 5. Arquitetura de Tombstones, Soft Delete e Prevenção de Ressurreição

A suíte `test/sync/supabase_soft_delete_test.dart` valida os cenários críticos de integridade de exclusões lógicas (Testes A a K):
- **Cenário A — Propagação de Exclusão via Tombstone:** Dispositivo A exclui registro (`deleted_at: now()`); a mutação sobe como tombstone e o Dispositivo B atualiza o registro local marcando `deleted_at`, sem apagá-lo fisicamente do histórico local.
- **Cenário B — Barreira Anti-Ressurreição:** Dispositivo B tenta enviar um upsert com dados desatualizados (`updated_at <= deleted_at`); o trigger do PostgreSQL e o cliente rejeitam a mutação e preservam o tombstone no servidor.
- **Cenário C — Exclusões Repetidas e Idempotência:** Múltiplas exclusões da mesma entidade na fila mantêm o estado íntegro sem duplicação de eventos.
- **Cenário D — Recuperação de Falha de Rede no Envio de Tombstone:** Queda de rede imediatamente após envio de PATCH preserva a operação na outbox para retry automático sem perda do tombstone.
- **Cenário E — Cursor Incremental Composto:** O cursor de sincronização ordenado por `(updated_at, id)` garante que tombstones criados concorrentemente nunca sejam ignorados em pulls incrementais.
- **Cenário F — Sincronização Livre de Loop:** A aplicação de um tombstone remoto no SQLite local não enfileira operação de exclusão reversa na outbox.
- **Cenário G — Cobertura Total nas 10 Tabelas:** Soft delete validado formalmente em `people`, `visits`, `bible_studies`, `study_participants`, `study_sessions`, `appointments`, `activity_records`, `voice_notes`, `phone_contacts` e `territory_landmarks`.
- **Cenário H — Tombstones com Chaves Nulas:** Mutações de exclusão para registros parciais (ex: contatos telefônicos sem pessoa convertida) são processadas com sucesso.
- **Cenário I — Atomicidade no Drift:** Atualização de tombstones remotos atualiza atomicamente `deletedAt`, `updatedAt` e `revision` em uma única transação no SQLite.
- **Cenário J — Rejeição de Revisão Nula:** Upserts com `revision` ou `updated_at` nulos são bloqueados na barreira anti-ressurreição.
- **Cenário K — Concorrência Local DELETE vs Remoto UPDATE:** Conflitos entre exclusão pendente local e atualização remota são resolvidos priorizando a intenção de exclusão do usuário sem ressuscitar dados.

---

## 6. Suíte de Testes End-to-End (E2E) em 4 Tiers (`test/e2e/`)

A suíte mestre de testes E2E (`test/e2e/ministry_enhancements_e2e_test.dart`) agrupa **60 testes automatizados** distribuídos em 4 níveis arquiteturais:

### 6.1 Tier 1: Cobertura de Requisitos Funcionais (25 testes)
*Arquivo: `test/e2e/tier1_feature_coverage_test.dart`*
- **Requisito R1 (Doorstep Briefing & LFF):** Extração de metas de aprendizado, lição atual, pontos de empatia, dúvidas pendentes e links canônicos do livro *Seja Feliz para Sempre!* (TC-R1-01 a TC-R1-05).
- **Requisito R2 (Pioneer Pace Calculator & Card):** Cálculo dinâmico de horas restantes, saídas restantes e ritmo horário para pioneiros regulares (50h) e auxiliares (30h/15h) considerando dias da semana designados (TC-R2-01 a TC-R2-05).
- **Requisito R3 (Sementes Recentes & Alertas de Resfriamento):** Identificação de contatos com primeiro contato há menos de 7 dias sem revisita realizada, cálculo de tempo decorrido amigável ("Hoje", "há N dias") e alertas visuais (TC-R3-01 a TC-R3-05).
- **Requisito R4 (Plan B Recommender & GPS Haversine):** Sugestão inteligente de contatos alternativos em cancelamentos usando distância geográfica Haversine com GPS ou urgência/horário de preferência quando sem coordenadas (TC-R4-01 a TC-R4-05).
- **Requisito R5 (Timer Autocorretivo de Campo):** Detecção de cronômetros esquecidos ligados (> 4h), corte/ajuste automático para limites plausíveis e persistência direta em `ActivityRecords` (TC-R5-01 a TC-R5-05).

### 6.2 Tier 2: Casos de Borda e Limítrofes (26 testes)
*Arquivo: `test/e2e/tier2_boundary_corner_test.dart`*
- **Fronteiras de R1:** Contatos com todos os campos opcionais nulos, limites extremos de lição (Lição 1 a Lição 60 do LFF), caracteres especiais UTF-8 em notas de empatia e deep links para Libras sem parágrafos (TC-R1-06 a TC-R1-10).
- **Fronteiras de R2:** Metas já atingidas ou superadas (`completedHours >= goalHours`), 0 saídas restantes sem divisão por zero (NaN/Infinity), último dia do mês e cálculos em anos bissextos (TC-R2-06 a TC-R2-11).
- **Fronteiras de R3:** Contato exatamente no limiar de 7 dias (00:00:00), tentativas sem contato que mantêm status de semente recente e exclusão de pessoas soft-deleted (TC-R3-06 a TC-R3-10).
- **Fronteiras de R4:** Apenas 1 candidato disponível sem estouro de índice, candidato cancelado nunca recomendado para si mesmo e ordenação de contatos sem coordenadas no final da lista ranqueada (TC-R4-06 a TC-R4-10).
- **Fronteiras de R5:** Sessão com duração nula, cronômetro cruzando a meia-noite do fim do mês e preservação de notas descritivas (TC-R5-06 a TC-R5-10).

### 6.3 Tier 3: Combinações Cross-Feature (5 testes de integração profunda)
*Arquivo: `test/e2e/tier3_cross_feature_test.dart`*
- **TC-XF-01 [R4 + R3]:** Estudo cancelado aciona o Plano B, que prioriza sementes recentes não visitadas localizadas a curta distância a pé.
- **TC-XF-02 [R5 + R2]:** Timer esquecido ligado por 7 horas é ajustado automaticamente para 2 horas, grava no banco e recalcula o ritmo de pioneiro em tempo real.
- **TC-XF-03 [R4 + R1]:** Seleção de recomendação do Plano B prepara instantaneamente o cartão de Doorstep Briefing com notas do morador sugerido.
- **TC-XF-04 [R1 + R3]:** Visita a uma semente recente exibe simultaneamente o alerta de resfriamento e as notas do primeiro contato no briefing.
- **TC-XF-05 [R2 + R5]:** Conclusão de sessão de cronômetro atualiza o acumulado de horas do mês e impulsiona a meta de pioneiro à conclusão.

### 6.4 Tier 4: Cenários Reais do Ministério de Campo (4 testes de jornadas completas)
*Arquivo: `test/e2e/tier4_field_scenarios_test.dart`*
- **TC-SCENARIO-01:** Jornada completa de uma manhã de pregação: configuração de metas de pioneiro, início de cronômetro, registro de conversas iniciais, revisitas, notas rápidas e finalização de relatório.
- **TC-SCENARIO-02:** Desmarcação de estudante bíblico com recomendação do Plano B, consulta do Doorstep Briefing e reagendamento do estudo sem colisão na agenda.
- **TC-SCENARIO-03:** Recuperação e ajuste de cronômetro esquecido ligado, prevenindo distorção de relatórios mensais e mantendo o dashboard íntegro.
- **TC-SCENARIO-04:** Reta final de fechamento do mês de serviço (*Pioneer Sprint*), calculando esforço residual necessário e comemorando a meta alcançada.

---

## 7. Procedimentos de Execução e Validação Local

### 7.1 Execução da Suíte Completa
Para executar os 635 testes automatizados do repositório:
```powershell
# Execução completa via Flutter
flutter test

# Ou utilizando o script PowerShell de auditoria com formatação
.\scripts\run_tests.ps1
```

### 7.2 Execução Focada por Domínios
```powershell
# Apenas a suíte mestre E2E (60 testes)
flutter test test/e2e/ministry_enhancements_e2e_test.dart

# Apenas as suítes de Sincronização e Resiliência Supabase
flutter test test/sync/

# Apenas a suíte de Backup, Staging e Envelope v2
flutter test test/backup_service_test.dart

# Apenas a integridade de chaves estrangeiras Drift
flutter test test/database_integrity_test.dart
```

### 7.3 Verificação de Análise Estática
A suíte de testes exige conformidade estrita com o analisador do Dart:
```powershell
flutter analyze
# Saída esperada: "No issues found!" (0 erros, 0 avisos, 0 lints)
```
