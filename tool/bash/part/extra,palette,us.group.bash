us_palette_extra_pre=User-Script.Palette
us_palette_extra_var=(
  User_Script_Palette_blboron16_console
  User_Script_Palette_blboron16_alacritty
  User_Script_Palette_nord19
  #User_Script_Palette_stdmap_dark
)

# The Bunsenlabs Boron palette for the linux console is again a bit different
# than the desktop environment settings
User_Script_Palette_blboron16_console="\
00 00 00  BLBORONALT0 BLACK
9e 18 28  BLBORONALT1
ae ce 92  BLBORONALT2
96 8a 38  BLBORONALT3
41 41 71  BLBORONALT4
96 3c 59  BLBORONALT5
41 81 79  BLBORONALT6
be be be  BLBORONALT7
88 88 88  BLBORONALT8
cf 61 71  BLBORONALT9
c5 f7 79  BLBORONALT10
ff f7 96  BLBORONALT11
41 86 be  BLBORONALT12
cf 9e be  BLBORONALT13
71 be be  BLBORONALT14
ff ff ff  BLBORONALT15 WHITE"

User_Script_Palette_blboron16_alacritty="\
1d 1f 21  BLBORONALACRITTY0 ALMOST_BLACK BLACK
cc 66 66  BLBORONALACRITTY1 DUSTY_RED RED
b5 bd 68  BLBORONALACRITTY2 GREENISH_BEIGE GREEN
f0 c6 74  BLBORONALACRITTY3 WHEAT YELLOW
81 a2 be  BLBORONALACRITTY4 GREY_BLUE BLUE
b2 94 bb  BLBORONALACRITTY5 HEATHER PURPLE
8a be b7  BLBORONALACRITTY6 DIM_PALE_TEAL
c5 c8 c6  BLBORONALACRITTY7 SILVER
66 66 66  BLBORONALACRITTY8 CHARCOAL_GREY
d5 4e 53  BLBORONALACRITTY9 FADED_RED
b9 ca 4a  BLBORONALACRITTY10 BOOGER
e7 c5 47  BLBORONALACRITTY11 MAIZE
7a a6 da  BLBORONALACRITTY12 FADED_BLUE
c3 97 d8  BLBORONALACRITTY13 PALE_PURPLE
70 c0 b1  BLBORONALACRITTY14 PALE_TEAL
ea ea ea  BLBORONALACRITTY15 PALE_GREY WHITE"

# XXX: this repeats colors and is fairly conservative, could be better
User_Script_Palette_nord19=\
'3b 42 52  nord1
bf 61 6a  nord11
a3 be 8c  nord14
eb cb 8b  nord13
81 a1 c1  nord9
b4 8e ad  nord15
88 c0 d0  nord8
e5 e9 f0  nord5
4c 56 6a  nord3
bf 61 6a  nord11
a3 be 8c  nord14
eb cb 8b  nord13
81 a1 c1  nord9
b4 8e ad  nord15
8f bc bb  nord7
88 c0 d0  nord8
d8 de e9  nordFg
2e 34 40  nordBg
d8 de e9  nordCursor'

# FIXME: make 0 and 7 and some other as well depend on CS={dark,light} setting
User_Script_Palette_stdmap_dark="\
C_DARK                BLACK BLACKGREY GREYBLACK DARKGREY
C_ERROR               RED MAROON
C_PASS                GREEN LIME
C_ABNORMAL            OLIVE YELLOW
C_AUXILIARY           BLUE NAVY
C_SECONDARY           CYAN AQUA TEAL
C_CONTEXT             MAGENTA
C_LIGHT               SILVER WHITEGREY GREYWHITE DARKWHITE DIM_WHITE"
