# Conformidade com a Lei Geral de Proteção de Dados (LGPD — Lei nº 13.709/2018)
## Field Assistant — Política de Privacidade, Segurança e Governança de Dados

- **Versão:** 1.0.0
- **Data:** 2026-11-17
- **Classificação:** Documento Técnico e de Governança
- **Aplicação:** Aplicativo móvel (iOS / iPadOS / Android / Web / Desktop) e backend Supabase

---

## 1. Visão Geral e Princípio de Minimização

O **Field Assistant** é uma ferramenta de produtividade e apoio organizacional para o ministério pastoral voluntário. Toda a sua arquitetura foi concebida sob os princípios de **Privacy by Design** (Privacidade desde a Concepção) e **Privacy by Default** (Privacidade por Padrão), em conformidade com o Art. 6º da Lei Geral de Proteção de Dados Pessoais (LGPD — Lei nº 13.709/2018).

O aplicativo opera prioritariamente em regime **offline-first**, garantindo que o titular dos dados mantenha a custódia primária de todas as suas informações em seu dispositivo pessoal.

---

## 2. Bases Legais e Finalidade do Tratamento (Art. 7º e Art. 11 LGPD)

1. **Finalidade Legítima:** O tratamento de dados pessoais (como nomes, telefones, anotações de conversas e endereços de moradores) ocorre exclusivamente para fins organizacionais e voluntários do próprio usuário, visando o acompanhamento de estudos bíblicos e revisitas programadas.
2. **Consentimento e Legítimo Interesse:** O usuário gerencia seus contatos no âmbito de suas atividades pessoais e religiosas. O aplicativo não compartilha, não comercializa, não realiza perfilamento comportamental e não utiliza dados para fins publicitários.

---

## 3. Categorias de Dados Pessoais Tratados

| Categoria | Exemplos | Armazenamento Local | Trânsito / Sincronização |
|---|---|---|---|
| **Identificação e Contato** | Nome, telefone, endereço, dia preferido | SQLite local cifrado (`sqlite3mc`) | Envelope cifrado E2EE (AES-256-GCM) |
| **Geolocalização** | Coordenadas de latitude/longitude | SQLite local cifrado | Envelope cifrado E2EE |
| **Registros Ministeriais** | Histórico de visitas, estudos bíblicos, tópicos | SQLite local cifrado | Envelope cifrado E2EE |
| **Mídias e Áudios** | Fotos de casas/locais, notas de voz, áudio Ticuna | Diretório local do app isolado (`p.canonicalize`) | Chunks cifrados AES-256-GCM nos 4 buckets Supabase |
| **Credenciais de Segurança** | PIN numérico, Salt, Frase mnemônica de 24 palavras | `FlutterSecureStorage` (iOS Keychain / Android KeyStore) | **Jamais transmitidos à nuvem** |
| **Biometria** | Face ID / Touch ID | Controlado pelo SO nativo (Secure Enclave) | **Nenhum acesso aos dados biométricos brutos** |

---

## 4. Medidas Técnicas e de Segurança da Informação (Art. 46 LGPD)

Em atendimento ao Art. 46 da LGPD, o Field Assistant implementa controles rígidos de segurança técnica:

### 4.1 Criptografia em Repouso (At-Rest)
- O banco de dados local SQLite é protegido por cifra simétrica AES-256 (`sqlite3mc`) usando chave derivada de 256 bits gerada aleatoriamente no primeiro uso e persistida no Keychain/KeyStore de hardware.
- No iOS, os arquivos do banco de dados, arquivos WAL/SHM e anexos de mídia recebem a flag de proteção `NSFileProtectionCompleteUntilFirstUserAuthentication` e são explicitamente marcados com `URLResourceValues.isExcludedFromBackup = true` para impedir uploads não criptografados ao iCloud.

### 4.2 Criptografia Ponta a Ponta (End-to-End Encryption — E2EE)
- **Zero-Knowledge Backend:** Nem o provedor de nuvem (Supabase), nem operadores de rede têm capacidade de ler os dados dos contatos, estudos ou visitas sincronizados.
- **Fail-Closed:** A política `SyncPrivacyPolicy` garante que, caso a chave criptográfica ou o cofre não estejam presentes, **a sincronização é abortada imediatamente**. O aplicativo jamais realiza fallback para envio de texto claro (plaintext).
- **Controle Monotônico:** Sincronização orientada por `server_seq BIGSERIAL` com Checkpoints transacionais locais (`EncryptedRecordCheckpoint`), impedindo adulterações ou perdas de sincronismo.

### 4.3 Isolamento Rígido de Contas (Multi-Account Safety)
- Implementação de `SyncOwnerGuard`: o logout limpa imediatamente tokens e chaves ativas de memória.
- A entrada de uma nova conta no mesmo dispositivo exige o reset transacional do workspace local ou confirmação explícita de migração, prevenindo qualquer contaminação cruzada entre diferentes usuários.

### 4.4 Proteção de Mídias e Contenção de Diretórios (Anti-Path Traversal)
- O subsistema `saveMediaBytes` valida rigorosamente extensões permitidas, aplica normalização de caminhos (`p.canonicalize`) e exige contenção restrita no diretório seguro do aplicativo (`p.isWithin`), prevenindo ataques de *path traversal* ou symlink escapement.

---

## 5. Exercício dos Direitos dos Titulares (Art. 18 LGPD)

O aplicativo disponibiliza mecanismos nativos para atendimento imediato aos direitos dos titulares:

1. **Acesso e Confirmação:** O usuário pode consultar a qualquer momento a totalidade de seus dados na interface do aplicativo.
2. **Correção de Dados:** Edição direta de nomes, telefones, notas e situações cadastrais.
3. **Eliminação de Dados e Expurgo:**
   - Remoção para a Lixeira local com retenção de segurança configurável.
   - Expurgo definitivo (`HARD_DELETE` seguro) com emissão de tombstone cifrado para a nuvem e remoção idempotente de chunks de mídia nos buckets remotos.
4. **Portabilidade:**
   - Exportação completa em formato de planilha (Excel/CSV) e relatórios formatados em PDF.
   - Exportação de **Backup Seguro v3**: arquivo autocontido cifrado com PBKDF2-HMAC-SHA256 (mínimo de 600.000 iterações em Isolate) e AES-256-GCM com salt aleatório.

---

## 6. Retenção e Descarte de Dados

- Dados inativos ou excluídos permanecem em lixeira durante o período configurado pelo usuário (padrão de 30 dias) antes do descarte definitivo.
- Backups automáticos locais mantêm rotatividade estrita, não acumulando dados históricos além do período de recuperação necessário.

---

## 7. Licenciamento e Auditoria de Terceiros

- O código-fonte do Field Assistant respeita integralmente as licenças dos componentes de código aberto utilizados, incluindo `enough_mail` (Mozilla Public License 2.0 — MPL-2.0, cujas alterações locais de constraints estão documentadas em `third_party/enough_mail/LOCAL_CHANGES.md`) e os motores cartográficos sob licenças permissivas (BSD-3-Clause / MIT).
- Os pacotes de dados cartográficos do OpenStreetMap são distribuídos em estrita conformidade com a licença **Open Database License (ODbL)**.

---

## 8. Contato e Responsabilidade

O Field Assistant opera como ferramenta de uso pessoal. Para dúvidas técnicas sobre a criptografia, auditoria de segurança ou implementação de governança de dados, consulte a documentação de engenharia em `docs/engineering/`.
