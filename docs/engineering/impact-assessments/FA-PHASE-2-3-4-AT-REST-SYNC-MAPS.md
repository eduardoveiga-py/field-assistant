# Impact Assessment & Design — Fases 2 (Conclusão), 3 e 4 (FA-SEC-06/08, FA-BAK-01, FA-SYNC-01/02, FA-MAP-01/02)

- **Branch:** `stabilization/faes-master-program`
- **Data:** 2026-11-17
- **Escopo:** Conclusão da Fase 2 (criptografia SQLite em repouso, iOS Data Protection + exclusão de backup iCloud, remoção de credenciais Supabase hardcoded, atomicidade transacional em `JwEmailService`, testes adversariais de Backup/Restore e honestidade visual do backup local de 24h), Fase 3 (revogação de `sync_upsert` legado sem CAS, suíte pgTAP completa, mapeamento completo das 26 tabelas em `mapEntityToRemoteTable`, detecção de conflitos de domínio na agenda, protocolo seguro de `HARD_DELETE` + limpeza de mídia órfã e testes multi-dispositivo/clock-skew/fault-injection) e Fase 4 (eliminação das 22/23 URLs 404 do catálogo MBTiles, alinhamento a `OfflineMapPackageManifest`, pipeline de download temporário/Range resume/disk-space/SHA-256/validação SQLite-PMTiles/instalação atômica/rollback, evolução do `MapEngineAdapter` com contatos offline, camadas configuráveis, busca offline local e endurecimento do `GeocodingService` com cache persistente, rate-limit <= 1 req/s, User-Agent unificado e aviso de privacidade).

---

## 1. Problema e Resultado Desejado

### Fase 2 (Conclusão)
1. **Dependência EOL & SQLite em texto claro (`FA-SEC-06`):** `pubspec.yaml` ainda inclui `sqlite3_flutter_libs: ^0.6.0+eol` e abre `ministerio_pessoal.sqlite` sem cifra em repouso.
   - *Resultado:* Remover `sqlite3_flutter_libs`, ativar `sqlite3mc` (SQLite3MultipleCiphers via Dart Build Hooks do `sqlite3 ^3.5.2`) e implementar helper de abertura/migração não-destrutiva (`LocalDatabaseEncryption`) que cifra bancos plaintext existentes preservando WAL/SHM via checkpoint + backup `.pre_enc.bak` + rollback automático, usando chave de 256 bits armazenada em `FlutterSecureStorage` (Keychain/Keystore).
2. **Proteção de arquivos iOS (`FA-SEC-06`):** Ausência de `ios/Runner/Runner.entitlements` (`com.apple.developer.default-data-protection`) e ausência de `URLResourceValues.isExcludedFromBackup = true` no `AppDelegate.swift` para SQLite/WAL/SHM/anexos.
   - *Resultado:* Criar `ios/Runner/Runner.entitlements` com `NSFileProtectionCompleteUntilFirstUserAuthentication` (documentado no ADR-015 para compatibilidade com background sync e proteção antes do primeiro desbloqueio) e registrar em `ios/Runner.xcodeproj/project.pbxproj`, além de aplicar `NSFileProtectionComplete` / `isExcludedFromBackup = true` em `AppDelegate.swift` para banco SQLite, `-wal`, `-shm`, mídias e backups locais.
3. **Credenciais Supabase hardcoded & atomicidade de e-mail (`FA-SEC-08`):** `SupabaseSyncService` contém `defaultUrl` e `defaultAnonKey` hardcoded em código; `JwEmailService.saveDraft` e `sendEmail` executam escrita em `inbox_entries` e `sync_queue` fora de transação única, sem `_base` e sem incremento de `revision` em `UPDATE`.
   - *Resultado:* Remover `defaultUrl`/`defaultAnonKey` hardcoded (exigindo `--dart-define` ou configuração runtime no `FlutterSecureStorage`, operando 100% offline-first sem segredos no código); tornar `saveDraft`, `sendEmail` e `syncEmails` atomicamente transacionais com incremento de `revision` e snapshot `_base` nos updates.
4. **Testes adversariais de Backup/Restore e ícone enganoso (`FA-BAK-01`):** `settings_screen.dart` exibe `Icons.cloud_done_outlined` para o backup silencioso local de 24h; cobertura adversarial de restore precisa provar resistência a arquivo corrompido, truncado, senha errada, mídia ausente, conta diferente e interrupção/rollback.
   - *Resultado:* Trocar ícone e texto para backup local criptografado no dispositivo (`Icons.sd_storage_outlined` / "Backup Local Automático no Dispositivo") e adicionar suíte adversarial completa.

### Fase 3 (`FA-SYNC-01`, `FA-SYNC-02`)
1. **RPC legada sem CAS (`FA-SEC-08`, `FA-SYNC-01`):** `public.sync_upsert(TEXT, JSONB)` ainda tem `GRANT EXECUTE ... TO authenticated` desde `20261112000000_hardening_storage_indexes_rls.sql`.
   - *Resultado:* Migration aditiva `20261118000000_revoke_legacy_sync_upsert.sql` revogando `EXECUTE` de `PUBLIC, anon, authenticated` com teste PGlite comprovando recusa.
2. **Suíte pgTAP (`FA-SEC-08`):** Ausência de `supabase/tests/` para `supabase test db`.
   - *Resultado:* Criar suíte pgTAP completa em `supabase/tests/01_rls_e2ee_storage_security.sql` cobrindo `anon`, `authenticated`, cross-user, `encrypted_record_cas`, `encrypted_records_pull_since`, `recovery_vault_create`, recusa de `sync_upsert` legado e os 4 buckets de Storage (`voice_notes`, `ticuna_audio`, `knowledge_vault`, `person_photos`).
3. **`mapEntityToRemoteTable` (`FA-SYNC-01`):** Garantir e testar cobertura completa das 26 tabelas em snake_case, camelCase, PascalCase e singular/plural.
4. **Conflitos de domínio na Agenda & `HARD_DELETE` seguro (`FA-SYNC-02`):** Pull pode inserir/atualizar um compromisso com UUID distinto cujo intervalo `[startTime, endTime]` colide com outro compromisso local ativo; `HARD_DELETE` hoje suspende sem protocolo explícito e pode deixar mídia remota órfã.
   - *Resultado:* Detectar sobreposição de compromissos ativos com UUIDs distintos após pull (`AppointmentDomainConflictDetector`) marcando conflito explícito (`status = 'conflito'` + registro de revisão sem sobrescrever/apagar nenhum dos dois compromissos); implementar protocolo transacional seguro de `HARD_DELETE` (com confirmação explícita/tombstone cifrado E2EE + limpeza idempotente de mídia órfã nos 4 buckets). Cobrir com testes de 2 dispositivos offline, clock skew e fault injection.

### Fase 4 (`FA-MAP-01`, `FA-MAP-02`)
1. **Catálogo 404 & Offline Manager (`FA-MAP-02`):** 22 das 23 regiões de `MBTilesService._defaultCatalog` apontam por fallback para `releases/download/mbtiles-v1/$id.mbtiles` (HTTP 404).
   - *Resultado:* Eliminar completamente o fallback quebrado `mbtiles-v1`; alinhar o catálogo a `OfflineMapPackageManifest` com status explícito (`CatalogPackageStatus.available` vs `CatalogPackageStatus.inPreparation`), licença ODbL, atribuição, bbox, zoom, formato e SHA-256 verificável; implementar pipeline completo no `MBTilesService` + `MBTilesNative`: checagem de espaço em disco → download temporário `.tmp` → pausa/retomada real via `HTTP Range` (`206 Partial Content`) → validação de tamanho → validação SHA-256 → validação de cabeçalho/integridade SQLite (MBTiles) ou PMTiles (`PMTiles\x03`) → swap atômico com `.bak` preservando versão anterior em erro → rollback automático.
2. **Map Engine Nível 2 (`FA-MAP-01`):** Evoluir `MapEngineAdapter` integrando apresentação do mapa (`RasterMBTilesMapEngineAdapter` + contrato pronto para `MapLibreNativeMapEngineAdapter`), overlay de contatos offline estritamente separado dos pacotes cartográficos públicos, camadas configuráveis (`MapLayerConfig`), busca offline local (`OfflineMapSearchService` sobre contatos, marcos, setores e endereços em cache) e avaliação/protótipo documentado de MapLibre Native + PMTiles + Valhalla/GraphHopper em `docs/engineering/MAP_ENGINE_ARCHITECTURE.md`.
3. **Endurecimento de `GeocodingService` (`FA-MAP-01`):** Hoje usa User-Agent divergente (`MinisterioPessoalTerritorio/1.0`), sem rate-limit, sem cache persistente e sem aviso de privacidade.
   - *Resultado:* Cache persistente SQLite/LRU (usando `app_kv_store` com chave versionada + cache LRU em memória), rate-limit real (<= 1 req/s com fila serializada), `AppVersion.userAgent`, flag/callback de consentimento/aviso de privacidade antes de transmitir endereço/coordenadas ao Nominatim, e diferenciação explícita na UI entre visualização de mapa offline e rota aberta em app externo.

---

## 2. Fronteiras de Confiança & Invariantes Preservados

- **Offline-first:** Todas as operações funcionam sem internet; ausência de credenciais Supabase nunca impede o app de inicializar ou operar.
- **Preservação de dados:** Migração SQLite faz `PRAGMA wal_checkpoint(TRUNCATE)`, cria backup `.pre_enc.bak`, migra via `sqlcipher_export`/`sqlite3mc` em arquivo novo `.enc.tmp`, verifica integridade (`PRAGMA integrity_check`) e só então faz swap atômico. Qualquer erro restaura o arquivo original intacto.
- **Separação de privacidade nos mapas:** Contatos, endereços e coordenadas permanecem exclusivamente no Drift SQLite local (cifrado em repouso + E2EE no sync); pacotes cartográficos MBTiles/PMTiles são dados públicos ODbL somente leitura.
- **Sem mentiras de capacidade:** MapLibre Native em hardware Apple e `supabase test db` contra Docker/staging real permanecem documentados como `NOT VERIFIED` no hardware/ambiente alvo até execução real.

---

## 3. Fontes de Pesquisa & Licenças

1. `package:sqlite3` 3.5.2 (`doc/hook.md`, `lib/src/hook/compile/description.dart`, inspecionado localmente no pub cache em 2026-11-17) — MIT / Public Domain; `SQLite3MultipleCiphers` (utelle) — MIT License.
2. Apple Developer Documentation — Data Protection (`com.apple.developer.default-data-protection`, `NSFileProtectionComplete` vs `NSFileProtectionCompleteUntilFirstUserAuthentication`) e `URLResourceValues.isExcludedFromBackup`.
3. OpenStreetMap Nominatim Usage Policy — máximo 1 req/s, User-Agent identificador válido, cache obrigatório de resultados.
4. Protomaps PMTiles v3 Specification — magic bytes `0x50 0x4D 0x54 0x69 0x6C 0x65 0x73` + versão `0x03`, BSD-3-Clause.
5. MapLibre Native / Valhalla / GraphHopper — BSD-2-Clause / MIT / Apache-2.0.

---

## 4. Plano de Testes e Rollback

- **Testes automatizados a executar:**
  - `test/security/local_db_encryption_test.dart` (abertura `sqlite3mc`, cifra em disco provando ausência de texto claro no arquivo, migração plaintext -> cifrado, WAL/SHM, rollback em falha).
  - `test/backup/backup_adversarial_test.dart` (corrompido, truncado, senha errada, mídia ausente, conta diferente, interrupção/rollback).
  - `test/inbox/jw_email_sync_atomicity_test.dart` (`saveDraft`, `sendEmail`, `syncEmails` transacionais com `_base` e `revision`).
  - `test/sql/revoke_legacy_sync_upsert_test.mjs` + suíte PGlite existente (5/5 scripts).
  - `test/sync/sync_phase3_domain_and_hard_delete_test.dart` (todas as 26 tabelas em `mapEntityToRemoteTable`, conflito de domínio de agenda com UUIDs distintos, `HARD_DELETE` seguro + limpeza de mídia órfã, 2 dispositivos offline, clock skew, fault injection).
  - `test/territory/map_engine_level2_test.dart` (catálogo sem 404, pipeline download/Range resume/disk-space/SHA-256/header SQLite & PMTiles/atomic swap/rollback, `MapEngineAdapter`, busca offline local, `GeocodingService` cache SQLite/LRU + rate-limit <= 1 req/s + User-Agent + privacidade).
  - `dart format --output=none --set-exit-if-changed`, `dart analyze lib test integration_test --fatal-warnings`, `flutter test`.
- **Rollback:** Commits atômicos por fase (`Fase 2`, `Fase 3`, `Fase 4`), permitindo `git revert` isolado sem impacto cruzado. Migration SQL aditiva reversível via `GRANT EXECUTE` se necessário.
