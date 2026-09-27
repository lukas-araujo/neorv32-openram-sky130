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
// A MACRO FICA ATRAS DE UM SHIM
//-----------------------------------------------------------------------------
// A macro OpenRAM varia em duas dimensoes: tamanho (1 kB ou 4 kB, com
// larguras de endereco e nomes de modulo diferentes) e view (.lib e .v
// discordam sobre a largura do dado -- ver DIARIO.md).
//
// Toda essa variacao esta isolada em sram_macro_shim.v. Este arquivo so
// enxerga uma interface normalizada. As macros SRAM_4KB e
// SRAM_SYNTH_VIEW sao consumidas la, nao aqui.
//
//-----------------------------------------------------------------------------
// ?? POR QUE A DECODIFICACAO DE FAIXA NAO E OPCIONAL
//-----------------------------------------------------------------------------
// A primeira versao deste arquivo tinha 'assign wb_err_o = 1'b0;' e usava
// apenas wb_adr_i[ADDR_BITS+1:2]. Os 20 bits altos do endereco NAO ERAM
// LIDOS POR NINGUEM.
//
// Consequencia na sintese: o Genus concluiu -- CORRETAMENTE -- que a
// logica que gerava aqueles bits nao tinha efeito observavel, e PODOU
// tudo, inclusive dentro do NEORV32. O netlist saiu com
//
//     UNCONNECTED_HIER_Z3702, UNCONNECTED_HIER_Z3701, xbus_adr[11:2], ...
//
// so os bits [11:2] conectados. Na simulacao pos-sintese o xbus_adr
// chegava com 'z' nos bits altos, o neorv32_bus_gateway comparava
// contra 'z', o cyc saia em X e a CPU NUNCA COMECAVA.
//
// Nao era bug de ferramenta: era a ferramenta fazendo o certo sobre um
// projeto incompleto. Usar o endereco completo nao e so boa pratica --
// e o que impede a poda da logica que o produz.
//
// Bonus: acaba com o espelhamento a cada 4 kB. Um ponteiro errado agora
// gera excecao de barramento em vez de ler lixo silenciosamente.
//
//-----------------------------------------------------------------------------
// OUTROS CUIDADOS
//-----------------------------------------------------------------------------
// 1. Todos os sinais do XBUS so sao validos com cyc alto. Sem qualificar
//    por cyc, acessos a memoria interna do NEORV32 aparecem nas linhas
//    externas e geram escritas fantasma.
// 2. csb0 e web0 sao ATIVOS EM NIVEL BAIXO.
// 3. A macro tem sempre 1 bit de endereco a mais que o necessario (a
//    linha sobressalente). O shim o amarra em 0. Hipotese CONFIRMADA em
//    simulacao pelo teste do limite de 1 kB.
// 4. Os bits wb_adr_i[1:0] (offset de byte dentro da palavra) continuam
//    sem uso -- a selecao de byte vem por wb_sel_i. Eles podem seguir
//    podados. CONFERIR no netlist depois de sintetizar: se o
//    bus_gateway nao depender deles, nao ha problema.
//=============================================================================

`timescale 1ns / 1ps

module sram_wb_wrapper #(
    // log2 do numero de palavras uteis.
    //   8  -> 256 palavras  -> 1 kB (macro padrao)
    //   10 -> 1024 palavras -> 4 kB (compilar com -DSRAM_4KB)
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
    // Decodificacao de faixa -- declarada ANTES de quem a usa.
    //
    // Com ADDR_BITS = 10 (4 kB), a faixa valida e 0x00000000..0x00000FFF.
    // Qualquer bit acima de [ADDR_BITS+1] em 1 significa fora da faixa.
    //-------------------------------------------------------------------------
    wire fora_da_faixa = |wb_adr_i[31:ADDR_BITS+2];

    //-------------------------------------------------------------------------
    // Maquina de estados: emite o acesso em IDLE, reconhece em ACK.
    //
    // Acesso fora da faixa TAMBEM e reconhecido -- com err em vez de
    // dado. Nunca deixar o barramento sem resposta: isso estouraria o
    // XBUS_TIMEOUT e travaria por 2048 ciclos.
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
    // Sinalizacao de erro
    //
    // Acompanha o ack: o mestre amostra os dois na mesma borda.
    //-------------------------------------------------------------------------
    reg err_pendente;

    always @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i)
            err_pendente <= 1'b0;
        else if ((state == ST_IDLE) && req)
            err_pendente <= fora_da_faixa;
        else if (state == ST_ACK)
            err_pendente <= 1'b0;
    end

    assign wb_err_o = wb_ack_o & err_pendente;

    //-------------------------------------------------------------------------
    // Sinais para a SRAM (combinacionais).
    //
    // csb0 so e ativado em ST_IDLE e SO dentro da faixa. Durante ST_ACK
    // ele volta a 1, senao a SRAM reexecutaria o mesmo acesso na borda
    // seguinte.
    //-------------------------------------------------------------------------
    wire                 sram_csb0   = ~(req & ~fora_da_faixa &
                                         (state == ST_IDLE));
    wire                 sram_web0   = ~wb_we_i;      // 0 = escrita
    wire [3:0]           sram_wmask0 = wb_sel_i;
    wire [31:0]          sram_din0   = wb_dat_i;
    wire [31:0]          sram_dout0;

    // Endereco de BYTE -> endereco de PALAVRA (descarta os 2 bits baixos).
    wire [ADDR_BITS-1:0] sram_addr0  = wb_adr_i[ADDR_BITS+1:2];

    //-------------------------------------------------------------------------
    // Portao de saida: zera o dado quando nao estamos respondendo.
    //
    // OBRIGATORIO se houver mais de um escravo no XBUS. A forma padrao de
    // juntar escravos e fazer OR das respostas de todos eles; sem o
    // portao, esta SRAM injetaria lixo (e X, vindo do bit sobressalente
    // nao inicializado) no OR o tempo todo. O modelo oficial
    // sim/xbus_memory.vhd do NEORV32 faz o mesmo.
    //
    // Fora da faixa tambem devolve zero, nao lixo.
    //-------------------------------------------------------------------------
    assign wb_dat_o = (wb_ack_o & ~err_pendente) ? sram_dout0 : 32'h0000_0000;

    //-------------------------------------------------------------------------
    // Memoria, atraves do shim. Tamanho e view sao resolvidos la dentro.
    //-------------------------------------------------------------------------
    sram_macro_shim #(
        .WORD_ADDR_BITS (ADDR_BITS)
    ) u_sram (
        .clk_i   (clk_i),
        .cs_n_i  (sram_csb0),
        .we_n_i  (sram_web0),
        .wmask_i (sram_wmask0),
        .addr_i  (sram_addr0),
        .din_i   (sram_din0),
        .dout_o  (sram_dout0)
    );

endmodule
