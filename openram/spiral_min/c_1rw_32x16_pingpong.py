"""
TESTE C -- macro do ping-pong da ISFFT.

16 palavras x 32 bits, 1rw. O ping-pong (2x8x8x32) separado por
banco x paridade de linha x paridade de coluna vira 8 macros deste
tamanho, com exatamente 1 acesso por ciclo em cada.

Uma porta -> spare row/col OBRIGATORIAS no sky130 (regra de paridade).
Ponto de parada no log: "Using bitcell: bitcell_1port".
"""
word_size = 32
num_words = 16
num_rw_ports = 1
num_r_ports  = 0
num_w_ports  = 0
ports_human  = "1rw"
num_spare_rows = 1
num_spare_cols = 1

import os
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "common_min.py")).read())
