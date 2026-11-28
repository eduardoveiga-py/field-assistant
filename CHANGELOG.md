# Changelog

## [2.3.0](https://github.com/eduardoveiga-py/field-assistant/compare/ministerio_pessoal-v2.2.0...ministerio_pessoal-v2.3.0) (2026-11-28)


### Features

* **appointments:** implement post-sync schedule collision detection and 1-tap resolution banner ([86db3ce](https://github.com/eduardoveiga-py/field-assistant/commit/86db3ce156a471a95be09f4c22387d352733e174))
* **audit-evolution:** auditoria completa, gravacao real, migracao drift v2, pbkdf2/aes-gcm, agenda realizado, soft delete sync e parser teocratico robusto ([e313104](https://github.com/eduardoveiga-py/field-assistant/commit/e313104f4d979667447ca67f9a5388bd86265d43))
* **calendar:** fingerprint eventkit, protecao contra delecao em massa e convergencia de id externo ([3f60654](https://github.com/eduardoveiga-py/field-assistant/commit/3f606540fbe635c03d92d210540976911108e9e0))
* complete calendar sync, official LFF 60 catalog, periodicals, schedule copy wizard, map gesture fixes, and foreign contacts ([b88a03b](https://github.com/eduardoveiga-py/field-assistant/commit/b88a03b756a763ce4ed9cdc165ca4c01a65d16f1))
* complete offline-first personal ministry app with drift, sync, and full test suite ([eefae66](https://github.com/eduardoveiga-py/field-assistant/commit/eefae662acd0afa3af908612833d46b8536de8b0))
* **core,map,search,e2e:** complete FAES 10/10 master delivery with pure-Dart A* router, Alto Solimões vector pipeline, FTS5 diacritics search & 184 E2E tests ([6b41be1](https://github.com/eduardoveiga-py/field-assistant/commit/6b41be199e5406116a917f9d58cf01004b88ffb5))
* **core:** complete FAES 10/10 stabilization program (M1-M5) ([fecd4b0](https://github.com/eduardoveiga-py/field-assistant/commit/fecd4b0f2ad140cce5d6807c9a1cc5752866aaaa))
* **database,demo:** adiciona exclusao segura de dados de teste e opcao para zerar banco local ([b3569bf](https://github.com/eduardoveiga-py/field-assistant/commit/b3569bfc760646aabd01db7d197b10407fc890ff))
* **desktop:** adicionar suporte nativo e pipeline de compilação para Windows, Linux e macOS ([1af51c4](https://github.com/eduardoveiga-py/field-assistant/commit/1af51c4b3ea90e26e7bf8197377a67a7d798f6ad))
* **e2ee,inbox,knowledge:** add persistent web key unlock, e2ee email sync, and complete second brain ([#66](https://github.com/eduardoveiga-py/field-assistant/issues/66)) ([effc300](https://github.com/eduardoveiga-py/field-assistant/commit/effc300716d26bcca7bd3e004a1aeb7c2f2d9f41))
* **estudos-agenda-mapa:** assistente replicar programacao com edicao por rotina, sync calendar ics/webcal resiliente, atalho cadastro em estudos, nomes oficiais de publicacoes com 3 brochuras/livro, deteccao de frequencia e desduplicacao de agendamentos, fix gesto zoom trackpad mapa e adicao marcos linha do tempo espiritual ([7f9429c](https://github.com/eduardoveiga-py/field-assistant/commit/7f9429c8ecee23dfd7467eb63064c5652da0b8af))
* **evolution:** personalizacao de recursos, Drift v3, calendarios bidirecionais (Google/Apple), backup 22 tabelas e preservacao total de dados ([3769f4d](https://github.com/eduardoveiga-py/field-assistant/commit/3769f4d0f8c10ad536b7eda212c064d974935937))
* **home:** display unread email count on top-right Inbox badge ([#65](https://github.com/eduardoveiga-py/field-assistant/issues/65)) ([56b0810](https://github.com/eduardoveiga-py/field-assistant/commit/56b08107b870a157c06a89c3ffebf315ef390581))
* implementa aba Ticuna, gravacao de audio, teclado de diacriticos, correcao de zoom/mapa CARTO, parser de voz e atalhos da home ([d4f45c5](https://github.com/eduardoveiga-py/field-assistant/commit/d4f45c58c7ce2101a9b17f2f6ae17b394ae1d6e2))
* implementacao completa dos niveis 1 e 2 (briefing na porta, ritmo de campo, sementes recentes, plano b e cronometro auto-corretivo) com 100% de cobertura e testes ([8cade1a](https://github.com/eduardoveiga-py/field-assistant/commit/8cade1a99e67f17a9b307c56d0dd3325d229a715))
* **inbox/calendar:** google session persistence, auto inline attachments and rich captures ([#48](https://github.com/eduardoveiga-py/field-assistant/issues/48)) ([2593517](https://github.com/eduardoveiga-py/field-assistant/commit/2593517094522fd7273c9bf84fb22108c336f41b))
* **inbox:** add tags support and filtering to email contacts ([#52](https://github.com/eduardoveiga-py/field-assistant/issues/52)) ([aaba033](https://github.com/eduardoveiga-py/field-assistant/commit/aaba03345d635f3eb9f3fd531092cb6a8d6163eb))
* **inbox:** modern OAuth 2.0 email authentication for Gmail and Microsoft Graph ([#37](https://github.com/eduardoveiga-py/field-assistant/issues/37)) ([c6a5c1f](https://github.com/eduardoveiga-py/field-assistant/commit/c6a5c1fd7fe15fdc18d820d4942d395277e0c75c))
* **inbox:** outlook split view, html email rendering and jw mail isolation ([#46](https://github.com/eduardoveiga-py/field-assistant/issues/46)) ([1b4a011](https://github.com/eduardoveiga-py/field-assistant/commit/1b4a011621a85e0a3d37bff702d47727f77e4da4))
* **inbox:** sandboxed iframe email viewer on web, strict jw mail exchange isolation, and email contacts screen ([#50](https://github.com/eduardoveiga-py/field-assistant/issues/50)) ([b9d29cd](https://github.com/eduardoveiga-py/field-assistant/commit/b9d29cd3e19dfeca5c0527a634b7909e5e328ced))
* **inbox:** web redirect for Microsoft OAuth, Gmail sync error reporting, and startup email sync ([#43](https://github.com/eduardoveiga-py/field-assistant/issues/43)) ([bbfa6ee](https://github.com/eduardoveiga-py/field-assistant/commit/bbfa6eeb9acb4c87b9d2f129858ae26009f5f6db))
* **inbox:** web remote images without CORS, fullscreen reader, capture cards headers, markdown clean editor and account html signatures ([#49](https://github.com/eduardoveiga-py/field-assistant/issues/49)) ([6eb7422](https://github.com/eduardoveiga-py/field-assistant/commit/6eb74223a76dc0971c19fb72cbf84a79ee4d30c9))
* **ios:** cria apps.json para suporte oficial a fontes no LiveContainer e AltStore ([4674bba](https://github.com/eduardoveiga-py/field-assistant/commit/4674bba617b8e1fb721ac30f6c05b742c5400628))
* **knowledge,inbox:** add cross-references, offline NWT Bible, JW highlights, and fix PWA OAuth/ID sync ([#54](https://github.com/eduardoveiga-py/field-assistant/issues/54)) ([6cb9d1a](https://github.com/eduardoveiga-py/field-assistant/commit/6cb9d1a32f6008b4893d1209d75cb442589fd045))
* **library,kb,pdf:** add multi-bible comparison, Settings EPUB library, PDF exports and modern KB UI ([#63](https://github.com/eduardoveiga-py/field-assistant/issues/63)) ([825fc0a](https://github.com/eduardoveiga-py/field-assistant/commit/825fc0a847883113c5a3f3e355939df9bf2034ce))
* **m0:** add overflow fixes, E2E opaque-box harness, tier-1 feature coverage tests ([7120f68](https://github.com/eduardoveiga-py/field-assistant/commit/7120f683a476f2915f5dcca5a10f032ed899093e))
* **m0:** resolve 5 immediate points and generate final differential audit ([996f210](https://github.com/eduardoveiga-py/field-assistant/commit/996f2105b740f50895db9d707848f06aaa772169))
* **map_engine & web:** resolve Flutter Web dart:ffi isolation and achieve 100% FAES test suite pass rate ([5755a72](https://github.com/eduardoveiga-py/field-assistant/commit/5755a7246e7f4c0ea9be098b13dfc75627924e94))
* **map,arch,privacy:** extract DynamicTileLayer from contacts_map_screen and add LGPD compliance policy (FA-ARCH-02, FA-REL-01) ([0f135ad](https://github.com/eduardoveiga-py/field-assistant/commit/0f135adaf3d8ef3773c98b6fb1b7a0257819d921))
* **map,sync:** implement MapLibre native vector map view, PMTiles v3 reader enhancements, and loopback map asset serving ([b1afbf6](https://github.com/eduardoveiga-py/field-assistant/commit/b1afbf6c646a50ddb68b07e7ebc95be54d6744cb))
* **map,ui,auth:** corrige geolocation_helper, zoom focado em Santo Antonio do Ica AM, splash login e cards ([3be5830](https://github.com/eduardoveiga-py/field-assistant/commit/3be5830cd7c7439a593ea04c99e152e03ccb669a))
* **map,ui,auth:** restaura map_location_picker_dialog compativel e corrige zoom em Santo Antonio do Ica AM ([c960fdb](https://github.com/eduardoveiga-py/field-assistant/commit/c960fdb67ff7e6c78631e0814ab8920004491c3f))
* **map:** Fase 1 - estilos vetoriais estilo Organic Maps (light e dark) ([#24](https://github.com/eduardoveiga-py/field-assistant/issues/24)) ([5aef844](https://github.com/eduardoveiga-py/field-assistant/commit/5aef844fc6b6a65a79c8a4c31850dafd7d875b0e))
* **map:** provide authentic Protobuf font glyphs and RGBA sprite atlas ([fa6e294](https://github.com/eduardoveiga-py/field-assistant/commit/fa6e2944ba98c27fb3841a4251ea5ae239885271))
* **maps,territory,ui:** complete Phase 4 — eliminate 404 catalog fallback, honest package status, fix map diagonal clipping & enable mouse/desktop rotation with compass reset (FA-MAP-01, FA-MAP-02) ([adf93ed](https://github.com/eduardoveiga-py/field-assistant/commit/adf93edad2a12a47d718899f9a91ecdf78fb18e2))
* **notifications,reminders:** implement LocalReminderService for offline appointment/study/task alerts (FA-FUNC-01) ([e7e3930](https://github.com/eduardoveiga-py/field-assistant/commit/e7e393064534b27b0fa9af5041e0bb6350beb7bf))
* **notion,pubs,covers,ux:** add multi-module views, note covers with PDF export, EPUB paragraph/point indexing + transcript insert, and typing optimization ([#69](https://github.com/eduardoveiga-py/field-assistant/issues/69)) ([2c353fb](https://github.com/eduardoveiga-py/field-assistant/commit/2c353fb278f57993fb3fbd1cf063f3ad2b7a2029))
* **official-docs:** add congregational letters, agendas, minutes, 7 styles, custom fonts and PDF/PNG/DOCX exports ([#62](https://github.com/eduardoveiga-py/field-assistant/issues/62)) ([91331f2](https://github.com/eduardoveiga-py/field-assistant/commit/91331f27618c44b5be6295b4b00c03d7e317f697))
* **onboarding:** suporte a primeiro uso com estudos avancados, estatisticas reais e redesign do botao de tags ([8731e4a](https://github.com/eduardoveiga-py/field-assistant/commit/8731e4ae6dc5e7594f115a79a5ea7ec8853ca50e))
* Organic Maps parity (4 layers, anti-flicker, compass, 23 Brazil regions), Multilingual persistence & seeding, Universal Attachment Viewer, Google auth gating, and rich editing (v1.3.1+8) ([482ca64](https://github.com/eduardoveiga-py/field-assistant/commit/482ca6438d43a1257e0da0a487bdc5ddca419408))
* Organic Maps parity, adaptive dialogs, dynamic languages, and sync hardening (v1.2.1+6) ([d94f597](https://github.com/eduardoveiga-py/field-assistant/commit/d94f597d1cb74ddceea3784b30482a81e6b005ea))
* **perf,database:** add SQLite performance indexes on coordinates, appointments & visits with 5k synthetic benchmark (FA-PERF-01) ([22ec46c](https://github.com/eduardoveiga-py/field-assistant/commit/22ec46c3a39e28d929a7712d652745a3e55a222e))
* **pessoas-folhetos-estudos:** bairro e setor na edicao de pessoas, novos folhetos oficiais e despadronizacao real de pontos e paragrafos ([57e1e1c](https://github.com/eduardoveiga-py/field-assistant/commit/57e1e1c317a3bb15049fc1f7a1129c257e06ee52))
* prepare opt-in native auth callback and sync safeguards ([e356496](https://github.com/eduardoveiga-py/field-assistant/commit/e3564968cee786b389f954b97e76e26face3841b))
* prepare SAI offline map and validate sync migration ([a21d73f](https://github.com/eduardoveiga-py/field-assistant/commit/a21d73f423392b62e8468652b97fba3fb9cb82aa))
* **publicacoes:** catalogo oficial completo do livro Seja Feliz Para Sempre com 60 licoes, secoes exatas do jw.org e quadros de fechamento ([62a5a36](https://github.com/eduardoveiga-py/field-assistant/commit/62a5a36df967b75ecbddedadb42f4f4782e36b9b))
* release v2.0.0 com exclusao de 5 pontos, liberacao de agenda, map engine nivel 2, emails exchange/jwpub e banco de gravuras ([7ecd76a](https://github.com/eduardoveiga-py/field-assistant/commit/7ecd76a704b0b68361b389980d16df8aa2df262a))
* **release,ci:** prepara releases estaveis multiplataforma com pipeline CI/CD completo para Web, Android e iOS ([817eabc](https://github.com/eduardoveiga-py/field-assistant/commit/817eabc914b0de5797eb1e0ddf736ed1fc86c72e))
* **release:** adiciona geracao de ipa nao assinado para iOS e restringe Android a arquivo apk ([8d433d6](https://github.com/eduardoveiga-py/field-assistant/commit/8d433d62289fc78fbfa3278a80c5c52e12bd0282))
* **release:** lancamento 1.2.0 com atualizador automatico, mapa inteligente, agendamento por proximidade, assistente multilingue e i18n ([d091b12](https://github.com/eduardoveiga-py/field-assistant/commit/d091b125b510b014dc15d749b459c657e566c9d1))
* **reliability:** correcao definitiva de AppSettingsManager, Outbox de calendarios, backup integral 22 tabelas e testes de migracao ([3f1ed5a](https://github.com/eduardoveiga-py/field-assistant/commit/3f1ed5afb983d61d48d250f52235382a81187f02))
* restaura base do master (splash/auth, OAuth Google, auto-sync, Santo Antonio do Ica) + briefing com data da ultima visita, feriados BR no calendario, download offline do setor e debounce de zoom ([0ed5097](https://github.com/eduardoveiga-py/field-assistant/commit/0ed5097d8ac3af459cc88e92d7c91b612ede6cbf))
* **routing,catalog,docs:** add graph serialization, fix catalog owner URL, and add final independent audit FAES 10/10 ([ad89765](https://github.com/eduardoveiga-py/field-assistant/commit/ad89765a33b568f809183507a104b874aff0066e))
* **security,backup,ios,inbox:** complete Phase 2 — sqlite3mc encryption & safe migration, iOS Data Protection & backup exclusion, zero hardcoded Supabase creds, transactional email sync & adversarial backup tests (FA-SEC-06, FA-SEC-08, FA-BAK-01) ([279c060](https://github.com/eduardoveiga-py/field-assistant/commit/279c060043e25ded652a053fb6c4e76210fbabb0))
* **security,backup,ux,maps,tests:** upgrade PIN KDF & Backup v3 isolate, harden Android backup rules, restore iPad Maps rail, onDevice dictation, FeatureRegistry & E2E tests (FA-SEC-06/07, FA-UX-01, FA-IOS-02, FA-FUNC-01, FA-MAP-01/02, FA-TEST-01) ([7eda064](https://github.com/eduardoveiga-py/field-assistant/commit/7eda064e3ff366ba3bd38a3409f37002b3bc6c4b))
* **splash,sync:** exibe splash screen minima de 1800ms com sincronizacao em segundo plano, enfileira participantes em sync_queue e ignora arquivos de midia ([ac1bc81](https://github.com/eduardoveiga-py/field-assistant/commit/ac1bc812d825a7b5492f2724da3f169fa2c5d0ba))
* Strategic Evolution complete - Universal Inbox, Tasks & Projects, Knowledge Base, and Organic Maps parity (v1.3.0+7) ([6c40313](https://github.com/eduardoveiga-py/field-assistant/commit/6c403130d7c0392e2e1cf0f980099d55fd05406d))
* Strategic Evolution Etapa 2 - Drift Schema v6, Supabase migration, sync, and backup support ([47d1134](https://github.com/eduardoveiga-py/field-assistant/commit/47d11345e0f1d6cf6a2c14594a826c2f0ebe8521))
* **supabase:** adiciona migracao para voice_notes, phone_contacts, territory_landmarks e storage ([35cb382](https://github.com/eduardoveiga-py/field-assistant/commit/35cb3821a890927a8272adb1cb093e6f4a627469))
* **sync,database,security:** complete Phase 3 — revoke un-CAS sync_upsert, pgTAP security suite, mapEntityToRemoteTable for all 26 tables & domain conflict detector (FA-SYNC-01, FA-SYNC-02, FA-SEC-08) ([8e9b524](https://github.com/eduardoveiga-py/field-assistant/commit/8e9b5249b2bc01c47bbab6f73a8b506ea9760b1e))
* **sync,splash:** cobertura completa de 17 entidades na fila e pull do Supabase, aguarda sincronizacao na splash ao abrir em outro dispositivo e persiste modo offline ([0d2e54c](https://github.com/eduardoveiga-py/field-assistant/commit/0d2e54cab3965585b2727bdb4805a20de78bd1d2))
* **sync:** adicionar suporte a credenciais dinamicas do supabase ([c0eb086](https://github.com/eduardoveiga-py/field-assistant/commit/c0eb086c5a23a6b6bce88dc0b422766bfb5bb3dd))
* **sync:** captura de baseData nas atualizacoes locais para merge de tres vias deterministico ([6bd1e6c](https://github.com/eduardoveiga-py/field-assistant/commit/6bd1e6c0b0d9120c90991830ef2870f2ca49e1ce))
* **sync:** complete production E2EE engine, reactivate Supabase sync and add recovery UI ([00b2832](https://github.com/eduardoveiga-py/field-assistant/commit/00b28326b9e959c94eae3a53dddfd24ad1b54205))
* **sync:** implement multi-device document binary sync via Supabase knowledge_vault storage ([c278947](https://github.com/eduardoveiga-py/field-assistant/commit/c27894738d7ebd44c76aefb85d23e16a9ceb91db))
* **sync:** pull incremental paginado, merge via sync engine e resiliencia de erros estruturados ([b2651b3](https://github.com/eduardoveiga-py/field-assistant/commit/b2651b3d36dee06bc139388f475a4be08ad37636))
* **tile_cache:** add _lonToTileX, _latToTileY and preloadBounds to TileCacheService ([0009e82](https://github.com/eduardoveiga-py/field-assistant/commit/0009e827358e0fc7ac0c50a42c2d3662eee00764))
* **ui,auth:** splash screen com login obrigatorio, cards glassmorphism e fix Google Calendar Web ([893abfe](https://github.com/eduardoveiga-py/field-assistant/commit/893abfe031aa958e97bbb78cc32b9d6b3f05010a))
* **ui:** redesign minimalista profissional (Linear / Apple HIG) e fix do teste flaky smtp ([#33](https://github.com/eduardoveiga-py/field-assistant/issues/33)) ([3f39697](https://github.com/eduardoveiga-py/field-assistant/commit/3f39697cdd513ab9b378c645810c1720722d1cd1))
* **ui:** WYSIWYG zero-syntax editors, JW Library floating highlights and picture bank pickers ([#55](https://github.com/eduardoveiga-py/field-assistant/issues/55)) ([6ef30c6](https://github.com/eduardoveiga-py/field-assistant/commit/6ef30c65ddefcee984fe11b25a4fc26d6eac3492))
* **ux,audio,map,arch:** activate MapLibre vector engine, add AVAudioSession interruption handling, decompose 5 monolithic screens & expand iPad/Semantics coverage ([54026d3](https://github.com/eduardoveiga-py/field-assistant/commit/54026d3043df0b40f7f7b071a7531b26f6501454))
* **ux,ipad:** implement adaptive master-detail split-view on PeopleScreen for iPad and wide displays (FA-UX-01) ([cca9857](https://github.com/eduardoveiga-py/field-assistant/commit/cca98576aa39a8e981c392c81b3c893154ae2044))
* **ux:** polish iPad multitasking breakpoints, button semantics containers and add split-view boundary tests ([9f27449](https://github.com/eduardoveiga-py/field-assistant/commit/9f274495ae4890fe308b751eec0a1f74cdfa2bbd))
* **voice-notes:** implementacao completa do nivel 3 com gravacao rapida de audio, ditado offline, parser teocratico deterministico e integracao ao briefing na porta ([c5e250b](https://github.com/eduardoveiga-py/field-assistant/commit/c5e250b81b5d06ad857d309eb24c962032bf0752))


### Bug Fixes

* alinha teclado Ticuna com WOL jw.org, estabiliza gravador de audio, deep links JW e focalizacao de zoom no mapa ([0b8c58f](https://github.com/eduardoveiga-py/field-assistant/commit/0b8c58f95bcfea2d063cadfe261f33abcd3e45cc))
* app_kv_store updated_at migration, universal markdown card formatting, document bytes persistence & staging, layer style tile cache isolation, and map layer modal scrolling ([8028d56](https://github.com/eduardoveiga-py/field-assistant/commit/8028d564a75feb53dc817f334b2381e2c9a1dc68))
* **appointments:** adaptive layout for modal dialogs and FAB at high text scales, update apps.json IPA sizes ([#35](https://github.com/eduardoveiga-py/field-assistant/issues/35)) ([528cdbd](https://github.com/eduardoveiga-py/field-assistant/commit/528cdbdc6e87109872398ee13a2503df9d5489c2))
* **appointments:** corrige erro de sintaxe fechando bloco try em google_calendar_provider.dart ([64e8adf](https://github.com/eduardoveiga-py/field-assistant/commit/64e8adfccc639c6130e6227c37d3aff97d78c0dd))
* **audio:** aplicar regra 7 para reproducao de audio web-safe com UrlSource ([498161f](https://github.com/eduardoveiga-py/field-assistant/commit/498161fa65f366e177f24d8e469a0f8a2fff75f2))
* **audit:** resolver storage RLS audio, plataforma updater, limite 30s gravador, 3 metricas cobertura, transporte proximidade e robustez ticuna ([ccf69a0](https://github.com/eduardoveiga-py/field-assistant/commit/ccf69a02625686caba23c7bd9a675ed364cf5cac))
* **auth,calendar,briefing:** restaura splash e auth Supabase, corrige dropdown do Google Calendar e exibe data da ultima visita no briefing ([427a8f1](https://github.com/eduardoveiga-py/field-assistant/commit/427a8f173bc3fbdc9c5bb0b5ff0151c88d3b9723))
* **auth:** melhorar fluxo da splash screen e autenticacao supabase ([7879958](https://github.com/eduardoveiga-py/field-assistant/commit/787995887977e8f2f7d29116211ab55e1c002ab1))
* **auth:** use safe call on onAuthenticated and AppTheme.primaryBlue ([c453a94](https://github.com/eduardoveiga-py/field-assistant/commit/c453a94f5fc75d404451ee7abb574c5599f03fa3))
* **backup,ci:** deduplicate legacy v2 syncQueue restore for unbound devices and fix coverage hit/total display (FA-BAK-01, FA-CI-01) ([fe78264](https://github.com/eduardoveiga-py/field-assistant/commit/fe78264159e200d150a84edc420eca91a9ef9839))
* **backup:** snapshot persistente obrigatorio, rollback transacional e deteccao de audio corrompido ([343ea6d](https://github.com/eduardoveiga-py/field-assistant/commit/343ea6d80c18987a40d90c5df350cc5e8060aaae))
* **backup:** staging atomico, preservacao de audios originais no rollback, snapshot web e remocao de systemTemp ([a07e690](https://github.com/eduardoveiga-py/field-assistant/commit/a07e6903aa9c307c1bf99f75ece77b38b5223d39))
* **bible,publications,ui:** fix NWT EPUB3 import, add cross-refs/WYSIWYG to student notes, and align official catalogs ([#60](https://github.com/eduardoveiga-py/field-assistant/issues/60)) ([7ae6789](https://github.com/eduardoveiga-py/field-assistant/commit/7ae6789cfb2771ab7a3bb2f2effc429b5c9b0162))
* **bible:** isolate partial translations from default fallback and show unavailable notice ([#64](https://github.com/eduardoveiga-py/field-assistant/issues/64)) ([f11f73e](https://github.com/eduardoveiga-py/field-assistant/commit/f11f73e1ff9331482df6fdf6d664d3b7d71805d9))
* **build:** corrigir getters e escopo de variáveis na compilação do Flutter ([f9fd99c](https://github.com/eduardoveiga-py/field-assistant/commit/f9fd99ceedd173f581d24a935f830a2f04323309))
* **build:** substituir getter bytes por f.readAsBytes() assíncrono compatível com file_picker 13+ ([2291b66](https://github.com/eduardoveiga-py/field-assistant/commit/2291b66e20635175439b57e2feec2935120bade2))
* **calendar,briefing,auth:** resolve identificador canônico no Google Calendar, unifica data mais recente no briefing de porta e alinha ignorados do repositório ([f76bc11](https://github.com/eduardoveiga-py/field-assistant/commit/f76bc110cea6bc5a5f3c15af90fb1e6649b19722))
* **calendar:** harden calendar event link reconciliation and offline conflict resolution ([cf9e420](https://github.com/eduardoveiga-py/field-assistant/commit/cf9e42075cafcfeb35f373593da2f55372b9906f))
* **calendar:** passa clientId web na inicializacao do GoogleSignIn na Web ([6c96ec5](https://github.com/eduardoveiga-py/field-assistant/commit/6c96ec55b07fbe798c596e7b1894c062a3979248))
* **calendar:** protecao contra falsas exclusoes parciais e inclusao de recorrencia no fingerprint do eventkit ([ec550fd](https://github.com/eduardoveiga-py/field-assistant/commit/ec550fdb36f36a923fb0f3ffaec2b6888d1d9e41))
* **calendar:** resolucao persistente de conflitos offline e convergencia deterministica ([456050e](https://github.com/eduardoveiga-py/field-assistant/commit/456050efc25ddbcf60a215214d7044a39dc6819c))
* **catalog:** catalogo oficial 100% fiel ao livro lff com contagens reais nao-padronizadas (4 a 7 pontos) extraido do EPUB oficial ([0329373](https://github.com/eduardoveiga-py/field-assistant/commit/03293733042b1fadc8b5900dc2aacfad32b406f7))
* **ci:** add linux audio/compression build dependencies for headless integration tests ([aaa1d61](https://github.com/eduardoveiga-py/field-assistant/commit/aaa1d61e6dd0383602ebc4f3220958a25e2cc0e2))
* **ci:** format repository, update release config for web pages and fix test assertions ([664ab7f](https://github.com/eduardoveiga-py/field-assistant/commit/664ab7f0a3891d7c7c527b072a67ed05f2a38859))
* **ci:** remove import duplicado de dart:convert e import nao usado no teste de selecao de calendario ([f07bf1f](https://github.com/eduardoveiga-py/field-assistant/commit/f07bf1fde30b09b8261816a904aca95b4e784f56))
* **ci:** restaura imports perdidos (brazil_holidays, math, tile_cache, date_utils), getter hasLastVisitDate, funcoes resolveCalendarSelection/uniqueCalendarItems, readonly calendar ids no provider Google, corrige testes do master e warnings fatais ([fb32fff](https://github.com/eduardoveiga-py/field-assistant/commit/fb32fffabd71bbdf1f392e856366b641e7e0a222))
* **ci:** set unique Pages artifact name per run attempt and wait for metadata propagation ([#40](https://github.com/eduardoveiga-py/field-assistant/issues/40)) ([d5ea675](https://github.com/eduardoveiga-py/field-assistant/commit/d5ea675b7907c8fe040e44b716815a0dc8e3f010))
* **core:** inicializa Supabase no main.dart com fallback offline ([86a8f94](https://github.com/eduardoveiga-py/field-assistant/commit/86a8f94bb07094962cf0766c09f69682370f4e1d))
* **core:** pacote de correções de estabilidade, segurança e integridade ([f44f63d](https://github.com/eduardoveiga-py/field-assistant/commit/f44f63d455802e303e10b39c2759afb68ec8cc5c))
* **core:** suprime info deprecated_member_use no Supabase.initialize em main.dart ([e2caf14](https://github.com/eduardoveiga-py/field-assistant/commit/e2caf14da767718645fa206ce64cb0d1f11ca411))
* correct historical iOS release metadata ([6a35b2f](https://github.com/eduardoveiga-py/field-assistant/commit/6a35b2fcab5e01df63e064cfaee2a8e3592f7165))
* corrige compilacao em supabase_sync_service, auth_splash_screen e settings_screen ([40a3f92](https://github.com/eduardoveiga-py/field-assistant/commit/40a3f92d932e4946753aff456b77898cdcccedb0))
* **database:** ativacao obrigatoria de PRAGMA foreign_keys = ON e WAL mode no SQLite nativo ([3fec509](https://github.com/eduardoveiga-py/field-assistant/commit/3fec509c01b59285bf6a9efd6d6f72e1bb9896d8))
* **desktop-ci:** corrigir dependências GStreamer no Linux e CMake de jni/local_auth no Windows ([dde1c9b](https://github.com/eduardoveiga-py/field-assistant/commit/dde1c9beaec31a65d9801c5514fd1c75363f9b8d))
* **e2ee,security,backup,search:** resolve 13 adversarial review bugs across E2EE pull/conflict/media, symlink containment, KDF/Backup v3 wiring, account switch & GlobalSearch (FA-SEC-02..09, FA-FUNC-01) ([6cb9a20](https://github.com/eduardoveiga-py/field-assistant/commit/6cb9a2042e2ec4ac3210e5ceef93ca307d8f4a28))
* fail closed on missing media records ([cbf75cf](https://github.com/eduardoveiga-py/field-assistant/commit/cbf75cfcec7cf3ba4b29a689d0807be2de04ced2))
* **inbox, map:** report email sync errors, add folder selector, and center map on GPS ([#36](https://github.com/eduardoveiga-py/field-assistant/issues/36)) ([0a79f6d](https://github.com/eduardoveiga-py/field-assistant/commit/0a79f6dcd39fb5613f924fa60d4c3e4aff07e590))
* **inbox:** allow Gmail in CSP, add pagination for OAuth sync and compact email list ([#45](https://github.com/eduardoveiga-py/field-assistant/issues/45)) ([deb3b5e](https://github.com/eduardoveiga-py/field-assistant/commit/deb3b5edfd329527c5af16ac04eaa801a1673bf0))
* **inbox:** deduplicate OAuth accounts, enforce Gmail consent and propagate fetch errors ([#44](https://github.com/eduardoveiga-py/field-assistant/issues/44)) ([b089cc2](https://github.com/eduardoveiga-py/field-assistant/commit/b089cc201f1af5621f3b6087e114b82458cbf61d))
* **inbox:** resolve Web PWA freeze, Sent/two-way sync, read-on-click, multi-select, compact captures, and Markdown preview ([#53](https://github.com/eduardoveiga-py/field-assistant/issues/53)) ([e47a9a9](https://github.com/eduardoveiga-py/field-assistant/commit/e47a9a9834a84ec68c2cd6d6d0d5150c9d8a36e4))
* **ios,camera,maps,speech,settings:** corrige câmera nativa, deep link JW Library, zoom de mapas, ditado por voz, Google Agenda e botões de demonstração ([0e67b97](https://github.com/eduardoveiga-py/field-assistant/commit/0e67b9705c5ee537db09ba99d9fc0e549118e6c8))
* **ios:** ajusta schema do apps.json para especificacao completa do LiveContainer (versions array, size e cdn json) ([44cb38b](https://github.com/eduardoveiga-py/field-assistant/commit/44cb38b816a06664ca3152b462a1ef3e6f8eb447))
* **knowledge,ui:** fix gallery/editor/search formatting leaks and add Kanban drag-and-drop ([#67](https://github.com/eduardoveiga-py/field-assistant/issues/67)) ([83a9ab7](https://github.com/eduardoveiga-py/field-assistant/commit/83a9ab7f06cda590a24cd85b62928c0f7f7e7e19))
* **lint:** resolver avisos do analisador estático e chamadas de teste em supabase_sync_service ([1215f50](https://github.com/eduardoveiga-py/field-assistant/commit/1215f50f47b849cb5bb0dbe60f1227a6e97ec374))
* **map,geocoding,ci,docs:** restore authentic SDF font PBF, wire OfflineGeocodingService, fix tile templates, tighten CI format check, and reconcile FAES forensic docs ([40a5828](https://github.com/eduardoveiga-py/field-assistant/commit/40a58284e378d55bdcc7214395645e2f3e7a11ab))
* **map,tiles:** eliminar bloqueio sincrono de disco, poda de fila de tiles, sincronizacao segura de resize e isolamento de repaint ([47cc87d](https://github.com/eduardoveiga-py/field-assistant/commit/47cc87d8ca360b5ec090e06ff24ed309de1e12ae))
* **map:** altera scaleEnabled para false sem duplicar argumento ([c0fe8e6](https://github.com/eduardoveiga-py/field-assistant/commit/c0fe8e63950e407a794fcacb3ab9c7b04012119c))
* **map:** asset cache invalidation and MapLibre lifecycle ([#16](https://github.com/eduardoveiga-py/field-assistant/issues/16)) ([faf46e5](https://github.com/eduardoveiga-py/field-assistant/commit/faf46e5a88e7aee937cd8e37226522fd9debd8b7))
* **map:** carregamento dinamico de tiles sem travamento e altura adaptativa em redimensionamento e rotacao ([dc61883](https://github.com/eduardoveiga-py/field-assistant/commit/dc61883a7661332d0b8d989bc076a4945afc4a16))
* **map:** mantem foco no centro e pino selecionado ao dar zoom em ContactsMapScreen ([5deb23f](https://github.com/eduardoveiga-py/field-assistant/commit/5deb23fd9521c84b7acb67759455d3b558fa4c95))
* **map:** remove linha scaleEnabled duplicada apos dart format ([74a4c2e](https://github.com/eduardoveiga-py/field-assistant/commit/74a4c2eb069f5a35d0c04e8bcb7e75dfda861ab1))
* **map:** restaurar OpenStreetMap oficial, contingencia OSM France e auto-cura de tiles CARTO com marca d'agua ([7bdc6c9](https://github.com/eduardoveiga-py/field-assistant/commit/7bdc6c998c871ef1234078fa00e37a16742020d0))
* meet Flutter Android Gradle plugin minimum ([0550abe](https://github.com/eduardoveiga-py/field-assistant/commit/0550abe83a64e8a9068fa67cc91b143cef2c06dd))
* preserve pending sync and guard deletions ([eb4566f](https://github.com/eduardoveiga-py/field-assistant/commit/eb4566f1ea81de61865f07610fac720a949c3511))
* reject sync writes with unknown remote columns ([ee59d17](https://github.com/eduardoveiga-py/field-assistant/commit/ee59d17f4c5297d52f924c500992db740c5a500f))
* **release,ci,android,ios:** corrige staging de artefatos no release, queries de intents no Android, schemes no iOS e memoria do Gradle ([bf1464c](https://github.com/eduardoveiga-py/field-assistant/commit/bf1464c371a3545c566e5289e84fefade04a2537))
* **reliability:** eliminacao de advertencias do analyze, deteccao de audio corrompido, idempotencia de sync e status reativo ([c827fdb](https://github.com/eduardoveiga-py/field-assistant/commit/c827fdb150b143b4ef1ff941d16a010c29785749))
* require review before saving geocoded map points ([f9ad64e](https://github.com/eduardoveiga-py/field-assistant/commit/f9ad64e4097a8e26ffa8c07abc3c86e40c7d8634))
* **scripts:** fixa porta 8080 e injecao de GOOGLE_WEB_CLIENT_ID no run_web.bat ([bd26aa9](https://github.com/eduardoveiga-py/field-assistant/commit/bd26aa96c6a0fcefa608046dbf17b8648b268725))
* **scripts:** fixa porta 8080 e injecao de GOOGLE_WEB_CLIENT_ID no run_web.ps1 ([69c174a](https://github.com/eduardoveiga-py/field-assistant/commit/69c174a7fd44b1d1e04031407a80704de4611de7))
* **security,e2ee,sync,backup:** eliminate all P0 blockers — fail-closed E2EE, server_seq pull, 4-bucket encrypted media, SyncOwnerGuard, path traversal & identity-safe restore (FA-SEC-01..05,09, FA-BAK-01) ([9613363](https://github.com/eduardoveiga-py/field-assistant/commit/96133638ec3a064924bce17d116aef4c4c213bbd))
* **settings:** fix CrossAxisAlignment typo and SupabaseAuthScreen route syntax ([d0aa75c](https://github.com/eduardoveiga-py/field-assistant/commit/d0aa75c4b63b5b83a0d4d050a8d1f9f5ced687a0))
* **sources:** ajustar tamanho do IPA no apps.json e adicionar invalidacao automatica de cache jsdelivr no CI ([415d5c9](https://github.com/eduardoveiga-py/field-assistant/commit/415d5c9f226b99f939275fc738464e4c1209e395))
* **supabase:** usa owner_id na migracao 20261102000000 ([e891c3d](https://github.com/eduardoveiga-py/field-assistant/commit/e891c3d41b8056749c0822d7dc38e7269ec2d6bc))
* **sync,library:** unblock E2EE queue, add backfill/realtime sync and fix Bible/EPUB picker ([#68](https://github.com/eduardoveiga-py/field-assistant/issues/68)) ([c9ee396](https://github.com/eduardoveiga-py/field-assistant/commit/c9ee3962368f062294c9d9f8e5fc63043f2cda4d))
* **sync,map,e2ee:** incorporar config supabase, chave e2ee sempre visivel, rotacao interativa do mapa e sync de email para nuvem ([1e81e5d](https://github.com/eduardoveiga-py/field-assistant/commit/1e81e5dbc6262fd42904d493be61dcc2c52dcf53))
* **sync:** add constructor and sync() method to SupabaseSyncService ([dc31561](https://github.com/eduardoveiga-py/field-assistant/commit/dc31561a654b6d9d518ea84fdcfc23193fe8ee3c))
* **sync:** cursor deterministico composto, upload e download resiliente de midia e captura de mutacao indireta em people ([b2d1774](https://github.com/eduardoveiga-py/field-assistant/commit/b2d17742efd5ea5204433617eab2fa4013c1b3cb))
* **sync:** registrar tabelas de inbox, tarefas e base de conhecimento em syncTables ([87e580d](https://github.com/eduardoveiga-py/field-assistant/commit/87e580d1e578bc4e96a4a3460ff8b91d9ae519b2))
* **territory:** corrige comentario em geolocation_helper.dart ([4bebbcb](https://github.com/eduardoveiga-py/field-assistant/commit/4bebbcbbe67385a75611b24107922bbb551ac7ad))
* **territory:** corrige sintaxe de GeolocationHelper em geolocation_helper.dart ([35b1737](https://github.com/eduardoveiga-py/field-assistant/commit/35b17379d55275fa449d42bb2f085d17c0c6daf0))
* **territory:** define Santo Antonio do Ica AM (-3.1022, -67.9397) como coordenada padrao ([cea5102](https://github.com/eduardoveiga-py/field-assistant/commit/cea5102b352af6d4f61c99c753e8ec9f51b39c30))
* **test:** alinha supabase_auth_screen_test com os textos reais da UI (Entrar na Conta, E-mail *, Senha *, Não tem conta? Cadastrar) ([5b48538](https://github.com/eduardoveiga-py/field-assistant/commit/5b4853860ad8beac40e309695439a81551682399))
* **test:** corrige expects incompativeis (grid de tiles 15x15=225 no mapa; 'Salvo Localmente' e Text e nao Tooltip) ([2b92243](https://github.com/eduardoveiga-py/field-assistant/commit/2b92243eac5d1c640d3ec18432b5d9e4b050109a))
* **test:** iPhone widget test navega pelo destino Estudos na NavigationBar (padrao do teste iPad que passa) ([ae1a3cb](https://github.com/eduardoveiga-py/field-assistant/commit/ae1a3cb4c784ed6c77a7584b0b4b1e0d28bb83a6))
* **ticuna,web:** resolve Unsupported operation: _Namespace no microfone e estabiliza fontes Noto Sans / Charis SIL para acentuacao Ticuna ([30e6acf](https://github.com/eduardoveiga-py/field-assistant/commit/30e6acfea496eec09f7b8da651c17bb434f31515))
* **ui:** ipad keyboard responsiveness and kb fullscreen ([#71](https://github.com/eduardoveiga-py/field-assistant/issues/71)) ([b4df7f3](https://github.com/eduardoveiga-py/field-assistant/commit/b4df7f3d825dd5c84fb07e0ad3d5f667347055c2))
* **ui:** previne overflow no AppBar e cabecalho de foco da TodayScreen em telas compactas (iPhone XR) ([a332930](https://github.com/eduardoveiga-py/field-assistant/commit/a33293089e72f83098b09f787741f5213eb6f3b2))
* **ui:** refatoracao do botao e chips de tags no card de contato e isolamento em teste de backup ([77b3a54](https://github.com/eduardoveiga-py/field-assistant/commit/77b3a540c55a46752a0b3412e1d4ab79a7a631b1))
* **ui:** wrap preferredSchedule text in Expanded on PeopleScreen to prevent 2.0x text scaling overflow ([8d17a83](https://github.com/eduardoveiga-py/field-assistant/commit/8d17a833ff63929df3fc91b92a5e9c095f6e7f01))
* use responsive LayoutBuilder height for email HTML iframe ([#51](https://github.com/eduardoveiga-py/field-assistant/issues/51)) ([8f4d20b](https://github.com/eduardoveiga-py/field-assistant/commit/8f4d20b5de49ed0de59376a804d42ccba768390e))
* **web:** adiciona meta tag google-signin-client_id no index.html ([bd3c46c](https://github.com/eduardoveiga-py/field-assistant/commit/bd3c46c9f98053c7b83351b55b7d19bf194f270f))
* **windows-ci:** remover link WIL versionado quebrado em local_auth_windows e expor erros de build ([5ce6b75](https://github.com/eduardoveiga-py/field-assistant/commit/5ce6b758dc29b9f16f303731fc3f861e40f34669))
* **windows-ci:** suprimir erro STL1011 de experimental/coroutine no MSVC 14.51 em local_auth_windows ([5f4faa7](https://github.com/eduardoveiga-py/field-assistant/commit/5f4faa7d9a7d07abf30960398092f64d7da1bf6d))

## 📜 Histórico de Lançamentos e Notas de Atualização (Changelog)

Todas as notas de versão, melhorias, correções de bugs e novidades do aplicativo **Ministério Pessoal (Field Assistant)**.

---

## 🚀 [2.2.0] — 27/11/2026 (Lançamento Oficial Multiplataforma)

### 🧩 Visões Estilo Notion Multi-Módulo (Lista, Tabela, Kanban e Galeria)
- **Experiência Unificada**: Criação de componentes reutilizáveis (`NotionViewModeBar`, `NotionKanbanBoard`, `NotionResponsiveTable`, `NotionGalleryGrid`) para alternância imediata sem perda de regras de negócio:
  - **Base de Conhecimento**: *Notas* (`Lista | Tabela | Kanban | Galeria` enriquecido com capas), *Perguntas & Dúvidas* (`Lista | Tabela | Kanban` com drag-and-drop), *Documentos* (`Lista | Tabela | Galeria`) e *Recursos* (`Lista | Tabela | Galeria`).
  - **Tarefas & Projetos**: *Minhas Tarefas* (`Lista | Tabela | Kanban` com persistência de `completedAt` ao arrastar) e *Projetos* (`Lista | Tabela | Kanban | Galeria`).
  - **Estudos Bíblicos**: `Lista | Tabela | Kanban | Galeria` preservando o filtro *Prioridade & Progresso* e o fluxo oficial de liberação de horários ao encerrar.
  - **Inbox & Experiências**: *Inbox Capturas* (`Lista | Tabela | Kanban` com drag-and-drop de triagem) e *Experiências de Campo* (`Lista | Tabela | Galeria`).

### 🎨 Capas nas Notas, Base de Conhecimento Segundo Cérebro & Exportação PDF
- **Capas Personalizáveis**: Suporte a **gradientes curados**, **12 ícones de marca d'água no canto direito** e **foto personalizada** (dispositivo ou Banco de Gravuras, comprimida client-side para `<= 180 KB` em Web/Mobile/Desktop), exibida no cabeçalho da nota, nos cards da Galeria e no topo do PDF exportado (`KnowledgeAndEmailPdfService`).
- **Editores WYSIWYG Zero-Sintaxe**: Formatação rica visual sem vazamento de tags HTML/Markdown na exibição ou edição, destaques coloridos estilo JW Library, subpáginas, backlinks e revisão espaçada.
- **Cartas, Pautas & Atas Oficiais**: Novo módulo com 7 estilos tipográficos, fontes customizadas e exportação em PDF, PNG e DOCX.

### 📚 Bíblias Multi-Tradução Offline & Publicações EPUB Inteligentes
- **Importação Real NWT EPUB3 e JSON + Comparador**: Comparação lado a lado de múltiplas traduções bíblicas e avisos claros quando uma tradução parcial não contém o versículo.
- **Índices Reais e Seleção por Parágrafo/Ponto**: Correção definitiva do importador EPUB (`toc.ncx` e `nav.xhtml` ignorando `page-list`/`#pageN`) com reparo automático de publicações já salvas, extração de `data-pnum`, subtítulos (`h2`/`h3`) e seções numeradas estilo *Seja Feliz Para Sempre!*, além de menu suspenso de capítulos/lições + seleção por parágrafos/pontos e scroll com destaque automático no leitor.
- **Modo Transcrito**: Inserção em **Somente link**, **Link + Transcrito** ou **Só Transcrito** tanto para passagens bíblicas quanto para publicações.

### ⌨️ Otimização Global de Digitação (iPad, iPhone e Android)
- **Modais Adaptativos com Foco em Escrita**: `showAdaptiveMinistrySheet` reage dinamicamente à abertura do teclado virtual (`viewInsets.bottom`), mantém barra fixa de ações para salvar, oferece alternância de **Tela Cheia**, compacta a barra de formatação e posiciona **Título + Conteúdo no topo** recolhendo propriedades secundárias em painel colapsável.

### 📬 Inbox Pro, OAuth 2.0 & Sincronização E2EE Multiplataforma
- **OAuth 2.0 Moderno & Isolamento JW Mail**: Fluxo Gmail e Microsoft Graph com refresh resiliente, assinaturas HTML por conta, viewer HTML sandboxed na Web, imagens remotas sem CORS, badge de não lidos na tela Inicial e tags nos contatos de e-mail.
- **Desbloqueio E2EE Persistente & Fila em Tempo Real**: Persistência segura em WebCrypto/IndexedDB e Keychain, desbloqueio automático da fila de sincronização bidirecional e backfill em tempo real para notas, tarefas, e-mails, inbox, documentos e recursos.

---

## 🚀 [2.1.0] — 21/11/2026 (Lançamento Oficial Multiplataforma)

### 🎨 Redesign Minimalista Profissional (Linear / Apple HIG)
- **Design System Sóbrio e Flat**:
  - Paleta refinada no Dark Mode (fundo `#0B0F17`, sidebar `#0E131F`, cards `#131A29`, bordas sutis de 1px com 7% de opacidade e acento primário `#3B82F6`).
  - Paleta equilibrada no Light Mode (fundo `#F8FAFC`, sidebar `#F1F5F9`, cards `#FFFFFF`, bordas sutis `#E2E8F0` e acento `#2563EB`).
  - `CardThemeData` com elevação zero (`elevation: 0`), bordas suaves de 14px e acabamento plano profissional.
  - AppBar compacto (`titleSpacing: 8`, tipografia refinada 18px).
- **Sidebar & Shell de Navegação Neutros**:
  - Remoção de saturações e caixas coloridas pesadas em itens inativos no `NavigationRail` e no menu inferior.
  - Indicador de seleção ativo com pill translúcida suave na cor primária.
- **Tela "Hoje no Ministério" Reestilizada**:
  - Cabeçalho tipográfico limpo e sem caixas com bordas laranjas; título em destaque (`22–24px, w700`), subtítulo discreto e data contextual.
  - Bloco de progresso sem molduras aninhadas redundantes; cards de Horas Realizadas e Estudos com tipografia em alto contraste (`FontFeature.tabularFigures()`), barra de progresso fina (4px) e badges neutros.
  - Chips de filtro sem emojis com ícones vetoriais Material sobriedade visual (`Principais`, `Ministério`, `Produtividade`, `Todos`).
  - Cards de atalho ministerial padronizados em 40x40 com cantos arredondados, sem gradientes saturados, priorizando tipografia hierárquica legível.

### 🗺️ Map Engine Padrão Organic Maps (Fases 1, 2, 3 e 4)
- **Estilos Vetoriais Estilo Organic Maps**:
  - Suporte completo a estilos vetoriais customizados claros (`organic_maps_light.json`) e escuros (`organic_maps_dark.json`).
  - Camadas cartográficas otimizadas para estradas, hidrografia, áreas residenciais, parques e marcos de referência.
- **Overzoom Offline & Resiliência Cartográfica**:
  - Algoritmo de overzoom para pacotes locais MBTiles/PMTiles que permite zoom contínuo além do nível máximo empacotado sem apresentar tela preta ou blocos vazios.
  - Cache dinâmico em dois níveis e gerenciador de pacotes do Alto Solimões (Betânia e Santo Antônio do Içá).
- **Aperfeiçoamento Mobile & iOS**:
  - Suporte robusto a gestos de pinça (pinch-to-zoom) sem perda de orientação.
  - Bússola magnética nativa com redefinição rápida com 1 toque.
  - GPS de alta precisão com indicador de raio de acurácia e cone de direção (*heading*).

### 📬 Inbox Pro & E-mails Exchange / JWPUB Multi-Contas
- **Filtros e Visual Profissional da Caixa de Entrada**:
  - Sistema de filtros rápidos por tipo de item, status e categorias de triagem.
  - Lista de mensagens com tipografia fluida, identificador de remetente e datação contextual.
- **Correções no Fluxo de Envio Exchange ActiveSync**:
  - Resolução definitiva de envio de e-mails em configurações com múltiplas contas.
  - Trava de segurança no ciclo de reconciliação de `SyncKey` para evitar loops de sincronização desnecessários.
- **Visualizador Universal de Anexos**:
  - Abertura e manipulação aprimoradas de anexos PDF, documentos e imagens diretamente no aplicativo.

### 🎨 Banco de Gravuras
- **Exclusão Rápida e Gestão Otimizada**:
  - Botão de exclusão rápida integrado ao visualizador e galeria.
  - Visualizador interativo em tela cheia com zoom gestual contínuo de até 10x.

### 🛡️ Testes, Qualidade & CI/CD
- **Estabilidade do Teste SMTP**:
  - Tratamento resiliente de sockets TLS no teste automatizado de SMTP em `test/audit_round2_features_test.dart`, eliminando falhas intermitentes (*flaky tests*).
- **CI / CD Multiplataforma**:
  - Concorrência de workflows no GitHub Actions (`cancel-in-progress` em PRs) e grupos de atualização no Dependabot.
  - Automação do script pré-push (`tool/pre_push.ps1`) com formatação estrita e análise estática `dart analyze` com zero apontamentos.
  - Matriz de compilação automatizada para **Android** (APK arm64 e Universal), **iOS** (unsigned IPA para LiveContainer/SideStore), **Web** (PWA Wasm), **Windows 10/11 x64**, **Linux GTK x64** e **macOS**.

---

## 📦 [2.0.0] — 20/11/2026 (Lançamento Oficial Estável)

### 🛡️ Exclusão Segura & Integridade Relacional (5 Pontos)
- Modal `PersonDeletionDialog` detalhando de forma transparente e clara os 5 pontos do ciclo de vida da exclusão.
- Preservação estrita de relatórios ministeriais históricos e histórico de conversas passadas.
- Limpeza segura de fotos locais associadas e desassociação ordenada de contatos telefônicos rápidos.

### ⚡ Liberação Atômica da Agenda & Lembretes Locais
- Motor transacional `ScheduleReleaseCoordinator` com cancelamento automático de revisitas e compromissos futuros ao encerrar estudos ou excluir contatos.
- Descarte imediato de notificações pendentes no sistema operacional via `LocalReminderService`.
- Sincronização e remoção imediata dos eventos nos calendários externos (Google Calendar e Apple EventKit).

### 🗺️ Map Engine Nível 2 (Alto Solimões Canônico & Fallback)
- Cartografia vetorial de alta precisão com pacotes MBTiles cobrindo **Betânia** e **Santo Antônio do Içá**.
- Servidor HTTP loopback local RFC 7233 (`OfflineTileServer`) para entrega de azulejos vetoriais com streaming sem internet.
- **Fallback Dinâmico Automático (`RasterFallbackAdapter`)**: comutação instantânea para renderização raster de alto desempenho quando o dispositivo não possuir aceleração GL/Metal.
- Layout responsivo adaptado com orientação horizontal para iPad e modo compacto para iPhone.

### 📬 Sistema Completo de E-mails Exchange / JWPUB / Multi-Contas
- Suporte a todas as caixas postais: **Caixa de Entrada**, **Enviados**, **Rascunhos** e **Lixeira**.
- **Gerenciador de Contatos Inteligente (`EmailContactsManager`)**: autocompletar e persistência imediata de novos endereços.
- Download de anexos integrado com visualização direta no Visualizador Universal.
- Editor de e-mail limpo com formatação profissional.

### 🎨 Banco de Gravuras Interativo com Super Zoom 10x
- Galeria temática de imagens e ilustrações teocráticas com filtros rápidos por tags.
- Visualizador em tela cheia com zoom contínuo de até 10x (`InteractiveViewer`), perfeito para detalhes bíblicos sob luz intensa.

### 💎 Navegação Shell Reestilizada com Badges Cromáticos
- Identidade visual moderna na barra inferior e no `NavigationRail` com badges cromáticos suaves para cada recurso.
- Ícones em pares delineados (*outlined*) e preenchidos (*filled*) com cores vivas e exclusivas para cada módulo ministerial.

### 🔒 Criptografia Fail-Closed & E2EE
- Máquina de estados explícita com 5 estados: `encrypted`, `migration_required`, `encryption_unavailable`, `migration_failed`, `recovery_required`.
- Proteção de arquivos iOS Classe B (`NSFileProtectionCompleteUntilFirstUserAuthentication`).
- Versionamento imutável de mídias criptografadas (`v_$versionId/chunk_$index.enc`) e CAS atômico.

---

## 📦 [1.3.3] — 11/11/2026

- **Configuração Supabase & OAuth Embutida nos Binários**:
  - `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID` e `GOOGLE_IOS_CLIENT_ID` injetados automaticamente nos 6 alvos de build do GitHub Actions (`Web`, `Android APK`, `iOS IPA`, `Windows`, `Linux` e `macOS`) via `--dart-define`, sem credenciais hardcoded no código-fonte.
- **Alinhamento Completo do Banco Supabase e Segurança**:
  - Schema remoto e migrações locais alinhados para todas as 26 tabelas sincronizadas + `sync_queue`, criação e políticas RLS do bucket privado `ticuna_audio`, proteção otimista em `sync_upsert`, índices de chave estrangeira e RLS otimizado com `(select auth.uid())`.
- **Funcionalidades Reais e Segurança Local**:
  - E-mail IMAP/SMTP operacional (`JwEmailService`), armazenamento offline de mapas `.mbtiles` (`MbtilesService`), geolocalização real (`geolocator`) sem coordenadas ou seeds fictícios, PIN obrigatório na ausência de biometria, verificação SHA-256 fail-closed para atualizações Android, sincronização completa das 7 tabelas estratégicas com tela de resolução de conflitos e backup/restauração cifrados integrais.

---

## 📦 [1.3.2] — 10/11/2026

- **Compilação Nativa Desktop e Distribuição Universal**:
  - Geração automatizada no GitHub Actions de binários nativos para **Windows 10/11 x64** (`field-assistant-windows-x64.zip`), **Linux GTK x64** (`field-assistant-linux-x64.tar.gz`) e **macOS Universal** (`field-assistant-macos.zip`), somados aos binários oficiais de **Android**, **iOS/iPadOS** e **Web**, acompanhados de manifesto de integridade `SHA256SUMS.txt`.
- **Abstrações e Isolamento Seguro de Plugins Móveis**:
  - **`VoiceDictationService`**: Factory condicional com fallback gracioso para plataformas desktop sem reconhecimento de voz nativo contínuo, preservando gravação de áudio e entrada manual no `QuickVoiceNoteDialog`.
  - **`CalendarProvider` / `AppleEventKitProvider`**: Isolamento condicional de plataforma impedindo chamadas nativas ao `device_calendar` em Windows, Linux e macOS, desabilitando o calendário Apple graciosamente na UI enquanto mantém o Google Calendar ativo.
- **Scaffolding e Compatibilidade CMake / MSVC / GStreamer**:
  - Estruturas nativas configuradas para `linux/` (GTK+ 3.0) e `macos/` (entitlements Sandbox de rede, áudio/microfone e arquivos + `Info.plist`).
  - Correções no build desktop para compatibilidade com **MSVC 14.51 (Visual Studio 2026)**, `local_auth_windows` e isolamento do `jni` transitivo.

---

## 📦 [1.3.1] — 09/11/2026

- **Paridade Cartográfica Avançada com Organic Maps**:
  - Pirâmide de blocos com cache de fallback multinível (`getFallbackFromMemory`) para zoom fluido sem flashes.
  - 4 camadas selecionáveis: Padrão (OSM), Satélite (Esri), Topográfico (OpenTopoMap) e Noturno (Carto Dark).
  - Catálogo de 23 regiões do Brasil no Gerenciador de Downloads.
  - Toque longo para criação de marcadores geográficos.
  - Bússola magnética $360^\circ$ e rotação contínua.
  - Modo Tela Cheia 100% imersivo e barra de escala métrica dinâmica.
- **Extensibilidade Multilíngue Persistente**:
  - Persistência reativa do idioma ativo no SQLite via `AppKvStore` (`active_language_code`).
  - Seeding formal de 5 idiomas teocráticos (`tca` Ticuna, `por` Português, `spa` Espanhol, `gub` Guajajara e `yan` Yanomami).
  - Barra dinâmica de caracteres especiais (diacríticos) ajustada por idioma.
- **Visualizador Universal Multi-Formato (`UniversalAttachmentViewerDialog`)**:
  - Visualização integrada de PDFs via `PdfPreview`, imagens com zoom gestual, áudios com player dedicado e textos/markdown.
- **Segurança e Contas**:
  - Gerenciamento de conta Google centralizado em Configurações.
  - Proteção biométrica/PIN na tela da Inbox Universal.
  - Conexão segura de e-mail JW.org (`mail.jw.org`, porta 993).
  - Cards de tarefas detalhados e cards de cursos bíblicos retráteis/expansíveis com 1 toque.

---

## 📦 [1.3.0] — 09/11/2026

- **MÓDULO A — Inbox Universal**:
  - Ponto de captura rápida (Ideia/Texto, Voz/Ditado até 5 min, Documentos/Fotos).
  - Pipeline de triagem não-destrutiva para Tarefas, Projetos, Notas de Conhecimento ou Dúvidas Teocráticas.
- **MÓDULO B — Tarefas e Projetos**:
  - `TaskManager`: Gerenciador de responsabilidades com prioridades, prazos e recorrência automática contínua.
  - `ProjectManager`: Projetos com cálculo reativo de progresso.
  - Tela `TasksScreen` com 5 abas organizadas.
- **MÓDULO C — Base de Conhecimento**:
  - `KnowledgeManager`: Notas em Markdown, Dúvidas com textos bíblicos, Documentos com hash SHA-256 e Catálogo JW.org.
- **Integração Global**:
  - Busca unificada no Hoje indexando todas as entidades.
  - Schema Drift v6 com 7 novas tabelas.

---

## 📦 [1.2.1] — 09/11/2026

- Componentes adaptativos universais (`showAdaptiveMinistrySheet`) para iPads, tablets e desktops.
- Seletor Pill interativo de idiomas e cadastro rápido de línguas pré-catalogadas.
- Motor cartográfico de alto desempenho estilo Organic Maps com bússola, rotação 2D e azulejos MBTiles locais.
- Auditoria de sincronização: backoff exponencial na outbox, ciclo pull-before-push e soft-delete.

---

## 📦 [1.2.0] — 08/11/2026

- Centralização de versão com `AppVersion` canônica.
- Atualizador automático in-app integrado com GitHub Releases e LiveContainer.
- Assistente Teocrático de Idiomas expandido com comparador e repetição espaçada SM-2.
- Internacionalização (i18n) em Português, Inglês e Espanhol.
- Território Inteligente com cálculo de Índice de Cobertura ($IC$), zonas esquecidas e exportação KML/GeoJSON.
- Agendamento de retorno na porta por proximidade.

---

## 📦 [1.1.2] — 07/11/2026

- Verificação de compatibilidade com LiveContainer iOS.
- Correção no tamanho e hashes do pacote IPA no catálogo `apps.json`.
- Estabilidade aprimorada na fila de sincronização offline Supabase.

---

## 📦 [1.1.1] — 06/11/2026

- Ajustes de responsividade para telas estreitas de smartphones.
- Modo Sol Intenso de alto contraste sob luz direta.
- Cache nativo aprimorado para azulejos OpenStreetMap.

---

## 📦 [1.1.0] — 05/11/2026

- Territórios e Setores com marcos de referência (POIs).
- Integração da publicação *Seja Feliz para Sempre!* com links profundos para JW Library.
- Ditado rápido de notas de voz com extração inteligente de dados.

---

## 📦 [1.0.1] — 07/11/2026

- Ícone nativo ministerial atualizado.
- Correção da integração com Google Agenda no iPadOS.
- Fallback automático de carregamento de mapas.

---

## 📦 [1.0.0] — 01/11/2026

- Lançamento inicial oficial do Ministério Pessoal com arquitetura 100% Offline-First.
- Gestão de contatos, estudos bíblicos, agenda ministerial e contagem rigorosa de relatórios.
- Criptografia AES-256 GCM e backups locais protegidos por senha.
