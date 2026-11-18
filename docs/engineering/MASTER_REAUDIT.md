# FIELD ASSISTANT — MASTER ENGINEERING RE-AUDIT
**Documento Oficial de Engenharia — Fase Zero Documental (M0)**  
**Programa:** Field Assistant Master Engineering Program (FAES 10/10)  
**Repositório:** `eduardoveiga-py/field-assistant`  
**Branch Auditada:** `master` / `stabilization/faes-master-program`  
**HEAD de Referência Auditado:** `6e1020fe867b97e64ff162bdf7d2fb231d04aaef`  
**Data da Auditoria:** 18 de Novembro de 2026  
**Status do Quality Gate:** **NOT APPROVED (Score: 6.72 / 10.0)**  
**Padrão Normativo:** Field Assistant Engineering Standard (FAES) — `AGENTS.md` & `.agents/skills/field-assistant-engineering-standard/SKILL.md`

---

## 1. SUMÁRIO EXECUTIVO & PROGRAM BASELINE

### 1.1. Contexto e Mandato do Programa Mestre
O aplicativo **Field Assistant** é uma solução móvel e desktop desenvolvida em Flutter/Dart voltada para apoio à atividade de campo ministerial e voluntária, operando sob o paradigma arquitetural **offline-first**. As plataformas prioritárias de produção são **iPhone** e **iPad** (iOS/iPadOS), com suporte secundário a Android e Web.

Em conformidade com a **Ordem Mestra de Engenharia** e o **Field Assistant Engineering Standard (FAES)**, este documento consolida a re-auditoria técnica exaustiva do repositório no commit de referência `6e1020fe867b97e64ff162bdf7d2fb231d04aaef`. 

O objetivo primordial desta Fase Zero Documental é **eliminar qualquer dissociação entre código-fonte, suíte de testes e documentação prévia**, substituindo narrativas teóricas por evidências empíricas, rastreabilidade forense por linha de código e um plano de remediação rigoroso para levar o produto à conformidade 10/10 do FAES.

### 1.2. Veredito do Quality Gate: NOT APPROVED (6.72 / 10.0)
Conforme estipulado na Seção 3 do FAES, a aprovação de release exige:
1. Pontuação média ponderada $\ge 9.7 / 10.0$;
2. Nenhuma dimensão técnica com nota $< 9.0 / 10.0$;
3. Zero ocorrências de severidade P0 ou P1 não remediadas;
4. Nenhuma via de exposição desprotegida de dados sensíveis ou bypass de criptografia.

A avaliação forense independente deste repositório estabeleceu a nota global de **6.72 / 10.0**, com quatro dimensões críticas abaixo de 7.5 (Arquitetura: 5.5; UX/Acessibilidade: 5.0; Testes/CI: 6.5; Release/CI/CD: 6.5) e a existência de **duas vulnerabilidades P0 críticas** e **nove defeitos de severidade P1**.

O sistema encontra-se formalmente **NOT APPROVED** para lançamento em produção ou declaração de conclusão.

---

## 2. MATRIZ CONSOLIDADA DE SEVERIDADE (P0, P1, P2, P3)

Esta matriz cataloga todos os achados empíricos validados pelos levantamentos das frentes de Segurança/Banco de Dados, Cartografia e Sincronização/CI/UX, com arquivos e linhas exatas.

| ID | Severidade | Área Técnica | Descrição Sintética | Arquivos e Linhas de Evidência |
|:---:|:---:|:---|:---|:---|
| **P0-01** | **P0 (Crítico)** | Segurança & DB | **Fallback silencioso para SQLite plaintext** na criação e abertura do banco local quando `sqlite3mc` ou chave falham. | `lib/database/connection/native.dart:42-50, 54-64`<br>`lib/database/connection/local_database_encryption.dart:167-175` |
| **P0-02** | **P0 Estratégico** | Cartografia | **Ausência real do MapLibre Native:** dependência inexistente no `pubspec.yaml`, `MapEngineAdapter` é casca órfã de 8 linhas com zero implementações, e a UI usa monólito raster de 4.489 linhas em `InteractiveViewer`. | `pubspec.yaml:30-78, 111-114`<br>`lib/territory/map_engine_adapter.dart:235-242`<br>`lib/ui/screens/contacts_map_screen.dart:3080-3150` |
| **P1-01** | **P1 (Alto)** | Mídias E2EE | **Mídias cifradas sobrescritas prematuramente com `upsert: true`:** caminho sem versionamento no Storage destrói chunks da versão ativa antes do manifesto e do CAS no banco. | `lib/sync/crypto/encrypted_media_transfer.dart:65-103, 120-128`<br>`lib/sync/supabase_sync_service.dart:4678-4729` |
| **P1-02** | **P1 (Alto)** | Banco Remoto | **Migração Supabase chama função inexistente `handle_soft_delete_and_resurrection_guard()`:** aborta migração em bancos limpos (`supabase db reset`). | `supabase/migrations/20261112000000_hardening_storage_indexes_rls.sql:130` |
| **P1-03** | **P1 (Alto)** | iOS & Integridade | **Política iOS `NSFileProtectionComplete` causando crash/falhas de SQLite em background:** chaves de arquivo e descritores SQLite são revogados com a tela bloqueada. | `ios/Runner/Runner.entitlements:4-7`<br>`ios/Runner/AppDelegate.swift:107-112` |
| **P1-04** | **P1 (Alto)** | Cartografia | **Validador de pacotes rejeita ativamente MBTiles vetoriais:** `_validateMbtilesFile` lança exceção para MVT/PBF; suporte a PMTiles é apenas enum; ativos offline ausentes no bundle. | `lib/territory/mbtiles/mbtiles_native.dart:273-308`<br>`pubspec.yaml:111-114` |
| **P1-05** | **P1 (Alto)** | Cartografia | **Geocodificação 100% online sem cache local no Nominatim:** chamadas HTTP diretas quebram funcionamento offline no campo e violam política de rate limit de 1 req/s. | `lib/territory/geocoding_service.dart:52-119, 122-159` |
| **P1-06** | **P1 (Alto)** | Cartografia / UX | **Rotação de mapa inverte textos e pinos de cabeça para baixo:** `Transform.rotate` no canvas inteiro sem contra-rotação individual de widgets ou suporte a pitch 3D. | `lib/ui/screens/contacts_map_screen.dart:3080-3085, 4118-4183, 4245-4290` |
| **P1-07** | **P1 (Alto)** | CI/CD | **CI omite `integration_test/` e restringe formatação a 18 arquivos:** pipeline executa apenas `flutter test` e ignora dezenas de arquivos com divergência de estilo. | `.github/workflows/ci.yml:140, 163`<br>`integration_test/app_stabilization_e2e_test.dart` |
| **P1-08** | **P1 (Alto)** | iOS & Áudio | **Ausência total de tratamento de interrupções de áudio (`AVAudioSession`):** chamadas telefônicas ou alarmes abortam/corrompem notas de voz sem recuperação de estado. | `lib/voice_notes/audio_recording_service.dart:63-289, 505-620` |
| **P2-01** | **P2 (Médio)** | iPad UX | **iPad Split-View Master-Detail ausente em 25 de 26 telas:** apenas `people_screen.dart` adapta layout para telas amplas; as demais 25 telas esticam interfaces mobile. | `lib/ui/screens/` (todas exceto `people_screen.dart:45-80`) |
| **P2-02** | **P2 (Médio)** | Acessibilidade | **Deficit severo de acessibilidade e VoiceOver:** widget `Semantics` instanciado em apenas duas linhas em todo o projeto; sem cabeçalhos e sem anúncios dinâmicos. | `lib/ui/screens/people_screen.dart:1052`<br>`lib/ui/screens/person_detail_screen.dart:4611` |
| **P2-03** | **P2 (Médio)** | Arquitetura | **22 telas monolíticas > 500 linhas (10 telas > 2.000 linhas):** acoplamento severo de banco, lógica de negócios e UI (`person_detail` com 7.499 linhas). | `lib/ui/screens/person_detail_screen.dart`<br>`lib/ui/screens/appointments_screen.dart:1-4687` |
| **P2-04** | **P2 (Médio)** | Sincronização | **Detector de conflitos de domínio restrito a agendamentos:** conflitos temporais e duplicações em `bible_studies` e `tasks` não são reconciliados pelo motor. | `lib/sync/domain_conflict_detector.dart:56-150` |
| **P2-05** | **P2 (Médio)** | CI/CD | **Verificação de cobertura de testes não enforçada no CI:** `tool/ci_coverage_check.py` é chamado sem `--enforce-crypto-min=90`, impedindo que quedas de cobertura quebrem a build. | `.github/workflows/ci.yml:172` |
| **P3-01** | **P3 (Baixo)** | Manutenibilidade | Catálogo de MBTiles offline possui 23 regiões cadastradas, mas 22 têm `downloadUrl: null`, disparando exceção 404 caso solicitadas sem URL customizada. | `lib/territory/mbtiles/mbtiles_service.dart:126-362, 634-638` |

---

## 3. ANÁLISE FORENSE DETALHADA DAS VULNERABILIDADES E DEFEITOS

### 3.1. [P0-01] Falha de Segurança Fail-Open: Fallback Silencioso para SQLite Plaintext
- **Componentes:** `lib/database/connection/native.dart` e `lib/database/connection/local_database_encryption.dart`.
- **Mecanismo da Falha:**
  O arquivo `native.dart` gerencia a inicialização da conexão local do Drift no desktop e mobile. No método `constructDb()`:
  ```dart
  // native.dart linhas 26-50:
  try {
    final candidateKey = await LocalDatabaseEncryption.getOrCreateHexKey();
    final result = await LocalDatabaseEncryption.prepareEncryptedDatabaseFile(
      file,
      hexKey: candidateKey,
    );
    encryptionActive = result.encryptionActive;
    if (encryptionActive) {
      dbHexKey = candidateKey;
    }
  } catch (e, st) {
    AppLogger.error('Falha ao preparar criptografia SQLite local...', e, st);
    // Linha 45-49:
    if (file.existsSync() &&
        file.lengthSync() >= 16 &&
        !LocalDatabaseEncryption.isPlaintextSqliteFile(file)) {
      rethrow;
    }
  }
  // Linha 54: prossegue com abertura do banco!
  return NativeDatabase.createInBackground(
    file,
    setup: (rawDb) {
      if (encryptionActive && dbHexKey != null) {
        LocalDatabaseEncryption.applyKeyPragma(rawDb, dbHexKey);
      }
      ...
    },
  );
  ```
  Adicionalmente, em `local_database_encryption.dart` (linhas 167–175):
  ```dart
  if (!isSqlite3McAvailable()) {
    AppLogger.warning('SQLite3MultipleCiphers indisponível... mantendo abertura padrão.');
    return const LocalDatabaseEncryptionResult(
      encryptionActive: false,
      migratedFromPlaintext: false,
    );
  }
  ```
- **Cenários de Exposição Crítica:**
  1. **Dispositivo sem suporte nativo a `sqlite3mc`:** `prepareEncryptedDatabaseFile` retorna silenciosamente `encryptionActive: false`. O banco é criado ou aberto em texto puro (`plaintext`), violando diretamente o princípio fail-closed.
  2. **Primeira instalação com Keychain inacessível:** Se `getOrCreateHexKey()` lançar exceção (ex.: erro de permissão ou Keychain bloqueado) em uma instalação nova, `file.existsSync()` é falso. A exceção é engolida pelo bloco `catch`, `encryptionActive` permanece `false`, e o app cria um banco SQLite virgem em texto puro sem chave.
  3. **Banco existente em texto claro:** Se um banco plaintext existir no disco e a leitura da chave falhar, `!LocalDatabaseEncryption.isPlaintextSqliteFile(file)` é falso. A exceção é descartada e o banco continua operando em texto claro indefinidamente.
- **Invariante Violada:** FAES Seção 1 (Invariante 8: Privacy by design) e Seção 5.1 (Fail-closed encryption).

### 3.2. [P0-02 Estratégico] Ausência Real do MapLibre Native e Ilusão Arquitetural
- **Componentes:** `pubspec.yaml`, `lib/territory/map_engine_adapter.dart`, `lib/ui/screens/contacts_map_screen.dart`.
- **Mecanismo da Falha:**
  A documentação oficial do repositório (`docs/engineering/MAP_ENGINE_ARCHITECTURE.md`) declarava que o Field Assistant já operava sob o padrão Nível 2 de Cartografia ou utilizava `flutter_map` como transição. A realidade do código-fonte revela:
  1. O pacote `maplibre_gl` (ou qualquer motor vetorial alternativo) **não existe** no `pubspec.yaml`.
  2. O arquivo `lib/territory/map_engine_adapter.dart` define a classe abstrata `MapEngineAdapter` com 8 linhas de assinatura, mas **não existe uma única classe concreta em todo o repositório que a implemente** (`implements MapEngineAdapter = 0`).
  3. A tela do mapa (`ContactsMapScreen`) é um monólito de **4.489 linhas** que implementa um visualizador cartográfico artesanal em Dart sobre `InteractiveViewer`:
     - Níveis de zoom discretizados por números inteiros (`_zoom = 15`), simulando saltos bruscos via escala do `InteractiveViewer` ($\ge 1.35$ ou $\le 0.75$).
     - Tiles raster PNG baixados via HTTP (`tile.openstreetmap.org`, CartoDB, etc.) e empilhados em uma árvore de widgets Flutter (`DynamicTileLayer`).
     - A rotação do mapa é um `Transform.rotate` aplicado no contêiner do `InteractiveViewer`. Ao girar o mapa, **todos os pinos e rótulos de contatos giram de ponta-cabeça** (sem contra-rotação).
- **Invariante Violada:** Ordem Mestra de Engenharia (Item 3 e 4) e FAES Seção 5.5.

### 3.3. [P1-01] Sobrescrita Prematura e Destruição de Mídias Cifradas (`upsert: true`)
- **Componentes:** `lib/sync/crypto/encrypted_media_transfer.dart` (linhas 65–128).
- **Mecanismo da Falha:**
  Ao enviar mídias ponta-a-ponta cifradas para o Supabase Storage, o path dos blocos é computado como:
  `$owner/e2ee/$safeMediaId/chunk_$index.enc`.
  Durante o upload, os chunks são gravados com `fileOptions: const FileOptions(upsert: true)`.
  Se um usuário editar ou atualizar uma mídia existente (ex.: foto de perfil recém-capturada ou nota de voz re-gravada), os chunks da nova versão sobrescrevem imediatamente os blocos da versão anterior antes da escrita do manifesto (`manifest.enc`).
  Caso a conexão caia no bloco 3 de 5, o bloco `catch` executa:
  ```dart
  if (uploadedChunks.isNotEmpty) {
    try {
      await client.storage.from(bucket).remove(uploadedChunks);
    } catch (_) {}
  }
  ```
  Isso apaga os blocos 0, 1 e 2 recém-enviados, que já haviam sobrescrito e destruído os blocos 0, 1 e 2 da versão original válida. A mídia original é irrevogavelmente perdida no Storage antes de qualquer confirmação de banco.
- **Invariante Violada:** FAES Seção 1 (Invariante 2: Preservação de dados) e Seção 5.1.

### 3.4. [P1-02] Erro Fatal em Migração do Supabase (`handle_soft_delete_and_resurrection_guard`)
- **Componentes:** `supabase/migrations/20261112000000_hardening_storage_indexes_rls.sql` (linha 130).
- **Mecanismo da Falha:**
  A linha 130 executa:
  ```sql
  ALTER FUNCTION public.handle_soft_delete_and_resurrection_guard() SET search_path = public;
  ```
  Uma varredura completa no histórico de migrações (`20261026000000` até `20261118000000`) demonstra que a função `handle_soft_delete_and_resurrection_guard()` **nunca foi criada** com `CREATE FUNCTION`.
  Qualquer tentativa de inicializar um ambiente de banco novo ou executar testes automatizados com `supabase db reset` aborta com erro fatal de objeto relacional inexistente.

### 3.5. [P1-03] Política iOS `NSFileProtectionComplete` vs Execução em Background
- **Componentes:** `ios/Runner/Runner.entitlements` (linhas 4–7) e `ios/Runner/AppDelegate.swift` (linhas 107–112).
- **Mecanismo da Falha:**
  O projeto aplica a política Apple `NSFileProtectionComplete` (Classe A de Proteção de Dados) para os arquivos locais e banco SQLite.
  Na Classe A, o subsistema criptográfico do iOS revoga as chaves do sistema de arquivos e fecha os file descriptors assim que a tela do dispositivo é bloqueada pelo usuário.
  Como o uso típico no campo ministerial envolve bloquear o aparelho e colocá-lo no bolso enquanto notas de voz são processadas, sincronizações de outbox ocorrem ou lembretes disparam, qualquer consulta do Drift/SQLite executada em background é terminada com erro de I/O de disco (`SqliteException: disk I/O error`), gerando instabilidade e falhas de persistência.
  A política correta exigida pelo padrão FAES é `NSFileProtectionCompleteUntilFirstUserAuthentication` (Classe B).

### 3.6. [P1-04] Rejeição Ativa de MBTiles Vetoriais e Falta de Ativos Offline
- **Componentes:** `lib/territory/mbtiles/mbtiles_native.dart` (linhas 273–308) e `pubspec.yaml` (linhas 111–114).
- **Mecanismo da Falha:**
  O validador nativo `_validateMbtilesFile` inspeciona a tabela `tiles` e analisa os primeiros bytes do blob `tile_data`. Se os bytes mágicos não forem PNG (`0x89 0x50`), JPEG (`0xFF 0xD8`) ou WebP (`WEBP`), ele deliberadamente lança:
  `FormatException('Pacote não contém tiles raster PNG, JPEG ou WebP compatíveis')`.
  Portanto, o app é ativamente incompatível com pacotes MBTiles vetoriais padronizados (Mapbox Vector Tiles em `.pbf`).
  Além disso, o `pubspec.yaml` tem sua seção `assets:` completamente comentada; não existe nenhum arquivo `style.json`, fontes `.pbf` ou sprites empacotados no bundle da aplicação.

### 3.7. [P1-05] Geocodificação Nominatim 100% Online sem Cache
- **Componentes:** `lib/territory/geocoding_service.dart` (linhas 52–159).
- **Mecanismo da Falha:**
  Os métodos `reverseGeocode` e `geocodeAddress` disparam requisições diretas via `http.get` para os endpoints públicos da API do OpenStreetMap Nominatim.
  Não existe tabela no Drift/SQLite para cache de consultas anteriores, não existe cache LRU em memória e não existe limitação de taxa (rate limiting de 1 req/s, exigência da OpenStreetMap Foundation). Em áreas rurais ou locais sem cobertura de celular, a busca e a resolução de coordenadas falham sumariamente com timeout.

### 3.8. [P1-06] Rotação 2D com Inversão de Elementos Gráficos
- **Componentes:** `lib/ui/screens/contacts_map_screen.dart` (linhas 3080–3085, 4118–4183, 4245–4290).
- **Mecanismo da Falha:**
  A rotação do mapa é efetuada envolvendo toda a árvore do `InteractiveViewer` em um `Transform.rotate(angle: _rotationAngle)`.
  Não há lógica de contra-rotação nos widgets filhos que renderizam os pinos dos contatos (`_buildMapPin`) ou marcos (`_buildLandmarkPin`). Quando o usuário navega em direção ao Sul (180°), fotos, nomes, números de casas e ícones ficam invertidos de cabeça para baixo, tornando a leitura impossível no campo. Os textos das ruas (sendo pixels raster de PNGs) também giram de forma invertida.

### 3.9. [P1-07] Omissão de Testes de Integração e Formatação no CI
- **Componentes:** `.github/workflows/ci.yml` (linhas 139–140, 163).
- **Mecanismo da Falha:**
  1. A suíte de integração end-to-end existe no repositório (`integration_test/app_stabilization_e2e_test.dart`), mas o CI executa apenas `flutter test --coverage`. No Flutter, o comando `flutter test` restringe-se estritamente à pasta `test/`, ignorando `integration_test/`. Os testes de integração não rodam no pipeline automatizado.
  2. O passo de validação de formatação `dart format` no GitHub Actions está restrito a uma lista codificada de apenas 18 arquivos. A execução de `dart format --output=none --set-exit-if-changed lib test` falha imediatamente em virtude de divergências de estilo acumuladas em dezenas de arquivos.

### 3.10. [P1-08] Ausência de Gerenciamento de Sessão de Áudio no iOS
- **Componentes:** `lib/voice_notes/audio_recording_service.dart` (linhas 63–289, 505–620).
- **Mecanismo da Falha:**
  A gravação e reprodução de notas de voz utilizam plugins de alto nível sem configuração de `AVAudioSession` nativa e sem escuta a eventos de interrupção (`AVAudioSessionInterruptionNotification`).
  Se o voluntário receber uma chamada telefônica, acionar a Siri ou disparar um alarme sonoro durante uma gravação no ministério, a captura é abortada bruscamente pelo sistema operacional sem que o áudio já capturado seja persistido e sem restauração do estado após o término da interrupção.

---

## 4. DESMASCARAMENTO DAS CONTRADIÇÕES ARQUITETURAIS

A tabela a seguir confronta diretamente as alegações contidas na documentação anterior com as evidências físicas irrefutáveis extraídas do código-fonte auditado:

| Componente / Tópico | Afirmação na Documentação Anterior | Evidência Real no Código (HEAD `6e1020f`) | Gravidade da Contradição |
|:---|:---|:---|:---:|
| **Motor Cartográfico** | *"flutter_map + MBTiles Raster (Atual)"* (`MAP_ENGINE_ARCHITECTURE.md`, linha 11) | O pacote `flutter_map` **não existe** no `pubspec.yaml`. O mapa é um `InteractiveViewer` artesanal em Dart puro. | **Inverdade Crítica** |
| **Abstração do Mapa** | *"UI desacoplada via MapEngineAdapter"* (`MAP_ENGINE_ARCHITECTURE.md`, linhas 28-30) | `MapEngineAdapter` é uma interface de 8 linhas com **zero implementações** no repositório. Nenhuma tela do app a utiliza. | **Teatro Arquitetural** |
| **Geocodificação Offline** | *"Nominatim (online com cache LRU/SQLite, rate limit 1 req/s...)"* (`MAP_ENGINE_ARCHITECTURE.md`, linha 37) | `GeocodingService` faz chamadas diretas via HTTP sem qualquer tabela SQLite, sem cache em memória e sem controle de taxa de 1 req/s. | **Inverdade Funcional** |
| **MBTiles Vetoriais** | *"Suporte planejado a vetores com fallback"* | `MBTilesNative._validateMbtilesFile` **rejeita ativamente** qualquer arquivo com tiles vetoriais via `FormatException`. | **Incompatibilidade Ativa** |
| **CI / CD Pipeline** | *"Pipeline automatizado com testes de integração e conformidade de formatação"* | CI omite `integration_test/` por completo e aplica `dart format` em apenas 18 arquivos para mascarar erros. | **Evasão de Gate** |
| **Interface iPadOS** | *"Design adaptativo com suporte a iPad Split-View"* | Apenas 1 tela (`people_screen`) possui split view; as outras 25 telas são colunas únicas esticadas para tablets de 12.9". | **Deficit de Usabilidade** |
| **Acessibilidade** | *"Conformidade com VoiceOver e semântica acessível"* | O widget `Semantics` aparece em apenas **duas linhas de código** em um universo de mais de 50.000 linhas de UI. | **Não Conformidade** |

---

## 5. SCORECARD DAS 10 DIMENSÕES DO FAES

Pontuação técnica formal avaliada estritamente a partir de evidências reproduzíveis, segundo os critérios da Seção 3 do padrão FAES:

| # | Dimensão do FAES | Peso | Nota (0–10) | Ponderada | Justificativa Técnica & Evidências Empíricas |
|:---:|:---|:---:|:---:|:---:|:---|
| **1** | **Funcionalidade e Jornada do Usuário** | 15% | **7.5** | 1.125 | Fluxos centrais de cadastro e anotações funcionais; cartografia está no nível raster artesanal (Nível 0/1); sincronização externa de EventKit possui exclusão com suporte parcial; transcrição de áudio em Ticuna sem processamento local. |
| **2** | **Integridade de Dados e Migrações** | 15% | **7.0** | 1.050 | Migrações Drift até v8 com integridade referencial ativa; porém migração Supabase `20261112000000` referencia função inexistente; envio de mídia em `encrypted_media_transfer.dart` destrói versões ativas em falhas de upload. |
| **3** | **Segurança, Privacidade e Isolamento** | 15% | **7.0** | 1.050 | Criptografia E2EE remota e isolamento por UID (`SyncOwnerGuard`) implementados; contudo, abertura do SQLite local possui fallback fail-open para plaintext em `native.dart`; chave Web volátil em memória. |
| **4** | **Offline-First e Sincronização** | 12% | **7.5** | 0.900 | Banco local Drift e CAS remoto garantem consistência; pull monotônico por sequência do servidor ativo; no entanto, geocodificação é 100% dependente de rede e conflitos de domínio não cobrem estudos ou tarefas. |
| **5** | **Arquitetura e Manutenibilidade** | 10% | **5.5** | 0.550 | **Deficit severo:** 22 de 26 telas são monólitos acima de 500 linhas; 10 telas excedem 2.000 linhas (`person_detail` com 7.499 linhas, `appointments` com 4.687 linhas); forte acoplamento entre queries de banco e widgets de apresentação. |
| **6** | **UX, Acessibilidade e iOS/iPadOS** | 10% | **5.0** | 0.500 | **Deficit severo:** iPad Split-View ausente em 96% das telas (25 de 26 telas); ausência total de tratamento de interrupções de áudio (`AVAudioSession`); Semantics praticamente ausente (apenas 2 linhas no projeto todo). |
| **7** | **Testes Automatizados e Evidências** | 10% | **6.5** | 0.650 | 118 testes unitários e de contrato passando; no entanto, `integration_test/` é ignorado no CI; 23 telas possuem zero testes de widget dedicados; diretório `test/e2e/p0_p1/` encontra-se vazio. |
| **8** | **Desempenho e Recursos** | 5% | **7.0** | 0.350 | Índices relacionais e benchmarks sintéticos estabelecidos; porém o monólito do mapa em `InteractiveViewer` aloca centenas de widgets em `Stack` e telas gigantes sofrem de recomposições excessivas de layout. |
| **9** | **Documentação e Operabilidade** | 4% | **7.0** | 0.280 | Extensa documentação existente; contudo, marcada por profundas contradições entre relatórios de engenharia e a real implementação no código (`MAP_ENGINE_ARCHITECTURE.md`). |
| **10** | **Release, CI/CD e Reprodutibilidade** | 4% | **6.5** | 0.260 | Workflows multi-plataforma configurados no GitHub Actions; entretanto, validação de formatação é seletiva e restrita a 18 arquivos, e cobertura não impõe bloqueio de falha no pipeline. |
| **TOTAL** | — | **100%** | — | **6.72** | **STATUS FINAL: NOT APPROVED** |

---

## 6. ROTEIRO ESTRATÉGICO DE REMEDIAÇÃO POR FASES

Para conduzir o Field Assistant ao patamar de aprovação FAES 10/10 com evidências irrefutáveis, o programa de engenharia deve executar sequencialmente as seguintes fases de correção e aprimoramento:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          ROTEIRO MESTRE DE REMEDIAÇÃO                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [FASE M0] Fase Zero Documental — Publicação de MASTER_REAUDIT.md           │
│      │                                                                      │
│      ▼                                                                      │
│  [FASE M1] Criptografia Local Fail-Closed & Proteção iOS                    │
│      │     - Eliminar fallback plaintext em native.dart                     │
│      │     - Máquina de 5 estados (encrypted..recoveryRequired)             │
│      │     - NSFileProtectionCompleteUntilFirstUserAuthentication           │
│      │     - Executor fail-closed para conexões não autorizadas             │
│      │                                                                      │
│      ▼                                                                      │
│  [FASE M2] Integridade de Mídias E2EE, Supabase & Conflitos                 │
│      │     - Versionamento imutável de chunks ($mediaId/v_$version/)        │
│      │     - Commit atômico: upload isolado -> manifesto -> CAS -> expurgo  │
│      │     - Correção da migração 20261112000000 (função de soft delete)    │
│      │     - Detecção de conflitos de domínio em estudos e tarefas          │
│      │                                                                      │
│      ▼                                                                      │
│  [FASE M3] MapLibre Native, Cartografia Nível 2 & Geocodificação            │
│      │     - Integração de maplibre_gl no pubspec.yaml                      │
│      │     - Servidor local shelf com suporte a HTTP range para PMTiles     │
│      │     - Descompactação de estilos e fontes pbf para disco local        │
│      │     - MapEngineAdapter: MapLibreNativeAdapter + RasterFallbackAdapter│
│      │     - Contra-rotação de pinos e cache SQLite para Nominatim          │
│      │                                                                      │
│      ▼                                                                      │
│  [FASE M4] CI/CD Rigoroso, Áudio iOS & Adaptação iPadOS                     │
│      │     - Inclusão de integration_test/ no GitHub Actions                │
│      │     - Formatação global (dart format 100%) e enforce-crypto-min=90   │
│      │     - Gerenciamento de AVAudioSession e interrupções telefônicas     │
│      │     - iPad Split-View Master-Detail em Appointments e Studies        │
│      │     - Semantics e acessibilidade para VoiceOver em componentes-chave │
│      │                                                                      │
│      ▼                                                                      │
│  [FASE M5] Decomposição de Telas Monolíticas & Homologação 10/10            │
│      │     - Modularização de person_detail (7.499L) e appointments (4.687L)│
│      │     - Suíte independente de testes E2E Opaque-Box (Tiers 1-5)        │
│      │     - Auditoria final e emissão de laudo APPROVED FAES 10/10         │
│      └──────────────────────────────────────────────────────────────────────┘
```

### 6.1. Detalhamento da Fase M1: Criptografia Local Fail-Closed
1. **Máquina de Estados Explícita:**
   Definir em `lib/database/connection/local_database_encryption_state.dart`:
   ```dart
   enum LocalDatabaseEncryptionState {
     encrypted,
     migrationRequired,
     encryptionUnavailable,
     migrationFailed,
     recoveryRequired,
   }
   ```
2. **Eliminação do Fallback em `native.dart`:**
   Remover as linhas 45–49 que silenciam erros para bancos novos ou plaintext. Caso a verificação da chave ou a preparação do banco falhe, definir o estado como `migrationFailed` ou `encryptionUnavailable`, acionar `dbFatalPersistenceError.value` e retornar um `_SafeNativeUnavailableQueryExecutor` que bloqueia qualquer leitura ou escrita.
3. **Atualização da Proteção de Arquivos no iOS:**
   - Em `ios/Runner/Runner.entitlements`: alterar para `NSFileProtectionCompleteUntilFirstUserAuthentication`.
   - Em `ios/Runner/AppDelegate.swift`: aplicar `FileProtectionType.completeUntilFirstUserAuthentication` para o banco SQLite, WAL, SHM e diretório de mídia.
4. **Opções do Keychain:**
   Instanciar `FlutterSecureStorage` com `IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device_only, synchronizable: false)` e `AndroidOptions(encryptedSharedPreferences: true)`.

### 6.2. Detalhamento da Fase M2: Integridade de Mídias E2EE e Supabase
1. **Versionamento Imutável de Chunks no Storage:**
   Em `lib/sync/crypto/encrypted_media_transfer.dart`, alterar o caminho de armazenamento:
   `$owner/e2ee/$safeMediaId/v_$versionId/chunk_$index.enc`.
   Desativar `upsert: true` em favor de `upsert: false`.
2. **Pipeline de Commit Atômico:**
   Upload de chunks isolados na pasta da nova versão $\to$ Validação de hashes SHA-256 de cada bloco $\to$ Publicação de `manifest.enc` na pasta da nova versão $\to$ Atualização atômica do ponteiro `e2ee_media_version` na tabela via CAS $\to$ Expurgo assíncrono dos blocos da versão anterior.
3. **Correção da Migração SQL:**
   Em `supabase/migrations/20261112000000_hardening_storage_indexes_rls.sql`, remover a invocação direta ou implementar com segurança:
   ```sql
   DO $$
   BEGIN
     IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'handle_soft_delete_and_resurrection_guard') THEN
       ALTER FUNCTION public.handle_soft_delete_and_resurrection_guard() SET search_path = public;
     END IF;
   END $$;
   ```
4. **Expansão da Detecção de Conflitos de Domínio:**
   Estender `lib/sync/domain_conflict_detector.dart` para identificar colisões de horários em sessões de estudos bíblicos (`study_sessions`) e tarefas concorrentes.

### 6.3. Detalhamento da Fase M3: MapLibre Native & Cartografia Nível 2
1. **Dependências e Ativos:**
   Adicionar `maplibre_gl: ^0.28.0` e `shelf: ^1.4.1` ao `pubspec.yaml`.
   Criar `assets/map/` com `style.json` configurado para fontes locais e registrar na seção `flutter: assets:`.
2. **Servidor Local de Tiles Vetoriais (`shelf`):**
   Implementar serviço escutando em `127.0.0.1` em porta efêmera, atendendo a range requests HTTP para leitura direta de pacotes `.pmtiles` e extração de blocos `.pbf` de `.mbtiles` vetoriais.
3. **Implementações de `MapEngineAdapter`:**
   - Criar `MapLibreNativeAdapter implements MapEngineAdapter` (motor principal acelerado por Metal no iOS e OpenGL no Android).
   - Criar `RasterFallbackAdapter implements MapEngineAdapter` (encapsulando o `DynamicTileLayer` para Web e compatibilidade).
4. **Geocodificação e Busca Offline:**
   Criar tabela Drift `GeocodingCache` para armazenamento local de respostas do Nominatim com expiração de 30 dias; implementar rate limit estrito de 1 req/s; disponibilizar busca offline instantânea de ruas e contatos locais via SQLite FTS5.
5. **Contra-rotação:**
   Configurar renderização vetorial nativa onde os rótulos de ruas e pinos de contatos mantêm alinhamento vertical legível automaticamente durante a rotação da câmera em 360°.

### 6.4. Detalhamento da Fase M4: CI/CD, Áudio iOS & iPad UX
1. **GitHub Actions:**
   Adicionar etapa no `.github/workflows/ci.yml` para executar `flutter test integration_test/app_stabilization_e2e_test.dart`.
   Substituir a lista de 18 arquivos por `dart format --output=none --set-exit-if-changed lib test`.
   Adicionar `--enforce-crypto-min=90` na chamada de verificação de cobertura de código.
2. **Sessão de Áudio no iOS:**
   Integrar o pacote `audio_session` em `RealAudioRecordingService`, configurando categoria `playAndRecord` e escutando `session.interruptionEventStream` para pausar e salvar gravações em caso de chamadas recebidas ou alarmes.
3. **iPad Master-Detail:**
   Aplicar o padrão adaptativo `LayoutBuilder (isWide >= 900)` em `appointments_screen.dart` (lista à esquerda, detalhe do compromisso à direita) e `studies_screen.dart`.
4. **Acessibilidade:**
   Envolver botões, cards e campos de entrada com widgets `Semantics` semânticos (`header: true`, `button: true`, `label: ...`) e disparar anúncios dinâmicos de acessibilidade via `SemanticsService.announce`.

### 6.5. Detalhamento da Fase M5: Decomposição de Monólitos & Auditoria 10/10
1. **Modularização de Telas:**
   Decompor `person_detail_screen.dart` (7.499 linhas) em componentes desacoplados (`PersonVisitsSection`, `PersonStudiesSection`, `PersonPhotosSection`, etc.).
   Decompor `appointments_screen.dart` (4.687 linhas) e `contacts_map_screen.dart` (4.489 linhas).
2. **Homologação e Auditoria Independente:**
   Submeter o sistema completo à bateria de testes E2E Opaque-Box Tiers 1-5, recalculando o scorecard para atingir pontuação $\ge 9.7 / 10.0$ em todas as dimensões, com zero pendências P0/P1.

---

## 7. MÉTODOS DE VERIFICAÇÃO INDEPENDENTE

Qualquer engenheiro ou auditor de segurança pode reproduzir e validar independentemente todos os achados deste relatório por meio dos seguintes comandos:

```powershell
# 1. Verificar vulnerabilidade de fallback plaintext em native.dart:
Get-Content -Path "lib/database/connection/native.dart" | Select-String -Pattern "encryptionActive = false|isPlaintextSqliteFile" -Context 3,3

# 2. Verificar ausência de dependência do MapLibre no pubspec.yaml:
Select-String -Path "pubspec.yaml" -Pattern "maplibre|flutter_map"

# 3. Confirmar que MapEngineAdapter não possui implementações:
Get-ChildItem -Path "lib" -Recurse -File -Include "*.dart" | Select-String -Pattern "implements MapEngineAdapter|extends MapEngineAdapter"

# 4. Verificar rejeição ativa de MBTiles vetoriais:
Get-Content -Path "lib/territory/mbtiles/mbtiles_native.dart" | Select-String -Pattern "FormatException.*raster" -Context 2,2

# 5. Verificar sobrescrita mutável com upsert: true em mídias cifradas:
Get-Content -Path "lib/sync/crypto/encrypted_media_transfer.dart" | Select-String -Pattern "upsert: true" -Context 2,2

# 6. Identificar função inexistente na migração do Supabase:
Get-ChildItem -Path "supabase/migrations" | Select-String "handle_soft_delete_and_resurrection_guard"

# 7. Constatar divergência de formatação no repositório inteiro:
dart format --output=none --set-exit-if-changed lib test

# 8. Listar as maiores telas monolíticas do projeto:
Get-ChildItem -Path "lib/ui/screens" -Filter "*.dart" | ForEach-Object { [PSCustomObject]@{ Screen = $_.Name; Lines = (Get-Content $_.FullName | Measure-Object -Line).Lines } } | Sort-Object Lines -Descending | Select-Object -First 10
```

---

## 8. CONCLUSÃO E ATESTAÇÃO TÉCNICA

A presente Re-Auditoria Mestra de Engenharia (Fase Zero Documental — M0) estabelece o diagnóstico definitivo do estado técnico do Field Assistant no HEAD `6e1020fe867b97e64ff162bdf7d2fb231d04aaef`. 

Embora o aplicativo demonstre fundamentos avançados em criptografia remota de registros e isolamento de contas, a presença de uma via de fallback desprotegida para banco local plaintext (P0), a simulação documental de um motor MapLibre inexistente (P0 Estratégico), o risco de perda de mídias por sobrescrita prematura (P1), erros em migrações SQL (P1) e severo déficit arquitetural e de acessibilidade (P2) determinam formalmente o resultado de **NÃO APROVAÇÃO (NOT APPROVED — 6.72 / 10.0)**.

O roteiro delineado nas Seções 5 e 6 é auto-suficiente e vinculante para a execução imediata das Fases M1 (P0 Criptografia Fail-Closed), M2 (P1 Mídias e Supabase), M3 (Fase Estratégica MapLibre), M4 (CI/CD, Áudio e UX) e M5 (Modularização e Fechamento FAES 10/10).

---
*Relatório consolidado e certificado pela equipe técnica em estrita observância ao Field Assistant Engineering Standard (FAES).*
