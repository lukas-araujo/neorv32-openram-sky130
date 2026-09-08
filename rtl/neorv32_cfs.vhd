-- ================================================================================ --
-- neorv32_cfs.vhd -- SUBSTITUI o template do NEORV32
--
-- Custom Functions Subsystem: somador e acumulador de 32 bits.
--
-- Projeto: neorv32-openram-sky130
--
-- ⚠️ Este arquivo tem a MESMA entidade (neorv32_cfs) e vai para a MESMA
--    biblioteca (neorv32) que o template original. O script de build
--    exclui rtl/core/neorv32_cfs.vhd do clone do NEORV32 e analisa este
--    no lugar. O repositorio de terceiros continua intocado.
--
-- ================================================================================ --
-- PROTOCOLO
-- ================================================================================ --
-- O CFS tem 64 kB de espaco mapeado em memoria (16 bits de endereco de
-- byte). Todo acesso -- leitura ou escrita -- PRECISA ser reconhecido no
-- ciclo seguinte via rsp_ack_o. Sem ack, o barramento estoura o tempo
-- limite e a CPU levanta excecao de falha de acesso.
--
-- Por isso reconhecemos TODOS os enderecos, inclusive os nao mapeados
-- (que leem zero). Ack incondicional e a forma mais simples de nunca
-- travar o barramento por engano.
--
-- ================================================================================ --
-- MAPA DE REGISTRADORES  (offsets a partir da base do CFS)
-- ================================================================================ --
--
--   0x00  OPA    rw   operando A
--   0x04  OPB    rw   operando B
--   0x08  SUM    ro   OPA + OPB (combinacional)
--   0x0C  ACC    rw   escrita ACUMULA (acc <= acc + dado)
--                     leitura devolve o acumulador
--   0x10  CTRL   rw   escrita: bit 0 = 1 limpa o ACC
--                     leitura: bit 0 = carry-out do SUM
--
-- ================================================================================ --
-- POR QUE DUAS FUNCOES: O EXPERIMENTO
-- ================================================================================ --
-- O SOMADOR (OPA/OPB/SUM) vai PERDER para a ALU da CPU, e isso e
-- esperado. Uma soma custa:
--
--   hardware: 2 escritas + 1 leitura, cada uma com handshake de
--             barramento  -> varios ciclos
--   software: 1 instrucao add                    -> 1 ciclo
--
-- O ACUMULADOR muda a conta: cada escrita faz trabalho util e NAO
-- precisa de leitura de volta. Somar N valores custa N escritas no
-- hardware, contra N cargas + N adds + laco no software.
--
-- Medindo os dois com o contador mcycle (RISCV_ISA_Zicntr), voce mostra
-- ONDE FICA A FRONTEIRA em vez de so afirmar que ela existe:
--
--   um acelerador so compensa quando o custo da operacao supera o
--   custo de transportar os dados ate ele.
--
-- E o mesmo calculo que decide se um bloco de processamento de sinal
-- vale a pena como periferico ou nao.
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_cfs is
  port (
    -- controle global --
    clk_i      : in  std_ulogic;
    rstn_i     : in  std_ulogic;                      -- reset assincrono, ativo baixo
    -- requisicao da CPU --
    req_addr_i : in  std_ulogic_vector(15 downto 0);  -- endereco de byte
    req_data_i : in  std_ulogic_vector(31 downto 0);
    req_ben_i  : in  std_ulogic_vector(3 downto 0);   -- byte enable
    req_stb_i  : in  std_ulogic;
    req_rw_i   : in  std_ulogic;                      -- 0=leitura, 1=escrita
    -- resposta --
    rsp_data_o : out std_ulogic_vector(31 downto 0);
    rsp_ack_o  : out std_ulogic;
    -- interrupcao --
    irq_o      : out std_ulogic;
    -- conduits externos --
    cfs_in_i   : in  std_ulogic_vector(255 downto 0);
    cfs_out_o  : out std_ulogic_vector(255 downto 0)
  );
end entity;

architecture neorv32_cfs_rtl of neorv32_cfs is

  -- Offsets de palavra. Usamos req_addr_i(4 downto 2): 8 slots.
  constant ADDR_OPA_C  : std_ulogic_vector(2 downto 0) := "000";  -- 0x00
  constant ADDR_OPB_C  : std_ulogic_vector(2 downto 0) := "001";  -- 0x04
  constant ADDR_SUM_C  : std_ulogic_vector(2 downto 0) := "010";  -- 0x08
  constant ADDR_ACC_C  : std_ulogic_vector(2 downto 0) := "011";  -- 0x0C
  constant ADDR_CTRL_C : std_ulogic_vector(2 downto 0) := "100";  -- 0x10

  signal reg_opa : std_ulogic_vector(31 downto 0);
  signal reg_opb : std_ulogic_vector(31 downto 0);
  signal reg_acc : std_ulogic_vector(31 downto 0);

  -- 33 bits para capturar o carry-out
  signal sum_ext : unsigned(32 downto 0);

  signal word_sel : std_ulogic_vector(2 downto 0);
  signal wr_full  : std_ulogic;   -- escrita de palavra inteira

begin

  word_sel <= req_addr_i(4 downto 2);

  -- Aceitamos apenas escrita de palavra inteira. Escrita parcial e
  -- ignorada (mas ainda reconhecida), igual ao template original.
  wr_full <= '1' when (req_ben_i = "1111") else '0';

  -- ------------------------------------------------------------------
  -- Somador combinacional. 33 bits: o bit 32 e o carry-out.
  -- ------------------------------------------------------------------
  sum_ext <= ('0' & unsigned(reg_opa)) + ('0' & unsigned(reg_opb));

  -- ------------------------------------------------------------------
  -- Escrita
  -- ------------------------------------------------------------------
  escrita: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      reg_opa <= (others => '0');
      reg_opb <= (others => '0');
      reg_acc <= (others => '0');
    elsif rising_edge(clk_i) then
      if (req_stb_i = '1') and (req_rw_i = '1') and (wr_full = '1') then
        case word_sel is

          when ADDR_OPA_C =>
            reg_opa <= req_data_i;

          when ADDR_OPB_C =>
            reg_opb <= req_data_i;

          -- SUM e somente leitura: escrita ignorada (mas reconhecida).

          when ADDR_ACC_C =>
            -- Aqui esta o ponto: a ESCRITA ja faz o trabalho.
            -- Nao ha leitura de volta a cada valor somado.
            reg_acc <= std_ulogic_vector(unsigned(reg_acc) +
                                         unsigned(req_data_i));

          when ADDR_CTRL_C =>
            if (req_data_i(0) = '1') then
              reg_acc <= (others => '0');
            end if;

          when others =>
            null;   -- enderecos nao mapeados: ignorados

        end case;
      end if;
    end if;
  end process;

  -- ------------------------------------------------------------------
  -- Leitura e acknowledge
  --
  -- O ack e INCONDICIONAL: todo strobe e reconhecido no ciclo seguinte,
  -- mapeado ou nao. Endereco nao mapeado devolve zero em vez de travar
  -- o barramento.
  -- ------------------------------------------------------------------
  leitura: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      rsp_ack_o  <= '0';
      rsp_data_o <= (others => '0');
    elsif rising_edge(clk_i) then
      rsp_ack_o  <= req_stb_i;
      rsp_data_o <= (others => '0');   -- default: zero

      if (req_stb_i = '1') and (req_rw_i = '0') then
        case word_sel is
          when ADDR_OPA_C  => rsp_data_o <= reg_opa;
          when ADDR_OPB_C  => rsp_data_o <= reg_opb;
          when ADDR_SUM_C  => rsp_data_o <= std_ulogic_vector(sum_ext(31 downto 0));
          when ADDR_ACC_C  => rsp_data_o <= reg_acc;
          when ADDR_CTRL_C => rsp_data_o <= (0 => sum_ext(32),   -- carry-out
                                             others => '0');
          when others      => rsp_data_o <= (others => '0');
        end case;
      end if;
    end if;
  end process;

  -- ------------------------------------------------------------------
  -- Sem interrupcao neste exemplo.
  -- ------------------------------------------------------------------
  irq_o <= '0';

  -- ------------------------------------------------------------------
  -- Conduit de saida: expoe a soma para observacao na forma de onda e
  -- em pinos, sem custo de barramento.
  -- ------------------------------------------------------------------
  cfs_out_o(31 downto 0)   <= std_ulogic_vector(sum_ext(31 downto 0));
  cfs_out_o(255 downto 32) <= (others => '0');

end architecture;
