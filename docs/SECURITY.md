# Política de Segurança e Privacidade: Ministério Pessoal

## 1. Princípios de Privacidade
Os dados gerenciados por este aplicativo dizem respeito a conversas, nomes, endereços e preferências espirituais de moradores e estudantes bíblicos. Portanto:
- **Zero Telemetria / Zero Ads:** Nenhum SDK de analytics comercial, rastreamento comportamental ou anúncios é incluído no projeto.
- **Isolamento de Logs:** Informações pessoais (nomes, telefones, anotações de visitas, perguntas) nunca são impressas no console ou em logs técnicos em ambiente de produção.
- **Comunicação Segura:** Toda comunicação de rede com o backend Supabase ocorre estritamente via TLS 1.3/HTTPS.

---

## 2. Segurança no Banco Local
- **Dispositivos Móveis (iOS/macOS):** Drift com SQLite em sandbox nativa de aplicativo. Opcionalmente, suporte a bloqueio biométrico (FaceID/TouchID) e chave mestra de desbloqueio.
- **Web:** Drift Wasm com IndexedDB isolado pela política de mesma origem (Same-Origin Policy).
- **Armazenamento de Segredos:** Tokens de autenticação de sessão são armazenados utilizando mecanismos seguros da plataforma (ex: `flutter_secure_storage` usando Keychain no iOS e criptografia de credenciais locais).
- **Sem senhas em texto puro:** Nenhuma credencial de conta é guardada desprotegida.

---

## 3. Segurança no Backend (Supabase / PostgreSQL)
- **Row Level Security (RLS):** Toda tabela possui RLS ativado. As políticas garantem que um usuário só pode selecionar, inserir, atualizar ou excluir registros cujo `user_id` corresponda ao `auth.uid()`.
- **Chaves de Acesso:** Apenas a chave pública do cliente (`anon key`) é configurada no cliente. A `service_role key` **nunca** é incluída no repositório nem distribuída na aplicação.
- **Auditoria de Acesso Cruzado:** Testes automatizados garantem que tentativas de leitura com `user_id` divergente são bloqueadas pelo banco de dados.

---

## 4. Segurança de Backup e Restauração
- **Criptografia Simétrica Forte:** O arquivo de backup exportado é criptografado com AES-GCM (256 bits).
- **Derivação de Chave:** A chave criptográfica é derivada da senha fornecida pelo usuário utilizando PBKDF2 com salt aleatório e alto número de iterações.
- **Verificação de Integridade:** O arquivo contém tag de autenticação HMAC/GCM para impedir restauração de dados corrompidos ou adulterados.
- **Proteção na Restauração:** O fluxo de restauração nunca sobrescreve o banco cegamente; ele realiza pré-visualização, cálculo de diff (adições, alterações, conflitos) e validação de versão do esquema antes de efetivar qualquer modificação.
