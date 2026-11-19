#!/usr/bin/env bash
# Suspenso: a versão anterior criava um PMTiles sintético quando faltavam
# dependências e anunciava metadados sem verificação do conteúdo publicado.
# Não tocar em artefatos existentes: falhar antes de criar diretórios/arquivos.
set -euo pipefail
printf '%s\n' 'Construção vetorial suspensa: não existe pipeline validado para gerar e verificar um PMTiles real. Nenhum arquivo foi criado ou alterado.' >&2
exit 1
