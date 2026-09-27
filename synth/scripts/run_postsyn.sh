#!/usr/bin/env bash
#=============================================================================
# backend/synthesis/scripts/run_postsyn.sh
#
# Simulacao POS-SINTESE no Xcelium: netlist de portas + SDF + modelo da
# SRAM. Roda na VM.
#
# Uso:
#   ./run_postsyn.sh <arquivo.hex> [tempo_ns]
#
#-----------------------------------------------------------------------------
# ⚠️ COMECE SEM SDF
#-----------------------------------------------------------------------------
# Duas coisas podem dar errado aqui, e e melhor separa-las:
#   (1) o netlist funciona?          -> rode SEM SDF (SDF=0)
#   (2) funciona com os atrasos?     -> rode COM SDF (SDF=1)
#
# Sem SDF a simulacao e de atraso zero: rapida, e isola problema de
# logica e de inicializacao. Com SDF entra o timing real, fica bem mais
# lenta, e as falhas que aparecem sao de temporizacao.
#
# Misturar os dois na primeira tentativa e receita para nao saber o que
# quebrou.
#
#   SDF=1 ./run_postsyn.sh app.hex
#=============================================================================

set -e
cd "$(dirname "$0")/../../.."      # raiz do projeto
PROJ="$(pwd)"

HEXFILE="${1:-}"
STOPTIME="${2:-200000}"
SDF="${SDF:-0}"

PDK_V="$PROJ/tech/verilog"
DEV="$PROJ/backend/synthesis/deliverables"
SIMDIR="$PROJ/backend/synthesis/sim_postsyn"

if [ -z "$HEXFILE" ]; then
  echo "Uso: $0 <arquivo.hex> [tempo_ns]"; exit 1
fi
HEXABS="$(readlink -f "$HEXFILE")"

mkdir -p "$SIMDIR"

#-----------------------------------------------------------------------------
# Gerar o modelo comportamental renomeado
#
# Precisa ser renomeado porque o adaptador sram_lib_view_model.v usa o
# nome original. Sem isso, colisao de modulo.
#-----------------------------------------------------------------------------
MACRO=sram_4kbyte_1rw_32x1024_8
if [ ! -f "$SIMDIR/${MACRO}_beh.v" ]; then
  echo "=== Gerando ${MACRO}_beh.v ==="
  sed "s/${MACRO}/${MACRO}_beh/g" "$PROJ/frontend/${MACRO}.v" \
      > "$SIMDIR/${MACRO}_beh.v"
fi

#-----------------------------------------------------------------------------
# Checagens previas
#-----------------------------------------------------------------------------
for f in "$DEV/neorv32_sram_soc.v" "$PROJ/frontend/${MACRO}.v" \
         "$SIMDIR/../../../sim_postsyn_src/sram_lib_view_model.v"; do
  :
done

NETLIST="$DEV/neorv32_sram_soc.v"
[ -f "$NETLIST" ] || { echo "FALTA o netlist: $NETLIST"; exit 1; }

# Os modelos Verilog das celulas padrao vieram no pacote?
if [ ! -d "$PDK_V" ]; then
  echo "ERRO: $PDK_V nao existe."
  echo "Os modelos Verilog das celulas padrao nao vieram no pacote."
  echo "Sem eles nao ha simulacao pos-sintese."
  exit 1
fi

cd "$SIMDIR"

#-----------------------------------------------------------------------------
# Montar a linha de comando
#-----------------------------------------------------------------------------
ARGS=(
  -64bit
  -access +rwc
  -timescale 1ns/1ps
  # modelos das celulas padrao (-v = biblioteca, nao design)
  -v "$PDK_V/primitives.v"
  -v "$PDK_V/sky130_fd_sc_hd.v"
  # netlist
  "$NETLIST"
  # macro de SRAM: adaptador + modelo comportamental
  "$PROJ/backend/synthesis/scripts/sram_lib_view_model.v"
  "$SIMDIR/${MACRO}_beh.v"
  # testbench
  "$PROJ/backend/synthesis/scripts/tb_gate.v"
  # programa
  +MEM_FILE="$HEXABS"
  -top tb_gate
)

if [ "$SDF" = "1" ]; then
  SDFFILE="$DEV/neorv32_sram_soc.sdf"
  [ -f "$SDFFILE" ] || { echo "FALTA o SDF: $SDFFILE"; exit 1; }
  echo "=== COM SDF (lento) ==="
  # O SDF e anotado na instancia 'dut' do testbench
  cat > sdf.cmd << EOF
COMPILED_SDF_FILE = "neorv32_sram_soc.sdf.X",
  SCOPE = tb_gate.dut,
  MTM_CONTROL = "TYPICAL",
  SCALE_FACTORS = "1.0:1.0:1.0";
EOF
  ARGS+=( -sdf_file "$SDFFILE" -sdf_cmd_file sdf.cmd )
else
  echo "=== SEM SDF (atraso zero) -- rode assim PRIMEIRO ==="
fi

echo "=== xrun ==="
xrun "${ARGS[@]}" 2>&1 | tee xrun.log

echo
echo "=== Log em $SIMDIR/xrun.log ==="
echo
echo "O que conferir:"
echo "  1. [TB] GPIO definido apos o reset  -> sem propagacao de X"
echo "  2. linhas [TB:GPIO] mudando          -> a CPU esta executando"
echo "  3. grep -i 'error\\|\$finish\\|timing violation' xrun.log"
