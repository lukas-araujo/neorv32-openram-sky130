# run_first.tcl -- na verdade um script SHELL, como no fluxo padrao.
# Uso:  source run_first.tcl     (a partir do bash)

export DESIGNS="neorv32_sram_soc"
export USER=aluno12
export PROJECT_DIR=/prj/ci/workarea/${USER}/projetos/${DESIGNS}
export BACKEND_DIR=${PROJECT_DIR}/backend
export HDL_NAME=${DESIGNS}

# DIFERENCA para o fluxo gpdk045: o sky130 NAO esta instalado na
# maquina. Ele vem dentro do proprio projeto (Apache 2.0).
export TECH_DIR=${PROJECT_DIR}/tech

# ⚠️ PATH ENXUTO, DELIBERADAMENTE.
# O script padrao carrega Quantus, Pegasus, PVS, Spectre, Virtuoso e o
# PDK TSMC. Aqui carregamos so o necessario:
#   DDI221  -> Genus, Innovus
#   XCELIUM -> simulacao
#   SSV231  -> Tempus
#   CONFRML -> Conformal (LEC)
#
# Motivo: variaveis residuais apontando para outro PDK podem fazer o
# Genus pegar biblioteca errada SILENCIOSAMENTE.
#
# ⚠️ NAO incluir /pdk/TSMC/... -- material sob NDA, sem relacao com
#    este projeto.
export PATH=/tools/cadence/DDI221/bin:/tools/cadence/DDI221/tools/bin
export PATH=$PATH:/tools/cadence/XCELIUM2309/tools/bin/64bit
export PATH=$PATH:/tools/cadence/XCELIUM2309/tools/bin
export PATH=$PATH:/tools/cadence/SSV231/bin:/tools/cadence/SSV231/tools/bin
export PATH=$PATH:/tools/cadence/CONFRML232/bin:/tools/cadence/CONFRML232/tools/bin
export PATH=$PATH:/tools/bin
export PATH=$PATH:/home/${USER}/.local/bin:/home/${USER}/bin
export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin

## Para executar o GENUS
cd ${PROJECT_DIR}/backend/synthesis/work

## apenas o programa (modo interativo)
#genus -abort_on_error -lic_startup Genus_Synthesis \
#      -lic_startup_options Genus_Physical_Opt -log genus -overwrite

## programa + script (sintese automatizada)
genus -abort_on_error -lic_startup Genus_Synthesis \
      -lic_startup_options Genus_Physical_Opt -log genus -overwrite \
      -files ${PROJECT_DIR}/backend/synthesis/scripts/${DESIGNS}.tcl

## Simulacao pos-sintese no XCELIUM (depois da sintese)
#cd ${PROJECT_DIR}/frontend
#xrun -64bit -v200x -v93 \
#  -v ${PROJECT_DIR}/tech/verilog/primitives.v \
#  -v ${PROJECT_DIR}/tech/verilog/sky130_fd_sc_hd.v \
#  ${PROJECT_DIR}/backend/synthesis/deliverables/${DESIGNS}.v \
#  ${PROJECT_DIR}/frontend/sram_4kbyte_1rw_32x1024_8.v \
#  <testbench> \
#  -sdf_file ${PROJECT_DIR}/backend/synthesis/deliverables/${DESIGNS}.sdf \
#  -access +rwc
