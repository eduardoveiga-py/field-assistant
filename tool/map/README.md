# Mapa experimental: Santo Antônio do Içá e entorno

Arquivo raster MBTiles gerado a partir do extrato de dados OpenStreetMap do
Amazonas distribuído por download.openstreetmap.fr; não foi extraído de tiles
online. Dados © contribuidores do OpenStreetMap, licenciados sob ODbL:
https://www.openstreetmap.org/copyright. As informações brutas e seu histórico
podem ser obtidos na fonte; o SHA-256 e os metadados do extrato acompanham o
pacote. O estilo é criado localmente com QGIS. Verifique os direitos das fontes
adicionais antes de alterar a receita.

Área retangular WGS84: oeste -69.95, sul -3.85, leste -67.65, norte -2.32;
engloba o município segundo uma referência de limites municipais IBGE e inclui
áreas vizinhas. Dados do extrato do Amazonas podem não cobrir áreas vizinhas em
outros estados ou países. Zoom 8 a 16. Nem toda aldeia, caminho, curso d'água ou
via pode estar mapeado; a atualização, completude e precisão não foram validadas
localmente. Não representa hidrovias navegáveis nem substitui orientação local.

Importe o arquivo .mbtiles no gerenciador de mapas offline do app, selecione a
camada padrão e teste em modo avião. Os pontos pessoais não estão neste pacote.
O aplicativo e o pacote requerem testes em iPhone/iPad e Windows. O pacote é
experimental e NÃO deve ser usado como única referência para deslocamento.

## Protótipo de grafo OSM (não é navegação)

`build_osm_graph_prototype.py` processa **localmente** um snapshot pequeno OSM
XML 0.6, opcionalmente gzip, e grava um JSON experimental exclusivo. Não aceita
PBF nem baixa dados. Exige SHA-256 do arquivo exato (compactado, quando gzip),
origem, licença e atribuição; não inclua credenciais ou informações pessoais na
origem, pois esses campos são gravados no JSON. Exemplo com dados fictícios:

```sh
python3 tool/map/build_osm_graph_prototype.py \
  --source exemplo.osm --source-sha256 "$(sha256sum exemplo.osm | cut -d' ' -f1)" \
  --source-description 'fixture sintético' --license 'dados fictícios' \
  --attribution 'fixture sintético' --output grafo-experimental.json
```

O arquivo de saída não é importado pelo app. A ferramenta rejeita diversas
restrições conhecidas que não implementa; isso **não garante** detecção de todas
as regras, cobertura, qualidade do extrato ou segurança de qualquer percurso.
Não habilita rotas nem substitui fonte atualizada, testes de acesso, manobras,
barreiras, travessias e homologação. Para dados reais, verifique direitos e
obrigações, incluindo https://www.openstreetmap.org/copyright e ODbL. Os limites
atuais de 16 MiB e formato XML servem apenas para experimentos pequenos.
