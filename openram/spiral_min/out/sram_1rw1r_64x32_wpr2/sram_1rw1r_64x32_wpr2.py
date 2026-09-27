"""
TESTE G -- repete o D forcando 2 palavras por linha (16 linhas x 128 colunas).
D e E falharam no roteador de alimentacao com 1 palavra por linha (64 colunas);
o F, que funcionou, tinha 2 palavras por linha. Mesma memoria, outra geometria.
"""
word_size = 64
num_words = 32
num_rw_ports = 1
num_r_ports  = 1
num_w_ports  = 0
ports_human  = "1rw1r"
words_per_row = 2
output_suffix = "_wpr2"

import os
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "common_min.py")).read())
