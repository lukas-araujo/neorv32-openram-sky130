"""
TESTE B -- menor macro possivel para o Spiral.

16 palavras x 32 bits, 1rw1r (porta 0 = escrita, porta 1 = leitura).
Os memMod do Spiral tem 8 e 4 palavras: usariam esta macro com os bits
altos do endereco amarrados em 0 -- metade ou 3/4 da macro sem uso.

Ponto de parada no log: "Using bitcell: bitcell_2port".
Se aparecer pbitcell, interrompa (ambiente errado).
"""
word_size = 32
num_words = 16
num_rw_ports = 1
num_r_ports  = 1
num_w_ports  = 0
ports_human  = "1rw1r"

import os
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "common_min.py")).read())
