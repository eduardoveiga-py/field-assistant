# Arquitetura do Sistema: Ministério Pessoal

## 1. Visão Geral do Sistema
O **Ministério Pessoal** é um sistema offline-first projetado para gerenciar registros do ministério pessoal de campo, com foco em:
- Acompanhamento de pessoas interessadas e contatos.
- Gestão de estudos bíblicos, sessões realizadas e múltiplos participantes.
- Registro cronológico de conversas e revisitas.
- Agenda com verificação em tempo real de disponibilidade, sobreposições e conflitos.
- Dashboard analítico e territorial com regras rígidas de contagem de atividade.
- Resolução de links do JW Library (`PublicationLinkResolver`).
- Módulo de atividades pessoais e metas mensais/anuais.
- Sincronização remota via Supabase com fila persistente e resolução explícita de conflitos.
- Backup criptografado e restauração idempotente com pré-visualização.

---

## 2. Plataformas e Tecnologias
- **Framework:** Flutter (Dart) com compilação para **Web** (Desktop/Browser) e **iOS** (iPhone XR, iPad 11 A16).
- **Banco de Dados Local:** Drift (SQLite) no Mobile/Desktop e Drift Wasm (SQLite via IndexedDB/Wasm) na Web.
- **Gerenciamento de Estado:** Riverpod / Notifiers imutáveis para reatividade desacoplada e alta testabilidade.
- **Backend de Sincronização:** Supabase (PostgreSQL, Row Level Security, Auth).
- **Criptografia de Backup:** AES-GCM / PBKDF2 com derivação segura de chave por senha.

---

## 3. Organização dos Módulos

```
lib/
├── core/                  # Utilitários, formatação de datas (DD/MM/AAAA), erros, segurança e tema
├── database/              # Tabelas Drift, DAOs, migrações versionadas, transações e adaptadores
├── sync/                  # Fila de sincronização (SyncQueue), reconciliador, resolução de conflitos
├── people/                # Cadastro de pessoas, preferências, restrições e busca offline
├── visits/                # Encontros, revisitas, tentativas sem contato e notas
├── studies/               # Estudos bíblicos, participantes e sessões de estudo
├── appointments/          # Calendário (dia, semana, mês), verificação de horários, conflitos e lembretes
├── dashboard/             # Indicadores calculados, regras de contagem, lista 'Precisam de Atenção'
├── publications/          # Catálogo (livro/brochura, idiomas), PublicationLinkResolver
├── activities/            # Horas, minutos, modalidades, metas e relatórios
└── settings/              # Preferências, backup criptografado, restauração e segurança
```

---

## 4. Princípios Arquiteturais Inegociáveis
1. **Offline-First:** O banco local Drift é a autoridade imediata para toda e qualquer operação de leitura e escrita da UI. Nenhuma ação do usuário depende de conexão remota para ser concluída.
2. **Separação de Entidades:**
   - Estudo Bíblico != Sessão de Estudo != Participante != Revisita.
   - Um estudo com múltiplos participantes é contado como exatamente **um** estudo.
   - Uma sessão realizada conta como exatamente **uma** sessão.
   - Sessões canceladas e tentativas sem contato não são computadas como realizadas.
3. **Imutabilidade e Rastreabilidade:**
   - Modificar a data do próximo retorno cria um novo agendamento ou atualiza metadados sem adulterar o histórico de visitas passadas.
   - Reagendamentos preservam o compromisso anterior com status apropriado.
4. **Resolução Explícita de Conflitos:**
   - Sem estratégia simplista de "last-write-wins" global.
   - Conflitos em campos idênticos retêm ambas as versões para resolução consciente do usuário.
5. **Privacidade e Segurança:**
   - Sem envio de telemetria ou logs com anotações de moradores.
   - Row Level Security estrito no backend por `user_id`.
   - Chaves secretas nunca expostas no cliente.
