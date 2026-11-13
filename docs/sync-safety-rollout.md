# Implantação e validação da sincronização

Esta branch exige a migração `20261113000000_sync_compare_and_swap.sql` para
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
