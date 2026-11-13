# Retorno de autenticação: validação pendente

O projeto atualmente usa confirmação por link. Não trocar templates nem
redirecionamentos remotos sem validar o destino e a entrega do link ao app.
Na configuração remota consultada anteriormente, o Site URL era localhost e a
allowlist estava vazia. No repositório o Info.plist só declarava um scheme de
Google placeholder. A instalação relatada usa um contêiner/sideload; sua
configuração e a versão instalada podem diferir desta árvore.

Foram preparadas telas de resultado e nova senha. O shell reage a eventos de
passwordRecovery recebidos enquanto seu listener está ativo e a erros explícitos
otp_expired recebidos nesse período. A tela de sucesso de confirmação ainda não
está ligada ao retorno, pois um evento signedIn comum não prova que o usuário
acabou de confirmar um e-mail. Eventos ou erros processados pelo SDK antes da
montagem do shell podem ser perdidos; não considerar o fluxo completo.

A duplicação anterior de getSessionFromUrl na splash foi removida: o SDK já
processa URIs e códigos de uso único não devem ser trocados duas vezes.

Antes de usar em produção: definir e testar recepção de callback para aplicativo
aberto e fechado no iPhone/iPad, incluindo a instalação utilizada; implementar
roteamento e resultados com base no processamento comprovado do callback;
configurar registro de protocolo e entrega do callback no Windows; validar erro,
link usado/expirado, recuperação, sessão preexistente e Supabase não configurado.
Não registrar tokens nem links completos nos logs ou testes.

Os testes Flutter não foram executados neste ambiente; sintaxe isolada não
comprova compilação, integração ou comportamento em dispositivo.

## Retorno nativo opt-in preparado, ainda não habilitado

A branch inclui o destino `ministeriopessoal://auth/callback` registrado no
iOS e no Android, tratamento de link único após instalar o listener de Auth,
e uso opcional do destino em cadastro, reenvio e recuperação. Para não alterar
o login existente sem validação de entrega, ele só é ativado compilando com
`--dart-define=AUTH_NATIVE_CALLBACK=true`; sem a flag o SDK e os redirecionamentos
anteriores permanecem como estavam. A URI não é escrita nos logs.

Antes de ativar a flag para usuários, configurar a allowlist do projeto para
esse destino e validar em instalação descartável no iOS, LiveContainer/SideStore
e Android: app aberto e fechado, cadastro, link expirado, recuperação e sessão
existente. Testar que o SDK e o handler não consomem o mesmo código duas vezes.
Custom schemes não provam identidade do app: verificar proteção PKCE e se o
contêiner realmente entrega o retorno ao aplicativo. A configuração remota Auth
não foi alterada nesta etapa; localhost continua sendo um problema no modo atual.
