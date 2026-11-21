## Resumo
<!-- Descreva de forma concisa o objetivo deste Pull Request e o problema resolvido. -->

## Alterações principais
<!-- Liste os arquivos e módulos modificados com o resumo das mudanças. -->
- 

## Checklist
- [ ] `.\tool\pre_push.ps1` executado localmente com sucesso (formatação e análise estática exit code 0).
- [ ] Testes unitários adicionados ou atualizados (`flutter test` passou com exit code 0).
- [ ] Sem import direto de `dart:io` ou `package:sqlite3/sqlite3.dart` em código alcançável pela Web (uso correto de *conditional imports*).
- [ ] Conexões SQLite, recursos e streams/sinks devidamente fechados (`stop()` / `dispose()`).
- [ ] Mensagens de commit no padrão Conventional Commits.
