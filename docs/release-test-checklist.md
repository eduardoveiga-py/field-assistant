# Preparação para release de testes (não publicada)

A branch prepara 1.3.4+11 como teste. O manifesto `apps.json` tem tamanho zero
como placeholder na árvore; a etapa de publicação cria uma cópia com o tamanho
real do IPA. O mínimo atual anunciado é iOS 15.0. O IPA é não assinado e requer
um método compatível de instalação/sideload. A integridade deve ser verificada
pelo SHA-256 da release; não é assinatura de desenvolvedor.

O job de tag exige configuração Supabase e assinatura Android; sem isso a release
não deve ser publicada, e o Android de release não deve cair na assinatura debug.
A etapa de mapa reconstrói o extrato, verifica estrutura/cobertura e publica mapa,
atribuição, proveniência e somas ao lado dos binários. Confirmação visual local
sobre rios e comunidades continua obrigatória. Outros mapas do catálogo não são
garantidos por esse pacote.

Análise estática continua tratando erros e warnings como fatais, mas não bloqueia
por infos (a maioria de deprecações das bibliotecas Flutter). Uma versão de SDK
estável não fixada pode mudar os resultados, portanto registrar e fixar o SDK
antes de produção. Corrigir infos progressivamente, sem silenciá-las no código.

Antes de autorizar publicação: revisar resultados de todos os jobs para o commit
exato, assinar Android e verificar atualização sem desinstalação, testar iOS/Windows
e backup-restauração; definir procedimento de opt-in e allowlist de Auth validado
no aparelho; tratar exclusões definitivas em conflito (ver sync-safety-rollout);
e testar concorrência e restauração entre dois usuários/aparelhos. Ausência de
credenciais da CI não foi verificada por falta de permissão para listar secrets.

O histórico do manifesto nesta branch lista apenas versões para as quais havia
release com IPA no momento da verificação, usando URLs fixas e os tamanhos reais
desses assets. O mínimo da versão 1.3.3 também foi corrigido para iOS 15 conforme
o projeto dessa tag; mínimos de versões anteriores ainda não foram revalidados.
