# Regras Arquiteturais Mandatórias do Projeto: Ministério Pessoal

Este arquivo contém restrições estritas e instruções persistentes para todos os agentes de IA, desenvolvedores e mantenedores que operam neste repositório.

## 1. Persistência e Banco Local
- NUNCA substitua o banco de dados local Drift por armazenamento efêmero em memória, mapas estáticos ou arquivos simples de preferências para funcionamento geral.
- Toda gravação e leitura da UI deve obrigatoriamente passar pelas transações e repositórios locais do Drift SQLite / Drift Wasm.
- A persistência no navegador Web deve utilizar Drift Wasm com IndexedDB para garantir sobrevivência ao recarregar a página.

## 2. Integridade e Regras de Contagem
- NUNCA misture os conceitos de:
  1. Estudo Bíblico ativo (o acompanhamento contínuo).
  2. Participante (pessoa cadastrada associada ao estudo).
  3. Sessão de Estudo (a aula/ocorrência individual em determinada data).
  4. Revisita/Conversa (contato do ministério).
- Um estudo bíblico compartilhado com múltiplos participantes continua contando exatamente como **1 estudo**.
- Uma sessão realizada com múltiplos presentes conta exatamente como **1 sessão**.
- Sessões canceladas ou não realizadas **NÃO** contam como sessões realizadas.
- Revisitas agendadas **NÃO** contam como revisitas realizadas.
- Tentativas sem contato **NÃO** contam como conversas realizadas.
- NUNCA altere as regras de contagem sem atualizar concomitantemente a documentação (`docs/DATA_MODEL.md`) e os testes automatizados correspondentes.

## 3. Sincronização e Conflitos
- NUNCA introduza mecanismos de sincronização que apliquem "Last Write Wins" silencioso para anotações de conversas ou pessoas.
- Conflitos em campos incompatíveis devem reter ambas as versões e solicitar resolução pelo usuário.
- Históricos de visitas e sessões são entidades cronológicas imutáveis e não devem ser apagadas ou sobrescritas por atualizações de dados cadastrais.
- As operações de sincronização devem ser estritamente idempotentes.

## 4. Integração com JW Library
- NUNCA invente esquemas de URL privados ou URLs inexistentes para o JW Library ou jw.org.
- Deep links devem passar pelo `PublicationLinkResolver`.
- Se um deep link direto para lição ou parágrafo não for homologado ou suportado no idioma (ex: Libras), o sistema deve reportar a precisão real e fornecer fallback para o navegador oficial ou referência manual.

## 5. Testes e Engenharia
- NUNCA remova, comente ou enfraqueça testes existentes para forçar a aprovação de uma compilação.
- Se um teste falhar, o código de implementação deve ser corrigido para honrar o requisito.
- NUNCA introduza dependências de pacotes sem justificar a necessidade no commit/documentação.

## 6. Segurança e Credenciais
- NUNCA comite segredos, chaves de serviço Supabase (`service_role key`) ou senhas de usuários no repositório.
- Apenas chaves públicas de cliente (`anon key`) são permitidas em arquivos de exemplo de configuração.
- O código cliente (`AppConfig`) deve bloquear expressamente qualquer chave privilegiada (`service_role`, `postgres`, `admin`).

## 7. Privacidade e Diretórios (Zero Diretórios Temporários)
- NUNCA utilize diretórios temporários do sistema (`Directory.systemTemp` ou `/tmp`) para dados persistentes, gravações de notas de voz ou staging de backups.
- Toda mídia e backup deve residir no diretório de documentos seguros da aplicação. Se indisponível, deve falhar explicitamente lançando `StorageUnavailableException`.
- Caminhos absolutos do sistema de arquivos local (`audio_file_path`) NUNCA devem ser transmitidos ao backend ou salvos na nuvem (`SupabaseSyncService.sanitizePayload`).

## 8. Backups Criptográficos Envelope v2
- Todos os arquivos de backup ministerial devem utilizar Envelope v2 com cifragem AES-256-GCM e derivação PBKDF2-HMAC-SHA256 (100.000 iterações).
- Restaurações de backup devem utilizar staging transacional em 3 etapas com backup preventivo de arquivos originais (`replacedOriginalsBackup`) para garantir rollback 100% íntegro em caso de falha.

## 9. Sincronização Multi-Dispositivo e Governança P0
- A sincronização entre dispositivos é obrigatória na v1. Não propor lançamento offline-only.
- Todas as 10 tabelas de domínio do usuário e o bucket de áudio devem cumprir os 10 cenários obrigatórios de aceitação (3-way merge, outbox durável pós-restart, tombstones sem ressurreição, detecção semântica de concorrência na agenda, e isolamento estrito via RLS `owner_id = auth.uid()`).

