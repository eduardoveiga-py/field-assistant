# Política de Segurança e Governança: Ministério Pessoal

## 1. Princípios de Privacidade e Soberania dos Dados
Os dados gerenciados por este aplicativo dizem respeito a conversas espirituais, nomes, endereços, notas teocráticas e preferências de moradores e estudantes bíblicos. A preservação da privacidade e o sigilo pastoral são requisitos mandatórios absolutos da arquitetura:
- **Zero Telemetria / Zero Ads:** Nenhum SDK de analytics comercial, rastreamento comportamental, telemetria em nuvem ou anúncios é incluído no projeto.
- **Isolamento Estrito de Logs:** Informações pessoais (nomes, telefones, anotações de visitas, perguntas, pontos de empatia) nunca são impressas no console ou em logs técnicos em ambiente de produção.
- **Comunicação Criptografada Ponto a Ponto:** Toda comunicação de rede com o backend Supabase ocorre estritamente via TLS 1.3 / HTTPS com certificados válidos.

---

## 2. Validação de Ambiente e Proteção de Segredos (`AppConfig`)
A aplicação utiliza a classe centralizada e imutável `AppConfig` (`lib/core/app_config.dart`) para validação rigorosa de variáveis de ambiente no boot:
- **Ambientes Suportados:** `development`, `homologation` e `production` (`AppEnvironment`).
- **Estados de Configuração (`ConfigStatus`):**
  - `unconfigured`: Ausência de URL e chave remota. O aplicativo entra em modo puramente offline, garantindo que o SQLite local funcione 100% sem disparar exceções ou requisições espúrias.
  - `valid`: Parâmetros validados, íntegros e seguros para sincronização com o backend.
  - `invalid`: Parâmetros incompletos, malformados ou inseguros. O boot recusa a inicialização de rede com erro explícito (`AppConfigException`).
- **Validação Estrita de URLs e Protocolos:**
  - Validação estrita de formato URI com verificação de esquema (`http` ou `https`).
  - Proibição categórica de credenciais de usuário embutidas na URL (`userInfo` / Basic Auth).
  - Proibição de parâmetros de consulta (`query parameters`) e fragmentos (`#`) no endpoint base.
  - **Exigência Obrigatória de HTTPS:** Em ambiente de produção (`production`) e homologação (`homologation`), a `SUPABASE_URL` deve obrigatoriamente utilizar HTTPS (permitindo `localhost`/`127.0.0.1` apenas em homologação local).
- **Detecção de Placeholders Não Configurados:**
  - Bloqueio imediato caso a URL ou chave contenha valores genéricos de exemplo como `your-supabase-url`, `example.com`, `<project-ref>`, `your-anon-key`, `your-supabase-anon-key` ou `<anon-key>`.
- **Rejeição Ativa de Chaves Privilegiadas (`_isPrivilegedKey`):**
  - O aplicativo cliente aceita única e exclusivamente a chave pública anônima (`anon key`).
  - Rejeição imediata de chaves contendo termos privilegiados como `service_role`, `supabase_admin` ou `super_admin`.
  - Bloqueio de tokens de gerenciamento pessoal da plataforma que iniciem com o prefixo `sbp_`.
  - Inspeção e decodificação do payload de tokens JWT (Base64URL): caso a propriedade `role` corresponda a `service_role`, `supabase_admin`, `admin`, `super_admin` ou `postgres`, a configuração é rejeitada instantaneamente.
- **Mascaramento Técnico de Segredos em Logs:**
  - Em relatórios de diagnóstico e saídas de console (`toDiagnosticString()`), URLs com credenciais têm seu `userInfo` substituído por `***:***`.
  - A chave anônima é exibida de forma truncada e mascarada (`maskedAnonKey`), exibindo apenas os primeiros 6 e os últimos 4 caracteres seguidos de sua extensão (ex: `eyJhbG...9xyz (len: 120)`), evitando vazamentos acidentais em traces ou logs de depuração.

---

## 3. Segurança no Banco de Dados Local (Drift / SQLite / Wasm)
- **Dispositivos Móveis e Desktop:** SQLite nativo sob sandbox isolada de aplicativo gerenciada pelo sistema operacional (iOS, Android, macOS, Windows).
- **Web:** Drift Wasm persistido via IndexedDB no navegador, protegido pelo isolamento de mesma origem (*Same-Origin Policy* - SOP).
- **Integridade Relacional Ativa:** O banco local é inicializado com `PRAGMA foreign_keys = ON;` e `PRAGMA journal_mode = WAL;`, impedindo a criação de registros órfãos ou inconsistências relacionais.
- **Armazenamento de Tokens de Sessão:** Tokens de autenticação JWT são armazenados exclusivamente através de mecanismos protegidos da plataforma (`flutter_secure_storage` usando Keychain no iOS/macOS e KeyStore criptografado no Android).
- **Proibição de Senhas em Texto Puro:** Nenhuma senha ou credencial em texto claro é armazenada no banco local ou em SharedPreferences.

---

## 4. Segurança no Backend (Supabase / PostgreSQL)

### 4.1 Isolamento por Linha (Row Level Security - RLS)
Toda e qualquer tabela exposta à sincronização na nuvem possui Row Level Security (RLS) ativado obrigatoriamente.
- **Identificador Canônico de Propriedade (`owner_id`):** O isolamento multi-inquilino (*multi-tenant*) no PostgreSQL é realizado estritamente pela coluna canônica `owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid()`.
- **Políticas em Todas as Tabelas de Dados:** As 10 tabelas sincronizadas (`people`, `visits`, `bible_studies`, `study_participants`, `study_sessions`, `appointments`, `activity_records`, `voice_notes`, `phone_contacts`, `territory_landmarks`) e a outbox (`sync_queue`) aplicam políticas que vinculam todas as operações (SELECT, INSERT, UPDATE, DELETE) à identidade autenticada:
  ```sql
  CREATE POLICY table_user_policy ON public.table
      FOR ALL
      TO authenticated
      USING (auth.uid() = owner_id)
      WITH CHECK (auth.uid() = owner_id);
  ```
- **Auditoria de Acesso Cruzado:** Testes de aceitação automatizados (`supabase_u3_schema_storage_test.dart` e `u3_2_integrated_acceptance_test.dart`) garantem que tentativas de consulta ou mutação com `owner_id` divergente são bloqueadas nativamente pelo PostgreSQL com erro de autorização.
- **Proteção Contra Ressurreição por Triggers:** Triggers no servidor (`handle_soft_delete_and_resurrection_guard`) inspecionam tentativas de upsert em registros marcados como tombstones (`deleted_at IS NOT NULL`), impedindo que clientes desatualizados ou desincronizados ressuscite registros apagados sem uma ação explícita de restauração (`revision > OLD.revision` e `updated_at > OLD.deleted_at`).

### 4.2 Segurança no Armazenamento de Arquivos (Supabase Storage)
O armazenamento de notas de voz e gravações de áudio (`.m4a`, `.mp4`, `.aac`) utiliza um bucket privado no Supabase Storage:
- **Bucket Privado `voice_notes`:** Configurado com `public = false`, teto máximo de tamanho de 10 MB por arquivo (`file_size_limit = 10485760`) e restrição de tipos MIME permitidos (`audio/m4a`, `audio/x-m4a`, `audio/mp4`, `audio/aac`).
- **RLS em `storage.objects`:**
  - **Upload (INSERT):** Exige usuário autenticado e valida se o usuário é proprietário da nota de voz referenciada na tabela `public.voice_notes`:
    ```sql
    CREATE POLICY "voice_notes_storage_insert" ON storage.objects
        FOR INSERT TO authenticated
        WITH CHECK (
            bucket_id = 'voice_notes' AND (
                auth.uid() = owner OR (
                    auth.role() = 'authenticated' AND EXISTS (
                        SELECT 1 FROM public.voice_notes vn 
                        WHERE vn.id::text = regexp_replace(storage.objects.name, '\.[^.]+$', '') 
                          AND vn.owner_id = auth.uid()
                    )
                )
            )
        );
    ```
  - **Download / Leitura (SELECT):** Permitido somente se `owner = auth.uid()` ou se `auth.uid()` for comprovadamente o proprietário (`owner_id`) do registro em `public.voice_notes`, utilizando normalização por expressão regular (`regexp_replace(storage.objects.name, '\.[^.]+$', '')`) para suportar extensões variadas.
  - **Atualização (UPDATE) e Exclusão (DELETE):** Restritos unicamente ao proprietário autenticado correspondente ao `owner_id` da nota.

---

## 5. Segurança Criptográfica de Backup e Restauração

### 5.1 Envelope Criptográfico Versão 2
O serviço de backup (`lib/settings/backup_service.dart`) gera contêineres autocontidos e autenticados de dados criptografados:
- **Derivação de Chave Forte (KDF):** Utiliza `PBKDF2-HMAC-SHA256` com **100.000 iterações** e salt criptograficamente seguro aleatório de 16 bytes gerado via `Random.secure()`.
- **Cifra Simétrica Autenticada:** Criptografia com algoritmo **AES-256-GCM** utilizando vetor de inicialização (IV) aleatório de 16 bytes e tag de autenticação integrada de 128 bits, garantindo tanto o sigilo quanto a autenticidade e integridade da carga útil.
- **Checksum de Integridade:** Checksum SHA-256 do payload JSON bruto gerado antes da cifragem e validado antes da desserialização interna.
- **Inventário Exaustivo:** O backup serializa e restaura com integridade relacional todas as **22 tabelas** do banco Drift, codificando anexos multimídia em Base64 com hashes SHA-256 individuais.

### 5.2 Estágios de Staging e Rollback de Mídia
Para impedir corrupção do repositório físico de áudios durante a restauração:
1. **Etapa 1 (Validação em Staging):** Áudios são extraídos para um diretório transitório de staging (`safety_staging_<runId>`) e validados individualmente contra o hash SHA-256 declarado. Se houver divergência, o arquivo corrompido é isolado e apontado na prévia.
2. **Etapa 2 (Salvaguarda de Originais):** Antes de sobrescrever qualquer áudio já existente em disco, o arquivo atual é copiado para um diretório de salvaguarda (`safety_audio_backup_<runId>`).
3. **Etapa 3 (Transação Atômica e Rollback Automático):** A restauração das 22 tabelas ocorre sob uma transação atômica única no Drift. Caso qualquer erro ocorra, o mecanismo de rollback restaura imediatamente os arquivos de áudio originais preservados, expurga os arquivos novos adicionados na sessão e deleta os diretórios de staging, evitando arquivos órfãos no dispositivo.

### 5.3 Snapshot de Segurança Pré-Restauração
Antes de efetivar qualquer modificação no banco de dados durante uma restauração:
- Um snapshot cifrado completo do estado atual do banco é exportado compulsoriamente com chave temporária e salvo em disco no diretório persistente de documentos (`safety_snapshots/snapshot_<timestamp>.bak`) e registrado em `app_kv_store` (ou armazenado na chave `last_safety_snapshot_data` no ambiente Web).
- Se a criação ou validação deste snapshot falhar por qualquer razão, a restauração é **imediatamente abortada** (`RestoreAbortedException`), preservando intacto o banco local.

---

## 6. Proibição Categórica de Diretórios Temporários (`Directory.systemTemp`)
O aplicativo rejeita expressamente o uso de diretórios temporários do sistema (`Directory.systemTemp`, `/tmp` ou caches voláteis) para operações de backup, restauração, salvaguarda de mídias ou persistência de áudios:
- **Fundamento Arquitetural:** Sistemas operacionais móveis (especialmente iOS e Android) e desktops purgam o diretório temporário arbitrariamente e sem aviso sob pressão de memória, o que resultaria em perda catastrófica e irrecuperável de dados do usuário e notas de voz.
- **Tratamento de Exceção (`StorageUnavailableException`):** Caso o diretório persistente e seguro de documentos (`getApplicationDocumentsDirectory()`) não possa ser obtido, o sistema **não realiza fallback silencioso para `systemTemp`**. Em vez disso, a operação é interrompida lançando imediatamente `StorageUnavailableException`, protegendo os dados de persistência degradada ou corrupção silenciosa (enforçado pelo teste `TC-BAK-ADV-03`).
