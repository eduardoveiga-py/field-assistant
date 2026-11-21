---
trigger: always_on
description: Regras obrigatórias de governança, CI, multiplataforma Web/iOS/Windows e workflow para todas as sessões de desenvolvimento no repositório field-assistant.
---

# Field Assistant CI Gate & Always-On Rules

Estas regras são de cumprimento obrigatório para o assistente em **toda e qualquer sessão** de desenvolvimento, manutenção, refatoração e auditoria no repositório `field-assistant`.

## Diretrizes Mandatórias de Sessão

1. **Leitura de Governança:**
   - Ler `AGENTS.md` antes de planejar alterações no repositório.

2. **Consulta a Especialistas (Skills):**
   - Consultar `.agents/skills/` sempre que a tarefa envolver:
     - Motor de mapas offline: `.agents/skills/map-engine-architect/SKILL.md`
     - Compatibilidade iOS e arquitetura offline-first: `.agents/skills/ios-offline-first-qa/SKILL.md`
     - Validação e preparação de Pull Request: `.agents/skills/flutter-pre-pr-gate/SKILL.md`

3. **Planejamento Prévio de Arquivos:**
   - Planejar brevemente os arquivos que serão tocados antes de iniciar as edições no código.

4. **Multiplataforma e Web-Safety (Conditional Imports):**
   - Nunca importar `dart:io` ou `package:sqlite3/sqlite3.dart` sem *conditional import* (`*_io.dart` / `*_web.dart`) em código alcançável pela Web.

5. **Feature Flag E2EE (Defesa em Profundidade):**
   - Manter `ENABLE_E2EE_SYNC` com `defaultValue: false` no código-fonte (ativação exclusiva via `--dart-define` no workflow).

6. **Desalocação de Recursos SQLite (Windows CI):**
   - Sempre fechar conexões SQLite (`db.close()` / `db.dispose()`) em métodos `stop()` e `dispose()` para evitar bloqueios de arquivo (file lock) no CI Windows.

7. **Validação Pré-Push / Pré-PR:**
   - Nunca fazer `git push` nem abrir PR sem antes executar `.\tool\pre_push.ps1` e `flutter test` do módulo alterado com exit code 0.
