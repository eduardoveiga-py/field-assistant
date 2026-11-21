---
name: ios-offline-first-qa
description: Aplica checklist de compatibilidade iOS e arquitetura offline-first (Info.plist, GPS, Google OAuth iOS, Organic Maps URL scheme, Supabase E2EE e layout mobile) no field-assistant.
---

# Skill: iOS Offline-First QA

Esta skill define os requisitos obrigatórios para garantia de compatibilidade com a plataforma iOS, precisão de geolocalização no ministério em campo, integração com apps externos e segurança de dados offline-first.

## 1. Precisão de GPS e Configuração de Localização (`Info.plist` & Geolocator)

- **Precisão Plena no iOS:**
  - Garantir que `ios/Runner/Info.plist` configure:
    ```xml
    <key>NSLocationDefaultAccuracyReduced</key>
    <false/>
    ```
  - Ao requisitar localização ou streaming de GPS via `geolocator`, utilize explicitamente a configuração nativa da Apple:
    ```dart
    final locationSettings = AppleSettings(
      accuracy: LocationAccuracy.best,
      activityType: ActivityType.fitness,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: false,
    );
    ```
  - Isso evita que o iOS 14+ forneça uma aproximação de 1 a 5 km (approximate location) quando o publicador precisa marcar a casa exata no território.

## 2. Esquemas de URL e Integração com Organic Maps

- **Permissões em `LSApplicationQueriesSchemes`:**
  - Manter o identificador `om` (Organic Maps) e `om-scheme` dentro de `LSApplicationQueriesSchemes` no `ios/Runner/Info.plist`.
  - Essa configuração é estritamente necessária no iOS 9+ para permitir chamadas `canLaunchUrl(Uri.parse('om://...'))` antes de despachar coordenadas para navegação offline sem conexão celular.

## 3. Autenticação Google OAuth no iOS (`google_sign_in`)

- **Separação Rígida de Client IDs:**
  - No fluxo nativo iOS (`!kIsWeb`), NUNCA envie `GOOGLE_WEB_CLIENT_ID` como parâmetro `clientId` para o plugin `google_sign_in`.
  - No iOS nativo, o `clientId` deve ser lido diretamente do `GoogleService-Info.plist` ou omitido na inicialização para permitir resolução automática pelo SDK do Google.
  - O `serverClientId` pode receber o client ID web quando a intenção for obter um `idToken` para troca de sessão no backend/Supabase.

## 4. Feature Flag e Criptografia Ponta a Ponta (E2EE)

- **Injeção via `--dart-define` nos Workflows iOS:**
  - O código-fonte Dart deve obrigatoriamente manter `ENABLE_E2EE_SYNC` com `defaultValue: false`.
  - Em workflows de compilação iOS (`iphone-ipa-*.yml` / GitHub Actions), a flag deve ser ativada explicitamente nos comandos de build:
    ```bash
    flutter build ipa --release --dart-define=ENABLE_E2EE_SYNC=true ...
    ```
  - O aplicativo nunca deve depender de compilação com chaves expostas ou hardcoded.

## 5. Responsividade Mobile e Títulos de `AppBar` em Telas Estreitas

- **Prevenção de Truncamento de Título:**
  - Dispositivos como iPhone SE, iPhone mini e telas com escala de acessibilidade ativa possuem larguras úteis restritas (< 375pt).
  - Títulos de tela longos na `AppBar` devem ser protegidos contra corte ou overflow:
    - Envolver o `Text` do título em `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft)`.
    - Ou utilizar estilos tipográficos compactos através do `AppBarTheme` com `fontSize: 18` e `maxLines: 1`.
