# 📜 Histórico de Lançamentos e Notas de Atualização (Changelog)

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
