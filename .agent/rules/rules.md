# Regras Arquiteturais Mandatórias do Projeto: Ministério Pessoal

Este arquivo contém restrições estritas e instruções persistentes para todos os agentes de IA, desenvolvedores e mantenedores que operam neste repositório.

## 1. Persistência e Banco Local
- NUNCA substitua o banco de dados local Drift por armazenamento efêmero em memória, mapas estáticos ou arquivos simples de preferências para funcionamento geral.
- Toda gravação e leitura da UI deve obrigatoriamente passar pelas transações e repositórios locais do Drift SQLite / Drift Wasm.
- A persistência no navegador Web deve utilizar Drift Wasm com IndexedDB para garantir sobrevivência ao recarregar a página.

## 2. Integridade e Regras de Contagem
- NUNCA misture os conceitos de:
  1. Estudo Bíblico ativo (o acompanhamento contínuo).
  2. Participante (pessoa cadastrada associada ao estudo).
  3. Sessão de Estudo (a aula/ocorrência individual em determinada data).
  4. Revisita/Conversa (contato do ministério).
- Um estudo bíblico compartilhado com múltiplos participantes continua contando exatamente como **1 estudo**.
- Uma sessão realizada com múltiplos presentes conta exatamente como **1 sessão**.
- Sessões canceladas ou não realizadas **NÃO** contam como sessões realizadas.
- Revisitas agendadas **NÃO** contam como revisitas realizadas.
- Tentativas sem contato **NÃO** contam como conversas realizadas.
- NUNCA altere as regras de contagem sem atualizar concomitantemente a documentação (`docs/DATA_MODEL.md`) e os testes automatizados correspondentes.

## 3. Sincronização e Conflitos
- NUNCA introduza mecanismos de sincronização que apliquem "Last Write Wins" silencioso para anotações de conversas ou pessoas.
- Conflitos em campos incompatíveis devem reter ambas as versões e solicitar resolução pelo usuário.
- Históricos de visitas e sessões são entidades cronológicas imutáveis e não devem ser apagadas ou sobrescritas por atualizações de dados cadastrais.
- As operações de sincronização devem ser estritamente idempotentes.

## 4. Integração com JW Library
- NUNCA invente esquemas de URL privados ou URLs inexistentes para o JW Library ou jw.org.
- Deep links devem passar pelo `PublicationLinkResolver`.
- Se um deep link direto para lição ou parágrafo não for homologado ou suportado no idioma (ex: Libras), o sistema deve reportar a precisão real e fornecer fallback para o navegador oficial ou referência manual.

## 5. Testes e Engenharia
- NUNCA remova, comente ou enfraqueça testes existentes para forçar a aprovação de uma compilação.
- Se um teste falhar, o código de implementação deve ser corrigido para honrar o requisito.
- NUNCA introduza dependências de pacotes sem justificar a necessidade no commit/documentação.

## 6. Segurança e Credenciais
- NUNCA comite segredos, chaves de serviço Supabase (`service_role key`) ou senhas de usuários no repositório.
- Apenas chaves públicas de cliente (`anon key`) são permitidas em arquivos de exemplo de configuração.


## 7. Compatibilidade Multiplataforma e Web-Safe (kIsWeb)
- NUNCA acesse `Platform.environment`, `Platform.isIOS`, `Platform.isAndroid` ou qualquer API de `dart:io` sem antes proteger o fluxo com `if (!kIsWeb)`.
- No Flutter Web (Wasm/CanvasKit), o acesso a `Platform` lança imediatamente `Unsupported operation: _Namespace`, quebrando fluxos de gravação de áudio, câmera e banco.
- Em reprodutores de áudio (`AudioPlayer`) e gravadores (`AudioRecorder`), trate áudios na Web exclusivamente através de `UrlSource(blobUrl)` ou buffers em memória, reservando `DeviceFileSource` e caminhos de arquivo locais apenas para mobile nativo e desktop.

## 8. Tipografia e Diacríticos Complexos / Indígenas (Língua Ticuna)
- O suporte à língua Ticuna exige a correta exibição e persistência das 12 vogais canônicas com diacríticos empilhados (ex: `ĩ`, `ü̃`, `ü̃́`, `ũ`, `ã́`, `ẽ`, `Ĩ`, `Ü̃`, `Ü̃́`, `Ũ`, `Ã́`, `Ẽ`).
- NUNCA dependa exclusivamente das fontes padrão do sistema operacional para renderizar caracteres com múltiplos diacríticos combinantes.
- É obrigatório manter `fontFamilyFallback: TicunaUnicodeHelper.fontFallback` (com `Noto Sans` e `Charis SIL`) configurado no `AppTheme` e injetado no `web/index.html`.
- Ao salvar e recuperar termos e frases Ticuna no Drift/SQLite, garanta a normalização Unicode canônica (NFC/NFD) para evitar duplicatas e inconsistências de busca.
