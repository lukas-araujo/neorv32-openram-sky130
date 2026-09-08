// ================================================================== //
// cfs_benchmark/main.c
//
// Mede o custo real de um periferico mapeado em memoria contra a ALU
// da propria CPU, usando o contador mcycle.
//
// Projeto: neorv32-openram-sky130
//
// ------------------------------------------------------------------ //
// A PERGUNTA
// ------------------------------------------------------------------ //
// "Vale a pena colocar esta operacao em hardware?"
//
// Um acelerador so compensa quando o custo da OPERACAO supera o custo
// de TRANSPORTAR os dados ate ele. Este programa mede os dois lados
// para que a resposta seja um numero, nao uma opiniao.
//
// Tres experimentos:
//
//   1. SOMA UNICA      a+b em software  x  2 escritas + 1 leitura
//                      Expectativa: o hardware PERDE. A ALU faz em
//                      1 ciclo o que o barramento nao entrega em 6.
//
//   2. ACUMULAR N      laco de somas    x  N escritas em ACC
//                      Aqui o hardware tem chance: cada escrita ja faz
//                      o trabalho, sem leitura de volta.
//
//   3. OVERHEAD PURO   acesso a endereco NAO MAPEADO do CFS.
//                      Isola o custo do transporte, sem operacao.
//                      E o numero mais reaproveitavel: sabendo o custo
//                      fixo de um acesso, da para estimar QUALQUER
//                      operacao futura antes de escrever RTL.
// ================================================================== //

#include <neorv32.h>

#define BAUD_RATE 1000000
#define N_ACC     64      // valores a acumular no experimento 2

// Mapa de registradores do nosso CFS (ver rtl/neorv32_cfs.vhd)
#define CFS_OPA   (NEORV32_CFS->REG[0])   // 0x00 rw
#define CFS_OPB   (NEORV32_CFS->REG[1])   // 0x04 rw
#define CFS_SUM   (NEORV32_CFS->REG[2])   // 0x08 ro
#define CFS_ACC   (NEORV32_CFS->REG[3])   // 0x0C escrita acumula
#define CFS_CTRL  (NEORV32_CFS->REG[4])   // 0x10 bit0 limpa ACC
#define CFS_VOID  (NEORV32_CFS->REG[64])  // 0x100 nao mapeado

// volatile impede o compilador de dobrar as contas em tempo de
// compilacao. Sem isso, -Os elimina o experimento inteiro e voce mede
// zero ciclo -- erro classico de benchmark.
volatile uint32_t dados[N_ACC];
volatile uint32_t resultado_sw;


int main() {

  neorv32_uart0_setup(BAUD_RATE, 0);

  neorv32_uart0_printf("\n=== Benchmark CFS: hardware x software ===\n");
  neorv32_uart0_printf("Clock: %u Hz\n\n", neorv32_sysinfo_get_clk());

  uint32_t t0, t1;
  uint32_t ciclos_vazio, ciclos_hw, ciclos_sw, ciclos_void;
  uint32_t i;

  // ---------------------------------------------------------------
  // Calibracao: quanto custa a propria medicao
  // ---------------------------------------------------------------
  t0 = neorv32_cpu_csr_read(CSR_MCYCLE);
  t1 = neorv32_cpu_csr_read(CSR_MCYCLE);
  ciclos_vazio = t1 - t0;
  neorv32_uart0_printf("Overhead da medicao: %u ciclos\n", ciclos_vazio);
  neorv32_uart0_printf("(descontado dos resultados abaixo)\n\n");

  // ---------------------------------------------------------------
  // Sanidade: o somador funciona?
  //
  // Benchmark de hardware quebrado nao mede nada. Verificar antes.
  // ---------------------------------------------------------------
  CFS_OPA = 0x12345678;
  CFS_OPB = 0x11111111;
  uint32_t esperado = 0x12345678 + 0x11111111;
  uint32_t obtido = CFS_SUM;

  if (obtido == esperado) {
    neorv32_uart0_printf("[OK] somador: 0x%x\n", obtido);
  } else {
    neorv32_uart0_printf("[FALHA] somador: 0x%x (esperado 0x%x)\n",
                         obtido, esperado);
    return 1;
  }

  // Carry-out: 0xFFFFFFFF + 1 deve estourar
  CFS_OPA = 0xFFFFFFFF;
  CFS_OPB = 0x00000001;
  if ((CFS_SUM == 0) && ((CFS_CTRL & 1) == 1)) {
    neorv32_uart0_printf("[OK] carry-out\n\n");
  } else {
    neorv32_uart0_printf("[FALHA] carry-out\n\n");
  }

  // ---------------------------------------------------------------
  // EXPERIMENTO 1 -- soma unica
  // ---------------------------------------------------------------
  neorv32_uart0_printf("--- 1. Soma unica ---\n");

  t0 = neorv32_cpu_csr_read(CSR_MCYCLE);
  CFS_OPA = 100;
  CFS_OPB = 200;
  resultado_sw = CFS_SUM;
  t1 = neorv32_cpu_csr_read(CSR_MCYCLE);
  ciclos_hw = t1 - t0 - ciclos_vazio;

  volatile uint32_t a = 100, b = 200;
  t0 = neorv32_cpu_csr_read(CSR_MCYCLE);
  resultado_sw = a + b;
  t1 = neorv32_cpu_csr_read(CSR_MCYCLE);
  ciclos_sw = t1 - t0 - ciclos_vazio;

  neorv32_uart0_printf("  hardware (CFS): %u ciclos\n", ciclos_hw);
  neorv32_uart0_printf("  software (ALU): %u ciclos\n", ciclos_sw);

  // ---------------------------------------------------------------
  // EXPERIMENTO 3 -- overhead puro do barramento
  // (medido antes do 2 para ja poder interpretar o 2)
  // ---------------------------------------------------------------
  t0 = neorv32_cpu_csr_read(CSR_MCYCLE);
  CFS_VOID = 0;
  t1 = neorv32_cpu_csr_read(CSR_MCYCLE);
  ciclos_void = t1 - t0 - ciclos_vazio;
  neorv32_uart0_printf("\n--- 3. Overhead puro ---\n");
  neorv32_uart0_printf("  1 escrita no CFS: %u ciclos\n", ciclos_void);

  t0 = neorv32_cpu_csr_read(CSR_MCYCLE);
  resultado_sw = CFS_VOID;
  t1 = neorv32_cpu_csr_read(CSR_MCYCLE);
  neorv32_uart0_printf("  1 leitura do CFS: %u ciclos\n",
                       t1 - t0 - ciclos_vazio);

  // ---------------------------------------------------------------
  // EXPERIMENTO 2 -- acumular N valores
  // ---------------------------------------------------------------
  neorv32_uart0_printf("\n--- 2. Acumular %u valores ---\n", N_ACC);

  for (i = 0; i < N_ACC; i++) {
    dados[i] = i * 3 + 1;
  }

  // Hardware: N escritas, nenhuma leitura no meio
  CFS_CTRL = 1;                    // limpa o acumulador
  t0 = neorv32_cpu_csr_read(CSR_MCYCLE);
  for (i = 0; i < N_ACC; i++) {
    CFS_ACC = dados[i];
  }
  t1 = neorv32_cpu_csr_read(CSR_MCYCLE);
  ciclos_hw = t1 - t0 - ciclos_vazio;
  uint32_t soma_hw = CFS_ACC;

  // Software: carga, soma, incremento
  t0 = neorv32_cpu_csr_read(CSR_MCYCLE);
  uint32_t acc = 0;
  for (i = 0; i < N_ACC; i++) {
    acc += dados[i];
  }
  t1 = neorv32_cpu_csr_read(CSR_MCYCLE);
  ciclos_sw = t1 - t0 - ciclos_vazio;
  resultado_sw = acc;

  neorv32_uart0_printf("  hardware: %u ciclos (soma = %u)\n",
                       ciclos_hw, soma_hw);
  neorv32_uart0_printf("  software: %u ciclos (soma = %u)\n",
                       ciclos_sw, acc);

  if (soma_hw != acc) {
    neorv32_uart0_printf("  [FALHA] as somas divergem!\n");
  }

  neorv32_uart0_printf("\n=== fim ===\n");

  // Sinaliza fim no GPIO, para quem estiver olhando a forma de onda
  neorv32_gpio_port_set(0xAA);

  while (1) {
    asm volatile ("nop");
  }

  return 0;
}
