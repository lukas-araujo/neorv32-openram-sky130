-- =====================================================================
-- tb_neorv32_sram_soc.vhd
--
-- Testbench do SoC para GHDL (memoria ideal).
--
-- Gera clock e reset, carrega o programa a partir de um arquivo HEX e
-- observa GPIO e UART.
--
-- Uso:
--   ghdl -r ... tb_neorv32_sram_soc -gMEM_FILE=<caminho.hex> --stop-time=5ms
--
-- Projeto: neorv32-openram-sky130
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;

use work.soc_config_pkg.all;

entity tb_neorv32_sram_soc is
  generic (
    -- Imagem do programa em HEX puro: 8 digitos hexadecimais por linha,
    -- uma palavra de 32 bits por linha. Gerado por:
    --   make ... hex   ->  neorv32_raw_exe.hex
    MEM_FILE : string := "";

    -- Baud rate esperado da UART. Precisa BATER com o que o software
    -- configura, senao o log sai como lixo.
    BAUD_RATE : real := 19200.0
  );
end entity;

architecture tb of tb_neorv32_sram_soc is

  constant CLK_PERIOD_C : time := 1 sec / CLK_FREQ_C;   -- 50 MHz -> 20 ns

  signal clk  : std_ulogic := '0';
  signal rstn : std_ulogic := '0';

  signal uart_txd : std_ulogic;
  signal gpio     : std_ulogic_vector(31 downto 0);

  signal gpio_ant : std_ulogic_vector(31 downto 0) := (others => 'U');

begin

  -- -------------------------------------------------------------------
  -- Clock e reset
  -- -------------------------------------------------------------------
  clk  <= not clk after CLK_PERIOD_C / 2;
  rstn <= '0', '1' after 10 * CLK_PERIOD_C;

  -- -------------------------------------------------------------------
  -- Sistema sob teste
  -- -------------------------------------------------------------------
  u_soc: entity work.neorv32_sram_soc_sim
  generic map (
    MEM_FILE => MEM_FILE
  )
  port map (
    clk_i       => clk,
    rstn_i      => rstn,
    uart0_txd_o => uart_txd,
    uart0_rxd_i => '1',      -- linha ociosa em nivel alto
    gpio_o      => gpio
  );

  -- -------------------------------------------------------------------
  -- Decodificador de UART: transforma a serial em texto no log.
  -- E o que permite ver printf sem abrir forma de onda.
  -- -------------------------------------------------------------------
  u_uart_rx: entity neorv32.sim_uart_rx
  generic map (
    NAME => "uart0",
    FCLK => real(CLK_FREQ_C),
    BAUD => BAUD_RATE
  )
  port map (
    clk => clk,
    rxd => uart_txd
  );

  -- -------------------------------------------------------------------
  -- Monitor de GPIO: reporta so quando MUDA.
  --
  -- Sem isso, um programa de blink encheria o log de linhas iguais.
  -- Reportar transicao em vez de estado e o que torna o log legivel.
  -- -------------------------------------------------------------------
  monitor_gpio: process(clk)
  begin
    if rising_edge(clk) then
      if (rstn = '1') and (gpio /= gpio_ant) then
        report "[TB:GPIO] " & to_hstring(gpio(7 downto 0)) &
               "  (t = " & time'image(now) & ")" severity note;
        gpio_ant <= gpio;
      end if;
    end if;
  end process;

  -- -------------------------------------------------------------------
  -- Aviso de arquivo ausente
  --
  -- Sem imagem, a memoria comeca zerada. Zero nao e instrucao valida em
  -- RISC-V, entao a CPU cai em excecao imediatamente. Melhor avisar do
  -- que deixar o usuario procurando causa.
  -- -------------------------------------------------------------------
  process
  begin
    if MEM_FILE = "" then
      report "[TB] MEM_FILE vazio: memoria zerada. A CPU vai buscar em " &
             "0x00000000, achar zeros e cair em excecao. Passe " &
             "-gMEM_FILE=<caminho.hex>." severity warning;
    else
      report "[TB] Carregando programa de '" & MEM_FILE & "'" severity note;
    end if;
    wait;
  end process;

end architecture;
