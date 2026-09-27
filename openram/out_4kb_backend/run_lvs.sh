#!/bin/sh
export OPENRAM_TECH="/home/lukas/Projects/OpenRAM/technology:/home/lukas/Projects/OpenRAM/technology"
echo "$(date): Starting LVS using Netgen /nix/store/h3crgmx1w7h86qjpr131igi7p576mp3x-netgen-1.5.318/bin/netgen"
/nix/store/h3crgmx1w7h86qjpr131igi7p576mp3x-netgen-1.5.318/bin/netgen -noconsole << EOF
lvs {sram_4kbyte_1rw_32x1024_8.spice sram_4kbyte_1rw_32x1024_8} {sram_4kbyte_1rw_32x1024_8.lvs.sp sram_4kbyte_1rw_32x1024_8} setup.tcl sram_4kbyte_1rw_32x1024_8.lvs.report -full -json
quit
EOF
magic_retcode=$?
echo "$(date): Finished ($magic_retcode) LVS using Netgen /nix/store/h3crgmx1w7h86qjpr131igi7p576mp3x-netgen-1.5.318/bin/netgen"
exit $magic_retcode
