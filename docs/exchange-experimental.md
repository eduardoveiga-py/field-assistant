# Exchange ActiveSync experimental — leitura parcial

Esta implementação é uma primeira etapa, não um cliente Exchange completo nem
um backup da caixa. Usa o cliente Dart `eas_client` 0.1.0-alpha.3 vendorizado
em commit fixo, com testes simulados. Não foi testada contra o servidor do
usuário nem em iPhone/LiveContainer.

- Configuração separada de IMAP/SMTP; HTTPS e Basic (usuário/senha) somente.
  O usuário deve inserir o servidor oficial confiável. O cliente não segue
  redirecionamentos HTTP com credenciais; OAuth e descoberta não estão ativos.
- Apenas FolderSync e Sync da INBOX, com dados de até 256 KiB de corpo por
  mensagem; anexos/MIME completos não são recuperados. Os itens são marcados
  como prévias parciais. O cliente oficial permanece a fonte de verdade.
- Páginas de prévias e SyncKey são persistidos juntos; falhas mantêm os lotes
  anteriores e a chave da página anterior. A invalidação da chave inicia uma
  nova leitura sem remover prévias. Alterações parciais criam novas prévias;
  exclusões do servidor não são propagadas. Não há comandos de escrita ou de
  exclusão remota, e o envio é bloqueado quando Exchange está selecionado.
- O dispositivo tem ID persistido no armazenamento seguro local; a senha fica
  no Keychain/Keystore, não no banco ou em logs. Somente a configuração de
  servidor/usuário e as prévias entram no armazenamento local e no backup.
- Provisionamento, políticas corporativas, remote wipe, OAuth, envio, leitura
  de anexos, pastas adicionais, atualização fiel de mensagens e contatos e
  calendário **não estão implementados**. Se o servidor exigir política, o
  app falha sem declarar conformidade nem executar wipe. Consulte o
  administrador; não tente contornar as políticas.
- A API e a biblioteca estão em estágio alpha. Antes de uso operacional, testar
  numa conta de teste autorizada: versões e autenticação do servidor, política
  e bloqueios, paginação, resets/erros, respostas parciais, anexos, privacidade,
  retentativas e recuperação. Validar MIME, envio e políticas antes de prometer
  sincronização integral. Não substituir a caixa original nem apagar dados.
