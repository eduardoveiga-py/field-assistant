# Exchange ActiveSync experimental — leitura parcial

Esta implementação é uma primeira etapa, não um cliente Exchange completo nem
um backup da caixa. Usa o cliente Dart `eas_client` 0.1.0-alpha.3 vendorizado
em commit fixo, com testes simulados. Não foi testada contra o servidor do
usuário nem em iPhone/LiveContainer.

- Configuração separada de IMAP/SMTP; HTTPS e Basic (usuário/senha) somente.
  O usuário deve inserir o servidor oficial confiável. O cliente não segue
  redirecionamentos HTTP com credenciais; OAuth e descoberta não estão ativos.
- Sem filtro de idade no Sync (o protocolo pede todos os itens disponíveis, mas isso não garante que o servidor os entregue).
- FolderSync e Sync de pastas classificadas como correio pelo servidor, com até 256 KiB de corpo por mensagem. Os itens são prévias: anexos/MIME completos não são recuperados. O cliente oficial permanece a fonte de verdade; pastas de tipo desconhecido não são importadas.
- Páginas de prévias, operações da fila de sincronização e SyncKey são persistidos juntos; a fila de envio ao Supabase está pausada até a proteção ponta a ponta ficar pronta; a chegada em outro dispositivo ainda requer implementação e validação; falhas mantêm os lotes
  anteriores e a chave da página anterior. A invalidação da chave inicia uma
  nova leitura sem remover prévias. Alterações parciais criam novas prévias;
  exclusões do servidor não são propagadas. Não há comandos de escrita ou de
  exclusão remota, e o envio é bloqueado quando Exchange está selecionado.
- O dispositivo tem ID persistido no armazenamento seguro local; a senha fica
  no Keychain/Keystore, não no banco ou em logs. Somente a configuração de
  servidor/usuário e as prévias entram no armazenamento local e no backup.
- Provisionamento, políticas corporativas, remote wipe, OAuth, envio, leitura
  de anexos, atualização fiel de mensagens e contatos e
  calendário **não estão implementados**. Se o servidor exigir política, o
  app falha sem declarar conformidade nem executar wipe. Consulte o
  administrador; não tente contornar as políticas.
- A API e a biblioteca estão em estágio alpha. Antes de uso operacional, testar
  numa conta de teste autorizada: versões e autenticação do servidor, política
  e bloqueios, paginação, resets/erros, respostas parciais, anexos, privacidade,
  retentativas e recuperação. Validar MIME, envio e políticas antes de prometer
  sincronização integral. Não substituir a caixa original nem apagar dados.

Prévias importadas antes da inclusão na fila não são automaticamente reenfileiradas.
Nesta branch, o envio da fila pelo Supabase está pausado. Versões antigas ainda
podem enviar o conteúdo legível; isso não constitui criptografia ponta a ponta
nem prova de entrega ao outro aparelho.
Esta versão não implementa download de anexos, MIME integral nem um arquivo
permanente completo e não deve ser usada como único backup da conta.

As novas prévias com anexos preservam localmente metadados e referências EAS
para uma futura implementação de download, inclusive quando uma atualização
parcial não inclui anexos. Isso não baixa nem garante a disponibilidade dos
arquivos; referências antigas podem deixar de funcionar. Prévias já baixadas
sem referências não são preenchidas automaticamente. Nenhum anexo é incluído
no backup completo enquanto seu conteúdo não for efetivamente baixado.
