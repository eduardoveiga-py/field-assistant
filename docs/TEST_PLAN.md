# Plano de Testes Automatizados: Ministério Pessoal

## 1. Estratégia de Testes
O projeto adota uma pirâmide de testes com três camadas:
1. **Testes Unitários:** Regras de contagem, verificação de disponibilidade e conflitos de horários na agenda, algoritmo de mesclagem de sincronização, criptografia e validação de backup, resolução de links pelo `PublicationLinkResolver`.
2. **Testes de Integração / Repositório:** Banco Drift em memória e em SQLite real, inserções transacionais com fila de sincronização, migrações versionadas, recuperação de falhas de transação, busca offline e filtros.
3. **Testes de Interface (Widgets & Flows):** Navegação entre abas, formulários com campos opcionais, fluxo rápido de agendamento de revisita, indicador de conflito na UI, modos responsivos para iPhone (layout compacto) e iPad (layout mestre-detalhe).

---

## 2. Casos de Teste Obrigatórios

### 2.1 Regras de Contagem (Dashboard & Indicadores)
- [x] **TC-COUNT-01:** Um estudo bíblico compartilhado com 3 participantes distintos conta como **1 único estudo ativo**.
- [x] **TC-COUNT-02:** Uma sessão de estudo realizada com múltiplos presentes conta como **1 única sessão realizada**.
- [x] **TC-COUNT-03:** Sessão com status `cancelada` ou `nao_realizada` **não** é contabilizada nas sessões realizadas.
- [x] **TC-COUNT-04:** Uma revisita agendada para o futuro **não** conta como revisita realizada.
- [x] **TC-COUNT-05:** Uma tentativa sem contato (`tentativa_sem_contato`) **não** conta como conversa realizada no dashboard.
- [x] **TC-COUNT-06:** Re-execução ou re-sincronização de uma operação não duplica contagens.

### 2.2 Agenda e Conflitos de Horário
- [x] **TC-SCHED-01:** Detecção de sobreposição parcial (ex: 14h00-14h30 colidindo com 14h20-14h50).
- [x] **TC-SCHED-02:** Detecção de contenção total (ex: 14h00-15h00 colidindo com 14h15-14h45).
- [x] **TC-SCHED-03:** Permitir agendamentos estritamente consecutivos quando não houver intervalo obrigatório (ex: 14h00-14h30 e 14h30-15h00).
- [x] **TC-SCHED-04:** Bloqueio de gravação silenciosa de sobreposição; apresentação de horários alternativos sugeridos.
- [x] **TC-SCHED-05:** Preservação do histórico ao reagendar (registro anterior preservado como `reagendado`, novo criado como `planejado`/`confirmado`).
- [x] **TC-SCHED-06:** Identificação explícita de agendamentos provisórios criados offline aguardando validação de sincronização.

### 2.3 Sincronização e Conflitos
- [x] **TC-SYNC-01:** Gravação offline cria registro na tabela e operação na `sync_queue`.
- [x] **TC-SYNC-02:** Alteração de campos distintos em dois nós (Dispositivo A edita telefone, Dispositivo B edita endereço) resulta em mesclagem íntegra sem perda.
- [x] **TC-SYNC-03:** Alteração divergente do mesmo campo sinaliza conflito e exige escolha consciente do usuário.
- [x] **TC-SYNC-04:** Reenvio de lote de mutações é idempotente e não gera duplicações de pessoas, visitas ou estudos.
- [x] **TC-SYNC-05:** Exclusão lógica (`deleted_at`) sincronizada é propagada e sobrepõe edições obsoletas.

### 2.4 Persistência, Backup e Restauração
- [x] **TC-BAK-01:** Exportação de backup gera arquivo criptografado contendo todos os dados, com checksum e versão.
- [x] **TC-BAK-02:** Tentativa de restaurar backup com senha incorreta ou arquivo adulterado é rejeitada com erro seguro.
- [x] **TC-BAK-03:** Restauração realiza pré-visualização de contagem (adicionados, atualizados, inalterados) e valida integridade antes de gravar no banco.
- [x] **TC-BAK-04:** Reimportar o mesmo backup não cria duplicatas devido ao uso de UUIDs.

### 2.5 Resolvedor de Links (`PublicationLinkResolver`)
- [x] **TC-PUB-01:** Resolução de Lição válida para o livro *Seja Feliz para Sempre!* em Português gera link oficial JW.org válido.
- [x] **TC-PUB-02:** Resolução para idioma Libras indica suporte a vídeo da lição e não gera referências a parágrafos inválidos.
- [x] **TC-PUB-03:** Fallback para navegador web e cópia de referência quando deep link direto não estiver disponível.
