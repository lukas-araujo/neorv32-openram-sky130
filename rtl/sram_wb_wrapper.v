//=============================================================================
// sram_wb_wrapper.v
//
// Escravo Wishbone b4 (classico) para a macro de SRAM gerada pela OpenRAM.
// Alvo: interface XBUS do NEORV32.
//
// Projeto: neorv32-openram-sky130
//
//-----------------------------------------------------------------------------
// PROTOCOLO
//-----------------------------------------------------------------------------
// A SRAM da OpenRAM registra as entradas na borda de SUBIDA e executa o
// acesso na borda de DESCIDA do mesmo ciclo. O dado lido fica valido do
// meio do ciclo ate a subida seguinte.
//
//   ciclo 0 : cyc & stb altos; wrapper baixa csb0 e apresenta addr/din/wmask
//   subida 1: SRAM captura as entradas; na descida executa o acesso
//   ciclo 1 : ack alto; dout0 passa combinacionalmente para wb_dat_o
//   subida 2: o mestre amostra ack e dado juntos
//
// Dois ciclos por acesso.
//
//-----------------------------------------------------------------------------
// DIVERGENCIA ENTRE .lib E .v  -- LEIA ANTES DE MEXER
//-----------------------------------------------------------------------------
// A macro tem num_spare_rows = 1 e num_spare_cols = 1. Essas NAO sao
// opcionais em sky130: a linha dummy e a coluna de replica bitline tornam
// os totais impares, e a tecnologia exige paridade par nos dois eixos.
// Sem elas a memoria nao compila.
//
// Consequencia: as duas views da macro DISCORDAM.
//
//   view        din0/dout0   addr0    spare_wen0
//   ---------   ----------   ------   ----------
//   .v  (sim)   33 bits      9 bits   existe
//   .lib (syn)  32 bits      9 bits   NAO existe
//
// Por isso a instanciacao e condicional. Defina SRAM_SYNTH_VIEW ao ler
// este arquivo com o sintetizador:
//
//   Genus:    read_hdl -define SRAM_SYNTH_VIEW ...
//   Yosys:    read_verilog -DSRAM_SYNTH_VIEW ...
//
// Sem a macro definida, vale a view de simulacao (33 bits).
//
//-----------------------------------------------------------------------------
// OUTROS CUIDADOS
//-----------------------------------------------------------------------------
// 1. Todos os sinais do XBUS so sao validos com cyc alto. Sem qualificar
//    por cyc, acessos a memoria interna do NEORV32 aparecem nas linhas
//    externas e geram escritas fantasma.
// 2. csb0 e web0 sao ATIVOS EM NIVEL BAIXO.
// 3. O endereco tem 9 bits (512 posicoes) mas so 256 palavras sao reais;
//    o bit 8 seleciona a linha sobressalente. Amarramos ele em 0.
//    ISSO E UMA HIPOTESE a confirmar em simulacao -- ver o teste do
//    limite de 1 kB no testbench.
//=============================================================================

`timescale 1ns / 1ps

module sram_wb_wrapper #(
    // log2 do numero de palavras uteis. 8 -> 256 palavras -> 1 kB
    parameter ADDR_BITS = 8
)(
    input  wire        clk_i,
    input  wire        rstn_i,      // reset assincrono, ativo em baixo

    // --- Wishbone b4, lado escravo ---
    input  wire [31:0] wb_adr_i,    // endereco de BYTE
    input  wire [31:0] wb_dat_i,    // dado de escrita (mestre -> escravo)
    output wire [31:0] wb_dat_o,    // dado de leitura (escravo -> mestre)
    input  wire        wb_we_i,     // 1 = escrita, 0 = leitura
    input  wire [3:0]  wb_sel_i,    // byte enable
    input  wire        wb_stb_i,
    input  wire        wb_cyc_i,
    output reg         wb_ack_o,
    output wire        wb_err_o
);

    //-------------------------------------------------------------------------
    // Requisicao valida: SEMPRE qualificada por cyc.
    //-------------------------------------------------------------------------
    wire req = wb_cyc_i & wb_stb_i;

    //-------------------------------------------------------------------------
    // Maquina de estados: emite o acesso em IDLE, reconhece em ACK.
    //-------------------------------------------------------------------------
    localparam ST_IDLE = 1'b0;
    localparam ST_ACK  = 1'b1;

    reg state;

    always @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            state    <= ST_IDLE;
            wb_ack_o <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (req) begin
                        // A SRAM capturou as entradas nesta mesma borda.
                        // O dado estara disponivel durante o proximo ciclo.
                        state    <= ST_ACK;
                        wb_ack_o <= 1'b1;
                    end else begin
                        wb_ack_o <= 1'b0;
                    end
                end

                ST_ACK: begin
                    state    <= ST_IDLE;
                    wb_ack_o <= 1'b0;
                end
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // Sinais para a SRAM (combinacionais).
    //
    // csb0 so e ativado em ST_IDLE. Durante ST_ACK ele volta a 1, senao a
    // SRAM reexecutaria o mesmo acesso na borda seguinte.
    //-------------------------------------------------------------------------
    wire        sram_csb0   = ~(req & (state == ST_IDLE));
    wire        sram_web0   = ~wb_we_i;          // 0 = escrita
    wire [3:0]  sram_wmask0 = wb_sel_i;
    wire [31:0] sram_din0   = wb_dat_i;
    wire [31:0] sram_dout0;

    // Endereco de 9 bits: bit 8 amarrado em 0 para nao cair na linha
    // sobressalente; bits [7:0] vem do endereco de palavra.
    wire [8:0]  sram_addr0  = {1'b0, wb_adr_i[ADDR_BITS+1:2]};

    assign wb_dat_o = sram_dout0;

    // Sem deteccao de erro: qualquer endereco entregue a este escravo e
    // aceito. Enderecos acima de 1 kB espelham, por usar so os bits baixos.
    assign wb_err_o = 1'b0;

    //-------------------------------------------------------------------------
    // Instancia da macro -- view conforme a ferramenta. Ver cabecalho.
    //-------------------------------------------------------------------------
`ifdef SRAM_SYNTH_VIEW

    // View do .lib: 32 bits de dado, sem spare_wen0.
    sram_1kbyte_1rw_32x256_8 u_sram (
        .clk0   (clk_i),
        .csb0   (sram_csb0),
        .web0   (sram_web0),
        .wmask0 (sram_wmask0),
        .addr0  (sram_addr0),
        .din0   (sram_din0),
        .dout0  (sram_dout0)
    );

`else

    // View do .v: 33 bits de dado, com spare_wen0.
    // O bit 32 e a coluna sobressalente: entra em 0, sai ignorado.
    wire [32:0] sram_dout0_33;

    sram_1kbyte_1rw_32x256_8 u_sram (
        .clk0       (clk_i),
        .csb0       (sram_csb0),
        .web0       (sram_web0),
        .wmask0     (sram_wmask0),
        .spare_wen0 (1'b0),
        .addr0      (sram_addr0),
        .din0       ({1'b0, sram_din0}),
        .dout0      (sram_dout0_33)
    );

    assign sram_dout0 = sram_dout0_33[31:0];

`endif

endmodule
