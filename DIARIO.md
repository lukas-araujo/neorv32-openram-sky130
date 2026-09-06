# Diário de bordo — SRAM OpenRAM + NEORV32 em sky130

Registro cronológico do projeto. Duas finalidades: rastrear decisões
para não repetir discussão, e acumular material real para a aula.

**Como usar:** a cada sessão de trabalho, acrescente uma entrada. Não
precisa ser bonito. O que importa é registrar o **erro** e a **causa**,
não só a solução. Erro sem causa registrada não ensina nada depois.

Modelo de entrada:

```
## AAAA-MM-DD — título curto

**Objetivo:** o que eu queria fazer.
**Fiz:** comandos / mudanças.
**Quebrou:** mensagem de erro literal (copie e cole, não parafraseie).
**Causa:** por que quebrou, quando eu descobrir.
**Resolvi com:** o que funcionou.
**Tempo gasto:** aproximado.
**Vira slide?** sim/não — e por quê.
```

---

## 2026-09-06 — Planejamento e decisões de arquitetura

**Objetivo:** definir escopo, ferramentas e arquitetura antes de instalar
qualquer coisa.

**Contexto de partida:** o objetivo final é sintetizar um RISC-V. Como
todo processador tem memória, e sintetizar memória como flip-flops é
inviável em área, surge a necessidade de um compilador de SRAM. Daí a
OpenRAM. A memória externa também será reaproveitada em outro projeto
pessoal.

### Decisões tomadas

| # | Decisão | Motivo |
|---|---|---|
| D1 | Fluxo **híbrido**: síntese no Cadence (VM da faculdade), layout no LibreLane (notebook) | sky130 não distribui techfile QRC nem rule decks Cadence; assinatura física não fecha no Innovus |
| D2 | Núcleo **NEORV32** | SoC completo pronto, com ganchos de extensão documentados (XBUS e CFS) |
| D3 | Somador no **CFS** | Periférico interno já mapeado em memória, com header de driver e demo prontos |
| D4 | SRAM no **XBUS** (Wishbone b4) | Interface pensada para memória/periférico externo; reaproveitável no outro projeto |
| D5 | **Desabilitar IMEM/DMEM internas** do NEORV32 | São arrays em VHDL → viram flip-flops em ASIC; substituídas pela macro OpenRAM |
| D6 | **VHDL é a fonte da verdade**; Verilog gerado via GHDL só para o LibreLane | Yosys não lê VHDL; evita duas fontes divergindo |
| D7 | SRAM alvo: **32 bits × 256 palavras (1 kB), single port** | Casa com barramento de 32 bits; configuração bastante rodada |
| D8 | Validar Cadence primeiro com macro **pré-gerada** do `sky130_sram_macros` | Separa "setup do Cadence errado" de "config da OpenRAM errada" |
| D9 | Ambiente Cadence **separado** do script da TSMC | Variáveis residuais da TSMC podem fazer o Genus pegar biblioteca errada silenciosamente |
| D10 | Incluir cadeia completa de verificação de síntese: lint → `check_design` → `check_timing` → LEC → STA → sim. pós-síntese | Todas rodam com sky130 (só precisam de `.lib`); LEC é diferencial raro em trabalho de graduação |

⚠️ Pegadinha antecipada do LEC: a SRAM precisa ser declarada black box
nos **dois** lados da comparação (golden e revised), senão o Conformal
acusa diferença inexistente.

### Inventário da VM (Cadence)

Funciona com sky130 (só precisa de `.lib` / `.lef` / Verilog):
Genus, Innovus, Joules (DDI 22.1); Xcelium 23.09; Tempus, Voltus
(SSV 23.1); Conformal 23.2.

Não funciona com sky130: PVS 23.1 e Pegasus 23.1 (faltam rule decks),
Quantus 22.1 (falta techfile QRC).

Oportunidades identificadas:
- Conformal (LEC) funciona 100% — provar equivalência RTL × netlist.
- SPEF gerado pelo OpenROAD pode alimentar STA no Tempus, contornando
  a ausência do Quantus.

⚠️ Há PDK TSMC 12nm sob NDA na VM. Não copiar, não misturar, não citar
em material público.

### Armadilhas já mapeadas (antes de bater nelas)

- Não clonar `google/skywater-pdk` direto: ~7 GB, é PDK fonte, precisa
  ser processado pelo `open_pdks`. Usar `ciel`.
- Tutoriais de 2021 mandam criar `technology/sky130A` na mão na OpenRAM.
  **Obsoleto** — hoje há suporte nativo e criar na mão gera conflito.
- Efabless faliu. `efabless/OpenLane` e `efabless/openlane2` não são mais
  referência viva. O sucessor é `librelane/librelane` (FOSSi Foundation).
- Ubuntu 24.04 bloqueia `pip install` no Python do sistema (PEP 668).
- Simulação pós-síntese: a SRAM entra pelo `.v` comportamental, não por
  netlist de portas. Sem inicializar o array, tudo vira `X` e propaga.

**Tempo gasto:** ~1 sessão de discussão.

**Vira slide?** Sim — praticamente toda esta entrada é a Aula 1.

---

## Pendências abertas

- [ ] Instalar OpenRAM em `/home/lukas/Projects/OpenRAM`
- [ ] `make sky130-pdk` e `make sky130-install`
- [ ] Montar `~/setup_sky130.sh` limpo na VM e testar `genus -version`
- [ ] Definir estratégia de carga de programa sem IMEM interna
