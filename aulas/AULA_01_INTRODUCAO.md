# Aula 1 — Do RTL ao silício com ferramentas abertas

**Público:** colegas de curso sem contato prévio com EDA open source,
PDK ou compiladores de memória.
**Duração sugerida:** 50–60 min + 10 min de perguntas.
**Pré-requisito:** saber o que é Verilog/VHDL e ter sintetizado algo
para FPGA. Só isso.

**Ao final, o aluno deve conseguir responder:**

1. O que é um PDK e por que ele não é "só um conjunto de arquivos".
2. Por que projetar chip era atividade fechada até 2020.
3. Qual ferramenta aberta corresponde a qual ferramenta comercial.
4. Por que memória não pode ser simplesmente sintetizada.
5. O que um compilador de memória entrega e por que isso é uma
   "caixa-preta" para o sintetizador.

---

## 1. Abertura — a pergunta que organiza a aula (5 min)

Escreva no quadro:

> "Quanto custa fazer um chip?"

Deixe o pessoal chutar. Depois reformule:

> "Quanto custa **tentar** fazer um chip?"

A diferença entre as duas perguntas é o assunto da aula. Fabricar
sempre foi caro. Mas até 2020, **tentar** também era proibitivo — e não
por causa do dinheiro da fábrica, e sim por causa de um documento
jurídico.

---

## 2. O muro do NDA (5 min)

Para projetar um circuito integrado você precisa saber, com precisão de
nanômetro, o que a fábrica consegue fazer: largura mínima de trilha,
distância mínima entre camadas, como o transistor se comporta em
temperatura e tensão, quanto de resistência tem cada metal.

Esse conjunto de informação é o **PDK** — *Process Design Kit*.

E o PDK sempre foi segredo industrial. Antes de receber um, você
assinava um acordo de confidencialidade com a fábrica. Consequência em
cadeia:

- Ferramenta open source não podia ser desenvolvida contra um PDK real.
- Trabalho acadêmico não era reproduzível: ninguém fora do grupo tinha
  o mesmo PDK.
- Hobbyista, estudante e projeto pequeno estavam simplesmente fora.

> **Analogia para o quadro:** é como se você pudesse comprar tijolo e
> cimento, mas o manual com as dimensões dos tijolos fosse secreto e só
> liberado para construtoras grandes mediante contrato.

Em 2020 o Google e a SkyWater Technology publicaram o **SKY130** sob
licença Apache 2.0. PDK real, de fábrica real, aberto. Foi isso que
destravou todo o ecossistema que vamos usar.

---

## 3. O que tem dentro de um PDK (8 min)

Abra um diretório do sky130 ao vivo e mostre. Não é abstrato, são
arquivos.

| Conteúdo | Para que serve | Quem consome |
|---|---|---|
| Regras de DRC | O que é fisicamente fabricável | Magic, KLayout |
| Modelos SPICE | Como o transistor se comporta | ngspice, Spectre |
| Biblioteca de células padrão | Portas prontas (NAND, flip-flop…) | sintetizador |
| `.lib` (Liberty) | Timing e potência de cada célula | Genus, Yosys, Tempus |
| `.lef` | Contorno físico: onde ficam os pinos, quanto ocupa | Innovus, OpenROAD |
| `.gds` | O layout de verdade, camada por camada | fábrica |
| Células de I/O | Pads de entrada e saída do chip | montagem do padframe |

**Ponto que vale insistir:** uma célula lógica aparece em várias
representações ao mesmo tempo. O sintetizador enxerga a versão `.lib`
(timing). O roteador enxerga a versão `.lef` (geometria). A fábrica
enxerga o `.gds`. É a mesma célula em três abstrações — entender isso
resolve metade da confusão do fluxo.

### O SKY130 em números

- Nó de 130 nm, tecnologia madura, originalmente desenvolvida
  internamente pela Cypress Semiconductor antes da SkyWater ser
  desmembrada dela.
- Núcleo em 1,8 V, I/O de 5,0 V (operável em 2,5 V).
- 5 níveis de metal, mais um nível de interconexão local.
- Capaz de indutor; capacitor MiM opcional.

### sky130A e sky130B

Duas variantes. A **A** é a usada em quase todo trabalho acadêmico. A
**B** acrescenta células de memória não volátil (SONOS). São compatíveis
em regras de projeto, mas não se misturam num mesmo chip. Se você não
precisa de flash embarcado, use a A e ignore a B.

> ⚠️ Diga com todas as letras: o repositório oficial ainda se
> descreve como *experimental preview*. Serve para chip de teste e
> validação inicial, não para produção.

---

## 4. O fluxo: de RTL a GDSII (8 min)

Desenhe como uma cadeia linear. Cada caixa consome o que a anterior
produziu.

```
Verilog/VHDL
    ↓  síntese lógica            → netlist de portas
    ↓  floorplan                 → contorno do chip, onde ficam as macros
    ↓  placement                 → posição de cada célula
    ↓  CTS (árvore de clock)     → clock distribuído com skew controlado
    ↓  routing                   → fios conectando tudo
    ↓  extração de parasitas     → resistência e capacitância reais dos fios
    ↓  STA (análise de timing)   → o circuito fecha na frequência alvo?
    ↓  DRC / LVS                 → é fabricável? confere com o netlist?
GDSII
```

**A grande diferença para FPGA:** em FPGA você sintetiza para blocos
que já existem no silício. Aqui você está *desenhando o silício*. Não
existe "bloco de RAM" pronto esperando — é isso que vai nos levar à
OpenRAM.

---

## 5. As ferramentas (10 min)

Duas famílias resolvem as mesmas etapas.

| Etapa | Comercial (Cadence) | Aberta |
|---|---|---|
| Simulação | Xcelium | Verilator, Icarus, GHDL |
| Síntese lógica | Genus | Yosys |
| Place & route | Innovus | OpenROAD |
| Extração RC | Quantus | OpenRCX |
| STA | Tempus | OpenSTA |
| DRC / LVS | PVS, Pegasus | Magic, Netgen, KLayout |
| Potência | Joules, Voltus | OpenSTA (estimado) |
| Equivalência lógica | Conformal | (sem equivalente maduro) |
| Simulação analógica | Spectre | ngspice |
| Compilador de SRAM | compiladores da fábrica | **OpenRAM** |

### As três camadas que confundem todo mundo

Este é o slide que mais gera pergunta. Vale caprichar.

- **OpenROAD** é o *motor* de projeto físico: floorplan, placement, CTS,
  routing. Equivale ao Innovus. Sozinho é de baixo nível, dirigido por
  Tcl.
- **OpenLane** é o *fluxo* que orquestra OpenROAD + Yosys + Magic +
  Netgen + KLayout, levando de RTL a GDSII com um arquivo de
  configuração só.
- **LibreLane** é o estado atual dessa linha.

> **História que vale contar** (e explica por que os tutoriais na
> internet estão desatualizados): o OpenLane foi criado pela Efabless.
> A Efabless faliu. O projeto foi assumido pela FOSSi Foundation e
> renomeado para LibreLane, com fluxo padrão "Classic" que replica o
> OpenLane quase perfeitamente e aceita os mesmos arquivos de
> configuração.

**Recado prático para a turma:** boa parte do material bem ranqueado no
Google é de 2021 e vai custar horas de vocês. Sinais de tutorial
obsoleto: manda clonar `efabless/OpenLane`, ou manda criar o diretório
`sky130A` na mão dentro da OpenRAM.

---

## 6. Como se obtém o PDK na prática (4 min)

Aqui cabe uma demonstração rápida e uma armadilha.

O repositório `google/skywater-pdk` é o PDK **fonte**. O download passa
de 7 GB e o conteúdo ainda precisa ser processado antes de virar algo
que as ferramentas consigam ler. Quem faz esse processamento é o
`open_pdks`. Quem distribui o resultado já pronto é o `ciel` (sucessor
do `volare`).

```
google/skywater-pdk   →   open_pdks   →   ciel   →   sky130A pronto
   (fonte, 7 GB)         (processa)     (empacota)    (usável)
```

> **Erro clássico:** clonar o repositório do Google achando que vai
> conseguir usar. Perde-se uma tarde e vários gigabytes.

---

## 7. Por que memória é especial (10 min)

Este é o coração da aula.

### O experimento mental

Peça para alguém escrever no quadro, em Verilog:

```verilog
reg [31:0] mem [0:255];   // 1 kB de memória
```

Pergunte: **o que o sintetizador faz com isso?**

Resposta: 8192 flip-flops, mais toda a lógica de multiplexação para
selecionar qual palavra ler. Em FPGA isso é absorvido por um bloco de
RAM dedicado que já existe no chip. Em ASIC, não existe bloco pronto —
o sintetizador constrói literalmente com portas lógicas.

### Por que isso é ruim

Um flip-flop em biblioteca padrão custa mais de vinte transistores.
Uma célula de SRAM custa **seis**, num layout desenhado à mão para ser
o mais denso possível. A diferença de área é de mais de uma ordem de
grandeza — e ainda vem acompanhada de problema de timing e de consumo.

> **Frase-resumo para o slide:** memória não se sintetiza, memória se
> *compila*.

### O que é um compilador de memória

Uma ferramenta que recebe parâmetros — quantas palavras, quantos bits
por palavra, quantas portas de acesso — e gera um bloco de memória
completo, com layout otimizado.

Isso não é novidade: toda fábrica tem o seu. O que é novidade é existir
um **aberto**. Esse é o **OpenRAM**, da Universidade da Califórnia em
Santa Cruz.

### O que a OpenRAM entrega

| Arquivo | Conteúdo | Usado em |
|---|---|---|
| `.gds` | layout | fabricação, LibreLane |
| `.lef` | contorno e pinos | Innovus, OpenROAD |
| `.lib` | timing caracterizado | Genus, Yosys, Tempus |
| `.sp` | netlist SPICE | simulação de circuito |
| `.v` | **modelo comportamental** | simulação lógica |

**Insista neste ponto, é o que mais confunde:** aquele `.v` **não é
sintetizável**. É só um modelo para simular. A memória de verdade é o
GDS. Para o sintetizador, a SRAM é uma **caixa-preta** (*hard macro*):
ele lê apenas o `.lib` para saber o timing dos pinos e nunca olha
dentro.

### Modo front-end e back-end

A OpenRAM roda de dois jeitos. No **front-end** ela gera netlist,
timing e views, estimando potência e atraso analiticamente — rápido. No
**back-end** ela gera também o layout e roda DRC/LVS — lento, mas é o
que produz o GDS. Comece sempre pelo front-end.

---

## 8. Onde o RISC-V entra (5 min)

**RISC-V é uma ISA aberta** — a especificação do conjunto de instruções,
livre de royalties. Não é um chip, é um documento. Qualquer um pode
implementar.

Vamos usar o **NEORV32**: um SoC completo em VHDL, com processador,
periféricos e dois ganchos de extensão documentados.

### O elo com a memória — e o motivo real do projeto

Um processador tem dois tipos de memória, e eles são bem diferentes:

- **Banco de registradores** (32 × 32 bits): pequeno. Flip-flop resolve,
  o sintetizador dá conta sem drama.
- **Memória de programa e de dados** (kilobytes): é aqui que o
  experimento mental da seção 7 explode.

Por padrão o NEORV32 traz IMEM e DMEM internas, descritas como arrays
em VHDL. Em FPGA viram block RAM. **Em ASIC virariam um mar de
flip-flops.**

> **Esta é a tese da aula inteira:** a gente não foi atrás da OpenRAM
> por curiosidade. Sem ela, o SoC não fecha em área. O compilador de
> memória é o que torna o processador sintetizável.

### Os dois ganchos do NEORV32

- **CFS** (*Custom Functions Subsystem*): periférico interno,
  fortemente acoplado, já mapeado em memória. É onde vai o nosso
  somador.
- **XBUS**: interface de barramento externo compatível com Wishbone b4,
  feita para pendurar memória e periférico fora do processador. É onde
  vai a SRAM.

---

## 9. O nosso projeto e a decisão de fluxo (5 min)

Arquitetura alvo:

```
        ┌──────────────── NEORV32 ────────────────┐
        │   CPU RV32                              │
        │   CFS ── somador (nosso periférico)     │
        │   IMEM/DMEM internas: DESABILITADAS     │
        └──────────────── XBUS ───────────────────┘
                           │  (Wishbone b4)
                    ┌──────┴───────┐
                    │ SRAM 1 kB    │  ← macro gerada pela OpenRAM
                    │ 32 × 256     │
                    └──────────────┘
```

### Por que fluxo híbrido, e não tudo no Cadence

Vale ser honesto com a turma, porque é uma limitação real e ninguém
conta:

O sky130 **não distribui** techfile QRC nem rule decks Cadence — essas
coisas existem apenas na versão proprietária do PDK, sob NDA. Resultado:
no ambiente Cadence, o Quantus não extrai parasitas e o PVS/Pegasus não
roda DRC/LVS para sky130.

Então dividimos:

| Onde | O quê | Por quê |
|---|---|---|
| Cadence (VM) | Genus, Xcelium, Conformal, Tempus | Só precisam de `.lib`, `.lef` e HDL |
| Aberto (notebook) | OpenRAM, LibreLane | Sky130 é cidadão de primeira classe |

E isso vira vantagem: dá para **comparar os dois mundos** no mesmo
projeto — área e timing do Yosys contra os do Genus. É um resultado que
um fluxo só não produz.

---

## 10. Como saber se a síntese deu certo (10 min)

O erro mais comum de quem está começando é achar que a síntese "deu
certo" porque rodou sem mensagem de erro. Rodar sem erro significa
apenas que a ferramenta **entendeu** o que você escreveu. Não diz nada
sobre o resultado estar correto.

Escreva as quatro perguntas no quadro. Elas são independentes — cada
uma exige uma verificação diferente, e passar em uma não implica passar
nas outras.

> 1. O netlist faz a mesma coisa que o RTL?
> 2. Sobrou alguma coisa sem resolver ou sem restrição?
> 3. O circuito fecha timing?
> 4. Ele funciona de verdade, com atraso e com reset?

### Antes da síntese: lint

Análise estática do RTL, sem simular. Pega latch criado por acidente,
sinal não inicializado, largura de barramento incompatível, `case` sem
default. É a verificação mais barata que existe e encontra bug antes de
ele entrar no fluxo.

Ferramentas: HAL (dentro do Xcelium) no lado comercial, `verilator
--lint-only` ou `ghdl -s` no lado aberto.

### Pergunta 1 — equivalência lógica (LEC)

O sintetizador **reescreve o circuito inteiro**. Ele fatora expressões,
remapeia portas, compartilha lógica, muda a estrutura por completo. O
netlist que sai não se parece em nada com o que você escreveu.

Então: como ter certeza de que ele não mudou o comportamento junto?

Simular não prova. Simulação cobre os vetores que você escreveu, e só.
**LEC** (*Logic Equivalence Checking*) faz outra coisa: compara
matematicamente as duas descrições. Ele particiona os dois circuitos em
pontos de comparação — registradores, saídas primárias — e prova
formalmente que a lógica combinacional entre eles é idêntica. Se houver
diferença, ele aponta exatamente onde.

Ferramenta: **Conformal**, da Cadence. Ele precisa apenas do `.lib`,
então funciona integralmente com sky130 — e isso é raro no fluxo
comercial com PDK aberto.

> ⚠️ **Pegadinha específica do nosso projeto:** a SRAM é uma
> caixa-preta. Ela precisa ser declarada como *black box* nos **dois
> lados** da comparação. Se você declarar só num lado, o Conformal
> acusa diferença onde não existe nenhuma, e você perde a tarde
> procurando um bug que não é seu.

### Pergunta 2 — checagens estruturais no próprio Genus

Duas que valem sempre, e que a maioria pula:

**`check_design -unresolved`** — lista módulos que o sintetizador não
conseguiu resolver. Um módulo não resolvido vira caixa-preta
**silenciosamente**: a síntese termina, o relatório de área sai bonito,
e falta um pedaço do circuito. É o erro número um de quem trabalha com
macro pela primeira vez, tipicamente por ter esquecido de carregar o
`.lib` da SRAM.

**`check_timing`** — aponta caminhos sem restrição, clock não declarado,
entrada sem `input_delay`. Sem isso, o timing pode "fechar"
maravilhosamente pelo motivo errado: não havia nada sendo verificado.
SDC ruim produz relatório otimista, não erro.

Complementos úteis: `report_qor`, `report_area`, `report_gates`.

### Pergunta 3 — análise de timing (STA)

Verifica setup e hold em todos os caminhos, sem precisar de vetores de
teste.

Um detalhe honesto: o timing reportado **durante a síntese** é
estimado, porque os fios ainda não existem. Ele só vira confiável
depois do roteamento, com os parasitas reais extraídos. É por isso que
no nosso projeto planejamos levar o SPEF gerado pelo OpenROAD para o
Tempus — assim a análise final usa parasitas de verdade.

### Pergunta 4 — simulação pós-síntese (gate-level) com SDF

O LEC prova que a lógica é a mesma. Ele **não** enxerga inicialização,
comportamento de reset, propagação de `X`, nem violação real de timing.

A simulação em nível de portas com atrasos anotados por SDF enxerga.
Você roda o mesmo testbench do RTL contra o netlist e compara.

> **Frase para o slide:** o LEC responde *"é o mesmo circuito?"*. A
> simulação responde *"esse circuito funciona?"*. São perguntas
> diferentes e nenhuma das duas substitui a outra.

No nosso caso a SRAM entra por meio do `.v` comportamental — ela não
tem netlist de portas para simular.

### Quadro-resumo

| Verificação | Responde | Ferramenta | Funciona com sky130? |
|---|---|---|---|
| Lint | O RTL tem vício? | HAL, Verilator | sim |
| `check_design` | Ficou caixa-preta? | Genus | sim |
| `check_timing` | O SDC cobre tudo? | Genus | sim |
| LEC | É o mesmo circuito? | Conformal | sim |
| STA | Fecha timing? | Genus, Tempus | sim |
| Sim. pós-síntese | Funciona mesmo? | Xcelium | sim |
| DRC / LVS | É fabricável? | Magic, Netgen | só no fluxo aberto |

As seis primeiras rodam no ambiente Cadence. A última é o motivo do
fluxo híbrido.

---

## 11. Onde baixar os arquivos

Todo o material desta aula, o diário de bordo do projeto, os scripts e
os arquivos de configuração estão em:

> **`<COLOCAR O LINK DO REPOSITÓRIO AQUI>`**

Clone com:

```bash
git clone <URL_DO_REPOSITORIO>
```

Ou baixe o ZIP pelo botão verde **Code → Download ZIP**, se preferir
não usar git.

---

## 12. Glossário para distribuir

| Termo | Significado |
|---|---|
| **PDK** | Kit com tudo que descreve o que a fábrica consegue fabricar |
| **RTL** | Descrição do circuito em Verilog/VHDL |
| **Netlist** | Lista de portas lógicas e suas conexões |
| **GDSII** | Formato do layout final, o que vai para a fábrica |
| **Standard cell** | Porta lógica pré-desenhada da biblioteca |
| **Hard macro** | Bloco com layout fixo, tratado como caixa-preta |
| **Liberty (`.lib`)** | Timing e potência de células e macros |
| **LEF** | Contorno físico e posição dos pinos |
| **SPEF** | Parasitas (R e C) extraídos do layout |
| **DRC** | Verificação das regras de fabricação |
| **LVS** | Confere se o layout bate com o netlist |
| **STA** | Análise de timing sem simular vetores |
| **CTS** | Construção da árvore de distribuição de clock |
| **ISA** | Conjunto de instruções (RISC-V é uma ISA) |
| **Lint** | Análise estática do RTL, sem simulação |
| **LEC** | Prova formal de que netlist e RTL são equivalentes |
| **SDC** | Arquivo com as restrições de timing (clock, delays) |
| **SDF** | Atrasos anotados, usados na simulação pós-síntese |
| **QoR** | *Quality of Results* — resumo de área, timing e potência |
| **Black box** | Bloco cujo interior a ferramenta não analisa |

---

## 13. Perguntas que vão aparecer

**"Se é aberto, posso fabricar meu chip de graça?"**
Não. A fábrica cobra. O que ficou aberto foi a informação de projeto, o
que permite chegar até o GDS sem gastar nada.

**"Ferramenta aberta é pior que a comercial?"**
Em nós avançados, a diferença é grande. Em 130 nm e projeto de porte
acadêmico, o fluxo aberto é competitivo e tem tapeouts comprovados. E
tem uma vantagem que a comercial não tem: roda no seu notebook, sem
licença e sem fila.

**"Por que 130 nm e não algo moderno?"**
Porque é o que está aberto. E porque 130 nm continua em uso comercial
real em microcontrolador, IoT e projeto mixed-signal.

**"Preciso de máquina potente?"**
Para o nosso escopo, um notebook comum resolve. Reserve uns 15 GB de
disco para o PDK.

---

## 14. Roteiro de tempo

| Bloco | Min |
|---|---|
| Abertura e o muro do NDA | 10 |
| O que tem no PDK | 8 |
| O fluxo RTL → GDSII | 8 |
| Ferramentas e as três camadas | 10 |
| Obtendo o PDK | 4 |
| **Por que memória é especial** | 10 |
| RISC-V e o elo com a memória | 5 |
| Nosso projeto e fluxo híbrido | 5 |
| Como saber se a síntese deu certo | 10 |
| **Total** | **70** |

Setenta minutos é bastante para uma sessão só. Duas saídas:

- **Dividir em duas aulas.** Aula 1A vai até a seção 9 (o contexto e o
  porquê). Aula 1B é a seção 10, dada logo antes da prática de síntese,
  quando a turma já tem onde encaixar o assunto.
- **Manter junto** e cortar a seção 6 (obtenção do PDK), que se resolve
  bem por escrito no README do repositório.

**Nunca corte a seção 7** — é o único bloco que justifica o projeto
inteiro existir.
