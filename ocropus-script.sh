img_dir=$1
hocr_dir=$2

for f in $img_dir/*.ppm;
do
	fn=`basename $f .ppm`;
	ocrocmd $f > $hocr_dir/$fn.html
done;

