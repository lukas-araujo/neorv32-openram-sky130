#!/usr/bin/env bash
#=============================================================================
# synth/make_package.sh
#
# Monta a arvore do projeto no formato do fluxo Cadence da turma e gera
# um .tar.gz para enviar por sftp.
#
# Estrutura produzida (mesma do fluxo gpdk045 da turma):
#
#   neorv32_sram_soc/
#   |-- frontend/
#   |   |-- neorv32/                  fontes do NEORV32 (BSD-3)
#   |   `-- *.vhd *.v                 nosso RTL + modelo da SRAM
#   |-- tech/                         sky130 (Apache 2.0)
#   |   `-- lib/ lef/ verilog/
#   `-- backend/synthesis/
#       |-- scripts/  constraints/  reports/  deliverables/  work/
#
# POR QUE SO UM CORNER
# --------------------
# sky130_fd_sc_hd tem 18 corners, 437 MB. Levamos so tt_025C_1v80.
# Nao e economia: e CONSISTENCIA. A macro de SRAM foi caracterizada so
# em TT 1.8V 25C. Levar ss/ff das celulas padrao nao teria par na
# memoria e a analise ficaria inconsistente.
#
# ⚠️ NAO copiar NADA do PDK TSMC da VM (sob NDA). Este pacote leva
#    apenas sky130 (Apache 2.0), NEORV32 (BSD-3) e codigo nosso.
#=============================================================================

set -e
cd "$(dirname "$0")/.."
PROJ_ROOT="$(pwd)"

PDK_ROOT="${PDK_ROOT:-/home/lukas/Projects/pdks}"
NEORV32_HOME="${NEORV32_HOME:-/home/lukas/Projects/neorv32}"

DESIGN="neorv32_sram_soc"
CORNER="tt_025C_1v80"
SRAM_DIR="openram/out_4kb"
SRAM_NAME="sram_4kbyte_1rw_32x1024_8"

PKG="synth/pacote_vm/$DESIGN"

#-----------------------------------------------------------------------------
# Verificacoes previas: falhar cedo e com mensagem util
#-----------------------------------------------------------------------------
faltando=0
for f in "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__$CORNER.lib" \
         "$SRAM_DIR/${SRAM_NAME}_TT_1p8V_25C.lib" \
         "$SRAM_DIR/${SRAM_NAME}.v" \
         "synth/rtl_files.tcl" \
         "synth/constraints/${DESIGN}.sdc" \
         "synth/scripts/${DESIGN}.tcl"; do
  [ -e "$f" ] || { echo "FALTANDO: $f"; faltando=1; }
done
if [ "$faltando" = "1" ]; then
  echo
  echo "Gere synth/rtl_files.tcl com o GHDL antes (ver DIARIO.md)."
  exit 1
fi

echo "=== Limpando pacote anterior ==="
rm -rf synth/pacote_vm synth/pacote_vm.tar.gz
mkdir -p "$PKG"/frontend/neorv32
mkdir -p "$PKG"/tech/{lib,lef}
mkdir -p "$PKG"/backend/synthesis/{scripts/common,constraints,reports,deliverables,work}
mkdir -p "$PKG"/sw

#-----------------------------------------------------------------------------
# Tecnologia
#-----------------------------------------------------------------------------
echo "=== tech: .lib do corner $CORNER ==="
cp "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__$CORNER.lib" \
   "$PKG/tech/lib/"
cp "$SRAM_DIR/${SRAM_NAME}_TT_1p8V_25C.lib" "$PKG/tech/lib/"

echo "=== tech: .lef ==="
cp "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lef/"*.lef "$PKG/tech/lef/"

# Modelos Verilog das celulas padrao: necessarios para simulacao
# pos-sintese no Xcelium.
VLOG_DIR="$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog"
if [ -d "$VLOG_DIR" ]; then
  echo "=== tech: modelos Verilog das celulas padrao ==="
  mkdir -p "$PKG/tech/verilog"
  cp "$VLOG_DIR"/*.v "$PKG/tech/verilog/" 2>/dev/null || true
else
  echo "AVISO: $VLOG_DIR nao existe -- sem simulacao pos-sintese na VM."
fi

#-----------------------------------------------------------------------------
# Frontend (RTL)
#-----------------------------------------------------------------------------
echo "=== frontend: NEORV32 (sem o CFS -- usamos o nosso) ==="
find "$NEORV32_HOME/rtl/core" -name '*.vhd' ! -name 'neorv32_cfs.vhd' \
     -exec cp {} "$PKG/frontend/neorv32/" \;

echo "=== frontend: nosso RTL ==="
cp rtl/*.vhd rtl/*.v "$PKG/frontend/"

echo "=== frontend: modelo Verilog da SRAM (p/ simulacao) ==="
cp "$SRAM_DIR/${SRAM_NAME}.v" "$PKG/frontend/"

#-----------------------------------------------------------------------------
# Scripts e constraints
#
# Cada arquivo copiado individualmente. O script antigo usava
#   cp synth/*.tcl synth/*.sdc ... || echo AVISO
# e o glob que nao expandia fazia o cp retornar erro MESMO tendo
# copiado o resto -- gerando aviso falso. Aviso falso treina a pessoa a
# ignorar avisos, e um dia o aviso e verdadeiro.
#-----------------------------------------------------------------------------
echo "=== scripts e constraints ==="
cp "synth/scripts/${DESIGN}.tcl"     "$PKG/backend/synthesis/scripts/"
cp "synth/scripts/run_first.tcl"     "$PKG/backend/synthesis/scripts/"
cp "synth/rtl_files.tcl"             "$PKG/backend/synthesis/scripts/"
cp synth/scripts/common/*.tcl        "$PKG/backend/synthesis/scripts/common/"
cp "synth/constraints/${DESIGN}.sdc" "$PKG/backend/synthesis/constraints/"

#-----------------------------------------------------------------------------
# Software
#-----------------------------------------------------------------------------
if [ -f sw/cfs_benchmark/neorv32_raw_exe.hex ]; then
  echo "=== sw: imagem do benchmark ==="
  cp sw/cfs_benchmark/neorv32_raw_exe.hex "$PKG/sw/"
else
  echo "AVISO: hex nao encontrado -- rode 'make hex' em sw/cfs_benchmark"
fi

cp "$SRAM_DIR/${SRAM_NAME}.html" "$PKG/" 2>/dev/null || true

#-----------------------------------------------------------------------------
# Manifesto
#-----------------------------------------------------------------------------
cat > "$PKG/MANIFESTO.txt" << EOF
Projeto neorv32-openram-sky130 -- pacote para sintese no Cadence
Gerado em: $(date -Iseconds)

INSTALACAO NA VM
  Descompactar em  /prj/ci/workarea/<user>/projetos/
  Conferir USER em backend/synthesis/scripts/run_first.tcl
  Rodar:  cd backend/synthesis/scripts && source run_first.tcl

CORNER UNICO: $CORNER
  A macro de SRAM so foi caracterizada em TT 1.8V 25C. Outros corners
  das celulas padrao nao teriam par na memoria.

MACRO: $SRAM_NAME  (4 kB, 32x1024, byte-write, 1rw)
  Gerada com OpenRAM em modo front-end (netlist_only = True).

⚠️ O .lib usa modelo analitico de Elmore, SEM dependencia de slew:
   para slews variando 32x o atraso e identico. A sintese FECHA e
   produz numeros, mas eles NAO servem para conclusao de timing.
   Use para COMPARAR configuracoes entre si.

⚠️ DIVERGENCIA ENTRE AS VIEWS DA MACRO:
     .v  (simulacao) 33 bits de dado, tem spare_wen0
     .lib (sintese)  32 bits de dado, NAO tem spare_wen0
   Por isso o RTL usa \`ifdef SRAM_SYNTH_VIEW, e o script de sintese
   le os Verilog com  -define SRAM_SYNTH_VIEW.

⚠️ SEM QRC E SEM CAP TABLE: o sky130 aberto nao os distribui para o
   fluxo Cadence. Por isso interconnect_mode = wireload, nao ple.
   Consequencia: sem extracao RC confiavel; DRC/LVS ficam para o fluxo
   aberto (LibreLane), no notebook.

LICENCAS
  sky130   Apache 2.0
  NEORV32  BSD-3-Clause
  Nada aqui vem do PDK TSMC da VM (NDA).
EOF

#-----------------------------------------------------------------------------
# Compactar
#-----------------------------------------------------------------------------
echo "=== Compactando ==="
tar czf synth/pacote_vm.tar.gz -C synth/pacote_vm "$DESIGN"

echo
echo "=== Tamanhos ==="
du -sh "$PKG"/* | sort -h
echo "---"
du -sh synth/pacote_vm.tar.gz
echo
echo "Pronto: $PROJ_ROOT/synth/pacote_vm.tar.gz"
echo "Enviar por sftp e descompactar em /prj/ci/workarea/<user>/projetos/"
