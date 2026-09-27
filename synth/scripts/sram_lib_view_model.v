//=============================================================================
// sram_lib_view_model.v
//
// Adaptador de SIMULACAO POS-SINTESE para a macro de SRAM.
//
// Projeto: neorv32-openram-sky130
//
//-----------------------------------------------------------------------------
// O PROBLEMA QUE ESTE ARQUIVO RESOLVE
//-----------------------------------------------------------------------------
// O netlist sintetizado instancia a macro com a interface do .lib:
//
//     din0[31:0]   dout0[31:0]   addr0[10:0]   (sem spare_wen0)
//
// Mas o modelo comportamental gerado pela OpenRAM tem outra interface:
//
//     din0[32:0]   dout0[32:0]   addr0[10:0]   spare_wen0
//
// O 33o bit e a coluna sobressalente, que o .lib nao modela. Jogar o
// netlist e o modelo juntos no simulador da incompatibilidade de
// largura -- e o dado sairia truncado ou em X sem erro claro.
//
// Este arquivo tem o NOME EXATO da macro e a interface do .lib. Ele
// instancia o modelo comportamental (renomeado para *_beh) e faz a
// adaptacao: bit 32 da entrada amarrado em 0, bit 32 da saida
// descartado, spare_wen0 desativado.
//
//-----------------------------------------------------------------------------
// COMO GERAR O MODELO *_beh
//-----------------------------------------------------------------------------
// O modelo da OpenRAM precisa ser renomeado, senao colide com este:
//
//   sed 's/sram_4kbyte_1rw_32x1024_8/sram_4kbyte_1rw_32x1024_8_beh/g' \
//       sram_4kbyte_1rw_32x1024_8.v > sram_4kbyte_1rw_32x1024_8_beh.v
//
//-----------------------------------------------------------------------------
// PRE-CARGA DO PROGRAMA
//-----------------------------------------------------------------------------
// O array 'mem' do modelo NAO e inicializado. Apos o reset a CPU busca
// a primeira instrucao e recebe X, que se propaga pelo nucleo inteiro.
//
// Passe a imagem por plusarg:
//
//   xrun ... +MEM_FILE=/caminho/neorv32_raw_exe.hex
//
// O arquivo e HEX puro, 8 digitos por linha, uma palavra de 32 bits por
// linha -- o mesmo formato que o xbus_memory.vhd consome. Os 32 bits
// entram nos bits [31:0] de cada palavra de 33.
//=============================================================================

`timescale 1ns / 1ps

module sram_4kbyte_1rw_32x1024_8 (
    input  wire        clk0,
    input  wire        csb0,      // chip select, ativo baixo
    input  wire        web0,      // write enable, ativo baixo
    input  wire [3:0]  wmask0,
    input  wire [10:0] addr0,
    input  wire [31:0] din0,      // 32 bits: view do .lib
    output wire [31:0] dout0      // 32 bits: view do .lib
);

    wire [32:0] dout0_33;

    sram_4kbyte_1rw_32x1024_8_beh u_beh (
        .clk0       (clk0),
        .csb0       (csb0),
        .web0       (web0),
        .wmask0     (wmask0),
        .spare_wen0 (1'b0),          // coluna sobressalente nunca escrita
        .addr0      (addr0),
        .din0       ({1'b0, din0}),  // bit 32 amarrado em 0
        .dout0      (dout0_33)
    );

    assign dout0 = dout0_33[31:0];   // bit 32 descartado

    //-------------------------------------------------------------------------
    // Pre-carga do programa
    //-------------------------------------------------------------------------
    reg [1023:0] mem_file;

    initial begin
        if ($value$plusargs("MEM_FILE=%s", mem_file)) begin
            $display("[sram_model] carregando '%0s'", mem_file);
            $readmemh(mem_file, u_beh.mem);
        end else begin
            $display("[sram_model] AVISO: sem +MEM_FILE.");
            $display("[sram_model] A memoria fica em X, a CPU busca em 0x0,");
            $display("[sram_model] recebe X e propaga pelo nucleo inteiro.");
        end
    end

endmodule
