#!/usr/bin/env bash
#=============================================================================
# sim/run_ghdl.sh
#
# Compila e simula o SoC no GHDL, com memoria IDEAL (xbus_memory.vhd).
# Este e o ambiente de iteracao rapida do notebook. O ambiente com a
# SRAM real e outro: Xcelium, na VM.
#
# NAO editamos o sim/ghdl.sh do NEORV32 -- ele so enxerga os arquivos do
# proprio repositorio. Este script importa as duas arvores.
#
# ⚠️ Rodar em terminal NORMAL, sem env_openram.sh (que exclui o
#    OSS CAD Suite, de onde vem o ghdl).
#
# Uso:
#   ./run_ghdl.sh                        # sem programa: so checa elaboracao
#   ./run_ghdl.sh caminho/para/app.hex   # com programa
#   ./run_ghdl.sh app.hex 20ms           # com tempo de parada customizado
#=============================================================================

set -e
cd "$(dirname "$0")"

NEORV32_HOME="${NEORV32_HOME:-/home/lukas/Projects/neorv32}"
BUILD_DIR="build"
GHDL="${GHDL:-ghdl}"

MEM_FILE="${1:-}"
STOP_TIME="${2:-5ms}"

if [ ! -d "$NEORV32_HOME" ]; then
  echo "ERRO: NEORV32_HOME nao encontrado em '$NEORV32_HOME'"
  echo "Defina a variavel: NEORV32_HOME=/caminho ./run_ghdl.sh"
  exit 1
fi

GHDL_OPTS="--std=08 --workdir=$BUILD_DIR -P=$BUILD_DIR"

echo "=== Limpando ==="
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "=== Importando NEORV32 (biblioteca 'neorv32') ==="
$GHDL -i $GHDL_OPTS --work=neorv32 \
      "$NEORV32_HOME"/rtl/core/*.vhd \
      "$NEORV32_HOME"/sim/xbus_memory.vhd \
      "$NEORV32_HOME"/sim/sim_uart_rx.vhd

echo "=== Importando nossos fontes (biblioteca 'work') ==="
# Ordem importa: o pacote antes de quem o usa.
$GHDL -i $GHDL_OPTS --work=work \
      ../rtl/soc_config_pkg.vhd \
      ../rtl/neorv32_sram_soc_sim.vhd \
      tb_neorv32_sram_soc.vhd

echo "=== Analisando e elaborando ==="
$GHDL -m $GHDL_OPTS --work=work tb_neorv32_sram_soc

echo "=== Simulando (stop-time = $STOP_TIME) ==="
RUN_ARGS="--stop-time=$STOP_TIME --ieee-asserts=disable --assert-level=error"

if [ -n "$MEM_FILE" ]; then
  if [ ! -f "$MEM_FILE" ]; then
    echo "ERRO: arquivo HEX nao encontrado: $MEM_FILE"
    exit 1
  fi
  # Caminho absoluto: o GHDL roda a partir deste diretorio.
  MEM_FILE_ABS="$(readlink -f "$MEM_FILE")"
  RUN_ARGS="$RUN_ARGS -gMEM_FILE=$MEM_FILE_ABS"
else
  echo "AVISO: sem arquivo HEX -- a CPU vai cair em excecao."
fi

# --ieee-asserts=disable silencia os avisos de 'metavalue detected' que
# aparecem no instante zero, antes do reset. Sao normais e escondem o
# que interessa.
$GHDL -r $GHDL_OPTS --work=work tb_neorv32_sram_soc $RUN_ARGS 2>&1 | tee ghdl.log

echo
echo "=== Log completo em sim/ghdl.log ==="
