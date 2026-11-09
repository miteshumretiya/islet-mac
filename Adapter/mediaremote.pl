#!/usr/bin/perl
# Loads Islet's Now Playing bridge into Apple's perl (see IsletMediaRemote.m) and runs it.
use strict;
use warnings;
use DynaLoader;

my ($lib, $fn) = @ARGV;
die "usage: mediaremote.pl LIB FUNCTION\n" unless $lib && $fn;
my $handle = DynaLoader::dl_load_file($lib, 0) or die "load failed: " . DynaLoader::dl_error() . "\n";
my $sym = DynaLoader::dl_find_symbol($handle, $fn) or die "symbol $fn not found\n";
DynaLoader::dl_install_xsub("main::islet_run", $sym);
islet_run();
