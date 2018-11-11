reset
set terminal png
b=0.4; a=0.4; B=0.5; r=1.0; s=0.1
set view 30, 20; set parametric
unset border; unset tics; unset key; unset colorbox
set ticslevel 0
set urange [0:1]; set vrange [0:1]
set xrange [-2:2]; set yrange [-2:2]; set zrange [0:3]
set multiplot
set palette model RGB functions 0.9, 0.9,0.95
splot -2+4*u, -2+4*v, 0 w pm3d
set palette model RGB functions 0.8, 0.8, 0.85
splot cos(u*2*pi)*v, sin(u*2*pi)*v, 0 w pm3d
set palette model RGB functions 0.333333, 0.166667, 0.111111
set urange [0.000000:0.090909]
splot cos(u*2*pi)*r, sin(u*2*pi)*r, s+v*a w pm3d
splot cos(u*2*pi)*r/2, sin(u*2*pi)*r/2, s+v*a w pm3d
set palette model RGB functions 0.666667, 0.333333, 0.222222
set urange [0.090909:0.272727]
splot cos(u*2*pi)*r, sin(u*2*pi)*r, s+v*a w pm3d
splot cos(u*2*pi)*r/2, sin(u*2*pi)*r/2, s+v*a w pm3d
set palette model RGB functions 1.000000, 0.500000, 0.333333
set urange [0.272727:0.454545]
splot cos(u*2*pi)*r, sin(u*2*pi)*r, s+v*a w pm3d
splot cos(u*2*pi)*r/2, sin(u*2*pi)*r/2, s+v*a w pm3d
set palette model RGB functions 0.333333, 0.666667, 0.444444
set urange [0.454545:0.500000]
splot cos(u*2*pi)*r, sin(u*2*pi)*r, s+v*a w pm3d
splot cos(u*2*pi)*r/2, sin(u*2*pi)*r/2, s+v*a w pm3d
set palette model RGB functions 0.666667, 0.833333, 0.555556
set urange [0.500000:0.636364]
splot cos(u*2*pi)*r, sin(u*2*pi)*r, s+v*a w pm3d
splot cos(u*2*pi)*r/2, sin(u*2*pi)*r/2, s+v*a w pm3d
set palette model RGB functions 1.000000, 1.000000, 0.666667
set urange [0.636364:0.909091]
splot cos(u*2*pi)*r, sin(u*2*pi)*r, s+v*a w pm3d
splot cos(u*2*pi)*r/2, sin(u*2*pi)*r/2, s+v*a w pm3d
set palette model RGB functions 0.333333, 0.166667, 0.777778
set urange [0.909091:1.000000]
splot cos(u*2*pi)*r, sin(u*2*pi)*r, s+v*a w pm3d
splot cos(u*2*pi)*r/2, sin(u*2*pi)*r/2, s+v*a w pm3d
set palette model RGB functions 0.333333, 0.166667, 0.111111
set urange [0.000000:0.090909]
splot cos(u*2*pi)*r*v, sin(u*2*pi)*r*v, s+a w pm3d
set palette model RGB functions 0.666667, 0.333333, 0.222222
set urange [0.090909:0.272727]
splot cos(u*2*pi)*r*v, sin(u*2*pi)*r*v, s+a w pm3d
set palette model RGB functions 1.000000, 0.500000, 0.333333
set urange [0.272727:0.454545]
splot cos(u*2*pi)*r*v, sin(u*2*pi)*r*v, s+a w pm3d
set palette model RGB functions 0.333333, 0.666667, 0.444444
set urange [0.454545:0.500000]
splot cos(u*2*pi)*r*v, sin(u*2*pi)*r*v, s+a w pm3d
set palette model RGB functions 0.666667, 0.833333, 0.555556
set urange [0.500000:0.636364]
splot cos(u*2*pi)*r*v, sin(u*2*pi)*r*v, s+a w pm3d
set palette model RGB functions 1.000000, 1.000000, 0.666667
set urange [0.636364:0.909091]
splot cos(u*2*pi)*r*v, sin(u*2*pi)*r*v, s+a w pm3d
set label 1 "1989" at cos(0.090909*pi)*B+cos(0.090909*pi), sin(0.090909*pi)*B+sin(0.090909*pi) centre
set label 2 "1990" at cos(0.363636*pi)*B+cos(0.363636*pi), sin(0.363636*pi)*B+sin(0.363636*pi) centre
set label 3 "1991" at cos(0.727273*pi)*B+cos(0.727273*pi), sin(0.727273*pi)*B+sin(0.727273*pi) centre
set label 4 "1992" at cos(0.954545*pi)*B+cos(0.954545*pi), sin(0.954545*pi)*B+sin(0.954545*pi) centre
set label 5 "1992" at cos(1.136364*pi)*B+cos(1.136364*pi), sin(1.136364*pi)*B+sin(1.136364*pi) centre
set label 6 "1993" at cos(1.545455*pi)*B+cos(1.545455*pi), sin(1.545455*pi)*B+sin(1.545455*pi) centre
set label 7 "1994" at cos(1.909091*pi)*B+cos(1.909091*pi), sin(1.909091*pi)*B+sin(1.909091*pi) centre
set palette model RGB functions 0.333333, 0.166667, 0.777778
set urange [0.909091:1]
splot cos(u*2*pi)*v, sin(u*2*pi)*v, a+s w pm3d
unset multiplot
