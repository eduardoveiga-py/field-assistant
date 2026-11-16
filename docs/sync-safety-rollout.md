# Implantação e validação da sincronização

Esta branch exige a migração `20261113173516_sync_compare_and_swap.sql` para
inserções/atualizações. O cliente chama `sync_upsert_if_unchanged` com a linha
exata lida no servidor; se a função não existir ou falhar, mantém a operação na
fila e **não** usa upsert direto. Não publicar este cliente antes de validar e
aplicar a migração no projeto de destino. Esta migração não desabilita clientes
legados nem suas permissões de escrita; a proteção de concorrência exige uma
estratégia de atualização/bloqueio dos clientes antigos.

A consolidação automática se limita a cadeias INSERT/UPDATE completas, com
revisões e bases coerentes e nenhuma tentativa anterior. Pendências ambíguas,
DELETE/HARD_DELETE, conflitos ou tentativas anteriores continuam bloqueadas;
não descarte a fila para resolver esses casos.

Teste SQL isolado (não usa Supabase): instale `@electric-sql/pglite@0.5.16` fora do
repositório e execute `PGLITE_MODULE=file:///caminho/para/node_modules/@electric-sql/pglite/dist/index.js node test/sql/sync_compare_and_swap_test.mjs`.
Ele cobre inserção, atualização, corrida, colisão de ID e isolamento por RLS
em um esquema mínimo; não substitui testes contra o esquema real, Storage,
migrações anteriores, ou clientes concorrentes em dispositivos.

Antes de publicar, execute `flutter analyze` e `flutter test`, teste contas e
dispositivos isolados, reconciliação e retomada depois de interrupções. A
exclusão definitiva e os arquivos em Storage precisam de validação própria;
não são garantidos apenas pela comparação atômica de INSERT/UPDATE.

O IMAP lista os UIDs de toda a INBOX e salva páginas de forma incremental,
reconsultando os UIDs ausentes após interrupção. O MIME bruto é preservado no
SQLite, mas ainda não há interface para extrair anexos ou exportar o MIME
original binário. A sincronização é limitada à INBOX, não a outras pastas.
A identidade inclui conta e UIDVALIDITY; importações legadas podem duplicar.
Execute os testes e valide com um servidor IMAP real antes de publicar.

Para Auth, configure URLs de produção e allowlist somente depois de validar os
destinos de confirmação/recuperação e os callbacks nas plataformas suportadas.
Não pressupor que um scheme cadastrado apenas no iOS trate Android ou Web.

## Estado remoto após implantação controlada

No projeto `field-assistant`, em 2026-11-13 foi instalada a função CAS por
migração `sync_compare_and_swap` e, em seguida, `sync_cas_revoke_anon` removeu
um privilégio explícito de execução concedido por padrão ao papel anon. A
verificação posterior confirmou SECURITY INVOKER, execução por authenticated e
negação de execução por anon. As 26 tabelas esperadas existiam com RLS, ID único,
owner_id UUID, revision e updated_at. Um teste remoto usando conta existente e
registro temporário em subtransação com rollback confirmou insert, update e
rejeição de alteração obsoleta; após o teste não restaram registros temporários.
Não houve alteração de Auth, templates, tabelas, políticas ou dados persistentes.

Isso não valida todos os campos/tabelas ou sincronização entre dispositivos,
Storage, exclusões e retomada; tampouco impede clientes legados de escrever.
As versões de histórico criadas pelo conector são geradas remotamente e não
correspondem necessariamente aos prefixos de arquivo locais; reconciliar o
histórico antes de executar um push de todas as migrações do repositório.
A versão local SQLite permanece na versão 8: CAS não exige nova coluna. Não
incremente a versão sem migração de dados necessária e testes de upgrade.

### Proteção adicional contra perda silenciosa de campos

A migração remota `20261113175529_sync_reject_unknown_columns` faz a RPC
recusar payloads com colunas inexistentes em vez de ignorá-las. Isso preserva
alterações pendentes, mas pode impedir a sincronização de entidades com schema
remoto divergente até sua correção; não significa que as 26 entidades foram
validadas ponta a ponta. Teste autenticado com rollback no projeto passou para
inserção, rejeição de coluna desconhecida sem alterar o registro, atualização
condicional e rejeição de atualização obsoleta. `people` e
`territory_landmarks` possuem as colunas de coordenadas e demais campos Drift
checados. Nenhum dado de teste foi persistido.

As três migrações CAS locais usam agora os mesmos prefixos registrados no
histórico remoto (`20261113173516`, `20261113173528`, `20261113175529`). As
migrações **anteriores** ainda diferem entre repositório e projeto; não executar
`supabase db push` indiscriminadamente: comparar conteúdo e histórico primeiro.

## Salvaguardas de exclusão e mídia nesta branch

A exclusão lógica exige base, revisão e timestamp compatíveis, e usa a mesma RPC
CAS para verificar a linha inteira no instante do UPDATE. Não remove arquivos de
Storage ao enviar para a lixeira. Comparação de timestamp considera segundos por
causa da precisão do SQLite legado; clientes que não incrementam revision ainda
não são protegidos integralmente contra alterações no mesmo segundo.

Exclusões definitivas legadas não contêm a base necessária para comprovar o que
seria apagado, e a exclusão de arquivo e banco não é transação única. Por isso,
a exclusão remota definitiva é deliberadamente suspensa como conflito, sem
remover registro ou binário. A exclusão local já solicitada ainda ocorre; a
remoção remota e dependentes exigem protocolo durável e resolução. Não confundir
esta salvaguarda com uma implementação completa da exclusão definitiva.
Arquivos locais de áudio, foto ou documento que deveriam ser enviados mas estão
ausentes ou vazios passam a gerar erro e manter a operação sem confirmação.
Fila em backoff, não configurada ou com operações não resolvidas não deve ser
apresentada como totalmente sincronizada.
