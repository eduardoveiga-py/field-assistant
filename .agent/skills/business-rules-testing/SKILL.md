---
name: business-rules-testing
description: Padrões de testes automatizados para regras de negócio, contagem de estudos, disponibilidade da agenda e concorrência.
---

# Skill: Testes e Validação de Regras de Negócio

## Diretrizes
1. NUNCA altere ou enfraqueça testes para contornar falhas de build.
2. Todo cálculo do Dashboard deve ser coberto por testes que verifiquem casos com múltiplos participantes, sessões canceladas e tentativas sem contato.
3. Testes da agenda devem cobrir sobreposição parcial, sobreposição total e compromissos consecutivos sem intervalo.
4. Execute `flutter test` localmente para garantir regressão zero antes de relatar conclusões.
