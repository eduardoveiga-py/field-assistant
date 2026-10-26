---
name: ios-build-ci-cd
description: Configuração de integração contínua (GitHub Actions), compilação web e preparação para builds iOS em runners macOS.
---

# Skill: Build iOS e CI/CD

## Diretrizes
1. Preparar o workflow de CI em `.github/workflows/ci.yml` para executar:
   - `flutter analyze`
   - `flutter test`
   - `flutter build web --release`
   - Preparação de build iOS em runner `macos-latest` com `flutter build ios --no-codesign`.
2. Sem dependências secretas obrigatórias no pipeline para validação de testes.
3. Não versionar certificados ou perfis de provisionamento em texto claro no repositório.
