"""
TESTE J (reserva, so se H falhar) -- geometria do E, alimentacao em pinos laterais em vez de anel.
"""
word_size = 64
num_words = 64
num_rw_ports = 1
num_r_ports  = 1
num_w_ports  = 0
ports_human  = "1rw1r"
supply_pin_type = "left"
output_suffix = "_left"

import os
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "common_min.py")).read())
