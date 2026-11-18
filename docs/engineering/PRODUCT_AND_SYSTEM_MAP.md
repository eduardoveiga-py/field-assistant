# Field Assistant — Mapa Funcional e Técnico do Produto (19 Domínios)

- **Linha de base verificada:** `master` @ `47cc87d` (2026-11-17)
- **Branch de trabalho:** `stabilization/faes-master-program`
- **Versão do app:** `1.3.6+13` (`pubspec.yaml`, `lib/core/app_version.dart`, `apps.json`)
- **Drift Schema Version:** `v8` (33 tabelas locais + 3 tabelas Ticuna raw SQL)
- **Migrations Supabase:** 11 arquivos em `supabase/migrations/` (20261026..20261116)
- **Padrão de Engenharia:** FAES (`.agents/skills/field-assistant-engineering-standard/SKILL.md`)

---

## 1. Fluxo de Bootstrap, Autenticação e Navegação

```
lib/main.dart
  -> SupabaseSyncService.initialize()
  -> ProviderScope -> MinisterioPessoalApp (Light / Dark / Sun WCAG AAA; PT-BR / EN / ES)
  -> _PersistenceHealthGate (Web)
  -> AuthSplashScreen (lib/ui/screens/auth_splash_screen.dart)
       -> Login / Signup / Recovery / Offline Mode
       -> MainNavigationShell (lib/ui/main_navigation_shell.dart)
            -> Mobile (<768px): NavigationBar (5 primários + modal "Mais")
            -> Tablet/Desktop (>=768px): NavigationRail (inclui territoryMaps após correção FA-UX-01)
```

---

## 2. Inventário dos 19 Domínios Funcionais

| # | Domínio | Telas / Entry Points | Serviços / Regras | Tabelas Locais | Sync / Storage / Integrações | `FeatureRegistry` |
|---|---|---|---|---|---|---|
| 1 | **Hoje (Today)** | `today_screen.dart`, `next_actions_screen.dart`, `quick_capture_sheet.dart` | `repository.dart`, `pioneer_pace_calculator.dart`, `recent_seeds_helper.dart` | Agregados (`people`, `visits`, `appointments`, `tasks`, `inbox_entries`, `bible_studies`) | Indireto | `today` (essencial) |
| 2 | **Pessoas & Visitas** | `people_screen.dart`, `person_detail_screen.dart`, `add_person_dialog.dart`, `person_*_tab.dart` | `repository.dart`, `doorstep_briefing_helper.dart`, `family_ties_manager.dart`, `person_photos_manager.dart`, `person_publications_manager.dart` | `people`, `visits`, `family_ties`, `person_photos`, `person_publications` | E2EE `encrypted_records` + Storage `person_photos` | `people` |
| 3 | **Telefones** | `phone_contacts_screen.dart` | `repository.dart`, `phone_contacts_importer.dart` | `phone_contacts` | E2EE `encrypted_records` | `phones` |
| 4 | **Estudos Bíblicos** | `studies_screen.dart`, `study_detail_screen.dart` | `study_engine.dart`, `repository.dart` | `bible_studies`, `study_participants`, `study_sessions` | E2EE `encrypted_records` | `studies` |
| 5 | **Agenda & Calendários** | `appointments_screen.dart` | `availability_engine.dart`, `calendar_sync_coordinator.dart`, `apple_calendar_provider.dart`, `google_calendar_provider.dart`, `ical_calendar_provider.dart` | `appointments`, `external_calendar_events`, `calendar_event_links` | E2EE + EventKit / Google Calendar / iCal | `agenda` |
| 6 | **Estatísticas & Relatórios** | `dashboard_screen.dart` | `monthly_report_service.dart`, `pdf_report_generator.dart` | `activity_records`, agregados | E2EE + PDF export | `dashboard` |
| 7 | **Território & Mapas** | `contacts_map_screen.dart`, `download_maps_screen.dart`, `location_picker_dialog.dart` | `mbtiles_service`, `offline_map_manager`, `tile_cache_service`, `geocoding_service` | `territory_landmarks`, `territory_sectors`, `people` (coords) | Pacotes offline (MBTiles/PMTiles) + Nominatim | `territoryMaps` |
| 8 | **Áudio & Ditado** | Widgets em `person_detail`, `quick_capture`, `ticuna` | `audio_recording_service.dart`, `audio_player_service.dart`, `voice_dictation_service.dart` | `voice_notes` | E2EE + Storage `voice_notes` | Submódulo `voiceNotes` |
| 9 | **Inbox, E-mail JW & Exchange** | `inbox_screen.dart` | `inbox_manager.dart`, `jw_email_service.dart`, `exchange_service.dart` | `inbox_entries` | E2EE + IMAP (`third_party/enough_mail`) + EAS (`third_party/eas_client`, experimental) | A integrar (`FA-FUNC-01`) |
| 10 | **Tarefas & Projetos** | `tasks_screen.dart`, `projects_screen.dart` | `task_manager.dart`, `project_manager.dart` | `tasks`, `projects` | E2EE | A integrar (`FA-FUNC-01`; Projetos sob Tarefas) |
| 11 | **Base de Conhecimento & Pesquisas** | `knowledge_screen.dart`, `research_screen.dart` | `knowledge_manager.dart`, `research_manager.dart` | `knowledge_notes`, `knowledge_questions`, `knowledge_documents`, `knowledge_resources`, `research_articles`, `research_tags` | E2EE + Storage `knowledge_vault` | `notesResearch` + integrar Knowledge (`FA-FUNC-01`) |
| 12 | **Experiências de Campo** | `experiences_screen.dart` | `experiences_manager.dart` | `ministry_experiences` | E2EE | `experiences` |
| 13 | **Língua Ticuna & Multilíngue** | `ticuna_screen.dart` | `ticuna_repository.dart`, `ticuna_search_helper.dart` | `app_languages`, `ticuna_words`, `ticuna_phrases`, `ticuna_tags` | E2EE + Storage `ticuna_audio` | `ticuna` |
| 14 | **Busca Global** | `global_search_screen.dart` | `global_search_service.dart` | Leitura transversal | 100% local offline | Transversal (`FA-FUNC-02`) |
| 15 | **Notificações & Lembretes** | Configurações & Agenda/Tarefas | A implementar lembretes locais nativos (`FA-FUNC-02`) | `app_kv_store` / `appointments` / `tasks` | Local OS notifications | Transversal |
| 16 | **Lixeira & Exclusão** | `trash_screen.dart` | Soft delete (`deleted_at`) + restauração | Todas entidades soft-deletáveis | Tombstones cifrados no E2EE | Transversal |
| 17 | **Autenticação & Contas** | `auth_splash_screen.dart`, `auth_return_screen.dart` | `SupabaseAuth`, `NativeAuthCallback`, `SyncOwnerGuard` | `app_kv_store` (`automatic_sync_owner_id`, `offline_mode_enabled`) | Supabase Auth | Transversal |
| 18 | **Sincronização & E2EE** | `settings_screen.dart`, `e2ee_setup_dialog.dart`, `sync_conflicts_screen.dart` | `SupabaseSyncService`, `E2eeService`, `EncryptedRecordSync`, `EncryptedRecordCheckpoint`, `EncryptedMedia`, `SyncOwnerGuard` | `sync_queue`, `app_kv_store` | Supabase PostgREST (`encrypted_records`, `recovery_vaults`) + 4 Storage buckets cifrados | Transversal |
| 19 | **Backup, Restore & Configurações** | `settings_screen.dart`, `customize_features_screen.dart`, `pin_lock_screen.dart` | `BackupService`, `PinSecurityService`, `FeatureRegistry` | Todas as tabelas (com preservação de identidade/sync no restore) | Exportação criptografada local (v2/v3) | Transversal |

---

## 3. Fronteiras de Confiança (Trust Boundaries)

1. **Dispositivo do Usuário (Confiável — Protegido em Repouso):**
   - Banco Drift/SQLite local, Keychain/Keystore (`FlutterSecureStorage`), arquivos de mídia locais no `ApplicationDocumentsDirectory`.
   - Contas isoladas via `SyncOwnerGuard` (`automatic_sync_owner_id`) e chaves E2EE estritamente escopadas por `ownerId` (zero espelhamento via `local_user`).
2. **Transporte e Backend Supabase (Não-confiável para dados pessoais em texto claro):**
   - Autenticação + RLS (`owner_id = auth.uid()`) garantem isolamento de autorização no servidor.
   - Confidencialidade e integridade dos dados pessoais e mídias são garantidas **exclusivamente** no cliente via AES-256-GCM (BIP-39 root key -> HKDF por rota/registro/chunk).
   - **Regra Inegociável:** Nenhum dado pessoal ou mídia pode ser enviado em texto claro em produção (`SyncPrivacyPolicy.unencryptedMediaAllowed == false`, zero fallback para `sync_upsert_if_unchanged`).
3. **Serviços Externos Opcionais (Com divulgação explícita de privacidade):**
   - Nominatim/Geocoding, Google Calendar, Apple EventKit, IMAP/Exchange, servidores de mapas offline (somente pacotes públicos ODbL verificados por SHA-256; coordenadas de contatos permanecem exclusivamente no banco local privado).
