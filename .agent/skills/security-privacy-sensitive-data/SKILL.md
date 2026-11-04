---
name: security-privacy-sensitive-data
description: Diretrizes mandatórias de segurança, privacidade e proteção de dados sensíveis do ministério pessoal e pastoral.
---

# Skill: Segurança, Privacidade e Proteção de Dados Sensíveis

Esta skill documenta as regras estritas e os padrões de implementação para garantir a confidencialidade, integridade e isolamento dos dados dos usuários no **Field Assistant**.

## 1. Zero Diretórios Temporários em Produção
- **Regra:** NUNCA utilize `Directory.systemTemp` ou caminhos `/tmp` voláteis para armazenar notas de áudio, fotos, backups cifrados ou dados pastorais em runtime de produção.
- **Motivo:** Diretórios temporários do sistema operacional são compartilhados, podem ser purgados a qualquer momento pelo SO sob pressão de memória e expõem dados a outros processos.
- **Implementação:** Toda persistência de mídia e staging de backup deve utilizar exclusivamente o diretório seguro de documentos do aplicativo (`getApplicationDocumentsDirectory()` / `documentsDirectoryProvider`). Se o diretório seguro estiver inacessível, o sistema deve falhar de forma explícita lançando `StorageUnavailableException`, sem fallback silencioso para `/tmp`.

## 2. Isolamento Multi-tenant e Políticas RLS (Row Level Security)
- **Regra:** Todo dado sincronizado com a nuvem (Supabase) pertence estritamente ao usuário autenticado (`owner_id = auth.uid()`).
- **Implementação:**
  1. Todas as 10 tabelas sincronizadas (`people`, `visits`, `bible_studies`, `study_participants`, `study_sessions`, `appointments`, `activity_records`, `voice_notes`, `phone_contacts`, `territory_landmarks`) devem possuir `ENABLE ROW LEVEL SECURITY;`.
  2. Políticas granulares para `SELECT`, `INSERT`, `UPDATE` e `DELETE` devem exigir `auth.uid() = owner_id`.
  3. O bucket de mídia `voice_notes` no Supabase Storage deve ser privado (`public = false`), limitando o acesso aos proprietários dos arquivos via join com `voice_notes.owner_id = auth.uid()`.

## 3. Proibição Absoluta de Credenciais Privilegiadas no Cliente
- **Regra:** Chaves com papel `service_role`, `postgres`, `admin` ou `super_admin` são estritamente proibidas no código cliente (mobile e web).
- **Implementação:**
  1. Apenas chaves públicas anônimas (`anon key`) são permitidas.
  2. A classe imutável `AppConfig` decodifica a chave JWT em tempo de inicialização e rejeita sumariamente qualquer token com papel privilegiado, lançando `AppConfigException`.
  3. Mascaramento compulsório: strings de configuração e diagnósticos devem mascarar a chave anônima (ex: `eyJhbG...90`), impedindo vazamento de tokens em relatórios de log e diagnósticos da UI.

## 4. Sanitização de Caminhos Físicos Locais
- **Regra:** Caminhos absolutos do sistema de arquivos local (ex: `/data/user/0/...` ou `/var/mobile/...`) NUNCA devem ser transmitidos ao backend ou salvos na nuvem.
- **Implementação:** O método `SupabaseSyncService.sanitizePayload` remove compulsoriamente os campos `audio_file_path` e `audioFilePath` antes do push para o Supabase. O áudio binário é transmitido separadamente para o bucket privado de Storage utilizando o UUID da nota.

## 5. Criptografia de Backups com Envelope v2
- **Regra:** Arquivos de backup ministerial gerados pelo usuário devem ser criptografados de ponta a ponta.
- **Implementação:**
  1. Cifragem simétrica com padrão militar AES-256-GCM.
  2. Derivação de chave segura via PBKDF2-HMAC-SHA256 utilizando salt aleatório de 16 bytes e 100.000 iterações.
  3. Staging atômico em 3 etapas na restauração: descompactação temporária em diretório isolado de documentos, backup de arquivos pré-existentes (`replacedOriginalsBackup`), e restauração atômica do SQLite Drift, com rollback transacional completo em caso de falha.
