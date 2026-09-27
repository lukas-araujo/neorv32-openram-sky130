
#-----------------------------------------------------------------------------
# Create Library Domain
#
# DIFERENCA para o fluxo gpdk045
# ------------------------------
# O script padrao cria dois dominios, 'worst' e 'best', porque o gpdk045
# distribui os dois corners.
#
# Aqui usamos UM so. Motivo: a macro de SRAM da OpenRAM foi
# caracterizada apenas em TT 1.8V 25C (nominal_corner_only = True).
# Criar 'worst' e 'best' com as celulas padrao nao adiantaria -- nao
# existe o corner correspondente da memoria para casar.
#-----------------------------------------------------------------------------
create_library_domain {typ}
set_db lib_search_path "${LIB_DIR} ${LEF_DIR}"
set_db [get_db library_domains typ] .library ${TYP_LIST}
set_db [get_db library_domains typ] .default true

#-----------------------------------------------------------------------------
# Operating conditions
#-----------------------------------------------------------------------------
set_db [get_db library_domains *typ] .operating_conditions ${TYP_LIB_OPERATING_CONDITION}
get_db [get_db library_domains *typ] .operating_conditions

#=============================================================================
# LEF -- DELIBERADAMENTE NAO CARREGADO
#=============================================================================
#
# Na primeira tentativa carregamos os LEF de celula e o Genus abortou:
#
#   Error: The layer 'li1' referenced in pin 'A1_N' in macro
#          'sky130_fd_sc_hd__a2bb2o_1' is not found in the database.
#   Error: No capacitance or resistance specified. [PHYS-10]
#          Specify the tech LEF first.
#
# CAUSA: sky130_fd_sc_hd.lef e um LEF de MACROS -- descreve as celulas
# mas nao define as camadas (li1, met1, nwell). Essas definicoes ficam
# no TECHNOLOGY LEF, um arquivo separado que precisa vir antes.
#
# E havia um segundo problema, pior:
#
#   Warning: The library cell 'sram_4kbyte_1rw_32x1024_8' was marked
#            'avoid' because there was no physical data in the LEF file.
#
# Nossa macro foi gerada em modo front-end e NAO TEM LEF. Marcada como
# 'avoid', ela nao seria usada -- e o resultado sairia errado sem erro.
#
# DECISAO: nao carregar LEF.
#
# Para este fluxo o LEF nao serve para nada. Sem QRC e sem cap table
# (o sky130 aberto nao os distribui), estamos em modo wireload, que usa
# os modelos estatisticos do proprio .lib. LEF so seria necessario para
# estimativa fisica ou para o Innovus -- e para o Innovus faltaria o
# LEF da macro de qualquer forma.
#
# A area reportada vem do atributo 'area' das celulas no .lib, que
# existe e basta para comparar configuracoes.
#
#-----------------------------------------------------------------------------
# SE UM DIA FOR PRECISO CARREGAR LEF (ex.: caminho ate o Innovus):
#
#   1. Achar o technology LEF do sky130:
#        ls $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/techlef/
#      (normalmente sky130_fd_sc_hd__nom.tlef)
#
#   2. Carregar o tech LEF PRIMEIRO, depois os LEF de celula:
#        set_db lef_library {sky130_fd_sc_hd__nom.tlef
#                            sky130_fd_sc_hd.lef
#                            sky130_ef_sc_hd.lef}
#
#   3. Gerar a macro em modo BACK-END para ter o LEF dela, ou entao:
#        set_db lib_lef_consistency_check_enable false
#      (evita o 'avoid', mas a macro fica sem dados fisicos)
#=============================================================================

#-----------------------------------------------------------------------------
# Liberar a macro de SRAM
#
# O Genus marca 'avoid' e 'dont_use' automaticamente em qualquer
# lib_cell com area ZERO. Nossa macro veio da rodada FRONT-END da
# OpenRAM, que nao gera layout -- logo o .lib nao tem area.
#
# Sem isto a instancia nao vincula: fica como referencia nao resolvida,
# uma caixa-preta VAZIA. O resultado e traicoeiro:
#   - a sintese termina sem erro
#   - a area sai plausivel (so a logica)
#   - mas os caminhos de/para os pinos da memoria NAO sao analisados
#
# Diagnostico:
#   get_db [get_db lib_cells *sram*] .avoid    -> true
#   report_timing -to [get_pins -hier *u_sram*/*dout0*]  -> No paths found
#
# ⚠️ Mesmo liberada, a area continua ZERO nos relatorios. Isso so se
#    resolve com a rodada BACK-END da OpenRAM.
#-----------------------------------------------------------------------------
set_db [get_db lib_cells *sram_4kbyte*] .avoid false
set_db [get_db lib_cells *sram_4kbyte*] .dont_use false

#-----------------------------------------------------------------------------
# Interconnect
#
# 'ple' precisa de LEF + cap table/QRC. Sem eles, wireload.
# Menos preciso -- mas a precisao ja esta limitada por outro motivo: o
# .lib da nossa SRAM usa modelo analitico sem dependencia de slew.
#-----------------------------------------------------------------------------
set_db interconnect_mode wireload
get_db interconnect_mode

#-----------------------------------------------------------------------------
# Report important info
#-----------------------------------------------------------------------------
get_db [get_db library_sets *typ] .libraries
