# run_first.tcl -- na verdade um script SHELL, como no fluxo padrao.
# Uso:  source run_first.tcl     (a partir do bash)
#
# Descomente UM bloco de execucao por vez, no fim do arquivo.

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

#=============================================================================
# Variaveis do projeto usadas pelos blocos abaixo
#=============================================================================
export MACRO_NAME=sram_4kbyte_1rw_32x1024_8
export HEX_FILE=${PROJECT_DIR}/sw/neorv32_raw_exe.hex
export SIM_DIR=${PROJECT_DIR}/backend/synthesis/sim_postsyn
export DEV_DIR=${PROJECT_DIR}/backend/synthesis/deliverables

#=============================================================================
# 1) SINTESE -- GENUS
#=============================================================================

cd ${PROJECT_DIR}/backend/synthesis/work

## apenas o programa (modo interativo -- use para DEPURAR)
## depois, no prompt:  source ${PROJECT_DIR}/backend/synthesis/scripts/${DESIGNS}.tcl
#genus -abort_on_error -lic_startup Genus_Synthesis \
#      -lic_startup_options Genus_Physical_Opt -log genus -overwrite

## programa + script (sintese automatizada)
genus -abort_on_error -lic_startup Genus_Synthesis \
      -lic_startup_options Genus_Physical_Opt -log genus -overwrite \
      -files ${PROJECT_DIR}/backend/synthesis/scripts/${DESIGNS}.tcl

#=============================================================================
# 2) SIMULACAO POS-SINTESE -- XCELIUM
#
# ⚠️ COMECE SEM SDF. Sao duas perguntas independentes:
#      (a) o netlist funciona?        -> bloco 2a, atraso zero, rapido
#      (b) funciona com os atrasos?   -> bloco 2b, com SDF, lento
#    Misturar as duas na primeira tentativa e receita para nao saber o
#    que quebrou.
#
# ⚠️ SIMULACAO DE PORTAS E LENTA: ~9.230 celulas. Use programa MINIMO.
#    O objetivo nao e reexecutar o benchmark, e provar que o netlist sai
#    do reset e busca instrucao da memoria.
#
# PREPARO (uma vez): renomear o modelo comportamental da macro.
# Precisa, porque sram_lib_view_model.v usa o nome original -- senao ha
# colisao de modulo.
#=============================================================================

#mkdir -p ${SIM_DIR}
#sed "s/${MACRO_NAME}/${MACRO_NAME}_beh/g" \
#    ${PROJECT_DIR}/frontend/${MACRO_NAME}.v \
#    > ${SIM_DIR}/${MACRO_NAME}_beh.v

## --- 2a) SEM SDF: atraso zero. RODE ASSIM PRIMEIRO. ---
#cd ${SIM_DIR}
#xrun -64bit -access +rwc -timescale 1ns/1ps \
#  -v ${TECH_DIR}/verilog/primitives.v \
#  -v ${TECH_DIR}/verilog/sky130_fd_sc_hd.v \
#  ${DEV_DIR}/${DESIGNS}.v \
#  ${PROJECT_DIR}/backend/synthesis/scripts/sram_lib_view_model.v \
#  ${SIM_DIR}/${MACRO_NAME}_beh.v \
#  ${PROJECT_DIR}/backend/synthesis/scripts/tb_gate.v \
#  +MEM_FILE=${HEX_FILE} \
#  -top tb_gate 2>&1 | tee ${SIM_DIR}/xrun_nosdf.log

## --- 2b) COM SDF: timing real, bem mais lento. ---
#cd ${SIM_DIR}
#cat > ${SIM_DIR}/sdf.cmd << EOF
#COMPILED_SDF_FILE = "${DESIGNS}.sdf.X",
#  SCOPE = tb_gate.dut,
#  MTM_CONTROL = "TYPICAL",
#  SCALE_FACTORS = "1.0:1.0:1.0";
#EOF
#xrun -64bit -access +rwc -timescale 1ns/1ps \
#  -v ${TECH_DIR}/verilog/primitives.v \
#  -v ${TECH_DIR}/verilog/sky130_fd_sc_hd.v \
#  ${DEV_DIR}/${DESIGNS}.v \
#  ${PROJECT_DIR}/backend/synthesis/scripts/sram_lib_view_model.v \
#  ${SIM_DIR}/${MACRO_NAME}_beh.v \
#  ${PROJECT_DIR}/backend/synthesis/scripts/tb_gate.v \
#  +MEM_FILE=${HEX_FILE} \
#  -sdf_file ${DEV_DIR}/${DESIGNS}.sdf \
#  -sdf_cmd_file ${SIM_DIR}/sdf.cmd \
#  -top tb_gate 2>&1 | tee ${SIM_DIR}/xrun_sdf.log

## O que conferir no log:
##   1. "[TB] GPIO definido apos o reset"  -> sem propagacao de X
##   2. linhas "[TB:GPIO]" mudando          -> a CPU esta executando
##   3. grep -i "error\|timing violation" xrun_nosdf.log

#=============================================================================
# 3) EQUIVALENCIA LOGICA -- CONFORMAL LEC
#=============================================================================

#cd ${PROJECT_DIR}/backend/synthesis/work
#lec -xl -nogui -dofile ${PROJECT_DIR}/backend/synthesis/scripts/${DESIGNS}_lec.do \
#    -logfile ${PROJECT_DIR}/backend/synthesis/reports/${DESIGNS}_lec.log
