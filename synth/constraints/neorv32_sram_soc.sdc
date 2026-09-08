#-----------------------------------------------------------------------------
# neorv32_sram_soc.sdc
#
# Adaptado do sequential.sdc padrao da turma. Mesma estrutura, mesmas
# variaveis vindas do .tcl.
#
# ⚠️ SOBRE A QUALIDADE DESTE TIMING
# O .lib da macro de SRAM foi gerado com modelo analitico de Elmore, que
# IGNORA o slew de entrada (para slews variando 32x, o atraso reportado
# e identico). A sintese FECHA e produz numeros, mas eles NAO servem
# para conclusao de timing.
#
# Use para COMPARAR configuracoes entre si -- por exemplo os quatro
# valores de CPU_RF_ARCH_SEL -- nao como valores absolutos.
#-----------------------------------------------------------------------------

set sdc_version 1.5
current_design ${HDL_NAME}

#################################################################################
## IDEAL NETS
#################################################################################
set_ideal_net [get_nets ${MAIN_CLOCK_NAME}]
set_ideal_net [get_nets ${MAIN_RST_NAME}]

#################################################################################
## CLOCK
#################################################################################
create_clock -name ${MAIN_CLOCK_NAME} -period $period_clk \
             [get_ports ${MAIN_CLOCK_NAME}]
set_clock_uncertainty ${clk_uncertainty} [get_clocks ${MAIN_CLOCK_NAME}]
set_clock_latency ${clk_latency} [get_clocks ${MAIN_CLOCK_NAME}]

#################################################################################
## RESET
##
## DIFERENCA para o fluxo padrao: rstn_i e ASSINCRONO por projeto (o
## NEORV32 o declara assim). Nao faz sentido analisar timing nele.
##
## Atencao: isso desliga a analise, nao o problema. A REMOCAO do reset
## (recovery/removal) importa e so e verificavel apos a arvore de reset.
#################################################################################
set_false_path -from [get_ports ${MAIN_RST_NAME}]

#################################################################################
## INPUT PINS
#################################################################################
set entradas [remove_from_collection [all_inputs] \
              "[get_ports ${MAIN_CLOCK_NAME}] [get_ports ${MAIN_RST_NAME}]"]

set_input_delay -clock [get_clocks ${MAIN_CLOCK_NAME}] ${in_delay} $entradas

#################################################################################
## OUTPUT PINS
#################################################################################
set_output_delay -clock [get_clocks ${MAIN_CLOCK_NAME}] ${out_delay} [all_outputs]

#################################################################################
# DEFAULT OUTPUT PIN LOAD
#################################################################################
set_load -pin_load ${out_load} [get_ports [all_outputs]]

#################################################################################
## DEFAULT DRIVER
##
## Sem isto a ferramenta assume driver ideal e o timing sai otimista de
## forma irrealista.
#################################################################################
set_input_transition -rise -min $slew_min_rise $entradas
set_input_transition -fall -min $slew_min_fall $entradas
set_input_transition -rise -max $slew_max_rise $entradas
set_input_transition -fall -max $slew_max_fall $entradas
