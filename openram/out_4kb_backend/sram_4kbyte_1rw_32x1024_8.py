"""
SRAM 4 kB para o SoC NEORV32 (sky130) -- RODADA BACK-END.

Projeto: neorv32-openram-sky130

------------------------------------------------------------------------
DIFERENCA EM RELACAO A RODADA FRONT-END
------------------------------------------------------------------------
A config front-end (sram_32x1024_frontend.py) tinha tres linhas que
desligavam o trabalho pesado:

    netlist_only     = True     # nao gerava layout
    check_lvsdrc     = False    # nao rodava DRC/LVS
    analytical_delay = True     # timing por modelo, sem SPICE

Aqui as duas primeiras saem. O layout e gerado e verificado.

------------------------------------------------------------------------
O QUE ESTA RODADA RESOLVE
------------------------------------------------------------------------
1. AREA REAL da macro. O .lib front-end tem area = 0, e por isso o
   Genus marcava a celula como 'avoid'/'dont_use' automaticamente.
   Tambem por isso a comparacao com o banco de registradores era
   extrapolacao (41,4 um2/bit x 32768 bits) em vez de medicao.

2. O .lef, que faltava para o Innovus e para qualquer analise fisica.

3. O .gds, necessario para o fluxo LibreLane (Fase 6).

------------------------------------------------------------------------
⚠️ TEMPO
------------------------------------------------------------------------
Referencias medidas neste projeto:
    1 kB front-end ....... 151 s
    4 kB front-end ....... 2457 s  (41 min)

O back-end acrescenta geracao de layout, roteamento de alimentacao,
DRC e LVS. Nao temos referencia -- estime VARIAS HORAS e rode com
nohup, de madrugada.

⚠️ Esta e a PRIMEIRA vez que o projeto exercita Magic e Netgen. Ate
agora o toolchain do Nix so foi usado para gerar netlist. Falhas
podem aparecer em pontos desconhecidos.

------------------------------------------------------------------------
NAO MEXER: as celulas sobressalentes sao OBRIGATORIAS
------------------------------------------------------------------------
Em sky130 as bitcells sao espelhadas e compartilham contatos -- so
existem em pares. A OpenRAM exige total PAR nos dois eixos:

    128 colunas de dados + 1 replica bitline  = 129, impar
     64 linhas          + 1 linha dummy       = 65, impar

A linha e a coluna sobressalentes sao o que restaura a paridade. Sem
elas a memoria NAO COMPILA (ja testado -- ver DIARIO.md).
------------------------------------------------------------------------
"""

# --- Geometria ---
word_size  = 32
num_words  = 1024          # 4 kB
write_size = 8             # byte write: necessario para sb/sh do RISC-V

# --- Portas ---
num_rw_ports = 1
num_r_ports  = 0
num_w_ports  = 0

# --- Redundancia: OBRIGATORIA, ver acima ---
num_spare_rows = 1
num_spare_cols = 1

# --- Tecnologia ---
tech_name = "sky130"
nominal_corner_only = True
route_supplies = "ring"
uniquify = True

# --- BACK-END ---
# netlist_only removido  -> gera layout
check_lvsdrc = True       # roda DRC e LVS

# Mantemos o modelo analitico. Caracterizacao SPICE de verdade
# (analytical_delay = False) somaria MUITO tempo, e a limitacao de
# slew do .lib nao e o gargalo agora -- o que falta e AREA e LEF.
# Fica para uma terceira rodada, se o timing virar prioridade.
analytical_delay = True

output_name = "sram_4kbyte_1rw_32x1024_8"
output_path = "/home/lukas/Projects/neorv32-openram-sky130/openram/out_4kb_backend"
