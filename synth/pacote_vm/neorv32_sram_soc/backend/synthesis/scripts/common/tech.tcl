
#-----------------------------------------------------------------------------
# Create Library Domain
#
# DIFERENCA IMPORTANTE para o fluxo gpdk045
# -----------------------------------------
# O script padrao cria dois dominios, 'worst' e 'best', porque o gpdk045
# distribui os dois corners.
#
# Aqui usamos UM dominio so. Motivo: a macro de SRAM gerada pela OpenRAM
# foi caracterizada apenas em TT 1.8V 25C (nominal_corner_only = True).
# Criar 'worst' e 'best' com as celulas padrao nao adiantaria -- nao
# existe o corner correspondente da memoria para casar, e a analise
# ficaria inconsistente.
#
# Se um dia a macro for gerada em multiplos corners, basta voltar a
# estrutura de dois dominios do script original.
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

#-----------------------------------------------------------------------------
# LEF
#-----------------------------------------------------------------------------
set_db lef_library ${LEF_LIST}

#-----------------------------------------------------------------------------
# QRC / Cap table -- INDISPONIVEIS NO SKY130
#
# O sky130 aberto NAO distribui techfile QRC nem cap table para o fluxo
# Cadence (existem so na versao proprietaria, sob NDA).
#
# Consequencia: nao da para usar 'interconnect_mode ple', que precisa
# desses dados para estimar parasitas a partir do LEF. Ficamos com
# wireload, que usa os modelos estatisticos do proprio .lib.
#
# Menos preciso -- mas a precisao ja esta limitada por outro motivo:
# o .lib da nossa SRAM usa modelo analitico sem dependencia de slew.
#
#set_db cap_table_file ...   # indisponivel
#set_db qrc_tech_file ...    # indisponivel
#-----------------------------------------------------------------------------
set_db interconnect_mode wireload
get_db interconnect_mode

#-----------------------------------------------------------------------------
# Report important info
#-----------------------------------------------------------------------------
get_db [get_db library_sets *typ] .libraries
