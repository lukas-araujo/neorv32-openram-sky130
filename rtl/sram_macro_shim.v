//=============================================================================
// sram_macro_shim.v
//
// Adaptador que esconde as variacoes da macro OpenRAM atras de uma
// interface normalizada. TODOS os `ifdef ficam aqui -- o wrapper de
// barramento nao precisa saber de nada disso.
//
// Projeto: neorv32-openram-sky130
//
//-----------------------------------------------------------------------------
// DUAS VARIACOES INDEPENDENTES
//-----------------------------------------------------------------------------
//
// (1) TAMANHO -- muda o nome do modulo e a largura do endereco
//
//     macro                          addr0   palavras
//     ----------------------------   -----   --------
//     sram_1kbyte_1rw_32x256_8       9 bits  256   (padrao)
//     sram_4kbyte_1rw_32x1024_8     11 bits  1024  (defina SRAM_4KB)
//
//     Em ambos, a largura do endereco e log2(palavras) + 1. O bit extra
//     vem da linha sobressalente e e sempre amarrado em 0 aqui.
//
// (2) VIEW -- .lib e .v discordam (ver DIARIO.md)
//
//     view        din0/dout0   spare_wen0
//     ---------   ----------   ----------
//     .v  (sim)   33 bits      existe
//     .lib (syn)  32 bits      NAO existe
//
//     Defina SRAM_SYNTH_VIEW ao ler com o sintetizador:
//       Genus:  read_hdl -define SRAM_SYNTH_VIEW ...
//       Yosys:  read_verilog -DSRAM_SYNTH_VIEW ...
//
//     As duas variacoes sao ortogonais: 4 combinacoes possiveis.
//=============================================================================

`timescale 1ns / 1ps

module sram_macro_shim #(
    // log2 do numero de palavras uteis. 8 -> 256 (1 kB); 10 -> 1024 (4 kB)
    parameter WORD_ADDR_BITS = 8
)(
    input  wire                      clk_i,
    input  wire                      cs_n_i,     // chip select, ativo baixo
    input  wire                      we_n_i,     // write enable, ativo baixo
    input  wire [3:0]                wmask_i,
    input  wire [WORD_ADDR_BITS-1:0] addr_i,     // endereco de PALAVRA
    input  wire [31:0]               din_i,
    output wire [31:0]               dout_o
);

    // A macro sempre tem 1 bit de endereco a mais que o necessario:
    // a linha sobressalente. Amarrado em 0 para nao cair nela.
    localparam MACRO_ADDR_BITS = WORD_ADDR_BITS + 1;

    wire [MACRO_ADDR_BITS-1:0] macro_addr = {1'b0, addr_i};

`ifdef SRAM_4KB
  `ifdef SRAM_SYNTH_VIEW
    sram_4kbyte_1rw_32x1024_8 u_sram (
        .clk0(clk_i), .csb0(cs_n_i), .web0(we_n_i), .wmask0(wmask_i),
        .addr0(macro_addr), .din0(din_i), .dout0(dout_o)
    );
  `else
    wire [32:0] dout_33;
    sram_4kbyte_1rw_32x1024_8 u_sram (
        .clk0(clk_i), .csb0(cs_n_i), .web0(we_n_i), .wmask0(wmask_i),
        .spare_wen0(1'b0),
        .addr0(macro_addr), .din0({1'b0, din_i}), .dout0(dout_33)
    );
    assign dout_o = dout_33[31:0];
  `endif
`else
  `ifdef SRAM_SYNTH_VIEW
    sram_1kbyte_1rw_32x256_8 u_sram (
        .clk0(clk_i), .csb0(cs_n_i), .web0(we_n_i), .wmask0(wmask_i),
        .addr0(macro_addr), .din0(din_i), .dout0(dout_o)
    );
  `else
    wire [32:0] dout_33;
    sram_1kbyte_1rw_32x256_8 u_sram (
        .clk0(clk_i), .csb0(cs_n_i), .web0(we_n_i), .wmask0(wmask_i),
        .spare_wen0(1'b0),
        .addr0(macro_addr), .din0({1'b0, din_i}), .dout0(dout_33)
    );
    assign dout_o = dout_33[31:0];
  `endif
`endif

    // Checagem de coerencia entre o parametro e a macro selecionada.
    // Se estas duas coisas divergirem, o erro seria silencioso.
    initial begin
`ifdef SRAM_4KB
        if (WORD_ADDR_BITS != 10)
            $fatal(1, "sram_macro_shim: SRAM_4KB exige WORD_ADDR_BITS=10 (recebido %0d)",
                   WORD_ADDR_BITS);
`else
        if (WORD_ADDR_BITS != 8)
            $fatal(1, "sram_macro_shim: macro de 1kB exige WORD_ADDR_BITS=8 (recebido %0d)",
                   WORD_ADDR_BITS);
`endif
    end

endmodule
