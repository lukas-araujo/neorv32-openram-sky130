# =====================================================================
# sw/cfs_benchmark/Makefile
#
# Programa de benchmark do CFS. Mora no NOSSO repositorio -- o clone do
# NEORV32 fica intocado e sobrevive a 'git pull'.
#
# Uso:
#   make            compila e gera neorv32_raw_exe.hex
#   make clean_all  limpa tudo
#
# Se o NEORV32 nao estiver em ~/Projects/neorv32:
#   make NEORV32_HOME=/outro/caminho
# =====================================================================

# ISA: precisa bater com a configuracao do hardware em
# rtl/soc_config_pkg.vhd e nos top-levels.
#   c        instrucoes comprimidas
#   m        mul/div
#   zicsr    acesso a CSR (necessario para ler mcycle)
#   zifencei fence.i
MARCH = rv32imc_zicsr_zifencei

# -Os: otimizar por tamanho. Com 3 kB de codigo, nao ha folga.
EFFORT = -Os

# ---------------------------------------------------------------------
# Particao da SRAM de 4 kB (decisao D17 do diario)
#
#   rom  0x00000000 .. 0x00000BFF   3 kB  codigo
#   ram  0x00000C00 .. 0x00000FFF   1 kB  dados + pilha
#
# O stack pointer nasce em ORIGIN(ram)+LENGTH(ram) = 0x00001000, topo
# da memoria. O codigo e o que aperta; por isso 3k/1k e nao 2k/2k.
# ---------------------------------------------------------------------
USER_FLAGS += -Wl,--defsym,__neorv32_rom_base=0x00000000
USER_FLAGS += -Wl,--defsym,__neorv32_rom_size=3072
USER_FLAGS += -Wl,--defsym,__neorv32_ram_base=0x00000C00
USER_FLAGS += -Wl,--defsym,__neorv32_ram_size=1024

# Descarta funcoes e dados nao usados. Sem isso o binario quase
# triplica -- ver a comparacao demo_gpio x demo_blink_led no diario.
USER_FLAGS += -ffunction-sections -fdata-sections -Wl,--gc-sections

NEORV32_HOME ?= /home/lukas/Projects/neorv32

include $(NEORV32_HOME)/sw/common/common.mk
