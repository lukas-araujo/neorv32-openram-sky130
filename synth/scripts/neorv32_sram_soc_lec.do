//=============================================================================
// neorv32_sram_soc_lec.do
//
// Conformal LEC: prova formal de que o netlist sintetizado e
// logicamente equivalente ao RTL.
//
// Projeto: neorv32-openram-sky130
//
//-----------------------------------------------------------------------------
// O QUE O LEC RESPONDE, E O QUE NAO RESPONDE
//-----------------------------------------------------------------------------
// O sintetizador REESCREVE o circuito inteiro: fatora expressoes,
// remapeia portas, compartilha logica. O netlist nao se parece com o
// RTL. Simular nao prova equivalencia -- cobre apenas os vetores que
// voce escreveu.
//
// O LEC compara MATEMATICAMENTE: particiona os dois circuitos em pontos
// de comparacao (registradores, saidas primarias) e prova que a logica
// combinacional entre eles e identica.
//
// O que ele NAO ve: inicializacao, comportamento de reset, propagacao
// de X, violacao de timing. Para isso e simulacao pos-sintese.
//
//   LEC       -> "e o mesmo circuito?"
//   simulacao -> "esse circuito funciona?"
//
// Sao perguntas diferentes e nenhuma substitui a outra.
//
//-----------------------------------------------------------------------------
// ⚠️ A MACRO DE SRAM PRECISA SER CAIXA-PRETA NOS DOIS LADOS
//-----------------------------------------------------------------------------
// A SRAM nao tem RTL -- ela vem do .lib. Se declarada caixa-preta em
// apenas UM dos lados, o Conformal acusa diferenca onde nao existe
// nenhuma, e voce perde a tarde procurando um bug que nao e seu.
//
// Por isso o 'add notranslate module' aparece com -both.
//
//-----------------------------------------------------------------------------
// ⚠️ E OS DOIS LADOS PRECISAM DA MESMA VIEW
//-----------------------------------------------------------------------------
// O RTL usa `ifdef para escolher entre a view de simulacao (33 bits,
// com spare_wen0) e a de sintese (32 bits, sem). O netlist foi
// sintetizado com SRAM_SYNTH_VIEW e SRAM_4KB.
//
// O lado GOLDEN tem que ser lido com as MESMAS macros, senao as
// interfaces divergem. Ver DIARIO.md.
//-----------------------------------------------------------------------------
// ⚠️ O CONFORMAL NAO USA SINTAXE TCL
//-----------------------------------------------------------------------------
// A primeira versao deste arquivo usava $env(PROJECT_DIR), como nos
// scripts do Genus. O Conformal tem linguagem de comandos propria e
// tratou isso como TEXTO LITERAL:
//
//   Error: Directory $env(TECH_DIR)/lib of file
//          '$env(TECH_DIR)/lib/...lib' does not exist.
//
// Por isso os caminhos aqui sao ABSOLUTOS. Se o projeto mudar de
// lugar, ajustar as ocorrencias de
//   /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc
//=============================================================================

// Nao abortar no primeiro aviso -- queremos o relatorio completo.
set log file /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/backend/synthesis/reports/lec_detail.log -replace

//-----------------------------------------------------------------------------
// Caixa-preta da macro de SRAM -- ANTES do read library
//
// Na primeira tentativa isto vinha DEPOIS e o Conformal avisou:
//   "Golden library has been read. This command has no effect on
//    existing library."
// Ou seja: nao adiantou nada. Declarar caixa-preta antes de ler as
// bibliotecas.
//-----------------------------------------------------------------------------
add notranslate module sram_4kbyte_1rw_32x1024_8 -both

//-----------------------------------------------------------------------------
// Biblioteca de celulas
//
// O Conformal precisa saber o que faz cada celula do netlist. Basta o
// .lib -- nao ha necessidade de LEF nem de QRC.
//-----------------------------------------------------------------------------
read library -liberty -statetable -both \
    /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/tech/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

//-----------------------------------------------------------------------------
// GOLDEN: o RTL
//
// ⚠️ MAPEAMENTO DA BIBLIOTECA LOGICA 'neorv32'
//
// Os fontes do NEORV32 fazem 'library neorv32;' e referenciam
// neorv32.<entidade>. Sem mapear, o Conformal le tudo em 'work' e
// falha:
//
//   Warning: library "neorv32" not defined or declared
//   Error:   entity not defined "neorv32.neorv32_prim_spram"
//
// Para PACOTES ele contorna sozinho (usa work.<pkg>), mas para
// INSTANCIACAO DIRETA DE ENTIDADE nao tem como -- o nome da biblioteca
// faz parte da referencia.
//
// A opcao -LIBRary <nome> <caminho> resolve (equivale a -Map).
// Foi o equivalente ao 'read_hdl -library neorv32' do Genus.
//-----------------------------------------------------------------------------
read design -vhdl -golden -lastmod -noelaborate \
    -library neorv32 /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/frontend/neorv32 \
    /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/frontend/neorv32/neorv32_package.vhd

read design -vhdl -golden -lastmod -noelaborate -append \
    -library neorv32 /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/frontend/neorv32 \
    /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/frontend/neorv32/*.vhd

// Nosso CFS substitui o template do NEORV32: mesma entidade, mesma
// biblioteca logica. Por isso vai DEPOIS e tambem mapeado.
read design -vhdl -golden -lastmod -noelaborate -append \
    -library neorv32 /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/frontend/neorv32 \
    /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/frontend/neorv32_cfs.vhd

// Nosso topo e o pacote de configuracao ficam em 'work'.
read design -vhdl -golden -lastmod -noelaborate -append \
    -library neorv32 /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/frontend/neorv32 \
    /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/frontend/soc_config_pkg.vhd \
    /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/frontend/neorv32_sram_soc.vhd

// Os Verilog, com AS MESMAS MACROS da sintese.
// Sem SRAM_4KB o shim instancia a macro de 1 kB -- foi o bug que custou
// horas na sintese (ver DIARIO.md).
read design -verilog2k -golden -lastmod -append \
    -define SRAM_SYNTH_VIEW -define SRAM_4KB \
    /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/frontend/sram_macro_shim.v \
    /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/frontend/sram_wb_wrapper.v

elaborate design -golden -root neorv32_sram_soc

//-----------------------------------------------------------------------------
// REVISED: o netlist
//-----------------------------------------------------------------------------
read design -verilog2k -revised -lastmod -netlist \
    /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/backend/synthesis/deliverables/neorv32_sram_soc.v

elaborate design -revised -root neorv32_sram_soc

//-----------------------------------------------------------------------------
// Comparacao
//-----------------------------------------------------------------------------
set system mode lec

report design data     > /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/backend/synthesis/reports/lec_design.rpt
report black box       > /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/backend/synthesis/reports/lec_blackbox.rpt
report unmapped points > /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/backend/synthesis/reports/lec_unmapped.rpt

add compared points -all
compare

//-----------------------------------------------------------------------------
// Relatorios
//
// O que conferir, em ordem:
//   1. lec_compare.rpt  -> tem que dizer 0 non-equivalent
//   2. lec_unmapped.rpt -> pontos nao mapeados sao suspeitos
//   3. lec_blackbox.rpt -> so a SRAM deve aparecer
//-----------------------------------------------------------------------------
report compare data   > /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/backend/synthesis/reports/lec_compare.rpt
report verification   > /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/backend/synthesis/reports/lec_verification.rpt
report statistics     > /prj/ci/workarea/aluno12/projetos/neorv32_sram_soc/backend/synthesis/reports/lec_statistics.rpt

exit -force
