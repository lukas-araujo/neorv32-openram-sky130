"""
TESTE A -- prova do limite. ESPERADO: FALHAR em segundos.

Tamanho do memMod8 do Spiral (8 palavras x 32 bits, 1 escrita + 1 leitura).

A OpenRAM 1.2.49 exige no minimo 16 palavras (compiler/sram_config.py,
amend_words_per_row):
    "Minimum number of rows is 16, but given ..."
Rodamos mesmo assim para registrar a mensagem real no diario.
"""
word_size = 32
num_words = 8
num_rw_ports = 1
num_r_ports  = 1
num_w_ports  = 0
ports_human  = "1rw1r"
# Sem write_size: escrita da palavra inteira (o Spiral nao usa byte enable)
# Sem spare rows/cols: a regra de paridade da OpenRAM so vale para 1 porta

import os
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "common_min.py")).read())
