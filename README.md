<div align="center">

# 📖 Ministério Pessoal
### *Gestão Eficiente, Discreta e Offline-First do Ministério de Campo*

[![Flutter](https://img.shields.io/badge/Flutter-3.27+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Offline First](https://img.shields.io/badge/Arquitetura-Offline--First-success?style=for-the-badge&logo=sqlite&logoColor=white)](https://drift.simonbinder.eu/)
[![Tests](https://img.shields.io/badge/Testes-549%20Passando%20(100%25)-brightgreen?style=for-the-badge&logo=checkmarx&logoColor=white)](https://github.com/eduardoveiga-py/field-assistant/actions)
[![Platforms](https://img.shields.io/badge/Plataformas-Android%20%7C%20iOS%20%7C%20Web-orange?style=for-the-badge)](https://github.com/eduardoveiga-py/field-assistant/releases)

<p align="center">
  <b>Um aplicativo completo, rápido e focado no usuário para organizar contatos, revisitas, estudos bíblicos, compromissos e relatórios mensais.</b><br>
  <i>Funciona 100% offline, sem anúncios, com privacidade absoluta e sincronização multi-dispositivo opcional.</i>
</p>

[📥 Baixar Aplicativo](#-downloads-e-instalação) • [✨ Recursos Principais](#-recursos-pensados-para-o-ministério) • [🚀 Guia Rápido de Uso](#-guia-rápido-de-uso) • [🔒 Privacidade e Segurança](#-privacidade-e-segurança-inviolável) • [🛠️ Para Desenvolvedores](#-desenvolvimento-e-compilação)

---

</div>

## 📥 Downloads e Instalação

Acesse a página de **[Releases Oficiais](https://github.com/eduardoveiga-py/field-assistant/releases/latest)** e baixe o instalador adequado para o seu dispositivo:

| Plataforma | Pacote | Como Instalar |
| :--- | :--- | :--- |
| **Android** | `app-release.apk` | Baixe diretamente no seu celular Android, abra o arquivo e confirme a instalação (ativando fontes desconhecidas se solicitado). |
| **iPhone / iPad** | `app-release-unsigned.ipa` | Instale no iOS usando ferramentas seguras de *sideloading* como **AltStore**, **Sideloadly** ou **TrollStore**. |
| **Navegador (Web)** | `web-release.zip` / Acesso Online | Acesse diretamente pelo Chrome ou Safari e clique em **"Adicionar à Tela de Início"** para instalar como PWA nativo com banco de dados local. |

> [!TIP]
> **Modo Offline Sem Conta**: Você não é obrigado a criar nenhuma conta para usar o aplicativo! Ao abrir pela primeira vez, basta tocar em **"Continuar em Modo Offline (Sem Conta)"** e o app funcionará imediatamente com armazenamento local no seu aparelho.

---

## ✨ Recursos Pensados para o Ministério

### 🚪 1. Briefing na Porta (30 Segundos)
Antes de bater à porta, consulte rapidamente um resumo estratégico do morador:
- **Onde paramos**: última lição e ponto do livro *Seja Feliz para Sempre!*.
- **Próximo passo acordado**: pendência ou pergunta que ficou pendente para o retorno.
- **Toque de empatia**: detalhes pessoais (ex: família, saúde, preferências) para uma conversa calorosa.
- **Data da última visita**: saiba com precisão quando foi o último contato.
- **Link Direto**: abra a lição correspondente diretamente no **JW Library** ou jw.org com um toque.

---

### 🎙️ 2. Anotação Rápida por Ditado de Voz
Enquanto caminha entre uma casa e outra, poupe tempo sem precisar digitar:
- Grave e dite uma nota de 15 segundos.
- O motor de inteligência determinística extrai automaticamente o **número da lição**, o **ponto considerado**, o nome do estudante e os pontos de empatia.
- Os campos são organizados e você salva o registro de visita em menos de 3 toques.

---

### 🗓️ 3. Agenda Inteligente & Feriados Nacionais
- **Anti-Colisão Estilo Consultório**: detecta sobreposições de horários e sugere horários livres no mesmo dia.
- **Feriados Brasileiros**: feriados nacionais (fixos e móveis calculados por Páscoa/Carnaval) aparecem destacados no calendário mensal para facilitar o planejamento de saídas de campo.
- **Sincronização com Google Calendar e Apple Calendar**: sincronize seus compromissos com sua agenda habitual fora do aplicativo.

---

### 🗺️ 4. Territórios e Mapas Offline
- Organize seu território por bairros, quadras e setores.
- **Download Offline**: baixe os mapas em níveis de zoom 13 a 17 para navegar em bairros e áreas remotas mesmo sem sinal de internet móvel.
- Filtro por cores de interessados, revisitas e estudos bíblicos diretamente no mapa.

---

### ☀️ 5. Modo Sol Intenso (Alto Contraste)
- No campo sob a luz forte do sol, ative o **Modo Sol** no topo da tela com um toque.
- O tema ajusta instantaneamente fontes, ícones e bordas pretas de alto contraste (**padrão WCAG AAA**), eliminando reflexos incômodos.

---

### 📊 6. Relatório e Contagem Rigorosa
- Regras oficiais e transparentes:
  - Casais ou famílias estudando juntos contam exatamente como **1 estudo bíblico**.
  - Apenas sessões de estudo efetivamente realizadas somam no mês.
  - Tentativas sem contato não são contadas como conversas.
- Acompanhamento do **Ritmo de Pioneiro** para planejar e atingir metas de horas com tranquilidade.

---

### 🔄 7. Sincronização Multi-Dispositivo
- Começou anotando no celular e quer continuar no tablet à noite?
- Ao conectar sua conta no Supabase, o app sincroniza automaticamente **todas as 17 tabelas** do sistema ao abrir a Splash Screen.
- Seus dados ficam protegidos e sincronizados entre todos os seus dispositivos.

---

## 🚀 Guia Rápido de Uso

```mermaid
flowchart LR
    A["👋 Início (Hoje)"] --> B["🚪 Briefing na Porta"]
    B --> C["💬 Conversa Realizada"]
    C --> D["🎙️ Ditado de Voz (15s)"]
    D --> E["📅 Agendar Próxima Visita"]
    E --> F["📊 Relatório Atualizado"]
```

1. **Adicionar Contato**:
   Na aba **Pessoas**, toque em `+` e informe o nome, endereço e preferências do morador.
2. **Iniciar um Estudo Bíblico**:
   No perfil da pessoa, vincule o estudo com a publicação *Seja Feliz para Sempre!*. O app acompanhará o progresso de cada lição.
3. **Registrar Visita**:
   Após falar com a pessoa, abra a tela dela ou use o ditado de voz no modal rápido. Confirme o que foi considerado e defina a data de retorno.
4. **Fechar o Mês**:
   Na aba **Atividades**, veja o total de horas, publicações entregues, vídeos mostrados, revisitas e estudos bíblicos prontos para envio.

---

## 🔒 Privacidade e Segurança Inviolável

- 🛡️ **Zero Telemetria / Sem Anúncios**: Seus contatos ministeriais e anotações pertencem apenas a você.
- 🔐 **Backups Criptografados de Ponta a Ponta**:
  - Criptografia militar **AES-256 GCM** com derivação de chave **PBKDF2** (100.000 iterações).
  - Exporte seu arquivo de backup com senha pessoal e restaure em qualquer aparelho.
- 📴 **100% Offline-First**: O banco de dados SQLite reside fisicamente na memória do seu próprio telefone.

---

## 🛠️ Desenvolvimento e Compilação

<details>
<summary><b>Clique para expandir instruções técnicas para desenvolvedores</b></summary>
<br>

### Pré-requisitos
- **Flutter SDK**: 3.27+ (canal estável).
- **Dart SDK**: 3.5+.
- **Java JDK**: 17 (Zulu ou OpenJDK).

### Instalação e Execução
```bash
# 1. Clonar repositório e obter dependências
git clone https://github.com/eduardoveiga-py/field-assistant.git
cd field-assistant
flutter pub get

# 2. Gerar código do banco Drift e Riverpod
dart run build_runner build --delete-conflicting-outputs

# 3. Executar em desenvolvimento
flutter run -d chrome      # Navegador Web
flutter run -d windows     # Desktop Windows
flutter run -d <device-id> # Dispositivo Android / iOS
```

### Qualidade de Código e Testes
```bash
# Análise estática obrigatória (zero warnings/erros)
dart analyze lib test --fatal-infos

# Suíte completa de testes automatizados com cobertura
flutter test --coverage
```

### Compilação de Produção
```bash
# Web SPA com SQLite Wasm
flutter build web --release

# Android APK
flutter build apk --release

# iOS (binário de release sem assinatura)
flutter build ios --no-codesign --release
```

### Estrutura de Pastas
```
lib/
  ├── core/            # Temas (SunMode), utilitários e constantes
  ├── database/        # Drift ORM (SQLite / Wasm) e repositório
  ├── appointments/    # Motor de agenda, colisões e feriados nacionais
  ├── contacts/        # Briefing na porta e gerenciamento de pessoas
  ├── studies/         # Gestão de estudos bíblicos e sessões
  ├── voice_notes/     # Gravador de áudio e parser inteligente
  ├── territory/       # Setores, geocodificação e cache de mapas
  ├── sync/            # Protocolo de sincronização offline com Supabase
  └── ui/              # Telas adaptativas e componentes de interface
```

</details>

---

## 📄 Licença

Desenvolvido para apoiar de forma pessoal, gratuita e voluntária o serviço de pregação cristão. Uso pessoal e comunitário incentivado.
