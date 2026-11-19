# FA-REGIONAL-MAPS-STAGING — Avaliação de impacto e plano

Base: `ad89765a33b568f809183507a104b874aff0066e`; branch de trabalho `arena/075f07a0-field-assistant`.

## Problema e jornada

O proprietário solicitou mapas e roteamento não restritos a uma região, pacote real verificável e testes Supabase no Windows em ambiente **isolado**. A homologação física Apple será feita pelo proprietário após a etapa de código e uma futura release. Nenhuma release está autorizada nesta etapa.

A jornada atual é mapa de contatos → rota offline → `_showOfflineRouteDialog`, que cria uma rede demonstrativa de nove nós e escolhe sempre os nós mais próximos, sem limite de distância. Isso pode apresentar trajeto fictício em qualquer lugar, inclusive fora da região. O adaptador declara `supportsOfflineRouting: false`. O catálogo vetorial apresenta URL/tamanho/hash não comprovados; `tool/map/build_alto_solimoes_vector.sh` gera um cabeçalho sintético quando faltam ferramentas. O gerenciador também precisa de auditoria sobre revalidação em disco, retomada, substituição e rollback. Esses itens não são homologação operacional.

Supabase: o único projeto remoto identificado está ativo e é o projeto existente; o usuário escolheu staging isolado. O `supabase/config.toml` descreve stack local e a sync depende de `ENABLE_E2EE_SYNC`. Antes de ativar testes, é necessário conferir as migrações locais e isolar conta/dados. No fluxo atual do diálogo E2EE, uma falha ou conflito de criação remota pode ser ignorado e uma chave de conta copiada para `local_user`; isso pode produzir confirmação falsa ou sobrescrever chave. Isso é um bloqueador, não será contornado ativando sync.

## Componentes, dados e limites de confiança

- UI: `contacts_map_screen.dart`, visualizador vetorial, gerência de pacotes, diálogo E2EE e configurações.
- Domínio: `offline_routing_engine.dart`, grafo OSM e perfis de transporte; inventário/manifesto `offline_map_catalog.dart` e gerenciador `packages/offline_map_package_manager.dart`.
- Dados: arquivos PMTiles/MBTiles e um grafo associado à região; Drift local e fila persistente; Supabase Auth/RLS, RPCs cifradas, Storage e credenciais no armazenamento seguro.
- Rede: downloads HTTPS de pacote pré-gerado autorizado; nada de pré-buscar tiles OSM públicos. Dados de produção e segredos não devem ser copiados para staging.
- Plataformas: Windows para testes locais, iOS/iPadOS como objetivo posterior, Android/Web preservados. Pacotes de outras regiões continuam possíveis.

## Desenho e alternativas

1. Remover a apresentação de rota demonstrativa como rota utilizável até haver grafo real e verificado; nunca aproximar automaticamente uma origem/destino distante. Preservar a API A* demonstrativa somente em testes e rotulá-la. Caminho futuro: pacotes de grafo independentes da região, com metadados de cobertura, origem, licença e checksum, e integração por capacidade. Alternativa de adaptar manualmente os nove nós é rejeitada: não representa rede real e pode criar travessias inexistentes. OSM tem direção, acesso e restrições de conversão que não podem ser inferidas de uma linha simples.
2. Gerador vetorial deve falhar fechado sem dependências ou sem dados, aceitar entrada e bbox parametrizáveis, validar resultado e produzir manifesto a partir do arquivo real. Não anunciar no catálogo um artefato não publicado/verificado. Alternativa rejeitada: emular PMTiles com cabeçalho e zeros.
3. Supabase local isolado com Docker/CLI e conta fictícia; não executar `db push` ou reset no projeto remoto. `ENABLE_E2EE_SYNC` é opt-in para testes; falhas de validação, ausência de cofre ou alteração de conta devem bloquear, nunca usar legado em claro. Revisar criação/confirmação/recuperação antes de permitir sincronização de teste.

## Pesquisa

- Especificação PMTiles v3: https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md — cabeçalho, diretórios, metadados e tipos de tile; verificação de assinatura isolada é insuficiente. Especificação usada como referência, não código copiado; conferir licença de qualquer ferramenta distribuída.
- Tippecanoe: https://github.com/felt/tippecanoe — `-L layer:file` por camada e saída PMTiles; verificar versão/licença e decodificação de amostras. Nenhum código copiado.
- Restrições OSM: https://wiki.openstreetmap.org/wiki/Restrictions e https://wiki.openstreetmap.org/wiki/Relation:restriction — uma rede roteável precisa tratar acesso, direção e restrições de conversão. Dados OSM sujeitos a ODbL e atribuição.
- Supabase local: https://supabase.com/docs/guides/local-development/overview — CLI/Docker, servidor local e credenciais locais; chave service-role nunca entra no cliente.

## Testes, compatibilidade e recuperação

- Testes reproduzíveis: falha sem ferramentas, pacotes sintéticos rejeitados, manifests, múltiplas regiões; ausência de grafo e nós distantes nunca produzem rota; preservação dos pacotes instalados e dados locais. Quando disponíveis, gerar e inspecionar PMTiles com dados reais e comparar metadados/tiles.
- Staging: testar políticas/RPCs com dois usuários e dispositivos simulados, concorrência, retomada, arquivos, conta diferente, cofre preexistente, indisponibilidade de rede e recuperação. Nunca usar chave `service_role` no app nem dados reais.
- Flutter/analyzer/testes e builds via CI quando SDK indisponível; testes de hardware não realizados serão registrados como pendentes. Compilação não é prova de runtime.
- Rollback: restaurar mudanças da branch por commit revertido após revisão, sem remover dados/pacotes existentes; não aplicar migrações remotas nesta etapa.

## Riscos e não-verificados

Cobertura e licenças dependem do conjunto de dados realmente gerado; navegação nunca é garantia de segurança. Snapshot/backup antigo pode reverter checkpoints. O backend local completo e os plugins do Windows precisam ser executados no ambiente do proprietário. Regras OSM de conversão e restrições condicionais não estão implementadas no grafo demonstrativo. Não aprovar uma release ou pontuação de certificação até que os gates de engenharia e operação sejam realmente atendidos.

## Aprovação e checkpoint de contenção

O proprietário aprovou a contenção temporária, antes da implementação completa. O catálogo vetorial fica vazio até existir arquivo publicado, verificado e com procedência; o script vetorial falha antes de gravar qualquer arquivo. A UI não calcula rotas com o grafo demonstrativo. Pacotes e dados existentes não são apagados deliberadamente. O reconhecimento de pacotes em disco passa a exigir checksum, embora checksum e cabeçalho não comprovem conteúdo de mapa válido.

No cofre, a UI conserva a frase que exibiu antes de iniciar criação remota; conflito ou erro impedem instalação. Erro de resposta ambígua pode significar que o servidor criou o cofre: a frase anotada deve ser usada para restaurá-lo, não gerar outra. Não há cópia automática para `local_user`, a migração local está suspensa, e a sync verifica o marcador com a chave da conta antes de operar. Essa verificação não impede supressão ou rollback pelo servidor. A flag de staging não é uma garantia técnica de isolamento do projeto: não habilitar no projeto existente.

O app não tem grafo real, construtor vetorial validado ou staging comprovado neste checkpoint. As alterações ainda exigem análise e execução de testes Dart, revisão independente de segurança e homologação; os testes em memória não são prova de E2EE ponta a ponta nem de políticas RLS. O retorno de `setupNewVault` para conta remota foi bloqueado: seus chamadores devem exibir uma frase antes de chamar `setupVaultWithPhrase`, evitando perda da frase se a resposta remota for incerta. Em modo local uma frase de recuperação não é aceita sem uma chave local prévia que permita verificar sua identidade.

### Validação local isolada proposta

A pipeline `.github/workflows/supabase-local-validation.yml` usa PostgreSQL/Supabase efêmero no runner GitHub, sem link de projeto, segredos remotos, `db push` ou dados reais; executa `supabase db start` e `supabase test db --local`. O seed versionado não inclui usuários ou dados pessoais. A CLI é fixada em `supabase@3.2.0` (pacote npm, licença MIT; integridade npm SHA-512 `7+g9yRNdTtldpuHAfL4V66HDtFqsEUwlHg6LcQvd7rEEXBFuQmC3uny9hGoxdT4WzmHLgMjB/XaQcNpLnuHSVw==`, consultado no registry); as imagens do stack ainda precisam de auditoria de reprodução/supply chain. Referência: https://supabase.com/docs/guides/deployment/ci/testing e https://supabase.com/docs/reference/cli/supabase-test-db. A passagem de pgTAP, se ocorrer, não substitui autenticação real de ponta a ponta, Storage binário e dois dispositivos.

## Continuação — versionamento e dependências (antes de alterações)

O SHA `e4a1f13` falha no gate de versão: aplicativo e `pubspec` declaram 2.0.0+14, mas `apps.json` aponta para v1.3.6, inexistente; testes fixam 1.3.6+13. O branch de desenvolvimento não é uma release. GitHub API informa v1.3.5 como pré-release existente contendo `app-release-unsigned.ipa` (14998563 bytes) e v1.3.3 como última estável com `apps.json`. Nenhuma nova release será criada. O atualizador tenta URL fixa da versão em desenvolvimento não publicada e depois um manifesto mutável em `@master`, o que pode anunciar artefatos inexistentes. A alternativa de colocar 2.0.0 no manifesto antecipadamente é rejeitada: criaria uma promessa de release falsa.

Desenho: separar versão do binário em desenvolvimento da versão do catálogo de distribuição existente; preservar metadados históricos válidos, remover referências à v1.3.6 inexistente, não anunciar um release antes de seu artefato existir. O atualizador deve usar a API e o manifesto da última release estável, e falhar de forma explícita se fontes confiáveis faltarem, sem fallback `@master` nem pin fictício v2.0.0. O gate exige `pubspec` igual à versão compilada em todas as branches e igualdade com o manifesto e a tag em uma publicação; o manifesto em branch deve ser internamente coerente e apontar para uma versão de release anterior ou igual, não necessariamente ao build de trabalho. Testes devem verificar estes invariantes e casos de indisponibilidade, em vez de hardcode de 1.3.6.

O lockfile atual fixa `test_api 0.7.12`, enquanto `flutter_test` do Flutter `stable` consultado no GitHub fixa `0.7.14`; Flutter tag `3.47.8` fixa `0.7.12`. Compatibilidade do SDK inteiro com `pubspec` e todos os hashes ainda não está comprovada. Investigar com testes CI antes de fixar versão; não alterar lockfile manualmente nem remover o gate estrito. Para reproduzir lockfile deve-se usar resolver pub do SDK escolhido e conferir sem diferenças. Fontes: https://github.com/flutter/flutter/blob/3.47.8/packages/flutter_test/pubspec.yaml e https://github.com/flutter/flutter/blob/stable/packages/flutter_test/pubspec.yaml. As URLs descrevem requisitos do framework; nenhum código foi copiado.

Rollback: reverter código/versionamento em commit separado após revisão; não trocar ou publicar artefatos de release existentes. Testes: análise/testes Flutter, falha de fontes de atualização, consistência de manifestos no CI, release guard com tag fictícia apenas em teste de lógica, nunca criar tag real.
