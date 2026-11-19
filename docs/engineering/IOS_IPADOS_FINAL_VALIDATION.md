# FIELD ASSISTANT — VALIDAÇÃO FINAL IOS E IPADOS
**Documento de Engenharia de Plataforma Mobile — FAES §4 & Ordem Mestra Parte XI**  
**Projeto:** Field Assistant  
**Plataformas Alvo:** iPhone (iOS 15.5+) e iPad (iPadOS 15.5+)  
**Data:** 18 de Novembro de 2026  
**Status:** **HOMOLOGADO E APROVADO (10/10)**

---

## 1. ESCOPO E FILOSOFIA DE EXPERIÊNCIA DE USO

O **Field Assistant** adota o iPad não como um telefone ampliado, mas como uma estação de trabalho para o ministério de campo em veículos e embarcações. Este documento atesta a homologação das características nativas de hardware, sistema e acessibilidade no ecossistema Apple.

---

## 2. ADAPTABILIDADE IPADOS & MULTITAREFA (SPLIT VIEW)

### 2.1. Viewports Homologados
- **Compact Phone (320px a 375px):** Interface de coluna única com navegação inferior tátil e painéis modais recolhíveis.
- **iPad Split View (678px):** Adaptação responsiva instantânea sem perda de estado ao redimensionar a divisória de tela.
- **iPad Landscape Full (1024px a 1366px):** Layout Master-Detail simultâneo: lista de contatos/estudos à esquerda e mapa vetorial interativo à direita.
- **Rotação Rápida de Orientação:** Alternância contínua entre retrato (*portrait*) e paisagem (*landscape*) sem vazamentos de memória ou estouros de renderização (`RenderFlex overflow = 0`).

---

## 3. ACESSIBILIDADE UNIVERSAL E USO SOB LUZ SOLAR

### 3.1. Dynamic Type e Escala de Texto
- O layout foi testado e aprovado sob o `TextScaler` do iOS em fatores de $2{,}0\times$ e $2{,}5\times$ (maior escala de acessibilidade do sistema).
- Nenhum botão de ação rápida tem seu texto truncado de forma inacessível; rótulos longos utilizam expansão vertical fluida.

### 3.2. VoiceOver e Alvos de Toque
- Todos os elementos interativos possuem rótulos Semantics descritivos em português e contexto de estado (ex.: *"Botão: Alternar para Modo Satélite, atualmente Vetorial"*).
- Alvos de toque estritamente dimensionados para o mínimo de $48 \times 48\text{ dp}$ da Apple Human Interface Guidelines.

### 3.3. Tema de Alto Contraste Solar
- Paleta cartográfica com taxa de contraste WCAG AAA para uso sob luz solar intensa em barcos e caminhadas abertas.

---

## 4. INTEGRAÇÃO EVENTKIT COM PROTEÇÃO CONTRA APAGAMENTO EM MASSA

- **Sincronização com Calendário iOS:** Sincronização bidirecional de agendamentos ministeriais e revisitas via EventKit.
- **Fingerprint Criptográfico SHA-256:** Cada evento gerado recebe um hash de conteúdo calculado com SHA-256; eventos inalterados no dispositivo não são sobrescritos desnecessariamente.
- **Mass Deletion Shield (Blindagem de Exclusão em Massa):** Caso o calendário do iOS seja limpo acidentalmente por desvinculação de conta do iCloud, um disparador de anomalia bloqueia a exclusão dos contatos e agendamentos no banco local Drift, exigindo confirmação explícita do usuário.

---

## 5. EVIDÊNCIAS DE TESTES DE HOMOLOGAÇÃO

| Caso de Teste | Descrição da Prova | Resultado |
|:---|:---|:---:|
| **TC-F1-01** | Renderização em 375px sem RenderFlex overflow | ✅ PASSOU |
| **TC-F1-02** | Dynamic Type 2.0x em tela estreita sem truncamento indevido | ✅ PASSOU |
| **TC-F15-B05** | Rotação rápida retrato/paisagem no iPad em mapa e agendamentos | ✅ PASSOU |
| **Tier4-Scenario6** | Multitarefa em Split View 678px e Master-Detail 1024px em barco/carro | ✅ PASSOU |
| **Tier4-Scenario8** | Sincronização EventKit + Blindagem contra apagamento em massa | ✅ PASSOU |
