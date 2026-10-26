# Resolução de Links e Publicações: Ministério Pessoal

## 1. Princípios e Diretrizes
O sistema tem como meta abrir as publicações na lição e, quando suportado com segurança, na seção ou parágrafo onde o estudo parou.
- **Transparência e Honestidade Técnica:** O aplicativo não inventa esquemas de URL privados nem promete deep linking para parágrafos específicos caso o protocolo oficial ou plataforma não ofereça suporte verificado.
- **Sem Raspagem Indevida:** Nenhuma engenharia reversa invasiva ou raspagem automatizada desautorizada de publicações protegidas é realizada.
- **Alternativa Confiável (Fallback):** Todo link que falhar ou não puder ser aberto via aplicativo JW Library oferecerá abertura direta na página oficial do jw.org ou cópia da referência textual para consulta manual.

---

## 2. Publicações Homologadas Inicialmente
1. **Brochura Seja Feliz para Sempre! — Introdução às Lições da Bíblia**
   - Código canônico: `lff` (brochura de 3 lições introdutórias).
   - Formato: Brochura impressa / digital / vídeos em línguas de sinais.
2. **Livro Seja Feliz para Sempre! — Você Pode Desfrutar de Uma Vida Feliz para Sempre**
   - Código canônico: `lff` (livro completo de 60 lições).
   - Formato: Livro completo / digital / vídeos.

---

## 3. Idiomas Suportados na Primeira Fase
- **Português (`pt`):** Livro e Brochura completamente indexados por Lição (1 a 60) e seções de parágrafos.
- **Ticuna (`tca`):** Publicações disponíveis no catálogo oficial; o resolvedor valida a existência antes de apresentar deep link.
- **Língua Brasileira de Sinais - Libras (`bzs`):** O conteúdo em Libras é distribuído predominantemente em vídeos por tópicos/lições. O resolvedor reconhece a modalidade em vídeo e fornece o link oficial correspondente à lição em vídeo, sem forçar divisões artificiais de parágrafos textuais.

---

## 4. O Componente `PublicationLinkResolver`
O `PublicationLinkResolver` é uma classe pura, altamente testável, com as seguintes responsabilidades:
1. **Modelagem:** Recebe publicação, idioma, lição, parágrafo ou referência em vídeo.
2. **Resolução de URL:** Monta o link oficial verificado (exemplo: URLs padronizadas de compartilhamento `jw.org/finder?srcid=jwlshare&wtlocale=...`).
3. **Classificação de Precisão do Link:**
   - `directLesson`: Abre diretamente a lição específica.
   - `publicationOnly`: Abre o índice da publicação (quando o deep link de lição não estiver disponível no idioma).
   - `referenceOnly`: Apenas texto de referência para consulta no aplicativo físico ou JW Library.
4. **Registro de Validação:** Mantém o status (`verified`, `provisional`, `unsupported`) sem corromper as anotações do estudo bíblico.
