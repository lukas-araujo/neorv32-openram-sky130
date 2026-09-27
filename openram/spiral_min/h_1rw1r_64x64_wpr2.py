"""
TESTE H -- repete o E forcando 2 palavras por linha (32 linhas x 128 colunas).
"""
word_size = 64
num_words = 64
num_rw_ports = 1
num_r_ports  = 1
num_w_ports  = 0
ports_human  = "1rw1r"
words_per_row = 2
output_suffix = "_wpr2"

import os
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "common_min.py")).read())
