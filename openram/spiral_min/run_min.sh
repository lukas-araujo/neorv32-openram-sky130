#!/usr/bin/env bash
#=============================================================================
# run_min.sh -- testes de tamanho da OpenRAM (Spiral, ping-pong, buffers)
#
# Uso (terminal normal, NAO dentro de nix develop):
#   source ~/Projects/env_openram.sh
#   bash run_min.sh d e f     # roda os testes indicados (letra = prefixo do .py)
#   bash run_min.sh           # sem argumento: g h
#=============================================================================
DIR="$(cd "$(dirname "$0")" && pwd)"
OPENRAM="$HOME/Projects/OpenRAM"          # raiz do repo (sram_compiler.py fica aqui)
mkdir -p "$DIR/logs" "$DIR/out"           # a OpenRAM usa os.mkdir: nao cria pais

roda () {
  local cfg="$1"; local nome; nome="$(basename "$cfg" .py)"
  echo "=================================================================="
  echo " $nome   ($(date +%H:%M:%S))"
  echo "=================================================================="
  local t0=$SECONDS
  python3 -u "$OPENRAM/sram_compiler.py" -v --keeptemp "$cfg" \
      2>&1 | tee "$DIR/logs/$nome.log"
  echo ">>> $nome: $((SECONDS - t0)) s" | tee -a "$DIR/logs/tempos.txt"
  # guarda os relatorios de DRC/LVS antes que o /tmp suma
  local tmp; tmp=$(grep -oE "/tmp/openram_[^ ]*_temp" "$DIR/logs/$nome.log" | head -1)
  if [ -n "$tmp" ] && [ -d "$tmp" ]; then
    mkdir -p "$DIR/relatorios/$nome"
    cp "$tmp"/*.lvs.report "$tmp"/*.drc.out "$tmp"/*.lvs.out "$DIR/relatorios/$nome/" 2>/dev/null
  fi
}

LETRAS=("$@"); [ ${#LETRAS[@]} -eq 0 ] && LETRAS=(g h)
for l in "${LETRAS[@]}"; do
  for cfg in "$DIR"/${l}_*.py; do [ -f "$cfg" ] && roda "$cfg"; done
done

echo
echo "=================== RESUMO ==================="
cat "$DIR/logs/tempos.txt"
for l in "$DIR"/logs/*.log; do
  echo "--- $(basename "$l")"
  grep -hE "Using bitcell|Minimum number of rows|ERROR|Rows: .* Cols:" "$l" | sort -u | head -4
done
for h in "$DIR"/out/*/*.html; do
  [ -f "$h" ] || continue
  echo "--- $(basename "$h")"
  grep -oE "Area \(&microm<sup>2</sup>\)</td><td>[^<]*" "$h" | sed 's/.*<td>/  Area (um2): /'
  grep -oE "(DRC|LVS) errors: [0-9]+" "$h" | sed 's/^/  /'
done
for l in "$DIR"/out/*/*.lef; do
  [ -f "$l" ] && echo "--- $(basename "$l"): $(grep -m1 -E '^\s*SIZE' "$l")"
done
