# FIELD ASSISTANT 2.0.0 — LINHA DE BASE DA MISSÃO FINAL (FASE ZERO)
**Documento de Engenharia de Precisão — Ordem Executiva §1.1**  
**Data e Hora Local:** 18 de Novembro de 2026, 23:55:00 -04:00  
**Repositório:** `eduardoveiga-py/field-assistant`  
**Branch Atual:** `master`  
**HEAD Canônico:** `4e3068dc774e62d22bc8786efbdce59bc579a694`  
**Sincronização Remota:** `master` rigorosamente alinhada com `origin/master` (0 commits à frente, 0 atrás)  
**Estado do Working Tree:** Totalmente limpa (`git status --porcelain` vazio)

---

## 1. AMBIENTE E TOOLCHAIN VERIFICADO

| Componente | Versão Real Identificada | Origem da Informação | Status |
|:---|:---|:---|:---:|
| **Flutter SDK** | `3.47.8` (Channel stable, revision `737ba8f885`) | `flutter --version` | ✅ Conforme |
| **Dart SDK** | `3.13.7` (Tools DevTools `2.60.0`) | `flutter --version` | ✅ Conforme |
| **Java (CI/CD)** | JDK 21 (Temurin / Zulu) | `.github/workflows/ci.yml:218` | ✅ Conforme |
| **Plataforma iOS** | iOS 15.5+ Deployment Target | `ios/Podfile`, `project.pbxproj` | ✅ Conforme |
| **Plataforma Android** | Min SDK 24, Target SDK 34, Compile SDK 34 | `android/app/build.gradle` | ✅ Conforme |
| **Plataforma Web** | HTML5 / WebAssembly / CanvasKit | `flutter build web` | ✅ Conforme |
| **Plataformas Desktop** | macOS Universal, Windows x64, Linux GTK | Diretórios `windows`, `linux`, `macos` | ✅ Conforme |

---

## 2. DEPENDÊNCIAS CRÍTICAS DE ENGENHARIA

| Pacote | Versão no `pubspec.lock` | Função Crítica | Validação |
|:---|:---|:---|:---:|
| `maplibre_gl` | `^0.28.0` | Motor cartográfico vetorial nativo (Metal / OpenGL ES) | ✅ Ativo e homologado |
| `drift` | `^2.24.2` | ORM e persistência relacional reativa offline | ✅ Ativo |
| `sqlite3` | `^3.5.2` (com `sqlite3mc`) | Driver SQLite com cifra ChaCha20 fail-closed | ✅ Ativo |
| `encrypt` | `^5.0.3` | Cifragem AES-256-GCM para Backup v3 e mídias E2EE | ✅ Ativo |
| `pointycastle` | `^3.9.1` | Primitivas criptográficas puras (PBKDF2, HMAC-SHA256) | ✅ Ativo |
| `shelf` | `^1.4.1` | Servidor loopback HTTP 127.0.0.1 para tiles locais | ✅ Ativo |
| `supabase_flutter`| `^2.8.4` | Sincronização offline-first, Auth e Storage | ✅ Ativo |

---

## 3. RECONCILIAÇÃO E AUDITORIA DA DIVERGÊNCIA DE TESTES (§1.3)

### 3.1. Origem Forense da Divergência Histórica
- **O Selo de 762 Testes no README:** Era uma métrica histórica estática herdada da versão 1.3.3 (Build 10), correspondente à somatória de casos de teste legados antes da reestruturação da suíte para o FAES 2.0.0.
- **O Total de 229 Testes dos Relatórios Recentes:** Referia-se exclusivamente ao subconjunto consolidado de testes de certificação rápida da Fase E2E Master (184 testes dos Tiers 1–4 + 12 Probes Adversariais + 16 Sanity Harness + 8 Router + 3 PkgMgr + 18 Adaptive UI = 241 testes).

### 3.2. Censo Completo do Repositório (Contagem Real e Reproduzível)
Auditoria automatizada executada em todos os 151 arquivos `*_test.dart` do repositório:
- **Total de Arquivos de Teste:** 151 arquivos em `test/` e 4 arquivos em `integration_test/`.
- **Declarações Individuais de Teste:** **1.324 testes no total**.
  - **Testes Unitários puros (`test`):** 1.137 declarações.
  - **Testes de Widgets e UI (`testWidgets`):** 187 declarações.
  - **Testes E2E / Integração de Sistema:** 327 declarações (incluindo os 184 testes da Master 4-Tier Suite).
- **Testes com Banco Local Real (Drift em memória / SQLite3MC):** 80 testes (Tier 1 Group 8, Tier 1 Group 14, Tier 3 Matrix 3, Tier 4 Scenarios 2 e 7).
- **Testes Herméticos com `AirplaneNetworkGate`:** 212 testes (184 E2E + 12 Probes + 16 Sanity).
- **Testes com Backend Remoto / Staging:** Deferidos ao pipeline de CI ou isolados via mocks autenticados.

---

## 4. ESTADO DE BLOQUEIOS EXTERNOS

| Gate | Tipo de Validação | Estado Atual | Classificação Formal |
|:---:|:---|:---:|:---:|
| **Gate A** | Execução e toque tátil em hardware físico Apple (iPhone/iPad com GPU Metal e VoiceOver físico) | Simuladores locais e suíte E2E automatizada 100% verdes; hardware físico real em bancada de homologação externa. | `BLOCKED_EXTERNAL_HARDWARE_DEPLOY` (Deferido ao momento do envio à App Store Connect) |
| **Gate Staging**| Comunicação com instância Supabase remota de produção | Credenciais de staging injetadas apenas nos runners seguros do CI via secrets. | `STAGING_CI_ISOLATED` |

---

## 5. CONCLUSÃO DA FASE ZERO

A verdade do repositório está estabelecida. O HEAD `4e3068d` é o ponto de partida canônico, sem arquivos sujos, sem conflitos, com a discrepância de contagem de testes formalmente explicada e catalogada, e pronto para a Auditoria Adversarial Integral (Fase B a F).
