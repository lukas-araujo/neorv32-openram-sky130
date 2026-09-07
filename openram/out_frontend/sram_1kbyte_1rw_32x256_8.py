"""
SRAM 1 kB para o SoC NEORV32 (sky130).
Derivado de OpenRAM/macros/sram_configs/sky130_sram_1kbyte_1rw_32x256_8.py

MODO FRONT-END: sem layout, sem DRC/LVS. Serve para validar a
configuracao e alimentar a sintese no Genus. O GDS/LEF vem depois,
numa rodada back-end.
"""

# --- Geometria ---
word_size = 32
num_words = 256
write_size = 8            # byte write: necessario para sb/sh do RISC-V

# --- Portas ---
num_rw_ports = 1
num_r_ports = 0
num_w_ports = 0

# --- Redundancia para reparo ---
num_spare_rows = 1
num_spare_cols = 1

# --- Tecnologia ---
tech_name = "sky130"
nominal_corner_only = True
route_supplies = "ring"
uniquify = True

# --- Front-end: as tres linhas que mudam em relacao a oficial ---
netlist_only = True
check_lvsdrc = False
analytical_delay = True   # modelo analitico, sem simulacao SPICE

output_name = "sram_1kbyte_1rw_32x256_8"
output_path = "/home/lukas/Projects/neorv32-openram-sky130/openram/out_frontend"
