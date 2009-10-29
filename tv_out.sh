# Toggle S-Video out on Thinkpad T41
xrandr --output S-video --off
xrandr --output S-video --set load_detection 1
# PAL-B
xrandr --output S-video --set tv_standard pal
xvattr -a XV_CRTC -v 1 
xrandr --output S-video --auto
#xrandr --addmode S-video 800x600
#xrandr --output S-video --mode 800x600
