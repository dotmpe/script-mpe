# [2022-09-04] see notes on unicode weather symbols and wttr.

xxd_hex ()
{
  xxd | cut -d ':' -f2 | sed 's/    *.*$//g'
}

weather='✨
☁️
🌫
🌧
❄️
🌦
🌧
🌨
⛅️
☀️
🌩
⛈
☁️
'
moons='
🌑
🌒
🌓
🌔
🌕
🌖
🌗
🌘
'

printf "$weather" | while read -r sym
do
  printf "$sym"
  echo
  printf "$sym" | xxd_hex
  printf "$sym" | iconv -f 'utf-8' -t 'utf-16' | xxd_hex
done
