//=============================================================================
// tb_gate.v
//
// Testbench para SIMULACAO POS-SINTESE do netlist de portas.
//
// Projeto: neorv32-openram-sky130
//
//-----------------------------------------------------------------------------
// POR QUE ESTE TESTBENCH E EM VERILOG
//-----------------------------------------------------------------------------
// O netlist que o Genus escreve e Verilog, e as celulas do sky130
// tambem. Testbench em Verilog evita atravessar fronteira de linguagem
// mais uma vez.
//
//-----------------------------------------------------------------------------
// POR QUE ESTA SIMULACAO E DIFERENTE DA DE RTL
//-----------------------------------------------------------------------------
// A simulacao de RTL prova que a LOGICA esta certa. Esta prova outras
// coisas, que o LEC nao pega:
//
//   - inicializacao e comportamento de reset em nivel de portas
//   - propagacao de X a partir de estado nao inicializado
//   - violacao real de timing, com os atrasos do SDF
//
// LEC responde "e o mesmo circuito?"; isto responde "esse circuito
// funciona?". Sao perguntas diferentes.
//
//-----------------------------------------------------------------------------
// ⚠️ SIMULACAO DE PORTAS E LENTA
//-----------------------------------------------------------------------------
// Sao ~9.230 celulas com atrasos anotados. O programa de benchmark leva
// 2,4 ms de tempo simulado (120 mil ciclos a 50 MHz) -- isso pode levar
// HORAS em nivel de portas.
//
// USE UM PROGRAMA MINIMO. O objetivo aqui nao e reexecutar o benchmark:
// e provar que o netlist sai do reset, busca instrucao da memoria e
// executa. Algumas centenas de ciclos bastam.
//=============================================================================

`timescale 1ns / 1ps

module tb_gate;

    // 50 MHz -- casa com CLK_FREQ_C e com o SDC
    localparam PERIODO = 20.0;

    reg clk  = 1'b0;
    reg rstn = 1'b0;

    wire        uart_txd;
    wire [31:0] gpio;

    integer ciclos = 0;

    always #(PERIODO/2.0) clk = ~clk;

    //-------------------------------------------------------------------------
    // Reset: 10 ciclos, generoso de proposito.
    // Em nivel de portas o reset precisa propagar por toda a arvore, que
    // ainda nao foi construida (sem CTS). Reset curto deixa parte dos
    // flip-flops em X.
    //-------------------------------------------------------------------------
    initial begin
        rstn = 1'b0;
        repeat (10) @(posedge clk);
        rstn = 1'b1;
        $display("[TB] reset liberado em t=%0t", $time);
    end

    //-------------------------------------------------------------------------
    // Sistema sob teste: o NETLIST, nao o RTL
    //-------------------------------------------------------------------------
    neorv32_sram_soc dut (
        .clk_i       (clk),
        .rstn_i      (rstn),
        .uart0_txd_o (uart_txd),
        .uart0_rxd_i (1'b1),
        .gpio_o      (gpio)
    );

    //-------------------------------------------------------------------------
    // Monitor de GPIO: reporta so quando muda
    //-------------------------------------------------------------------------
    reg [31:0] gpio_ant = 32'hXXXX_XXXX;

    always @(posedge clk) begin
        if (rstn && (gpio !== gpio_ant)) begin
            $display("[TB:GPIO] %02h  em t=%0t", gpio[7:0], $time);
            gpio_ant <= gpio;
        end
    end

    //-------------------------------------------------------------------------
    // Detector de X no GPIO
    //
    // Esta e a verificacao mais importante desta simulacao. Se o GPIO
    // ficar em X depois do reset, houve propagacao de estado nao
    // inicializado -- tipicamente memoria sem pre-carga, ou reset que
    // nao alcancou algum flip-flop.
    //-------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rstn) begin
            ciclos <= ciclos + 1;
            if (ciclos == 50) begin
                if (^gpio[7:0] === 1'bx)
                    $display("[TB] ⚠️ GPIO em X 50 ciclos apos o reset. Provavel propagacao de X.");
                else
                    $display("[TB] GPIO definido apos o reset: %02h", gpio[7:0]);
            end
        end
    end

    //-------------------------------------------------------------------------
    // Monitor de UART minimo
    //
    // Amostra no meio de cada bit. O baud tem que casar com o que o
    // software configura (ver sw/cfs_benchmark/main.c).
    //-------------------------------------------------------------------------
    localparam real BAUD    = 1000000.0;
    localparam real BIT_NS  = 1000.0 / BAUD * 1000.0;  // ns por bit

    integer i;
    reg [7:0] rx_byte;

    initial begin
        forever begin
            @(negedge uart_txd);              // start bit
            #(BIT_NS * 1.5);                  // meio do bit 0
            for (i = 0; i < 8; i = i + 1) begin
                rx_byte[i] = uart_txd;
                #(BIT_NS);
            end
            if (rx_byte >= 8'h20 && rx_byte < 8'h7F)
                $write("%c", rx_byte);
            else if (rx_byte == 8'h0A)
                $write("\n");
            $fflush();
        end
    end

    //-------------------------------------------------------------------------
    // Limite de tempo
    //
    // Ajuste conforme o programa. Simulacao de portas e lenta: comece
    // pequeno e va aumentando.
    //-------------------------------------------------------------------------
    initial begin
        #200000;   // 200 us = 10.000 ciclos
        $display("\n[TB] fim por limite de tempo em t=%0t", $time);
        $finish;
    end

endmodule
