reset
set terminal postscript eps size 14,4 enhanced color font 'Helvetica,32'
set output "wan-switch-raft.eps"

set ytics out nomirror offset 0.7 scale 0.9
set y2tics out nomirror offset -0.7 scale 0.9
set xtics out nomirror scale 0.7 offset -0.5,0 #rotate by -60


set yrange [0:140]
set y2range [0:105]
set xrange [100:970]

set tics scale 0.5

set style line 1 lt 1 lw 3 lc rgb '#000' pt 8 ps 1.2
set style line 2 lt 1 lw 1 lc rgb '#0060ad' pt 5 ps 1.5 pi -1
set style line 3 lt 1 lw 2 lc rgb '#E41B17' pt 1 ps 1
set pointintervalbox 2

set key left box height 1

set style line 12 lc rgb '#ddccdd' lt 3 lw 1.5
set style line 13 lc rgb '#ddccdd' lt 3 lw 0.5
set grid xtics mxtics ytics mytics back ls 12, ls 13

set xlabel "SMR command number"
set ylabel "Cost (# of messages)" offset 2
set y2label "Latency (milliseconds)" offset -2

set style line 10 lc rgb 'black' lt 1
set arrow from 550,118 to 454,50 size 15,15 filled ls 10 lw 8 front
set label 1 "Quorum switches\n to include the straggler" at 550,122 front font 'Helvetica,32'

# set label "6099.1" at screen 0.094,0.84 rotate by -60 font 'Helvetica,26'
# set label "3098.5" at screen 0.11,0.63   rotate by -60 font 'Helvetica,26'

# set lmargin at screen 0.08
# set rmargin at screen 0.9

plot './bandwidth' u 2:3 w lp t "SMR cost" ls 2,\
    '' u 2:4 w lp t "Consensus cost" ls 3,\
    '' u 2:($5/1000) w lp t "Latency" ls 1 axes x1y2
    # '' u 1:2:3 w yerrorb notitle ls 2,\
    # '' every 2::3 u 1:($2 + 100):($2) with labels rotate by -60 font 'Helvetica,26' offset -1,1.5 notitle
