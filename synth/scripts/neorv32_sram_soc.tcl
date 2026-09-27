
# neorv32_sram_soc.tcl
# Sintese do SoC NEORV32 + SRAM OpenRAM em sky130.
# Adaptado do fluxo padrao da turma (sequential.tcl / gpdk045).

puts "  "
puts "=== neorv32_sram_soc :: sintese sky130 ==="
puts "  "

#-----------------------------------------------------------------------------
# Main Custom Variables Design Dependent
#-----------------------------------------------------------------------------
set PROJECT_DIR $env(PROJECT_DIR)
set DESIGNS     $env(DESIGNS)
set HDL_NAME    $env(HDL_NAME)

#-----------------------------------------------------------------------------
# Variaveis usadas no SDC
#
# Nomes de porta diferem do fluxo padrao: aqui sao clk_i e rstn_i.
#-----------------------------------------------------------------------------
set MAIN_CLOCK_NAME clk_i
set MAIN_RST_NAME   rstn_i

# 50 MHz -- tem que casar com CLK_FREQ_C de rtl/soc_config_pkg.vhd
set period_clk     20.0
set clk_uncertainty 2.0   ;# 10% do periodo, antes do CTS
set clk_latency     1.0
set in_delay        6.0   ;# 30% do periodo
set out_delay       6.0
set out_load        0.05  ;# pF

# Transicoes de entrada. Valores conservadores para sky130 a 1.8V.
set slew_min_rise 0.05
set slew_min_fall 0.05
set slew_max_rise 0.50
set slew_max_fall 0.50

#-----------------------------------------------------------------------------
# Bibliotecas
#
# UM corner so (ver comentario em common/tech.tcl).
# A macro de SRAM entra aqui como CAIXA-PRETA: o Genus le so o .lib
# dela e nunca olha para dentro.
#-----------------------------------------------------------------------------
set TYP_LIST {sky130_fd_sc_hd__tt_025C_1v80.lib
              sram_4kbyte_1rw_32x1024_8_TT_1p8V_25C.lib}

set TYP_LIB_OPERATING_CONDITION tt_025C_1v80

set LEF_LIST {sky130_fd_sc_hd.lef sky130_ef_sc_hd.lef}

#-----------------------------------------------------------------------------
# Load Path / Tech
#-----------------------------------------------------------------------------
source ${PROJECT_DIR}/backend/synthesis/scripts/common/path.tcl
source ${SCRIPT_DIR}/common/tech.tcl

#-----------------------------------------------------------------------------
# Analyze RTL
#
# TRES DIFERENCAS para o fluxo padrao:
#
# 1. LINGUAGEM MISTA. O topo e VHDL, mas o wrapper da SRAM e o shim sao
#    Verilog. Sao lidos com read_hdl separados.
#
# 2. BIBLIOTECA LOGICA 'neorv32'. Os fontes do NEORV32 declaram
#    'library neorv32; use neorv32.neorv32_package.all;'. Precisam ir
#    para essa biblioteca, nao para work.
#
# 3. ORDEM DOS ARQUIVOS VHDL IMPORTA. O GHDL resolve dependencias
#    sozinho; o Genus le na ordem dada. A lista em rtl_files.tcl foi
#    extraida do log do GHDL, que ja analisou na ordem correta.
#-----------------------------------------------------------------------------
set_db init_hdl_search_path "${FRONTEND_DIR} ${NEORV32_RTL_DIR} ${DEV_DIR}"

# Lista ordenada dos fontes do NEORV32 (gerada a partir do log do GHDL)
source ${SCRIPT_DIR}/rtl_files.tcl

read_hdl -language vhdl -library neorv32 $NEORV32_VHDL_FILES

# Nosso CFS: substitui o template do NEORV32, mesma entidade, mesma
# biblioteca. Por isso vai depois.
read_hdl -language vhdl -library neorv32 ${FRONTEND_DIR}/neorv32_cfs.vhd

# ⚠️ -define SRAM_SYNTH_VIEW e OBRIGATORIO.
# Sem ele, o RTL instancia a view de SIMULACAO da macro (33 bits de
# dado, com spare_wen0) e nao casa com o .lib (32 bits, sem spare_wen0).
# O erro apareceria como porta nao conectada ou macro nao resolvida.
read_hdl -language sv -define {SRAM_SYNTH_VIEW SRAM_4KB} \
    [list ${FRONTEND_DIR}/sram_macro_shim.v \
          ${FRONTEND_DIR}/sram_wb_wrapper.v]

# Nosso topo e o pacote de configuracao (biblioteca work)
read_hdl -language vhdl [list ${FRONTEND_DIR}/soc_config_pkg.vhd \
                              ${FRONTEND_DIR}/neorv32_sram_soc.vhd]

#-----------------------------------------------------------------------------
# Elaborate
#-----------------------------------------------------------------------------
elaborate ${HDL_NAME}
set_top_module ${HDL_NAME}

#-----------------------------------------------------------------------------
# check_design -unresolved  -- NAO PULE ESTA ETAPA
#
# Modulo nao resolvido vira caixa-preta SILENCIOSAMENTE: a sintese
# termina, o report_area sai bonito, e falta um pedaco do circuito.
#
# No nosso caso a macro de SRAM DEVE aparecer como caixa-preta (isso e
# correto, ela vem do .lib). Qualquer OUTRA coisa nao resolvida e bug.
#-----------------------------------------------------------------------------
check_design -unresolved ${HDL_NAME} > ${RPT_DIR}/${HDL_NAME}_unresolved.rpt
puts "--> conferir ${RPT_DIR}/${HDL_NAME}_unresolved.rpt"
check_library

#-----------------------------------------------------------------------------
# Constraints
#-----------------------------------------------------------------------------
read_sdc ${BACKEND_DIR}/synthesis/constraints/${HDL_NAME}.sdc

# check_timing: aponta caminho sem restricao, clock nao declarado,
# entrada sem input_delay. SDC ruim faz o timing "fechar" pelo motivo
# errado -- porque nao havia nada sendo verificado.
report timing -lint > ${RPT_DIR}/${HDL_NAME}_timing_lint.rpt

#-----------------------------------------------------------------------------
# Pos-elaborate
#-----------------------------------------------------------------------------
set_db auto_ungroup none

#-----------------------------------------------------------------------------
# Sintese
#-----------------------------------------------------------------------------
set_db syn_generic_effort medium
syn_generic ${HDL_NAME}

set_db syn_map_effort medium
syn_map ${HDL_NAME}

set_db syn_opt_effort medium
syn_opt

#-----------------------------------------------------------------------------
# Relatorios
#-----------------------------------------------------------------------------
report_design_rules  > ${RPT_DIR}/${HDL_NAME}_drc.rpt
report_area          > ${RPT_DIR}/${HDL_NAME}_area.rpt
report_timing        > ${RPT_DIR}/${HDL_NAME}_timing.rpt
report_gates         > ${RPT_DIR}/${HDL_NAME}_gates.rpt
report_qor           > ${RPT_DIR}/${HDL_NAME}_qor.rpt
report_power         > ${RPT_DIR}/${HDL_NAME}_power.rpt

# Area por hierarquia: e AQUI que se ve quanto custa cada bloco, e onde
# vamos ler o custo do banco de registradores no experimento do
# CPU_RF_ARCH_SEL.
report_area -depth 3  > ${RPT_DIR}/${HDL_NAME}_area_hier.rpt

write_sdf -edge check_edge -setuphold merge_always -nonegchecks \
          -recrem split -version 3.0 -design ${HDL_NAME} \
          > ${DEV_DIR}/${HDL_NAME}.sdf
write_hdl ${HDL_NAME} > ${DEV_DIR}/${HDL_NAME}.v

puts "  "
puts "=== fim. relatorios em ${RPT_DIR} ==="
puts "  "
