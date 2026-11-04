# Modelo de Dados: Ministério Pessoal

## 1. Princípios de Entidades e Identificadores
- **Identificadores:** UUID v4 gerados localmente no dispositivo para todas as entidades persistíveis.
- **Auditoria Universal:** Toda entidade de negócio e de sincronização possui campos de rastreabilidade temporal e versionamento monotônico:
  - `created_at`: Data e hora da criação no dispositivo.
  - `updated_at`: Data e hora da última modificação.
  - `deleted_at`: Data e hora da exclusão lógica (soft delete). Se `NULL`, o registro está ativo.
  - `revision`: Inteiro com incremento monotônico (default 1) utilizado pelo algoritmo de 3-way merge e pela barreira contra ressurreição de tombstones.
- **Motor de Banco de Dados:** Drift (SQLite) fortemente tipado, versão de esquema 4 (`schemaVersion: 4`).
- **Idempotência:** A tabela transacional `sync_queue` registra cada mutação com identificador único de operação e snapshot base (`_base`).

---

## 2. Inventário Completo das 22 Tabelas Drift

### 2.1 Núcleo do Ministério de Campo

#### 1. People (`people`)
Representa uma pessoa contatada no ministério de campo.
- `id` (TEXT/UUID, PK): Identificador único da pessoa.
- `name` (TEXT, NOT NULL): Nome ou identificação da pessoa.
- `phone` (TEXT, NULL): Telefone principal.
- `address` (TEXT, NULL): Endereço residencial ou comercial.
- `latitude` (REAL, NULL): Coordenada geográfica de latitude.
- `longitude` (REAL, NULL): Coordenada geográfica de longitude.
- `first_contact_at` (DATETIME, NOT NULL): Data do primeiro encontro.
- `status` (TEXT, NOT NULL DEFAULT 'interessado'): `'interessado'`, `'revisita'`, `'estudo'`, `'outro'`.
- `preferred_schedule` (TEXT, NULL): Horários preferenciais de visita.
- `general_notes` (TEXT, NULL): Notas e observações gerais.
- `contact_restrictions` (TEXT, NULL): Restrições de contato (ex: não bater aos sábados de manhã).
- `tags` (TEXT, NOT NULL DEFAULT '[]'): Tags serializadas em JSON.
- `last_contact_at` (DATETIME, NULL): Data do último contato efetivo.
- `next_action_at` (DATETIME, NULL): Data planejada para próxima ação.
- `next_action_note` (TEXT, NULL): Detalhes da próxima ação planejada.
- `created_at`, `updated_at` (DATETIME, NOT NULL), `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

#### 2. Visits (`visits`)
Registro cronológico de interação ministerial com uma pessoa.
- `id` (TEXT/UUID, PK): Identificador único da visita.
- `person_id` (TEXT/UUID, FK -> `people.id`, NOT NULL): Pessoa contatada.
- `date_time_field` (DATETIME, NOT NULL): Data e hora exata do contato.
- `contact_type` (TEXT, NOT NULL): `'conversa_inicial'`, `'revisita'`, `'estudo'`, `'tentativa_sem_contato'`, `'contato_telefonico'`, `'outro'`.
- `result` (TEXT, NOT NULL): Resumo do resultado da visita.
- `notes` (TEXT, NULL): Notas detalhadas da conversa.
- `topics_discussed` (TEXT, NULL): Temas bíblicos discutidos.
- `scripture_or_pub` (TEXT, NULL): Textos bíblicos lidos ou publicação deixada.
- `expressed_question` (TEXT, NULL): Pergunta deixada para a próxima visita.
- `next_step` (TEXT, NULL): Próximo passo planejado.
- `suggested_return_date` (DATETIME, NULL): Sugestão de retorno.
- `appointment_id` (TEXT/UUID, NULL): Vínculo com compromisso da agenda.
- `created_at`, `updated_at` (DATETIME, NOT NULL), `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

#### 3. BibleStudies (`bible_studies`)
Acompanhamento contínuo de estudo bíblico.
- `id` (TEXT/UUID, PK): Identificador único do estudo.
- `title` (TEXT, NOT NULL): Título ou descrição do estudo.
- `owner_id` (TEXT, NOT NULL DEFAULT 'local_user'): Identificador do publicador proprietário.
- `started_at` (DATETIME, NOT NULL): Data de início do estudo.
- `status` (TEXT, NOT NULL DEFAULT 'ativo'): `'ativo'`, `'pausado'`, `'concluido'`, `'encerrado'`.
- `publication_id` (TEXT, NOT NULL): Identificador da publicação (ex: `'lff-book'`, `'lff-brochure'`).
- `language` (TEXT, NOT NULL DEFAULT 'pt'): Idioma do estudo (`'pt'`, `'tca'`, `'bzs'`).
- `current_lesson` (INTEGER, NULL): Lição atual.
- `current_paragraph` (INTEGER, NULL): Parágrafo atual.
- `manual_reference` (TEXT, NULL): Referência manual caso não utilize a publicação padrão.
- `frequency` (TEXT, NOT NULL DEFAULT 'semanal'): `'semanal'`, `'quinzenal'`, `'mensal'`, `'personalizada'`.
- `learning_goals` (TEXT, NULL): Metas espirituais do estudante.
- `pending_doubts` (TEXT, NULL): Dúvidas pendentes do estudante.
- `next_topic` (TEXT, NULL): Próximo tema a considerar.
- `pause_or_close_reason` (TEXT, NULL): Motivo da pausa ou encerramento.
- `last_session_at` (DATETIME, NULL): Data da última sessão realizada.
- `next_planned_at` (DATETIME, NULL): Data planejada para o próximo estudo.
- `created_at`, `updated_at` (DATETIME, NOT NULL), `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

#### 4. StudyParticipants (`study_participants`)
Tabela associativa de relação M:N entre estudos bíblicos e pessoas.
- `id` (TEXT/UUID, PK): Identificador único da participação.
- `study_id` (TEXT/UUID, FK -> `bible_studies.id`, NOT NULL): Estudo bíblico associado.
- `person_id` (TEXT/UUID, FK -> `people.id`, NOT NULL): Pessoa participante.
- `is_primary` (BOOLEAN, NOT NULL DEFAULT false): Indica se é o estudante principal.
- `created_at`, `updated_at` (DATETIME, NOT NULL), `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

#### 5. StudySessions (`study_sessions`)
Ocorrência pontual de uma sessão de estudo bíblico.
- `id` (TEXT/UUID, PK): Identificador único da sessão.
- `study_id` (TEXT/UUID, FK -> `bible_studies.id`, NOT NULL): Estudo ao qual pertence.
- `date_time_field` (DATETIME, NOT NULL): Data e hora da realização da sessão.
- `publication_code` (TEXT, NULL): Código da publicação considerada.
- `lesson_covered` (INTEGER, NULL): Lição abrangida na sessão.
- `paragraphs_covered` (TEXT, NULL): Parágrafos abrangidos.
- `session_notes` (TEXT, NULL): Observações da sessão.
- `pending_questions` (TEXT, NULL): Perguntas que ficaram para a próxima vez.
- `next_step` (TEXT, NULL): Próximo passo definido.
- `status` (TEXT, NOT NULL DEFAULT 'realizada'): `'realizada'`, `'cancelada'`, `'nao_realizada'`.
- `participant_ids` (TEXT, NOT NULL DEFAULT '[]'): Lista JSON com os IDs das pessoas presentes.
- `created_at`, `updated_at` (DATETIME, NOT NULL), `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

#### 6. Appointments (`appointments`)
Compromissos agendados no calendário ministerial (revisitas, estudos ou saídas de campo).
- `id` (TEXT/UUID, PK): Identificador único do agendamento.
- `person_id` (TEXT/UUID, FK opcional -> `people.id`, NULL): Pessoa vinculada.
- `study_id` (TEXT/UUID, FK opcional -> `bible_studies.id`, NULL): Estudo vinculado.
- `title` (TEXT, NOT NULL): Título descritivo do compromisso.
- `start_time` (DATETIME, NOT NULL): Horário de início.
- `end_time` (DATETIME, NOT NULL): Horário de término.
- `duration_minutes` (INTEGER, NOT NULL DEFAULT 30): Duração em minutos.
- `status` (TEXT, NOT NULL DEFAULT 'planejado'): `'planejado'`, `'confirmado'`, `'realizado'`, `'cancelado'`, `'nao_realizado'`, `'reagendado'`, `'provisorio'`, `'conflito'`.
- `previous_appointment_id` (TEXT/UUID, NULL): ID de compromisso anterior caso reagendado.
- `location_notes` (TEXT, NULL): Ponto de encontro ou endereço.
- `reminder_minutes_before` (INTEGER, NULL): Primeiro lembrete em minutos.
- `second_reminder_minutes_before` (INTEGER, NULL): Segundo lembrete em minutos.
- `is_provisional` (BOOLEAN, NOT NULL DEFAULT false): Sinaliza agendamento provisório ou em conflito de sobreposição temporal concorrente.
- `created_at`, `updated_at` (DATETIME, NOT NULL), `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

#### 7. ActivityRecords (`activity_records`)
Registro de horas e modalidades de serviço de campo para relatórios pessoais.
- `id` (TEXT/UUID, PK): Identificador único da atividade.
- `date` (DATETIME, NOT NULL): Data da atividade ministerial.
- `duration_seconds` (INTEGER, NOT NULL): Duração total em segundos.
- `modality` (TEXT, NOT NULL): `'campo'`, `'testemunho_publico'`, `'informal'`, `'carta_telefone'`, `'outro'`.
- `notes` (TEXT, NULL): Observações sobre o dia de serviço.
- `created_at`, `updated_at` (DATETIME, NOT NULL), `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

---

### 2.2 Mídia, Contatos Rápidos e Território

#### 8. VoiceNotes (`voice_notes`)
Notas de voz e transcrições gravadas após conversas e revisitas.
- `id` (TEXT/UUID, PK): Identificador único da nota de voz.
- `person_id` (TEXT/UUID, FK -> `people.id`, NOT NULL): Pessoa associada.
- `visit_id` (TEXT/UUID, FK opcional -> `visits.id`, NULL): Visita associada.
- `study_id` (TEXT/UUID, FK opcional -> `bible_studies.id`, NULL): Estudo associado.
- `audio_file_path` (TEXT, NULL): Caminho local absoluto do arquivo de áudio no filesystem. Sanitizado no envio de metadados; sincronizado via Supabase Storage.
- `audio_duration_seconds` (INTEGER, NOT NULL DEFAULT 0): Duração do áudio.
- `transcription` (TEXT, NOT NULL): Transcrição textual gerada.
- `detected_lesson` (INTEGER, NULL): Lição identificada no áudio.
- `detected_point` (INTEGER, NULL): Ponto ministerial detectado.
- `extracted_pending_doubt` (TEXT, NULL): Dúvida do morador extraída pelo assistente.
- `extracted_empathy_note` (TEXT, NULL): Ponto de empatia ou nota pessoal extraída.
- `created_at`, `updated_at` (DATETIME, NOT NULL), `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

#### 9. PhoneContacts (`phone_contacts`)
Registro de contatos rápidos informais ou telefônicos antes da conversão em pessoa formal.
- `id` (TEXT/UUID, PK): Identificador único.
- `name` (TEXT, NOT NULL): Nome ou apelido do contato.
- `phone` (TEXT, NOT NULL): Telefone principal.
- `secondary_phone` (TEXT, NULL): Telefone secundário.
- `has_whatsapp` (BOOLEAN, NOT NULL DEFAULT false): Possui WhatsApp ativo.
- `whatsapp_info` (TEXT, NULL): Informações adicionais de WhatsApp.
- `has_social` (BOOLEAN, NOT NULL DEFAULT false): Possui rede social.
- `social_platform` (TEXT, NULL): Plataforma da rede social.
- `social_handle` (TEXT, NULL): Perfil ou usuário na rede social.
- `notes` (TEXT, NULL): Notas de conversas breves.
- `tags` (TEXT, NOT NULL DEFAULT '[]'): Tags serializadas em JSON.
- `origin` (TEXT, NOT NULL DEFAULT 'Informal'): Origem do contato.
- `converted_person_id` (TEXT/UUID, FK opcional -> `people.id`, NULL): ID da pessoa formal caso tenha sido promovido.
- `created_at`, `updated_at` (DATETIME, NOT NULL), `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

#### 10. TerritoryLandmarks (`territory_landmarks`)
Pontos de referência geográficos e marcos no território (estabelecimentos, praças, condomínios).
- `id` (TEXT/UUID, PK): Identificador único.
- `name` (TEXT, NOT NULL): Nome do ponto de referência.
- `category` (TEXT, NOT NULL): Categoria (`comercio`, `escola`, `praca`, `outro`).
- `address` (TEXT, NULL): Endereço físico aproximado.
- `latitude` (REAL, NULL): Latitude.
- `longitude` (REAL, NULL): Longitude.
- `notes` (TEXT, NULL): Observações úteis para o ministério.
- `created_at`, `updated_at` (DATETIME, NOT NULL), `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

#### 11. TerritorySectors (`territory_sectors`)
Definição de setores ou quadras dentro de um território designado.
- `id` (TEXT/UUID, PK): Identificador único do setor.
- `name` (TEXT, NOT NULL): Nome ou número do setor.
- `description` (TEXT, NULL): Descrição dos limites e características.
- `created_at` (DATETIME, NOT NULL), `updated_at`, `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

---

### 2.3 Vínculos Familiares, Publicações e Experiências

#### 12. FamilyTies (`family_ties`)
Mapeamento de relacionamentos familiares e de convivência entre pessoas contatadas.
- `id` (TEXT/UUID, PK): Identificador único.
- `person_id` (TEXT, NOT NULL): Pessoa primária.
- `related_person_id` (TEXT, NULL): Pessoa relacionada cadastrada no banco.
- `related_person_name` (TEXT, NOT NULL): Nome do familiar ou parente.
- `relationship_type` (TEXT, NOT NULL): Tipo de parentesco (`conjugue`, `filho`, `pai`, `parente`, `outro`).
- `created_at` (DATETIME, NOT NULL), `updated_at`, `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

#### 13. PersonPhotos (`person_photos`)
Fotos de fachadas ou de identificação de moradores para auxílio de memória ministerial.
- `id` (TEXT/UUID, PK): Identificador único da imagem.
- `person_id` (TEXT, NOT NULL): Pessoa vinculada.
- `photo_type` (TEXT, NOT NULL): Tipo da foto (`fachada`, `residencia`, `outro`).
- `image_data` (TEXT, NOT NULL): Dados da imagem ou URI codificada.
- `created_at` (DATETIME, NOT NULL), `updated_at`, `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

#### 14. PersonPublications (`person_publications`)
Histórico de publicações teocráticas entregues a uma pessoa específica.
- `id` (TEXT/UUID, PK): Identificador único.
- `person_id` (TEXT, NOT NULL): Pessoa que recebeu a publicação.
- `publication_title` (TEXT, NOT NULL): Título da publicação, folheto ou revista.
- `item_type` (TEXT, NOT NULL): Tipo do item (`livro`, `brochura`, `revista`, `folheto`, `link`).
- `status` (TEXT, NOT NULL): Status (`entregue`, `enviado_digital`, `prometido`).
- `date` (TEXT, NOT NULL): Data em formato ISO-8601.
- `notes` (TEXT, NULL): Observações adicionais.
- `created_at` (DATETIME, NOT NULL), `updated_at`, `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

#### 15. MinistryExperiences (`ministry_experiences`)
Registro de experiências marcantes no ministério de campo para incentivo e partilha.
- `id` (TEXT/UUID, PK): Identificador único.
- `title` (TEXT, NOT NULL): Título da experiência.
- `content` (TEXT, NOT NULL): Relato detalhado da experiência.
- `media_urls` (TEXT, NOT NULL DEFAULT '[]'): Links ou referências de mídia anexadas.
- `tags` (TEXT, NOT NULL DEFAULT '[]'): Tags de classificação.
- `date_time` (DATETIME, NOT NULL): Data e hora do acontecimento.
- `location_or_modality` (TEXT, NULL): Modalidade ou localidade.
- `created_at`, `updated_at` (DATETIME, NOT NULL), `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

---

### 2.4 Pesquisa Teocrática e Ordenação Manual

#### 16. ResearchArticles (`research_articles`)
Artigos de pesquisa e notas temáticas salvas pelo publicador para visitas e respostas.
- `id` (TEXT/UUID, PK): Identificador único.
- `title` (TEXT, NOT NULL): Título do artigo de pesquisa.
- `summary` (TEXT, NOT NULL): Breve resumo ou sinopse.
- `content` (TEXT, NOT NULL): Conteúdo textual e citações.
- `tags` (TEXT, NOT NULL DEFAULT '[]'): Tags temáticas associadas.
- `attachments` (TEXT, NOT NULL DEFAULT '[]'): Referências de anexos.
- `created_at`, `updated_at` (DATETIME, NOT NULL), `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

#### 17. ResearchTags (`research_tags`)
Catálogo de tags organizacionais para pesquisa teocrática.
- `id` (TEXT/UUID, PK): Identificador único da tag.
- `name` (TEXT, NOT NULL): Nome descritivo da tag.
- `created_at` (DATETIME, NOT NULL), `updated_at`, `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

#### 18. StudentManualOrder (`student_manual_order`)
Ordenação customizada da lista de estudantes na visualização do publicador.
- `study_id` (TEXT, PK): ID do estudo ordenado.
- `manual_index` (INTEGER, NOT NULL): Posição ordinal definida manualmente pelo usuário.
- `updated_at`, `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

---

### 2.5 Integração com Calendários Externos

#### 19. ExternalCalendarEvents (`external_calendar_events`)
Espelho local de eventos obtidos de provedores externos de calendário.
- `id` (TEXT/UUID, PK): Identificador único.
- `provider` (TEXT, NOT NULL): Provedor de calendário (`google`, `apple_eventkit`, `ical_url`).
- `external_account` (TEXT, NULL): Conta do usuário (ex: e-mail Google).
- `calendar_id` (TEXT, NOT NULL): ID do calendário externo.
- `external_event_id` (TEXT, NOT NULL): ID do evento no provedor remoto.
- `ical_uid` (TEXT, NULL): Identificador iCalendar (iCal UID).
- `title` (TEXT, NOT NULL): Título do evento.
- `location` (TEXT, NULL): Local do evento.
- `description` (TEXT, NULL): Descrição textual.
- `start_time` (DATETIME, NOT NULL): Início do evento.
- `end_time` (DATETIME, NOT NULL): Fim do evento.
- `time_zone` (TEXT, NULL): Fuso horário do evento.
- `is_all_day` (BOOLEAN, NOT NULL DEFAULT false): Evento de dia inteiro.
- `external_status` (TEXT, NULL): Status no provedor (`confirmed`, `tentative`, `cancelled`).
- `last_modified_external` (DATETIME, NULL): Data da última modificação externa.
- `last_synced_at` (DATETIME, NULL): Data da sincronização local.
- `is_deleted_external` (BOOLEAN, NOT NULL DEFAULT false): Indica se foi excluído externamente.
- `metadata` (TEXT, NULL): JSON bruto com metadados adicionais do provedor.
- `etag` (TEXT, NULL): Hash ETag para controle de concorrência HTTP.
- `created_at`, `updated_at` (DATETIME, NOT NULL), `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

#### 20. CalendarEventLinks (`calendar_event_links`)
Vínculo bidirecional entre um compromisso local (`appointments`) e um evento externo (`external_calendar_events`).
- `id` (TEXT/UUID, PK): Identificador único do link.
- `appointment_id` (TEXT, NOT NULL): ID do compromisso interno.
- `external_event_id` (TEXT, NOT NULL): ID do evento externo correspondente.
- `provider` (TEXT, NOT NULL): Provedor (`google`, `apple_eventkit`).
- `sync_status` (TEXT, NOT NULL DEFAULT 'synced'): `'synced'`, `'pending_upload'`, `'pending_download'`, `'conflict'`, `'failed'`.
- `last_error` (TEXT, NULL): Última mensagem de erro na sincronização externa.
- `local_revision_at_sync` (INTEGER, NOT NULL DEFAULT 1): Versão local no momento do sync.
- `external_etag_at_sync` (TEXT, NULL): ETag externo no momento do sync.
- `pending_resolution` (TEXT, NULL): Resolução pendente para reconciliação manual.
- `created_at`, `updated_at` (DATETIME, NOT NULL), `deleted_at` (DATETIME, NULL), `revision` (INTEGER, NOT NULL DEFAULT 1).

---

### 2.6 Infraestrutura e Sincronização Local

#### 21. SyncQueue (`sync_queue`)
Fila transacional persistente da outbox para operações de sincronização offline-first.
- `id` (TEXT/UUID, PK): Identificador da operação.
- `entity_type` (TEXT, NOT NULL): Nome da entidade (`people`, `visits`, `bible_studies`, `study_participants`, `study_sessions`, `appointments`, `activity_records`, `voice_notes`, `phone_contacts`, `territory_landmarks`).
- `entity_id` (TEXT, NOT NULL): UUID do registro impactado.
- `operation` (TEXT, NOT NULL): Tipo de operação (`INSERT`, `UPDATE`, `DELETE`).
- `payload` (TEXT, NOT NULL): JSON com dados modificados e snapshot base (`_base`) para 3-way merge.
- `created_at` (DATETIME, NOT NULL): Carimbo local de inclusão na fila.
- `attempts` (INTEGER, NOT NULL DEFAULT 0): Contador de tentativas de despacho.
- `last_error` (TEXT, NULL): Mensagem técnica da última falha.
- `status` (TEXT, NOT NULL DEFAULT 'pending'): `'pending'`, `'in_progress'`, `'synced'`, `'conflict'`, `'failed'`.

#### 22. AppKvStore (`app_kv_store`)
Armazenamento local chave-valor para parâmetros operacionais, cursores incrementais de sincronização e tokens transitórios de download de áudio.
- `key` (TEXT, PK): Chave identificadora (ex: `'last_synced_at_people'`, `'last_synced_id_people'`, `'pending_audio_download_<id>'`).
- `value` (TEXT, NOT NULL): Valor persistido.
- `updated_at` (DATETIME, NULL): Carimbo de atualização.

---

## 3. Regras Teocráticas Formais de Contagem Ministerial
1. **Contagem de Estudos Bíblicos Ativos:**
   - Contagem distinta de registros na tabela `BibleStudies` onde `status = 'ativo'` e `deleted_at IS NULL`.
   - Se 3 pessoas participam do mesmo estudo (`StudyParticipants`), conta **1 único estudo ativo**.
2. **Contagem de Sessões de Estudo Realizadas:**
   - Contagem de registros na tabela `StudySessions` onde `status = 'realizada'`, `date_time_field` dentro do mês em questão e `deleted_at IS NULL`.
   - A presença de múltiplos participantes na mesma sessão continua contando como **1 sessão realizada**.
   - Sessões com status `'cancelada'` ou `'nao_realizada'` **nunca** são contabilizadas como horas ou atividades.
3. **Contagem de Revisitas Realizadas:**
   - Contagem de registros na tabela `Visits` com `contact_type IN ('revisita', 'estudo', 'contato_telefonico')`, onde o contato com o morador efetivamente ocorreu.
   - Visitas com status ou tipo `'tentativa_sem_contato'` **não contam** como revisitas.
4. **Agendamentos Futuros:**
   - Registros em `Appointments` com data futura ou status `'planejado'`, `'provisorio'` ou `'conflito'` não entram em relatórios nem estatísticas ministeriais até que uma visita ou sessão correspondente seja registrada.
