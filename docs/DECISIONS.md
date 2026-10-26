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
