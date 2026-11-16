# Revisão dos mapas e uso offline

## Escopo e limites

Revisão estática do código, testes existentes e disponibilidade do release público.
Não foram executados Flutter, simuladores, testes com o app, dispositivos ou
servidores reais de mapas. Os achados abaixo distinguem comportamento explícito
no código de riscos que precisam de reprodução em dispositivos. A versão que
está no iPhone pode não corresponder às alterações locais desta branch.

## Achados prioritários

1. **Coordenadas podem ser salvas para o ponto anterior.** Ao tocar no mapa de
   seleção, a coordenada selecionada muda, mas `_geocodedResult` não é limpo;
   ao confirmar, ele tem prioridade sobre a coordenada mais recente. Uma resposta
   de rede antiga também pode chegar após outra mais nova. O resultado devolvido
   pode apontar para outro lugar (`lib/ui/widgets/map_location_picker_dialog.dart`,
   `_fetchAddressForCoords`, `onTapUp`, botão de confirmação). A correção precisa
   sempre retornar as coordenadas atuais, associar endereço à requisição e testar
   respostas fora de ordem e confirmação enquanto a busca está pendente.
2. **Download regional padrão indisponível.** O catálogo usa a release
   `mbtiles-v1` no GitHub (`lib/territory/mbtiles/mbtiles_service.dart`). A API do
   GitHub retornou 404 para essa release durante esta revisão; não há indicação de
   mapas padrão prontos para download. Uma URL personalizada ou importação
   local pode ser usada, desde que o arquivo seja compatível e licenciado.
3. **Pré-download de setor não é adequado ao servidor OSM público.**
   `sector_detail_screen.dart` solicita uma janela 9x9 em cinco zooms usando
   `preloadArea`; para o estilo padrão o backend consulta `tile.openstreetmap.org`.
   A política da OSM proíbe pré-busca e downloads de regiões nesse serviço,
   mesmo com poucas conexões: https://operations.osmfoundation.org/policies/tiles/.
   Não usar o botão para baixar áreas desse servidor; adotar pacotes de fonte ou
   provedor que permita o uso offline. O fallback OSM France tem política própria
   que precisa ser verificada; não presumir permissão.
4. **Download de setor pode cobrir a cidade errada ou indicar sucesso falso.**
   O geocodificador busca o setor em Santo Antônio do Içá e, se falhar, usa a
   coordenada fixa dessa cidade. Além disso, se zero blocos forem obtidos, a UI
   afirma que a área já está em cache, embora possam ter falhado todos os pedidos.
   `saveTile` captura falha de gravação, e o chamador conta bytes recebidos como
   salvos. O tamanho fixo em blocos abrange áreas geográficas diferentes em
   cada zoom e não prova cobertura completa do setor.
5. **Fallback visual pode posicionar ruas de forma incorreta.**
   `TileCacheService.getFallbackFromMemory` devolve o bloco pai inteiro; o widget
   o exibe como se fosse o bloco filho, sem recortar o quadrante correto. Durante
   o carregamento pode haver ruas duplicadas/deslocadas em relação aos pinos.
   Na ausência do bloco exato, `_loadTile` também substitui o fallback por null.
6. **Alguns pacotes podem parecer instalados, mas não renderizar corretamente.**
   A validação de MBTiles confere cabeçalho SQLite e colunas, não formato raster,
   conteúdo, cobertura, integridade ou níveis de zoom. Pacotes vetoriais não são
   renderizados pelo widget `Image.memory`. A leitura tenta TMS e depois XYZ sem
   saber o esquema do pacote: se o tile TMS não existir, o fallback pode buscar
   uma linha de outra latitude (`mbtiles_native.dart`, `getTile`).
7. **Risco na atualização dos pacotes e início.** A instalação apaga o arquivo
   antigo antes de renomear o novo; se a renomeação falhar ou o processo parar
   nesse intervalo, o pacote anterior é perdido. Na inicialização, o backend
   marca `_initialized` antes das operações assíncronas; buscas de tiles podem
   ocorrer antes de abrir os arquivos, sem uma atualização explícita dos widgets.
   A substituição e a inicialização exigem testes e implementação robusta.
8. **Orientação de posição não é bússola.** O mapa desenha um cone fixo no ponto
   azul; o código não consulta rumo da pessoa ou sensor magnético. O controle
   chamado `Norte Magnético` só mostra/controla rotação manual. A posição é obtida
   sob demanda, não acompanhada continuamente. Uma posição antiga obtida no
   timeout é apresentada como sucesso sem idade/precisão. No gesto, a rotação
   acumulada é somada em cada atualização e o cálculo de toque longo não aplica
   uma transformação inversa da rotação: essas interações precisam de testes.
9. **Rotas são externas e não são calculadas offline neste app.** Uma seleção
   individual abre pesquisa no Google Maps; a rota múltipla envia destinos ao
   Google Maps. O app limita a lista a 10 e descarta pontos além de 60 km com
   aviso; não executa otimização de ordem, apesar da mensagem dizer 'otimizada'.
   O funcionamento offline depende do app externo e dos dados dele. O envio
   expõe os destinos ao provedor escolhido.
10. **Geocodificação não é offline.** `GeocodingService` envia endereços ou
    coordenadas ao Nominatim. No contato destacado ele pode gravar automaticamente
    o primeiro resultado, que pode ser impreciso; há risco de sobrescrever dados
    alterados durante a chamada porque usa um objeto previamente capturado.
    A busca precisa de transparência/consentimento adequados, validação, limites
    e tratamento de falhas; política: https://operations.osmfoundation.org/policies/nominatim/.

## Outras observações

- MBTiles só é consultado na camada padrão. Satélite, relevo e noturno dependem
  dos blocos daquela camada já obtidos ou de rede; verificar licença e atribuição
  de cada provedor.
- O cache em disco é persistente no diretório de documentos nativo, mas não há
  comprovação de cobertura completa. A detecção de erro por tamanhos fixos pode
  rejeitar imagens válidas do mesmo tamanho. Não depender disso para segurança.
- O mapa usa grade fixa 7x7 e reprojeção/gestos próprios; tela grande, arraste,
  rotação, escala e seleção exigem testes de precisão. Um mecanismo maduro como
  `flutter_map` com suporte a raster MBTiles é candidato a avaliação, não uma
  solução automática para dados, licenças, navegação ou offline.
- A localização depende de permissões, equipamento e sinal. iPads somente Wi-Fi
  podem não ter receptor GNSS; não assumir disponibilidade/precisão offline.
- Existem testes de cache e pacotes com HTTP mock e SQLite mínimo e alguns testes
  de gestos, mas não foram executados nesta sessão; não comprovam o fluxo real de
  download, aparência geográfica ou navegação em modo avião.

## Sequência recomendada

1. Corrigir seleção e atualização de coordenadas, respostas concorrentes e sinais
   enganosos de orientação; testar seleção com e sem rede.
2. Desativar pré-download no servidor OSM público e eliminar mensagens de sucesso
   falso. Definir fornecedor de pacotes compatíveis com licenças e cobertura real.
3. Garantir validação raster/cobertura/zoom, inicialização e atualização segura
   dos pacotes; verificar armazenamento, importação, cancelamento e versão.
4. Avaliar motor de visualização mantido e testar pan, zoom, rotação, projeção,
   seleção, mudança de camada e dispositivos. Não migrar sem prova de conceito.
5. Decidir se rotas offline são requisito ou se será oferecida integração com um
   app externo, esclarecendo dependências e privacidade.
6. Testar em iPhone/iPad, incluindo LiveContainer/SideStore, e Windows: instalar
   um pacote legítimo, encerrar o app, desligar internet, reiniciar, ver ruas e
   pinos em vários zooms, cadastrar/editar ponto, testar GPS, ausência de pacote,
   espaço cheio, atualização interrompida e sincronização ao reconectar.

## Alterações locais posteriores à revisão

Os achados acima registram a situação anterior às correções, não uma descrição
atualizada de cada trecho. A branch passa a exigir seleção de ponto, descarta
respostas reversas antigas, deixa de mostrar tiles ancestrais inteiros e cone de
rumo fictício, e protege geocodificação de edição concorrente. O pré-download de
área foi bloqueado; o botão do setor direciona à gestão de pacotes. A leitura
MBTiles usa TMS por padrão ou XYZ declarado em metadata; importa apenas amostra
com assinatura raster e tenta preservar o arquivo anterior na troca. Isso **não**
valida imagens inteiras, todos os tiles, cobertura, zooms, integridade ou licenças.
A disponibilidade do catálogo padrão continua não resolvida. A geocodificação
por endereço continua online e pode fornecer posição aproximada automaticamente;
ela ainda precisa de confirmação do usuário antes de ser considerada exata.

As mudanças locais e testes adicionais não foram executados com Flutter nem em
aparelhos. Validar em iPhone/iPad e Windows com pacote obtido de fonte autorizada,
conexão desativada, zooms e limites da área, reabertura do app, substituição do
pacote, precisão dos pinos, seleção, arraste, rotação e dispositivos GPS reais.

## Área prioritária informada pelo usuário

Oeste do Amazonas, com prioridade para o Alto Solimões, Santo Antônio do Içá e
aldeias/comunidades ribeirinhas. O nome já existente no catálogo é apenas um
rótulo: **não comprova que exista um pacote ou sua cobertura**. O limite exato e
as comunidades atendidas precisam ser definidos com conhecimento local, sem
publicar localizações sensíveis ou dados de contatos sem autorização.

Caminho a investigar: dados do Amazonas em formato OSM PBF, por exemplo o
[extrato da OSM France](https://download.openstreetmap.fr/extracts/south-america/brazil/north/),
para renderização própria a partir de dados armazenados localmente; PBF não é o
MBTiles raster que o app importa. A ferramenta do QGIS
[gera MBTiles raster](https://github.com/qgis/QGIS-Documentation/blob/master/docs/user_manual/processing_algs/qgis/rastertools.rst),
mas estilos e fontes dos dados devem ser adequados e licenciados. Outra opção é
[encomendar pacotes raster da Geofabrik](https://www.geofabrik.de/maps/tile-packages.html),
sujeito a orçamento, licença e confirmação de cobertura. Não extrair imagens em
massa do servidor público de tiles da OSM. Nenhuma opção foi instalada ou testada.

Planejar nível regional para orientação e áreas menores em detalhe; selecionar
zooms e limites a partir de dados reais e espaço disponível. Conferir rios,
canais e comunidades com usuários locais, registrar a data da base e testar sem
rede. O mapa e os pontos são referências; não presumir navegabilidade ou
segurança de deslocamento a partir da cartografia.

## Pacote experimental de SAI gerado

O pipeline `Build experimental SAI offline map`, execução 43474748369, produziu
um arquivo raster de dados OSM do Amazonas. A área é o retângulo de longitude
-69,95 a -67,65 e latitude -3,85 a -2,32, que abrange os limites consultados
para o município e partes vizinhas; o extrato pode não conter dados de outras
regiões ou países. Contém zoom 8 a 16, sem zoom 17 a 19. Os dados pessoais de
contatos não são incorporados. Atribuição e informações de origem acompanham o
arquivo. O artefato é temporário (retenção de 14 dias):
https://github.com/eduardoveiga-py/field-assistant/actions/runs/43474748369

A execução 43477013593 verificou a integridade SQLite, todos os blocos no
retângulo em cada zoom e a importação e decodificação, pelo backend Flutter real,
dos blocos da sede em zoom 8, 12 e 16. Isso não verifica a qualidade visual ou
completude da base, a precisão de cada comunidade, nem testa aparelho ou modo
avião. Necessária revisão por usuário local e testes no iPhone/iPad e Windows.
O catálogo automático ainda não aponta para esse artefato temporário; por enquanto
é preciso baixar o ZIP, extrair o .mbtiles e importá-lo no app em camada padrão.

## Preparação posterior da distribuição

Nesta branch o catálogo identifica o pacote como **SAI e entorno experimental**,
zooms 8–16, e direciona para um arquivo `.mbtiles` da própria versão do app.
O pipeline preparado para uma futura tag deve gerar novamente o pacote a partir
dos dados brutos OSM, conferir o retângulo, anexar MBTiles, proveniência e SHA-256
à release. Não existe esse endereço de versão até a publicação realmente ocorrer;
o pacote temporário indicado acima continua sendo a alternativa de teste manual.

Uma busca automática por endereço não grava mais coordenadas por conta própria:
a pessoa pode dispensar a sugestão ou revisar o ponto no mapa e confirmá-lo. A
comparação do endereço e das coordenadas existentes protege edição concorrente.
Isso não verifica se o endereço geocodificado corresponde à casa correta; a
confirmação e os testes sem internet em aparelhos seguem indispensáveis.
