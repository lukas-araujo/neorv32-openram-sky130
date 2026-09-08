
#-----------------------------------------------------------------------------
# Common path variables (directory structure dependent)
#
# Adaptado do fluxo padrao da turma para o projeto neorv32-openram-sky130.
#-----------------------------------------------------------------------------
set BACKEND_DIR ${PROJECT_DIR}/backend
set SYNT_DIR ${BACKEND_DIR}/synthesis
set SCRIPT_DIR ${SYNT_DIR}/scripts
set RPT_DIR ${SYNT_DIR}/reports
set DEV_DIR ${SYNT_DIR}/deliverables
set LAYOUT_DIR ${BACKEND_DIR}/layout

#-----------------------------------------------------------------------------
# Setting rtl search directories
#
# DIFERENCA para o fluxo gpdk045: o RTL vem de duas arvores.
#   frontend/         -> nosso RTL (VHDL e Verilog)
#   frontend/neorv32/ -> fontes do NEORV32 (BSD-3-Clause)
#-----------------------------------------------------------------------------
set FRONTEND_DIR ${PROJECT_DIR}/frontend
set NEORV32_RTL_DIR ${FRONTEND_DIR}/neorv32

#-----------------------------------------------------------------------------
# Setting technology directories
#
# DIFERENCA para o fluxo gpdk045: o sky130 NAO esta instalado na maquina.
# Ele vem dentro do proprio pacote do projeto, em tech/.
# Isso e legal -- o sky130 e Apache 2.0.
#-----------------------------------------------------------------------------
set TECH_DIR ${PROJECT_DIR}/tech
set LIB_DIR ${TECH_DIR}/lib
set LEF_DIR ${TECH_DIR}/lef
