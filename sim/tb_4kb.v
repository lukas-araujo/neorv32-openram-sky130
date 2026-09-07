//=============================================================================
// tb_sram_wb_wrapper.v
//
// Testbench do escravo Wishbone da SRAM OpenRAM.
//
// Cobre:
//   1. Escrita e leitura de palavra inteira
//   2. Escrita parcial por byte (wb_sel), verificando que os bytes nao
//      selecionados sao preservados
//   3. Acessos consecutivos sem ciclo ocioso entre eles
//   4. Ausencia de escrita fantasma quando cyc esta baixo
//
// Rodar:
//   iverilog -o tb.vvp tb_sram_wb_wrapper.v sram_wb_wrapper.v \
//            ../openram/out_frontend_nospare/sram_1kbyte_1rw_32x256_8.v
//   vvp tb.vvp
//=============================================================================

`timescale 1ns / 1ps

module tb_sram_wb_wrapper;

    reg         clk  = 1'b0;
    reg         rstn = 1'b0;

    reg  [31:0] adr  = 32'h0;
    reg  [31:0] dat_w = 32'h0;
    wire [31:0] dat_r;
    reg         we   = 1'b0;
    reg  [3:0]  sel  = 4'h0;
    reg         stb  = 1'b0;
    reg         cyc  = 1'b0;
    wire        ack;
    wire        err;

    integer erros = 0;

    always #5 clk = ~clk;          // 100 MHz

    sram_wb_wrapper #(.ADDR_BITS(10)) dut (
        .clk_i   (clk),
        .rstn_i  (rstn),
        .wb_adr_i(adr),
        .wb_dat_i(dat_w),
        .wb_dat_o(dat_r),
        .wb_we_i (we),
        .wb_sel_i(sel),
        .wb_stb_i(stb),
        .wb_cyc_i(cyc),
        .wb_ack_o(ack),
        .wb_err_o(err)
    );

    //-------------------------------------------------------------------------
    // Transacao Wishbone: mantem a requisicao ate ack, amostra na mesma borda.
    //-------------------------------------------------------------------------
    task wb_write(input [31:0] endereco, input [31:0] dado, input [3:0] mask);
    begin
        @(negedge clk);
        adr = endereco; dat_w = dado; sel = mask;
        we = 1'b1; stb = 1'b1; cyc = 1'b1;
        @(posedge clk);
        while (!ack) @(posedge clk);
        @(negedge clk);
        stb = 1'b0; cyc = 1'b0; we = 1'b0; sel = 4'h0;
    end
    endtask

    task wb_read(input [31:0] endereco, output [31:0] dado);
    begin
        @(negedge clk);
        adr = endereco; sel = 4'hF;
        we = 1'b0; stb = 1'b1; cyc = 1'b1;
        @(posedge clk);
        while (!ack) @(posedge clk);
        dado = dat_r;                 // valido na borda do ack
        @(negedge clk);
        stb = 1'b0; cyc = 1'b0; sel = 4'h0;
    end
    endtask

    task checar(input [8*24:1] nome, input [31:0] obtido, input [31:0] esperado);
    begin
        if (obtido === esperado)
            $display("  [OK]    %0s = 0x%08h", nome, obtido);
        else begin
            $display("  [FALHA] %0s = 0x%08h (esperado 0x%08h)",
                     nome, obtido, esperado);
            erros = erros + 1;
        end
    end
    endtask

    reg [31:0] lido;

    initial begin
        $dumpfile("tb_sram_wb_wrapper.vcd");
        $dumpvars(0, tb_sram_wb_wrapper);

        repeat (4) @(posedge clk);
        rstn = 1'b1;
        repeat (2) @(posedge clk);

        $display("\n=== 1. Escrita e leitura de palavra inteira ===");
        wb_write(32'h0000_0000, 32'hDEAD_BEEF, 4'hF);
        wb_write(32'h0000_0004, 32'h1234_5678, 4'hF);
        wb_read (32'h0000_0000, lido); checar("addr 0x00", lido, 32'hDEAD_BEEF);
        wb_read (32'h0000_0004, lido); checar("addr 0x04", lido, 32'h1234_5678);

        $display("\n=== 2. Escrita parcial por byte ===");
        wb_write(32'h0000_0008, 32'h0000_0000, 4'hF);
        wb_write(32'h0000_0008, 32'hAABB_CCDD, 4'b0001);  // so byte 0
        wb_read (32'h0000_0008, lido); checar("byte 0", lido, 32'h0000_00DD);

        wb_write(32'h0000_0008, 32'hAABB_CCDD, 4'b1000);  // so byte 3
        wb_read (32'h0000_0008, lido); checar("byte 3", lido, 32'hAA00_00DD);

        wb_write(32'h0000_0008, 32'h1122_3344, 4'b0110);  // bytes 1 e 2
        wb_read (32'h0000_0008, lido); checar("bytes 1-2", lido, 32'hAA22_33DD);

        $display("\n=== 3. Acessos consecutivos ===");
        wb_write(32'h0000_000C, 32'h1111_1111, 4'hF);
        wb_write(32'h0000_0010, 32'h2222_2222, 4'hF);
        wb_write(32'h0000_0014, 32'h3333_3333, 4'hF);
        wb_read (32'h0000_000C, lido); checar("seq 0x0C", lido, 32'h1111_1111);
        wb_read (32'h0000_0010, lido); checar("seq 0x10", lido, 32'h2222_2222);
        wb_read (32'h0000_0014, lido); checar("seq 0x14", lido, 32'h3333_3333);

        $display("\n=== 4. Sem escrita fantasma com cyc baixo ===");
        // Simula o que o NEORV32 faz durante acesso interno: as linhas
        // mudam, mas cyc e stb ficam baixos.
        @(negedge clk);
        adr = 32'h0000_0000; dat_w = 32'hFFFF_FFFF; sel = 4'hF;
        we = 1'b1; stb = 1'b0; cyc = 1'b0;
        repeat (4) @(posedge clk);
        @(negedge clk);
        we = 1'b0; dat_w = 32'h0; sel = 4'h0;
        wb_read(32'h0000_0000, lido);
        checar("addr 0x00 intacto", lido, 32'hDEAD_BEEF);

        $display("\n=== 5. Ultima palavra (limite de 1 kB) ===");
        wb_write(32'h0000_03FC, 32'hCAFE_F00D, 4'hF);
        wb_read (32'h0000_03FC, lido); checar("addr 0x3FC", lido, 32'hCAFE_F00D);

        $display("\n----------------------------------------");
        if (erros == 0) $display("RESULTADO: todos os testes passaram.");
        else            $display("RESULTADO: %0d falha(s).", erros);
        $display("----------------------------------------\n");

        repeat (4) @(posedge clk);
        $finish;
    end

    // Rede de seguranca contra travamento
    initial begin
        #50000;
        $display("ERRO: timeout do testbench (ack nunca chegou?).");
        $finish;
    end

endmodule
