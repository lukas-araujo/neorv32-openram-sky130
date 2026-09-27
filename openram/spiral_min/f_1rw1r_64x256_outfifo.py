"""
TESTE F -- FIFO de saida da ISFFT (out_mem 256 x 64) em UMA macro de 64 bits.
"""
word_size = 64
num_words = 256
num_rw_ports = 1
num_r_ports  = 1
num_w_ports  = 0
ports_human  = "1rw1r"

import os
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "common_min.py")).read())
