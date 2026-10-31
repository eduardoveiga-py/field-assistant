# Registro de Decisões Técnicas (ADR): Ministério Pessoal

## ADR-001: Adoção do Flutter com Suporte a Web e iOS
- **Contexto:** Necessidade de aplicação executável no Windows (Web/Desktop) e em dispositivos móveis da Apple (iPhone XR e iPad 11 A16), com uma base de código compartilhada.
- **Decisão:** Utilizar Flutter com Dart estável.
- **Consequências:**
  - Código único para interface, modelo de domínio, lógica de sincronização e testes.
  - Testabilidade via `flutter test` direto no ambiente Windows.
  - Preparado para compilação nativa iOS via runner macOS em GitHub Actions.

## ADR-002: Banco de Dados Local Drift (SQLite & Wasm)
- **Contexto:** Sistema estritamente offline-first. Necessidade de integridade relacional, consultas tipadas, migrações versionadas e persistência real no navegador.
- **Decisão:** Drift (antigo Moor) com backend SQLite no nativo e SQLite Wasm com IndexedDB na Web.
- **Consequências:**
  - Zero risco de perda de anotações ao recarregar a página web ou ficar sem rede móvel.
  - Consultas reativas com streams automáticos para atualização de telas.
  - Não dependência de arquivos SQLite monolíticos para sincronização.

## ADR-003: Backend Supabase com Row Level Security (RLS)
- **Contexto:** Sincronização multi-dispositivo sem expor dados a outros usuários, mantendo esquema relacional e escalabilidade.
- **Decisão:** Supabase com PostgreSQL e autenticação por email/senha.
- **Consequências:**
  - Aplicação de regras rígidas de segurança por linha (`user_id = auth.uid()`).
  - Sem uso de segredos de administrador no cliente.
  - Abstração local que permite funcionamento com modo de demonstração isolado sem requerer credenciais na inicialização.

## ADR-004: Fila de Sincronização Transacional com Resolução de Conflitos
- **Contexto:** Riscos de concorrência e perdas silenciosas quando o usuário edita anotações no campo (offline) e no iPad em casa.
- **Decisão:** Fila persistente `sync_queue` com operações atômicas, controle de revisão e retenção de versões conflitantes para decisão humana consciente.
- **Consequências:**
  - Proibição de "last-write-wins" cego em anotações de conversas.
  - Histórico de revisitas e sessões de estudos preservado como registros imutáveis pontuais.

## ADR-005: Formatação de Horários e Agenda Tipo Consultório
- **Contexto:** No ministério de campo, o usuário combina retornos com o morador e precisa de verificação instantânea de conflitos.
- **Decisão:** Motor de disponibilidade que analisa intervalos `[start, end]` contra a base de dados local antes da confirmação, gerando opções alternativas em caso de colisão.
- **Consequências:**
  - Impossibilidade de sobreposição involuntária de visitas.
  - Suporte a agendamentos provisórios quando criado offline.

## ADR-006: Envelope Criptográfico de Backup v2 com PBKDF2-HMAC-SHA256 e AES-256-GCM
- **Contexto:** Garantir integridade e confidencialidade máxima das exportações de dados confidenciais do ministério, com chave mestra do dispositivo e compatibilidade retroativa com arquivos v1.
- **Decisão:** Adotar envelope criptográfico versão 2 contendo salt de 16 bytes gerado via `Random.secure()`, derivação de chave por PBKDF2-HMAC-SHA256 com 100.000 iterações, cifra autenticada AES-256-GCM com tag de 128 bits e IV aleatório de 16 bytes. Backups silenciosos utilizam segredo de dispositivo gerado e persistido no `app_kv_store` local em vez de senha estática.
- **Consequências:**
  - Impossibilidade matemática de adulteração silenciosa do arquivo de backup (autenticação de integridade integrada no GCM).
  - Proteção robusta contra força bruta por meio das 100.000 iterações de derivação de chave.
  - Compatibilidade com restauração de arquivos v1 legados (AES-CBC + checksum SHA-256).

## ADR-007: Serviços Reais de Áudio e Ditado com Degradação Graciosa
- **Contexto:** Necessidade de gravação de notas rápidas pós-visita no ministério de campo utilizando o hardware real do dispositivo (microfone e reconhecimento de voz).
- **Decisão:** Implementação de `RealAudioRecordingService` (`package:record`), `RealAudioPlayerService` (`package:audioplayers`) e `RealVoiceDictationService` (`package:speech_to_text`), mantendo fakes completos para testes automatizados sem dependência de hardware nativo.
- **Consequências:**
  - Suporte a gravação m4a/aac nativa no diretório de documentos do app.
  - Tratamento de negação de permissão de microfone com feedback explícito em tela e fallback para entrada manual digitada.
  - Ditado contínuo em pt-BR com `SpeechListenOptions`.

## ADR-008: Evolução do Esquema Drift v2 com Tabelas Fortemente Tipadas
- **Contexto:** Módulos de notas de voz, importação de contatos da agenda, marcos territoriais e armazenamento chave-valor utilizavam consultas SQL cruas ou criação manual de tabelas.
- **Decisão:** Evoluir o esquema Drift para versão 2 com as tabelas tipadas `VoiceNotes`, `PhoneContacts`, `TerritoryLandmarks` e `AppKvStore`, integradas ao repositório transacional e ao mecanismo de migração segura.
- **Consequências:**
  - Tipagem estrita de colunas no Dart com DAOs nativos.
  - Suporte a transações atômicas multi-entidade (ex: `saveQuickVisitFromVoiceNote` grava visita, nota e atualiza estudante/participante em uma única transação).
  - Reconstituição fiel de entidades adicionais no backup e no sync remoto.
