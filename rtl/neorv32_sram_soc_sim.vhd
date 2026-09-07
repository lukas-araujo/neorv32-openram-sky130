-- =====================================================================
-- neorv32_sram_soc_sim.vhd
--
-- Top-level do SoC para SIMULACAO EM VHDL PURO (GHDL, no notebook).
-- Usa o modelo de memoria oficial sim/xbus_memory.vhd no lugar da SRAM
-- da OpenRAM, porque o GHDL nao le Verilog.
--
-- O gemeo deste arquivo e neorv32_sram_soc.vhd, que usa a SRAM real.
-- Os dois compartilham soc_config_pkg.vhd, entao o processador e
-- identico -- so a memoria muda.
--
-- =====================================================================
-- O QUE ESTA LIGADO E POR QUE
-- =====================================================================
--
--   RISCV_ISA_C       instrucoes comprimidas de 16 bits. Com 4 kB de
--                     memoria para codigo e dados, densidade importa.
--   RISCV_ISA_M       multiplicacao e divisao. Qualquer programa real
--                     usa, e rende conteudo interessante na sintese.
--   RISCV_ISA_Zicntr  contadores de ciclo e instrucao. NAO e enfeite:
--                     e como vamos MEDIR o ganho do somador em
--                     hardware contra a mesma soma em software.
--   XBUS_EN           a interface externa onde vive nossa SRAM.
--   IO_CFS_EN         onde entra o somador.
--   IO_UART0_EN       sem ela ficamos cegos na simulacao.
--   IO_GPIO_NUM       sinalizacao barata (fim de teste, erro).
--   IO_CLINT_EN       temporizador e interrupcoes; base do RISC-V.
--
-- =====================================================================
-- O QUE ESTA DESLIGADO E POR QUE
-- =====================================================================
--
--   DUAL_CORE_EN      dobraria a complexidade sem ensinar nada sobre
--                     memoria.
--   IMEM_EN/DMEM_EN   O PONTO DO PROJETO. Sao arrays em VHDL que
--                     virariam um mar de flip-flops no ASIC. Foram
--                     substituidas pela SRAM da OpenRAM no XBUS.
--   ICACHE/DCACHE     com 4 kB de memoria externa, cache e redundante
--                     e so atrapalharia a analise do timing do XBUS.
--   OCD_EN            exige JTAG e complica o testbench.
--   XBUS_REGSTAGE_EN  desligado DE PROPOSITO, para exercitar nosso
--                     wrapper como esta. Ligar acrescenta um estagio
--                     de registro que ajuda o timing e custa um ciclo.
--                     Vale ligar depois e comparar -- conscientemente.
--   CPU_FAST_MUL_EN   usa DSP, que existe em FPGA e nao em ASIC.
--   CPU_FAST_SHIFT_EN barrel shifter: mais rapido, bem maior. Bom
--                     experimento de sintese depois (ligar e comparar
--                     area).
--   CPU_RF_ARCH_SEL   NAO usa o default. O default (0=sram_sync) e
--                     pensado para FPGA; usamos 2 (flip-flops). Ver
--                     soc_config_pkg.vhd.
--   TRNG, DMA, SPI, TWI, PWM, WDT, NEOLED, ONEWIRE, SLINK, TRACER,
--   SMC, PMP, HPM     nao usados aqui; so somariam area e ruido.
--
-- BOOT: BOOT_MODE_SELECT = 1 (endereco customizado). O modo 2 exigiria
-- IMEM interna; o modo 0 exigiria bootloader e UART de carga, o que nao
-- faz sentido num ASIC. A CPU comeca a executar em SRAM_BASE_C.
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;

library neorv32;
use neorv32.neorv32_package.all;

use work.soc_config_pkg.all;

entity neorv32_sram_soc_sim is
  generic (
    -- Imagem HEX carregada na memoria. Sem ela, a memoria comeca zerada
    -- (o modelo oficial zera; nao gera X como o modelo Verilog da SRAM).
    MEM_FILE : string := ""
  );
  port (
    clk_i       : in  std_ulogic;
    rstn_i      : in  std_ulogic;
    uart0_txd_o : out std_ulogic;
    uart0_rxd_i : in  std_ulogic := 'L';
    gpio_o      : out std_ulogic_vector(31 downto 0)
  );
end entity;

architecture rtl of neorv32_sram_soc_sim is

  -- XBUS: sinais planos no topo do NEORV32, records no modelo de memoria
  signal xbus_adr : std_ulogic_vector(31 downto 0);
  signal xbus_dat_w : std_ulogic_vector(31 downto 0);
  signal xbus_dat_r : std_ulogic_vector(31 downto 0);
  signal xbus_cti : std_ulogic_vector(2 downto 0);
  signal xbus_tag : std_ulogic_vector(2 downto 0);
  signal xbus_we, xbus_stb, xbus_cyc, xbus_ack, xbus_err : std_ulogic;
  signal xbus_sel : std_ulogic_vector(3 downto 0);

  signal mem_req : xbus_req_t;
  signal mem_rsp : xbus_rsp_t;

begin

  -- -------------------------------------------------------------------
  -- Processador
  -- -------------------------------------------------------------------
  u_neorv32: entity neorv32.neorv32_top
  generic map (
    CLOCK_FREQUENCY  => CLK_FREQ_C,
    DUAL_CORE_EN     => false,

    BOOT_MODE_SELECT => 1,              -- endereco customizado
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

    IMEM_EN          => false,          -- substituida pela SRAM externa
    DMEM_EN          => false,          -- idem
    ICACHE_EN        => false,
    DCACHE_EN        => false,

    XBUS_EN          => true,
    XBUS_TIMEOUT     => 2048,
    XBUS_REGSTAGE_EN => false,

    IO_CFS_EN        => true,           -- somador
    IO_CLINT_EN      => true,
    IO_UART0_EN      => true,
    IO_UART0_RX_FIFO => 1,
    IO_UART0_TX_FIFO => 32,             -- evita gargalo no log de sim
    IO_GPIO_NUM      => 8,
    IO_GPIO_DIR_EN   => false
  )
  port map (
    clk_i       => clk_i,
    rstn_i      => rstn_i,

    xbus_adr_o  => xbus_adr,
    xbus_dat_o  => xbus_dat_w,
    xbus_cti_o  => xbus_cti,
    xbus_tag_o  => xbus_tag,
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
  -- Empacotar os sinais planos nos records do modelo de memoria
  -- -------------------------------------------------------------------
  mem_req.addr <= xbus_adr;
  mem_req.data <= xbus_dat_w;
  mem_req.cti  <= xbus_cti;
  mem_req.tag  <= xbus_tag;
  mem_req.we   <= xbus_we;
  mem_req.sel  <= xbus_sel;
  mem_req.stb  <= xbus_stb;
  mem_req.cyc  <= xbus_cyc;

  xbus_dat_r <= mem_rsp.data;
  xbus_ack   <= mem_rsp.ack;
  xbus_err   <= mem_rsp.err;

  -- -------------------------------------------------------------------
  -- Memoria IDEAL
  --
  -- MEM_LATE = 1 e o equivalente exato do nosso wrapper: ack e dado
  -- ficam validos um ciclo apos a requisicao. Isso foi verificado
  -- lendo o handshake de sim/xbus_memory.vhd.
  -- -------------------------------------------------------------------
  u_mem: entity neorv32.xbus_memory
  generic map (
    MEM_RST  => false,
    MEM_SIZE => SRAM_SIZE_C,
    MEM_LATE => 1,
    MEM_FILE => MEM_FILE
  )
  port map (
    clk_i      => clk_i,
    rstn_i     => rstn_i,
    xbus_req_i => mem_req,
    xbus_rsp_o => mem_rsp
  );

end architecture;
