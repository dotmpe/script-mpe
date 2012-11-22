#!/bin/bash

gawk  'BEGIN {i=0}
{
if($0!~/#/) {
 label[i] = $1
 v[i] = $2
 D+= $2
 i++
}
}
END {
print "reset"
print "set terminal png"
print "b=0.4; a=0.4; B=0.5; r=1.0; s=0.1"
print "set view 30, 20; set parametric"
print "unset border; unset tics; unset key; unset colorbox"
print "set ticslevel 0"
print "set urange [0:1]; set vrange [0:1]"
print "set xrange [-2:2]; set yrange [-2:2]; set zrange [0:3]"
print "set multiplot"
print "set palette model RGB functions 0.9, 0.9,0.95"
print "splot -2+4*u, -2+4*v, 0 w pm3d"
print "set palette model RGB functions 0.8, 0.8, 0.85"
print "splot cos(u*2*pi)*v, sin(u*2*pi)*v, 0 w pm3d"
d=0.0;
for(j=0;j<i;j++) {
 printf "set palette model RGB functions %f, %f, %f\n", (j%3+1)/3, (j%6+1)/6, (j%9+1)/9
 printf "set urange [%f:%f]\n", d, d+v[j]/D
 print "splot cos(u*2*pi)*r, sin(u*2*pi)*r, s+v*a w pm3d"
 print "splot cos(u*2*pi)*r/2, sin(u*2*pi)*r/2, s+v*a w pm3d"
 d+=v[j]/D
}

d=0.0;
for(j=0;j<i-1;j++) {
 printf "set palette model RGB functions %f, %f, %f\n", (j%3+1)/3, (j%6+1)/6, (j%9+1)/9
 printf "set urange [%f:%f]\n", d, d+v[j]/D
 print "splot cos(u*2*pi)*r*v, sin(u*2*pi)*r*v, s+a w pm3d"
 d+=v[j]/D
}
d=v[0]/D;
for(j=0;j<i;j++) {
 printf "set label %d \"%s\" at cos(%f*pi)*B+cos(%f*pi), sin(%f*pi)*B+sin(%f*pi) centre\n", j+1, label[j], d, d, d, d
 d=d+v[j]/D+v[j+1]/D
}
printf "set palette model RGB functions %f, %f, %f\n", ((i-1)%3+1)/3, ((i-1)%6+1)/6, ((i-1)%9+1)/9
printf "set urange [%f:1]\n", 1.0-v[i-1]/D
print "splot cos(u*2*pi)*v, sin(u*2*pi)*v, a+s w pm3d"
print "unset multiplot"

}' $1
