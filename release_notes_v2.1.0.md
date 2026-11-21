# Ministério Pessoal v2.1.0 — Redesign Minimalista, Map Engine Padrão Organic Maps e Inbox Pro

## 🚀 Destaques da Versão 2.1.0

### 🎨 Redesign Minimalista Profissional (Linear / Apple HIG)
- **Tema Sóbrio Flat**: Paletas refinadas em Dark Mode (`#0B0F17`) e Light Mode (`#F8FAFC`), elevação zero nos cards (`elevation: 0`), bordas sutis e tipografia compacta.
- **Sidebar & Shell de Navegação Neutros**: Fundo e ícones inativos monocromáticos sem saturações pesadas; seleção com pill translúcida na cor primária.
- **Tela "Hoje no Ministério" Reestilizada**:
  - Cabeçalho tipográfico limpo e sem caixas com bordas laranjas.
  - Bloco de progresso sem molduras aninhadas redundantes com números grandes em alto contraste (`FontFeature.tabularFigures()`).
  - Chips de filtro limpos (`Principais`, `Ministério`, `Produtividade`, `Todos`).
  - Cards de atalho padronizados em 40x40 com cantos arredondados e tipografia hierárquica.

### 🗺️ Map Engine Padrão Organic Maps (Fases 1, 2, 3 e 4)
- **Estilos Vetoriais**: Suporte a estilos vetoriais claros (`organic_maps_light.json`) e escuros (`organic_maps_dark.json`).
- **Overzoom Offline**: Algoritmo de overzoom contínuo para blocos MBTiles/PMTiles que permite navegar além do nível máximo sem telas pretas.
- **Aperfeiçoamentos Mobile**: Gestos de pinça (pinch-to-zoom) sem perda de orientação, bússola magnética nativa de 1 toque e GPS nativo com cone de direção.

### 📬 Inbox Pro & E-mails Exchange Multi-Contas
- **Filtros e Visual Profissional**: Filtros rápidos na Caixa de Entrada e lista de mensagens com tipografia fluida.
- **Exchange ActiveSync**: Resolução de envio com múltiplas contas e guarda no ciclo de `SyncKey`.
- **Anexos**: Abertura rápida de PDFs, documentos e imagens no Visualizador Universal.

### 🎨 Banco de Gravuras
- **Exclusão Rápida**: Botão de exclusão rápida integrado ao visualizador e galeria.
- **Super Zoom 10x**: Visualizador em tela cheia com zoom gestual contínuo de até 10x.

### 🛡️ Testes, Qualidade & CI/CD
- **Estabilidade de Rede**: Correção definitiva do teste de integração SMTP intermitente.
- **CI / CD Multiplataforma**: Concorrência de workflows, Dependabot groups e script pré-push padronizado (`tool/pre_push.ps1`).

---

## 📱 LiveContainer & AltStore (iOS)
Para atualizar ou instalar pelo LiveContainer / SideStore / AltStore, adicione a fonte oficial:
`https://github.com/eduardoveiga-py/field-assistant/releases/latest/download/apps.json`
