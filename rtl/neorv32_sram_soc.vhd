-- =====================================================================
-- neorv32_sram_soc.vhd
--
-- Top-level REAL do SoC: NEORV32 + SRAM da OpenRAM em sky130.
-- Alvo: Xcelium (simulacao mista) e Genus (sintese), na VM da faculdade.
--
-- Este e o gemeo de neorv32_sram_soc_sim.vhd. A configuracao do
-- processador vem do mesmo soc_config_pkg.vhd -- a UNICA diferenca e a
-- memoria: aqui entra o wrapper Verilog com a macro real, la entrava o
-- modelo ideal xbus_memory.
--
-- ⚠️ Este arquivo instancia um modulo VERILOG (sram_wb_wrapper) a
-- partir de VHDL. Exige ferramenta com suporte a linguagem mista:
-- Xcelium e Genus tem; GHDL NAO tem. Por isso os dois top-levels.
--
-- Ordem de leitura na sintese:
--   read_hdl -define SRAM_SYNTH_VIEW {sram_macro_shim.v sram_wb_wrapper.v}
--   read_hdl -vhdl {soc_config_pkg.vhd neorv32_sram_soc.vhd}
--   (mais os fontes do NEORV32 e o .lib da macro)
--
-- =====================================================================
-- O QUE ESTA LIGADO E POR QUE
-- =====================================================================
--
--   RISCV_ISA_C       instrucoes comprimidas de 16 bits. Com 4 kB para
--                     codigo e dados, densidade importa.
--   RISCV_ISA_M       multiplicacao e divisao; rende conteudo de
--                     sintese e qualquer programa real usa.
--   RISCV_ISA_Zicntr  contadores. E como vamos MEDIR o ganho do
--                     somador em hardware contra a soma em software.
--   XBUS_EN           interface externa onde vive a SRAM.
--   IO_CFS_EN         onde entra o somador.
--   IO_UART0_EN       visibilidade na simulacao.
--   IO_GPIO_NUM       sinalizacao barata.
--   IO_CLINT_EN       temporizador e interrupcoes.
--
-- =====================================================================
-- O QUE ESTA DESLIGADO E POR QUE
-- =====================================================================
--
--   IMEM_EN/DMEM_EN   O PONTO DO PROJETO. Sao arrays em VHDL que
--                     virariam um mar de flip-flops no ASIC --
--                     estimados em mais de 15x a area de uma SRAM
--                     equivalente. Substituidas pela macro OpenRAM.
--   DUAL_CORE_EN      complexidade sem retorno didatico aqui.
--   ICACHE/DCACHE     redundantes com 4 kB externos; atrapalhariam a
--                     analise de timing do XBUS.
--   OCD_EN            exige JTAG.
--   XBUS_REGSTAGE_EN  desligado de proposito. Ligar ajuda o timing e
--                     custa um ciclo -- vale comparar depois.
--   CPU_FAST_MUL_EN   usa DSP: existe em FPGA, nao em ASIC.
--   CPU_FAST_SHIFT_EN barrel shifter, bem maior. Bom experimento de
--                     area para ligar e comparar.
--   CPU_RF_ARCH_SEL   NAO usa o default. O default (0=sram_sync) e
--                     pensado para FPGA; usamos 2 (flip-flops). Ver
--                     soc_config_pkg.vhd.
--   demais perifericos so somariam area e ruido.
--
-- BOOT: modo 1 (endereco customizado) = SRAM_BASE_C. O modo 2 exigiria
-- IMEM interna; o modo 0 exigiria bootloader com UART de carga.
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;

library neorv32;
use neorv32.neorv32_package.all;

use work.soc_config_pkg.all;

entity neorv32_sram_soc is
  port (
    clk_i       : in  std_ulogic;
    rstn_i      : in  std_ulogic;
    uart0_txd_o : out std_ulogic;
    uart0_rxd_i : in  std_ulogic := 'L';
    gpio_o      : out std_ulogic_vector(31 downto 0)
  );
end entity;

architecture rtl of neorv32_sram_soc is

  -- -------------------------------------------------------------------
  -- Componente Verilog. Tipos declarados como std_logic para a ligacao
  -- em linguagem mista ser a mais direta possivel.
  -- -------------------------------------------------------------------
  component sram_wb_wrapper is
    generic (
      ADDR_BITS : integer := 10
    );
    port (
      clk_i    : in  std_logic;
      rstn_i   : in  std_logic;
      wb_adr_i : in  std_logic_vector(31 downto 0);
      wb_dat_i : in  std_logic_vector(31 downto 0);
      wb_dat_o : out std_logic_vector(31 downto 0);
      wb_we_i  : in  std_logic;
      wb_sel_i : in  std_logic_vector(3 downto 0);
      wb_stb_i : in  std_logic;
      wb_cyc_i : in  std_logic;
      wb_ack_o : out std_logic;
      wb_err_o : out std_logic
    );
  end component;

  signal xbus_adr   : std_ulogic_vector(31 downto 0);
  signal xbus_dat_w : std_ulogic_vector(31 downto 0);
  signal xbus_dat_r : std_ulogic_vector(31 downto 0);
  signal xbus_we, xbus_stb, xbus_cyc, xbus_ack, xbus_err : std_ulogic;
  signal xbus_sel   : std_ulogic_vector(3 downto 0);

  signal sram_dat_r : std_logic_vector(31 downto 0);
  signal sram_ack, sram_err : std_logic;

begin

  -- -------------------------------------------------------------------
  -- Processador (configuracao IDENTICA a do top de simulacao)
  -- -------------------------------------------------------------------
  u_neorv32: entity neorv32.neorv32_top
  generic map (
    CLOCK_FREQUENCY  => CLK_FREQ_C,
    DUAL_CORE_EN     => false,

    BOOT_MODE_SELECT => 1,
    BOOT_ADDR_CUSTOM => SRAM_BASE_C,

    RISCV_ISA_C      => true,
    RISCV_ISA_M      => true,
    RISCV_ISA_Zicntr => true,

    -- Banco de registradores como flip-flops explicitos.
    -- O default (0 = sram_sync) e pensado para FPGA, onde o
    -- sintetizador infere block RAM. Em ASIC nao existe block RAM.
    -- Ver soc_config_pkg.vhd -- este e o parametro do experimento de
    -- area registradores x memoria.
    CPU_RF_ARCH_SEL  => CPU_RF_ARCH_C,

    IMEM_EN          => false,
    DMEM_EN          => false,
    ICACHE_EN        => false,
    DCACHE_EN        => false,

    XBUS_EN          => true,
    XBUS_TIMEOUT     => 2048,
    XBUS_REGSTAGE_EN => false,

    IO_CFS_EN        => true,
    IO_CLINT_EN      => true,
    IO_UART0_EN      => true,
    IO_UART0_RX_FIFO => 1,
    IO_UART0_TX_FIFO => 32,
    IO_GPIO_NUM      => 8,
    IO_GPIO_DIR_EN   => false
  )
  port map (
    clk_i       => clk_i,
    rstn_i      => rstn_i,

    xbus_adr_o  => xbus_adr,
    xbus_dat_o  => xbus_dat_w,
    xbus_cti_o  => open,      -- sem rajada: nosso escravo nao usa
    xbus_tag_o  => open,
    xbus_we_o   => xbus_we,
    xbus_sel_o  => xbus_sel,
    xbus_stb_o  => xbus_stb,
    xbus_cyc_o  => xbus_cyc,
    xbus_dat_i  => xbus_dat_r,
    xbus_ack_i  => xbus_ack,
    xbus_err_i  => xbus_err,

    uart0_txd_o => uart0_txd_o,
    uart0_rxd_i => uart0_rxd_i,
    gpio_o      => gpio_o        -- BUG CORRIGIDO: estava 'open', e o
                                 -- GPIO ficava sempre em zero. Com o
                                 -- demo_blink_led nao se veria nada.
  );

  -- -------------------------------------------------------------------
  -- SRAM real, via wrapper Verilog
  -- -------------------------------------------------------------------
  u_sram: sram_wb_wrapper
  generic map (
    ADDR_BITS => SRAM_ADDR_BITS_C
  )
  port map (
    clk_i    => std_logic(clk_i),
    rstn_i   => std_logic(rstn_i),
    wb_adr_i => std_logic_vector(xbus_adr),
    wb_dat_i => std_logic_vector(xbus_dat_w),
    wb_dat_o => sram_dat_r,
    wb_we_i  => std_logic(xbus_we),
    wb_sel_i => std_logic_vector(xbus_sel),
    wb_stb_i => std_logic(xbus_stb),
    wb_cyc_i => std_logic(xbus_cyc),
    wb_ack_o => sram_ack,
    wb_err_o => sram_err
  );

  xbus_dat_r <= std_ulogic_vector(sram_dat_r);
  xbus_ack   <= std_ulogic(sram_ack);
  xbus_err   <= std_ulogic(sram_err);

end architecture;
