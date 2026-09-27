#!/bin/sh
export OPENRAM_TECH="/home/lukas/Projects/OpenRAM/technology:/home/lukas/Projects/OpenRAM/technology"
echo "$(date): Starting LVS using Netgen /nix/store/h3crgmx1w7h86qjpr131igi7p576mp3x-netgen-1.5.318/bin/netgen"
/nix/store/h3crgmx1w7h86qjpr131igi7p576mp3x-netgen-1.5.318/bin/netgen -noconsole << EOF
lvs {sram_1rw_32x16.spice sram_1rw_32x16} {sram_1rw_32x16.lvs.sp sram_1rw_32x16} setup.tcl sram_1rw_32x16.lvs.report -full -json
quit
EOF
magic_retcode=$?
echo "$(date): Finished ($magic_retcode) LVS using Netgen /nix/store/h3crgmx1w7h86qjpr131igi7p576mp3x-netgen-1.5.318/bin/netgen"
exit $magic_retcode
