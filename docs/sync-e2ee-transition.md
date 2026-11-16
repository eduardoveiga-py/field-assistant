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
