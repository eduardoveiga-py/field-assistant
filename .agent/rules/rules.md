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

## 9. Provedores de Mapas e Cache de Tiles (Resiliência Offline e Livre de Chaves)
- NUNCA aponte tiles primários ou fallbacks para provedores proprietários que exijam chaves de API restritas (como CARTO sem chave, Mapbox ou Stadia sem cota pública permanente) sem autenticação formal, pois provedores como a CARTO retornam HTTP 200 com marcas d'água de erro embutidas no PNG.
- O OpenStreetMap oficial (`https://tile.openstreetmap.org/`) é o provedor primário obrigatório, com OpenStreetMap France (`https://a.tile.openstreetmap.fr/osmfr/`) como fallback de contingência verificado.
- O cache de tiles nativo e web deve implementar auto-cura: rejeitar e expurgar do disco arquivos de 2049, 2513 ou 6725 bytes, arquivos vazios (0 bytes) e respostas com ETag de marca d'água (`wm-`).
- A concorrência máxima de download para o OpenStreetMap deve respeitar estritamente o limite de 2 conexões simultâneas da Tile Usage Policy do OSM.

## 10. Modais e Diálogos Adaptativos (Responsividade iPad / Tablet / Web)
- NUNCA utilize `DraggableScrollableSheet` ou `showModalBottomSheet(isScrollControlled: true)` sem definir limites estritos de altura (`maxHeight: 0.85 * viewportHeight`) em telas grandes.
- Em dispositivos com largura superior a 600pt (iPads, tablets e desktop), modais informativos e de seleção DEVEM ser renderizados como `Dialog` centralizado com `maxWidth: 720`, cantos totalmente arredondados (`BorderRadius.circular(24)`) e botão explícito de fechamento.

## 11. Arquitetura Extensível de Múltiplos Idiomas no Drift
- NUNCA engesse tabelas ou interfaces linguísticas a um único idioma através de SQL cru ou constantes fixas.
- O catálogo de idiomas deve ser persistido na tabela Drift `AppLanguages`, com o Ticuna (`tca`) configurado como padrão (`is_default = true`).
- A inclusão de novas línguas indígenas pelo publicador deve ser 100% dinâmica em tempo de execução, associando vocabulário, frases e áudios ao respectivo `language_id`.

## 12. Motor de Mapas de Alta Performance e Conformidade Offline
- NUNCA implemente download de cidades ou estados inteiros via scraping direto de imagens individuais do servidor OpenStreetMap oficial, pois isso viola a Tile Usage Policy e resulta em banimento por IP (HTTP 403).
- O download regional deve ser estruturado em pacotes consolidados `.mbtiles` (SQLite) servidos por CDN/Releases.
- O motor de renderização cartográfica deve manter interpolação contínua de resolução (eliminando flickering de tela no zoom), rotação tridimensional livre com 2 dedos, agulha de bússola com retorno ao Norte magnético e barra de escala métrica dinâmica.

