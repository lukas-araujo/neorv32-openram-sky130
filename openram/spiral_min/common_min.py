"""
Configuracao comum dos testes de tamanho minimo (Spiral / ping-pong).
Incluida por exec() nos tres arquivos deste diretorio.

Rodada BACK-END direto: o objetivo e a AREA, e o front-end da area 0.
Memorias de 16 palavras devem levar minutos, nao horas.
"""
tech_name = "sky130"
nominal_corner_only = True
route_supplies = "ring"
uniquify = True
check_lvsdrc = True
analytical_delay = True

import os
output_name = "sram_{}_{}x{}{}".format(ports_human, word_size, num_words,
                                      globals().get("output_suffix", ""))
output_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "out", output_name)
