# ~/.bashrc  ───── Better CPU Watch ────
# 
# Example output:
#
#     === temps ===
#     edge:         +43.0°C
#     Tctl:         +47.8°C
#     === clocks (cores 0|4|8|12|16|20|24|28) ===
#     CPU       MHZ
#       0 5714.2510
#       4 3071.3159
#       8 3628.5229
#      12 3613.3860
#      16 4985.9951
#      20  600.0000
#      24  600.0000
#      28  600.0000
#     avg: 2599 MHz

cpuwatch() {
    # pick every 4th core: 0, 4, 8 …  (change 4 → 2 or 6 if you like)
    local cores
    cores=$(seq 0 4 $(( $(nproc) - 1 )) | tr '\n' '|' | sed 's/|$//')

    echo "Sampling every 4th core: $cores"
    watch -n1 \
      "echo '=== temps ==='; \
       sensors | grep -E 'Tctl|Tdie|edge'; \
       echo '=== clocks (cores $cores) ==='; \
       lscpu -e=CPU,MHZ | awk -v pat='^($cores)$' 'NR==1 || \$1 ~ pat'; \
       avg=\$(lscpu -e=MHZ | awk 'NR>1 {sum+=\$1} END {printf \"%.0f\", sum/(NR-1)}'); \
       echo \"avg: \$avg MHz\""
}
