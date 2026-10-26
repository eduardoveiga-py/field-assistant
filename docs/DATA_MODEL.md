# Modelo de Dados: Ministério Pessoal

## 1. Princípios de Entidades e Identificadores
- **Identificadores:** UUID v4 gerados localmente no dispositivo para todas as entidades persistíveis.
- **Auditoria:** Toda entidade sincronizável possui `id`, `created_at`, `updated_at`, `deleted_at` (soft delete) e `version` (ou `revision`).
- **Idempotência:** A tabela de sincronização registra transações locais com identificador único de operação.

---

## 2. Diagrama de Relacionamento e Entidades

### 2.1 Person (Pessoa)
Representa um indivíduo encontrado no ministério de campo.
- `id` (TEXT/UUID, PK)
- `name` (TEXT, NOT NULL)
- `phone` (TEXT, NULL)
- `address` (TEXT, NULL)
- `latitude` (REAL, NULL)
- `longitude` (REAL, NULL)
- `first_contact_at` (DATETIME, NOT NULL)
- `status` (TEXT: 'interessado', 'revisita', 'estudo', 'outro')
- `preferred_schedule` (TEXT, NULL)
- `general_notes` (TEXT, NULL)
- `contact_restrictions` (TEXT, NULL)
- `tags` (TEXT, lista serializada em JSON)
- `last_contact_at` (DATETIME, NULL)
- `next_action_at` (DATETIME, NULL)
- `next_action_note` (TEXT, NULL)
- `created_at`, `updated_at`, `deleted_at`, `revision`

### 2.2 Visit (Visita / Revisita)
Registro cronológico de interação com uma pessoa.
- `id` (TEXT/UUID, PK)
- `person_id` (TEXT/UUID, FK -> Person.id, NOT NULL)
- `date_time` (DATETIME, NOT NULL)
- `contact_type` (TEXT: 'conversa_inicial', 'revisita', 'estudo', 'tentativa_sem_contato', 'contato_telefonico', 'outro')
- `result` (TEXT, NOT NULL)
- `notes` (TEXT, NULL)
- `topics_discussed` (TEXT, NULL)
- `scripture_or_pub` (TEXT, NULL)
- `expressed_question` (TEXT, NULL)
- `next_step` (TEXT, NULL)
- `suggested_return_date` (DATETIME, NULL)
- `appointment_id` (TEXT/UUID, NULL)
- `created_at`, `updated_at`, `deleted_at`, `revision`

### 2.3 BibleStudy (Estudo Bíblico)
Acompanhamento contínuo de uma pessoa ou grupo.
- `id` (TEXT/UUID, PK)
- `title` (TEXT, NOT NULL)
- `owner_id` (TEXT, NOT NULL)
- `started_at` (DATETIME, NOT NULL)
- `status` (TEXT: 'ativo', 'pausado', 'concluido', 'encerrado')
- `publication_id` (TEXT, NOT NULL)
- `language` (TEXT, NOT NULL)
- `current_lesson` (INTEGER, NULL)
- `current_paragraph` (INTEGER, NULL)
- `manual_reference` (TEXT, NULL)
- `frequency` (TEXT: 'semanal', 'quinzenal', 'mensal', 'personalizada')
- `learning_goals` (TEXT, NULL)
- `pending_doubts` (TEXT, NULL)
- `next_topic` (TEXT, NULL)
- `pause_or_close_reason` (TEXT, NULL)
- `last_session_at` (DATETIME, NULL)
- `next_planned_at` (DATETIME, NULL)
- `created_at`, `updated_at`, `deleted_at`, `revision`

### 2.4 StudyParticipant (Participante do Estudo)
Mapeamento M:N entre estudo bíblico e pessoas participantes.
- `id` (TEXT/UUID, PK)
- `study_id` (TEXT/UUID, FK -> BibleStudy.id, NOT NULL)
- `person_id` (TEXT/UUID, FK -> Person.id, NOT NULL)
- `is_primary` (BOOLEAN, NOT NULL DEFAULT 0)
- `created_at`, `updated_at`, `deleted_at`, `revision`

### 2.5 StudySession (Sessão de Estudo)
Ocorrência pontual de um estudo bíblico realizado.
- `id` (TEXT/UUID, PK)
- `study_id` (TEXT/UUID, FK -> BibleStudy.id, NOT NULL)
- `date_time` (DATETIME, NOT NULL)
- `publication_code` (TEXT, NULL)
- `lesson_covered` (INTEGER, NULL)
- `paragraphs_covered` (TEXT, NULL)
- `session_notes` (TEXT, NULL)
- `pending_questions` (TEXT, NULL)
- `next_step` (TEXT, NULL)
- `status` (TEXT: 'realizada', 'cancelada', 'nao_realizada')
- `participant_ids` (TEXT, lista serializada em JSON de IDs presentes)
- `created_at`, `updated_at`, `deleted_at`, `revision`

### 2.6 Appointment (Compromisso / Agenda)
Compromisso marcado para revisita ou estudo.
- `id` (TEXT/UUID, PK)
- `person_id` (TEXT/UUID, FK -> Person.id, NULL)
- `study_id` (TEXT/UUID, FK -> BibleStudy.id, NULL)
- `title` (TEXT, NOT NULL)
- `start_time` (DATETIME, NOT NULL)
- `end_time` (DATETIME, NOT NULL)
- `duration_minutes` (INTEGER, NOT NULL)
- `status` (TEXT: 'planejado', 'confirmado', 'realizado', 'cancelado', 'nao_realizado', 'reagendado', 'provisorio')
- `previous_appointment_id` (TEXT/UUID, NULL)
- `location_notes` (TEXT, NULL)
- `reminder_minutes_before` (INTEGER, NULL)
- `second_reminder_minutes_before` (INTEGER, NULL)
- `created_at`, `updated_at`, `deleted_at`, `revision`

### 2.7 ActivityRecord (Registro de Atividade do Ministério)
Horas e modalidades dedicadas para relatórios e metas pessoais.
- `id` (TEXT/UUID, PK)
- `date` (DATE, NOT NULL)
- `duration_seconds` (INTEGER, NOT NULL)
- `modality` (TEXT: 'campo', 'testemunho_publico', 'informal', 'carta_telefone', 'outro')
- `notes` (TEXT, NULL)
- `created_at`, `updated_at`, `deleted_at`, `revision`

---

## 3. Regras Formais de Contagem
1. **Estudos Ativos:** Contagem distinta de registros na tabela `BibleStudy` onde `status = 'ativo'` e `deleted_at IS NULL`.
   - Se 3 pessoas participam do mesmo estudo, conta **1 estudo ativo**.
2. **Sessões Realizadas:** Contagem de registros na tabela `StudySession` onde `status = 'realizada'`, `date_time` no período e `deleted_at IS NULL`.
   - Se uma sessão teve 4 participantes presentes, conta como **1 sessão realizada**.
   - Sessões com status `'cancelada'` ou `'nao_realizada'` **nunca** contam.
3. **Revisitas Realizadas:** Contagem de registros na tabela `Visit` com `contact_type IN ('revisita', 'estudo', 'contato_telefonico')`, onde o contato efetivamente ocorreu e não foi `'tentativa_sem_contato'`.
4. **Compromissos Agendados:** Compromissos futuros não são contados como revisitas ou sessões realizadas.
