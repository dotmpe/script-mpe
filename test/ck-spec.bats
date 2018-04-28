#!/usr/bin/env bats

load init

setup()
{
  testf=test/var/crc32-asdn.txt
  size=4
  crc32_zip=355327694
  crc32_ck=1814461271
  crc32_eth=1531968134
}

@test "CRC32 Commonly used, in ZIP and other software CRCs ('asd\\n' = 355327694 / 0x152DDECE)" {

  run cksum.py -a rhash-crc32 $testf
  test "${lines[*]}" = "$crc32_zip $size $testf" || stdfail rhash-crc32

  run cksum.py -a zlib-crc32 $testf
  test "${lines[*]}" = "$crc32_zip $size $testf" || stdfail zlib-crc32

  run php -r 'echo hexdec(hash_file("crc32b", "'"$testf"'")).PHP_EOL;'
  test "${lines[*]}" = "$crc32_zip" || stdfail php-crc32b-direct

  run cksum.py -a php-crc32b $testf
  test "${lines[*]}" = "$crc32_zip $size $testf" || stdfail php-crc32b

  #rhash --crc32 $testf
}

@test "Crazy UNIX cksum CRC32 compatible algo ('asd\\n' = 1814461271 / 0x6C267B57)" {
  run cksum $testf
  test "${lines[*]}" = "$crc32_ck $size $testf" || stdfail cksum
  run cksum.py $testf
  test "${lines[*]}" = "$crc32_ck $size $testf" || stdfail cksum-py
  run cksum.py -a ckpy $testf
  test "${lines[*]}" = "$crc32_ck $size $testf" || stdfail cksum-py-mem
}

@test "CRC32 Used in Ethernet packet CRCs ('asd\\n' = 1531968134 / 0x5B4FFA86)" {

  run cksum.py -a php-crc32 $testf
  test "${lines[*]}" = "$crc32_eth $size $testf" || stdfail php-crc32

  #php -r 'echo hexdec(hash_file("crc32", "$testf")).PHP_EOL;'
}
