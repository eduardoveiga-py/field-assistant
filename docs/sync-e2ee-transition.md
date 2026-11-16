# Transição de sincronização privada (ainda não implementada)

Nesta versão do código, os caminhos de sincronização legada PostgREST e Storage
e o upload/download direto de áudio Ticuna estão pausados para evitar novas
transferências de conteúdo sem E2EE por esses caminhos. URLs públicas antigas
que tenham sido salvas como links podem ainda ser abertas ou reproduzidas pelo
visualizador e não são bloqueadas por essa pausa; não é uma barreira de rede geral.
A fila, banco e mídias locais são preservados. Não é um backup e outros aparelhos
não recebem alterações enquanto a sincronização estiver pausada. Login continua
usando HTTPS; HTTPS não é criptografia ponta a ponta. Aplicativos antigos,
como o IPA 1.3.5 já instalado, não têm este bloqueio. Para evitar novos envios
legados, pause a sincronização ou desconecte a conta Supabase neles. Nenhum
registro ou objeto existente no servidor foi apagado ou criptografado.

Os testes antigos do protocolo legado usam um opt-in explícito com cliente
simulado apenas em modo debug. O aplicativo não ativa esse opt-in. Não é uma
opção para habilitar sincronização em produção.

## Trabalho necessário antes de ativar E2EE

- Gerar chave forte no dispositivo e possibilitar abertura em outros aparelhos
  com frase de recuperação gerada no aplicativo; nunca enviar frase nem chave
  ao servidor. Validar cópia e armazenamento seguro, minimizar exposição e
  informar que perder a frase e todos os aparelhos significa perder acesso.
- Definir formato versionado, criptografia autenticada, nonces, integridade e
  vinculação de identidade/contexto dos registros; mídia em blocos autenticados.
  Rever segurança, custos e compatibilidade em todas as plataformas.
- Planejar servidor com dados cifrados e metadados mínimos, autenticação e
  proteção contra downgrade, concorrência e replay; testes de alteração,
  truncamento, chaves incorretas, falhas e recuperação entre aparelhos.
- Migrar o legado sem apagá-lo antes de confirmar cópias e integridade; versões
  antigas não podem ser consideradas seguras ou compatíveis automaticamente.
- Comparar dados Exchange primeiro, usando identidades estáveis e diferenças;
  preservar conflitos concorrentes em vez de confiar cegamente em relógios.
  Leitura EAS completa, anexos e rascunhos continuam pendentes de implementação
  e validação em servidor real.

Nenhum bloqueio no cliente substitui políticas no servidor contra versões
antigas. Mudanças remotas, limpeza de dados legados e nova publicação exigem
plano e autorização apropriados.

## Base experimental em desenvolvimento

`RecoveryCrypto` implementa isoladamente frase BIP39 de 24 palavras em
português, derivação de chave e envelopes AES-256-GCM autenticados com
contexto. Não está ligada à interface, ao armazenamento de chaves ou ao
Supabase e não torna os dados existentes cifrados. É uma base sujeita a revisão
antes de uso real. Faltam confirmação da frase, persistência segura, limites e
rotação de chaves/nonces, recuperação e associação segura entre aparelhos,
protocolo de mídia, migração, anti-replay e prevenção de downgrade. Os testes
unitários não substituem uma revisão de segurança nem validam interoperabilidade
com dados reais.

A base experimental inclui também blocos de mídia com manifesto cifrado e
integridade vinculada à conta, ao arquivo, à posição e aos envelopes dos
blocos. O receptor precisa gravar em arquivo temporário e publicar apenas
após validar o manifesto e todos os blocos: o stream pode falhar depois de
emitir dados. Blocos enviados antes de uma falha precisam de coleta segura de
órfãos. Um manifesto inteiro antigo ainda pode ser reapresentado pelo servidor;
anti-replay exige protocolo de versões e estado confiável. Isso ainda não é a
sincronização de mídia e não libera o bloqueio de upload legado.

Existe também um armazenamento local experimental da chave derivada usando o
serviço de credenciais do sistema, com confirmação da frase e recusa de
substituição de uma chave existente. Ainda não está ligado à interface; antes de
usá-lo em outro dispositivo é necessário verificar que a chave corresponde ao
cofre remoto. O armazenamento para Web está explicitamente desativado até ser
avaliado. Essa etapa não criptografa o banco local nem oferece recuperação caso
a frase e todos os aparelhos com a chave sejam perdidos.

O protótipo de envelopes de registros gera um identificador opaco por HMAC com
chave separada e cifra o tipo, o identificador original e os dados. Conta, rota
e revisão são autenticadas. Ainda são visíveis ao servidor a conta, a rota
opaca repetida, a revisão e o tamanho; nenhuma proteção contra replay integral,
exclusão ou negação de serviço está implementada. Esse formato ainda não está
ligado a nenhuma tabela remota e pode mudar após revisão de segurança.

`RecoveryVaultVerifier` é um marcador experimental autenticado que permite
verificar uma frase contra um marcador já obtido e vinculado à conta, usando
uma subchave distinta e ID aleatório. Não consulta nem cria um cofre remoto e
não está ligado à interface ou ao armazenamento de chave. Aceitar um marcador
apresentado pelo servidor por si só não impede substituição, exclusão ou replay;
a identidade do cofre deve ser verificada com estado confiável, e uma criação
futura precisa ser atômica e nunca substituir um marcador preexistente. Uma
resposta remota ausente ou falha de rede não autoriza automaticamente criar
outro cofre. Isso não ativa a sincronização.
