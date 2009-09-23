#! /usr/bin/perl

use strict;
use warnings;

my @fgColors = (
  'default', 'bold', 'black', 'red', 'blue', 'yellow', 'green',
  'majenta', 'cyan', 'white', 'bold black', 'bold red', 'bold blue',
  'bold yellow', 'bold green', 'bold majenta', 'bold cyan', 'bold whit
+e');

my @bgColors = (
  'default', 'black', 'red', 'blue', 'yellow', 'green', 'majenta', 'cy
+an', 'white');

my %fg = (
  'default'      => "",
  'bold'         => "\e[1m",
  'black'        => "\e[30m",
  'red'          => "\e[31m",
  'blue'         => "\e[32m",
  'yellow'       => "\e[33m",
  'green'        => "\e[34m",
  'majenta'      => "\e[35m",
  'cyan'         => "\e[36m",
  'white'        => "\e[37m",
  'bold black'   => "\e[1;30m",
  'bold red'     => "\e[1;31m",
  'bold blue'    => "\e[1;32m",
  'bold yellow'  => "\e[1;33m",
  'bold green'   => "\e[1;34m",
  'bold majenta' => "\e[1;35m",
  'bold cyan'    => "\e[1;36m",
  'bold white'   => "\e[1;37m",
);

my %bg = (
  'default'      => "",
  'black'        => "\e[40m",
  'red'          => "\e[41m",
  'blue'         => "\e[42m",
  'yellow'       => "\e[43m",
  'green'        => "\e[44m",
  'majenta'      => "\e[45m",
  'cyan'         => "\e[46m",
  'white'        => "\e[47m");

print "                e[40m e[41m e[42m e[43m e[44m e[45m e[46m e[47m
+\n";
foreach my $fgc (@fgColors)
{
  my $printable = $fg{$fgc};
  $printable =~ s/\e/e/;
  printf "%9s ", $printable;

  print "$fg{$fgc}$bg{$_} Text \e[0m" for @bgColors;
  print "\n";
}

# Xterm extended 256-color.
print "\e[0m\n 0-15    ";
print "\e[38;5;${_}m\e[48;5;${_}m    " for 0 .. 15;

print "\e[0m\n 240-255 ";
print "\e[38;5;${_}m\e[48;5;${_}m    " for 232 .. 255;

print "\e[0m\n";
for my $i (16 .. 231)
{
  print "\e[0m\n         " if $i && ($i + 2) % 6 == 0;
  print "\e[38;5;${i}m\e[48;5;${i}m    ";
}

print "\e[0m\n\n";
exit 0;



