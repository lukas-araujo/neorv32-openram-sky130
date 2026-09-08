#!/usr/bin/env bash
#=============================================================================
# sim/run_ghdl.sh
#
# Compila e simula o SoC no GHDL, com memoria IDEAL (xbus_memory.vhd).
# Este e o ambiente de iteracao rapida do notebook. O ambiente com a
# SRAM real e outro: Xcelium, na VM.
#
# NAO editamos arquivos do clone do NEORV32. O CFS e a unica substituicao,
# feita excluindo o original da lista de import.
#
# ⚠️ Rodar em terminal NORMAL, sem env_openram.sh (que exclui o
#    OSS CAD Suite, de onde vem o ghdl).
#
# Uso:
#   ./run_ghdl.sh                        # sem programa: so checa elaboracao
#   ./run_ghdl.sh app.hex                # com programa (5ms)
#   ./run_ghdl.sh app.hex 20ms           # tempo de parada customizado
#
# O caminho do .hex pode ser relativo ao diretorio onde VOCE esta.
#=============================================================================

set -e

#-----------------------------------------------------------------------------
# Resolver o caminho do HEX ANTES do 'cd'.
#
# BUG CORRIGIDO: o script faz 'cd' para o proprio diretorio, e um caminho
# relativo passado pelo usuario passava a ser interpretado a partir de
# sim/. Passar 'sw/app.hex' virava 'sim/sw/app.hex' -- arquivo nao
# encontrado, com mensagem que nao dizia o porque.
#-----------------------------------------------------------------------------
MEM_FILE_IN="${1:-}"
MEM_FILE_ABS=""
if [ -n "$MEM_FILE_IN" ]; then
  MEM_FILE_ABS="$(readlink -f "$MEM_FILE_IN" 2>/dev/null || true)"
fi

STOP_TIME="${2:-5ms}"

cd "$(dirname "$0")"

NEORV32_HOME="${NEORV32_HOME:-/home/lukas/Projects/neorv32}"
BUILD_DIR="build"
GHDL="${GHDL:-ghdl}"

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
# Excluimos neorv32_cfs.vhd do clone: usamos a NOSSA versao, analisada
# logo em seguida na mesma biblioteca. Assim o repositorio de terceiros
# fica intocado e nossa alteracao sobrevive a um 'git pull'.
find "$NEORV32_HOME/rtl/core" -name '*.vhd' ! -name 'neorv32_cfs.vhd' \
     -exec $GHDL -i $GHDL_OPTS --work=neorv32 {} +

$GHDL -i $GHDL_OPTS --work=neorv32 \
      ../rtl/neorv32_cfs.vhd \
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

if [ -n "$MEM_FILE_IN" ]; then
  if [ -z "$MEM_FILE_ABS" ] || [ ! -f "$MEM_FILE_ABS" ]; then
    echo "ERRO: arquivo HEX nao encontrado: $MEM_FILE_IN"
    echo "      (resolvido para: ${MEM_FILE_ABS:-<vazio>})"
    exit 1
  fi
  RUN_ARGS="$RUN_ARGS -gMEM_FILE=$MEM_FILE_ABS"
else
  echo "AVISO: sem arquivo HEX -- a CPU vai cair em excecao."
fi

# --ieee-asserts=disable silencia os avisos de 'metavalue detected' que
# aparecem no instante zero, antes do reset. Sao normais e escondem o
# que interessa.
$GHDL -r $GHDL_OPTS --work=work tb_neorv32_sram_soc $RUN_ARGS 2>&1 | tee ghdl.log

#-----------------------------------------------------------------------------
# A UART sai um caractere por linha de report. Remontar em texto legivel.
#-----------------------------------------------------------------------------
if grep -q "uart0:" ghdl.log 2>/dev/null; then
  echo
  echo "=== Saida da UART (remontada) ==="
  sed -n 's/.*uart0: \(.*\)$/\1/p' ghdl.log \
    | sed 's/^(13)$//; s/^(10)$/\n/' \
    | tr -d '\n' \
    | sed 's/\\n/\n/g'
  echo
fi

echo
echo "=== Log completo em sim/ghdl.log ==="
