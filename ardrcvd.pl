#!/usr/bin/env perl
#===============================================================================
#
#         FILE: ardrcvd.pl
#
#        USAGE: ./ardrcvd.pl  
#
#  DESCRIPTION: Arduino recieve daemon
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Tor Stefan Lura (), torstefan@gmail.com
# ORGANIZATION: DERP Engineering
#      VERSION: 1.0
#      CREATED: 01/04/17 16:25:57
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use Time::HiRes qw /usleep/;
use Device::SerialPort::Arduino;
my $DEBUG = 1;
my $PAUSE_TIME = 100;

sub getTty {
	print "getTty() " if $DEBUG;	
	my @tty = grep /attached to/, split /\n/, `dmesg`;
	my $last = pop @tty;	
	
	if ( $last =~ m/to\s(.*)/xm ) {
		print "TTY: $1\n" if $DEBUG;
		return $1;
	}
}

sub ttyActive{
	my $tty = shift;
	print "ttyActive() " if $DEBUG;
	usleep ($PAUSE_TIME);
	my $ls = `ls -la /dev/${tty} 2>&1`;
	print "\n$ls\n" if $DEBUG;	
	if ( $ls !~ m/crw-rw----/xm ) {
		$PAUSE_TIME = 1000000;
		return 0;
	}
		print "TTY ACTIVE\n" if $DEBUG;
		$PAUSE_TIME = 100000;
	return 1;

}

my $g_arduino; 
my $g_tty;
sub getArduino{
	print "2. getArduino() " if $DEBUG;
	my $tty = getTty();
	return unless ttyActive($tty);

	if ( ! defined $g_tty ) {
		print "TTY NOT DEF\n";
		$g_tty = $tty;
		$g_arduino = connectArduino($g_tty);
	}
	
	if ( $tty !~/$g_tty/ ) {
		print "TTY CHANGED $g_tty $tty\n";
		$g_tty = $tty;
		$g_arduino = connectArduino($g_tty);
	}

	return $g_arduino; 
}
sub connectArduino{
	print "3. connectArduino() " if $DEBUG;

	my $tty = shift;
	
	return unless ttyActive(getTty());

	return Device::SerialPort::Arduino->new(
			port     => "/dev/${tty}",
			baudrate => 9600,
			databits => 8,
			parity   => 'none',
			);
}


while ( 1 ) {
	print "1. LOOPSTART\n";
	my $arduino = getArduino(getTty());
	usleep (100000);
	
	print time."\n" if ! defined $arduino and $DEBUG;
	next if ! defined $arduino;

	my $rcv;
	$rcv = $arduino->receive();
	print time ." $rcv";
	 `echo $rcv > /tmp/rcv`;
	print "LOOPSTOP\n";
}

