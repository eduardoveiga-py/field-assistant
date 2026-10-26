# Ministério Pessoal — Gestão Pessoal do Ministério de Campo

Aplicativo multiplataforma (**Web**, **iPhone XR** e **iPad 11 A16**) desenvolvido em **Flutter** e arquitetura **Offline-First**, projetado para organização do ministério de campo pessoal com privacidade total, alta legibilidade sob luz solar, agendamento sem colisões e contagem rigorosa de atividades.

---

## 🏛️ Princípios Arquiteturais e Invioláveis

1. **Separação Rígida de Entidades**:
   - `BibleStudy` ≠ `StudySession` ≠ `Participant` ≠ `Visit`.
   - Um estudo com múltiplos participantes (ex: casal) conta como **exatamente 1 estudo bíblico ativo**.
   - Uma sessão realizada com 3 participantes conta como **1 sessão de estudo realizada**.
   - Sessões canceladas ou não realizadas **NÃO** contam como sessões de estudo.
   - Revisitas agendadas para o futuro **NÃO** contam como revisitas realizadas.
   - Tentativas sem contato no território **NÃO** contam como conversas realizadas.

2. **Agenda Estilo Consultório Médico (`AvailabilityEngine`)**:
   - Detecção em tempo real de colisões de horário antes de salvar.
   - Bloqueio de sobreposições parciais ou totais.
   - Encaixes imediatamente consecutivos são permitidos quando não houver buffer configurado.
   - Sugestão automática de próximos horários livres no mesmo dia.

3. **Offline-First Verdadeiro com Drift**:
   - **Mobile / Desktop**: SQLite nativo via `sqlite3_flutter_libs`.
   - **Web**: Drift WebAssembly (`WasmDatabase` / IndexedDB).
   - Fila persistente de mutações (`SyncQueue`) gravada atomicamente na mesma transação local.
   - Detecção explícita de conflitos em nível de campos individuais (sem "last-write-wins" cego em anotações).

4. **Backup Criptografado de Ponta a Ponta (`BackupService`)**:
   - Criptografia **AES-256 GCM** com derivação de chave **PBKDF2** (100.000 iterações).
   - Checksum de integridade **SHA-256**.
   - Pré-visualização com detecção de diferenças antes de confirmar a restauração.
   - Restauração idempotente baseada em chaves primárias UUID e timestamp de revisão.

5. **Links Oficiais para Publicações (`PublicationLinkResolver`)**:
   - Mapeamento direto verificado para o livro *Seja Feliz para Sempre!* nos idiomas Português (`pt`), Libras (`bzs`) e Ticuna (`tca`).
   - Deep links honestos: fallback seguro para página inicial da publicação ou jw.org quando a lição direta não for suportada na língua de sinais.

6. **Design e Acessibilidade Sob Luz Solar (`mobile-ux-accessibility`)**:
   - Contraste elevado (WCAG AAA para textos de dados e status).
   - Alvos de toque amplos (mínimo de 48dp).
   - Layout responsivo adaptativo: `NavigationBar` ergonômica para iPhone XR (414x896) e `NavigationRail` lateral para iPad / Desktop (larguras ≥ 768px).

---

## 📁 Estrutura de Diretórios e Documentação

```
docs/
  ├── ARCHITECTURE.md           # Visão geral de arquitetura e camadas
  ├── DATA_MODEL.md             # Esquema das tabelas e regras de contagem
  ├── SYNC_PROTOCOL.md          # Protocolo da fila de sincronização e merge
  ├── SECURITY.md               # Políticas RLS, telemetria zero e privacidade
  ├── JW_LIBRARY_LINKS.md       # Catálogo e limitações de deep links
  ├── TEST_PLAN.md              # Matriz completa de casos de teste
  └── DECISIONS.md              # ADRs (Architectural Decision Records 001 a 005)
lib/
  ├── core/                     # Tema acessível, utilitários de data e gerador demo
  ├── database/                 # Drift tables, repositório transacional e conexões
  ├── appointments/             # Motor de disponibilidade e colisão de agenda
  ├── dashboard/                # Regras de contagem e inteligência de pendências
  ├── publications/             # Catálogo de publicações e resolvedor de links
  ├── settings/                 # Backup criptografado e exportação/importação
  ├── sync/                     # Motor de merge e detecção de conflitos
  └── ui/                       # Telas (Hoje, Pessoas, Agenda, Estudos, Dashboard, Ajustes)
test/                           # Suíte automatizada com 25 testes cobrindo todos os módulos
```

---

## 🚀 Como Executar o Projeto Localmente

### Pré-requisitos
- **Flutter SDK**: Versão 3.27+ (estável) instalado.
- **Dart SDK**: 3.5+ incluído no Flutter.
- **Google Chrome** ou **Microsoft Edge** para testes em Web.

### 1. Instalação das Dependências
```bash
flutter pub get
```

### 2. Geração de Código do Banco Drift
Caso altere alguma tabela ou query:
```bash
dart run build_runner build --force-jit --delete-conflicting-outputs
```

### 3. Execução no Navegador (Web)
```bash
flutter run -d chrome
```

### 4. Execução no Desktop (Windows)
```bash
flutter run -d windows
```

### 5. Compilação para Produção (Web Release)
```bash
flutter build web --release
```

---

## 🧪 Suíte de Testes Automatizados

Para executar todos os 25 testes de aceitação unitários e de interface:
```bash
flutter test
```

Para validar a integridade estática do código (zero erros e zero warnings):
```bash
dart analyze lib test
```

### Cobertura de Testes
- `test/counting_rules_test.dart` (TC-COUNT-01 a 05): Regras de contagem de estudos, sessões e contatos.
- `test/availability_engine_test.dart` (TC-SCHED-01 a 05): Detecção de sobreposição, contenção e intervalos.
- `test/publication_link_resolver_test.dart` (TC-PUB-01 a 03): Resolução de links em Português, Libras e fallback.
- `test/repository_database_test.dart`: Transações atômicas com `SyncQueue`, busca offline e soft-delete.
- `test/sync_engine_test.dart` (TC-SYNC-01 a 03): Mesclagem em campos distintos, conflitos e idempotência.
- `test/backup_service_test.dart` (TC-BAK-01 a 03): AES-256 GCM, senha incorreta e idempotência de restauração.
- `test/widget_test.dart`: Navegação responsiva iPad (`NavigationRail`) e iPhone XR (`NavigationBar`), sem vazamentos de layout.

---

## 🎮 Modo de Demonstração (Demo Offline)

Para experimentar o aplicativo imediatamente sem necessidade de criar contas ou conectar ao backend:
1. Abra a tela **Hoje** ou **Ajustes**.
2. Clique no card **Carregar Dados de Demonstração**.
3. O sistema gerará pessoas com diferentes situações (Interessados, Revisitas, Estudos), compromissos do dia, sessões de estudo em andamento e histórico de visitas.
4. Todos os dados fictícios ficam isolados no banco local e podem ser removidos a qualquer momento.
