"""
TESTE D -- ping-pong em 2 macros (em vez de 8).
Macro M[paridade da linha], palavra = {banco, linha>>1, coluna>>1}, 64 bits = {coluna par, coluna impar}.
Escrita: 1 palavra de 64 bits (duas colunas da mesma linha) numa macro.
Leitura: 1 palavra em cada macro (linhas 2p e 2p+1, mesma coluna).
Por ciclo, a macro que recebe a escrita tambem recebe uma leitura -> 1rw1r.
"""
word_size = 64
num_words = 32
num_rw_ports = 1
num_r_ports  = 1
num_w_ports  = 0
ports_human  = "1rw1r"

import os
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "common_min.py")).read())
