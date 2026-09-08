-- =====================================================================
-- soc_config_pkg.vhd
--
-- Configuracao unica do SoC, compartilhada pelos dois top-levels:
--   neorv32_sram_soc_sim.vhd  -> GHDL, memoria ideal (xbus_memory)
--   neorv32_sram_soc.vhd      -> Xcelium/Genus, SRAM OpenRAM real
--
-- Como os dois usam ESTE pacote, a configuracao do processador e
-- identica nos dois ambientes. So a memoria muda. E exatamente o
-- experimento que queremos: memoria ideal x memoria real, todo o
-- resto constante.
--
-- Projeto: neorv32-openram-sky130
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;

package soc_config_pkg is

  -- -------------------------------------------------------------------
  -- Clock
  -- -------------------------------------------------------------------
  -- 50 MHz. Confortavel para o sky130 e um numero redondo para
  -- calcular baud rate da UART.
  constant CLK_FREQ_C : natural := 50_000_000;

  -- -------------------------------------------------------------------
  -- Mapa de enderecos
  -- -------------------------------------------------------------------
  -- A SRAM externa fica em 0x00000000 e guarda CODIGO E DADOS juntos:
  -- sao 4 kB no total. O linker script tem que colocar tudo aqui e o
  -- stack pointer tem que comecar no topo (0x00000FFC).
  --
  -- Como a IMEM interna esta desligada, 0x00000000 esta livre.
  -- A regiao 0x80000000 (default da DMEM) tambem cai no XBUS, mas nao
  -- vamos usa-la.
  --
  -- O CFS NAO aparece aqui: ele e interno ao NEORV32 e o proprio
  -- processador o mapeia no espaco de IO automaticamente.
  constant SRAM_BASE_C : std_ulogic_vector(31 downto 0) := x"00000000";
  constant SRAM_SIZE_C : natural := 4*1024;   -- 4 kB = 1024 palavras

  -- log2 do numero de palavras. 1024 palavras -> 10 bits.
  constant SRAM_ADDR_BITS_C : natural := 10;

  -- Arquivo HEX de inicializacao (so no top de simulacao).
  constant SRAM_INIT_FILE_C : string := "";

  -- -------------------------------------------------------------------
  -- ⚠️ ESPELHAMENTO
  -- -------------------------------------------------------------------
  -- Nosso wrapper usa apenas os bits baixos do endereco e NAO decodifica
  -- faixa. Qualquer acesso que chegue ao XBUS -- de qualquer endereco --
  -- e atendido pela SRAM, espelhado a cada 4 kB.
  --
  -- Aceitavel num exercicio com um escravo so. Em projeto real, o
  -- escravo deve comparar os bits altos e responder err='1' fora da
  -- faixa. Fica registrado como simplificacao consciente.

  -- -------------------------------------------------------------------
  -- Estilo do banco de registradores (CPU_RF_ARCH_SEL)
  -- -------------------------------------------------------------------
  --   0 = sram_sync   memoria sincrona  (DEFAULT -- pensado para FPGA,
  --                   onde o sintetizador infere block RAM)
  --   1 = sram_async  memoria assincrona
  --   2 = reg         flip-flops explicitos  <- NOSSA ESCOLHA
  --   3 = latch       latches: menor area, mas latch em ASIC traz
  --                   problema de timing e de teste (DFT)
  --
  -- Em ASIC nao existe block RAM. Com sram_sync o Genus teria que
  -- improvisar a partir de uma descricao pensada para outra coisa.
  -- Flip-flops explicitos sao previsiveis.
  --
  -- ⚠️ EXPERIMENTO: sintetizar os quatro valores e comparar a area.
  -- E a tese do projeto -- registradores contra memoria -- medida no
  -- proprio processador. So este constante muda entre as rodadas.
  constant CPU_RF_ARCH_C : natural := 2;

  -- -------------------------------------------------------------------
  -- Particao de memoria para o linker
  -- -------------------------------------------------------------------
  -- O linker script sw/common/neorv32.ld usa simbolos sobrescreviveis
  -- (padrao "DEFINED(x) ? x : default"), entao nao precisa ser editado.
  -- Basta passar via -Wl,--defsym:
  --
  --   __neorv32_rom_base = 0x00000000   __neorv32_rom_size = 2048
  --   __neorv32_ram_base = 0x00000800   __neorv32_ram_size = 2048
  --
  -- As duas regioes vivem DENTRO da nossa unica SRAM de 4 kB. O
  -- stack pointer nasce em ORIGIN(ram)+LENGTH(ram) = 0x00001000, o
  -- topo da memoria. A divisao 2k/2k e chute inicial -- ajustar
  -- conforme o tamanho real do programa.
  constant ROM_SIZE_C : natural := 2048;
  constant RAM_SIZE_C : natural := 2048;

end package;
