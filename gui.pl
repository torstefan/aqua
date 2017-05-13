#!/usr/bin/env perl
#===============================================================================
#
#         FILE: gui.pl
#
#        USAGE: ./gui.pl  
#
#  DESCRIPTION: The Derp Auqa GUI
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Tor Stefan Lura (), torstefan@gmail.com
# ORGANIZATION: DERP Engineering
#      VERSION: 1.0
#      CREATED: 02/03/17 22:39:31
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use Curses::UI;

use Device::SerialPort::Arduino;
use Sys::Syslog;                          # Misses setlogsock.
use Sys::Syslog qw(:DEFAULT setlogsock);  # Also gets setlogsock.

my @dev = split /\n/, `ls /dev/ttyUSB*`;
my $Arduino;

if ( isRcvdActive() ) {
	$Arduino = Device::SerialPort::Arduino->new(
			port     => $dev[0],
			baudrate => 9600,

			databits => 8,
			parity   => 'none',
			);
}


my $l_time;
my $l_env;
my $l_meta;
my $l_brand;


my $href_sensor;

sub isRcvdActive{
	return `ps aux | grep \"perl ardrcvd.pl\"| grep -v grep | wc -l`;
}

sub getData{

	if (isRcvdActive()){
		return `cat /tmp/rcv`;
	}else{
		die "No Arduino object.." if ! defined $Arduino;
    	return $Arduino->receive();

	}
}

sub logToSplunk{
	my $msg = shift;
	my $ident = "derp_aqua";  
	my $logopt = ""; # Options for sysslog
	my $facility = "local0";
	my $priority = "info";

	setlogsock({ type => "udp", host => "10.10.30.4", port => "1234"});
	openlog($ident, $logopt, $facility);    # don't forget this
	syslog($priority, $msg);        
	closelog();
}
sub updateGui{
 	my $text;
    my $rcv = getData(); 
	logToSplunk($rcv);	
	# Updates the time label
    $l_time->text(`date`);


	# Updates the environment label
    if ( $rcv =~ m/T=(\d{1,}\.\d{1,}).*/xm ) {
        my $v = $1;
        $text .= "Temp:\t\t${v}*C\n";
		$href_sensor->{temp} = $v;
    }

    if ( $rcv =~ m/H=(\d{1,}\.\d{1,}).*/xm ) {
        my $v = $1;
        $text .= "Humidity:\t${v}%\n";
		$href_sensor->{hum} = $v;
    }
    if ( $rcv =~ m/P=(\d{1,}\.\d{1,}).*/xm ) {
        my $v = $1;
        $text .= "Pressure:\t${v}hPa\n";
		$href_sensor->{pres} = $v;
    }

    if ( $rcv =~ m/Lx=(\d{1,}).*/xm ) {
        my $v = $1;
        $text .= "Ambience:\t${v}lx\n";
		$href_sensor->{ambi} = $v;
    }

    if ( $rcv =~ m/Pr=(\d{1,}).*/xm ) {
        my $v = $1;
        $text .= "Water lvl:\t${v}\n";
		$href_sensor->{lvl} = $v;
    }

    if ( $rcv =~ m/EV=(.*?)\s/xm ) {
        my $v = $1;
        $text .= "Button pos:\t${v}\n";
        $l_env->text($text);
        $text = "";
    }


}

sub makeGui{
    my $cui = new Curses::UI( -color_support => 1 );

    my $win = $cui->add( "win", "Window", -border => 1, -bfg => "red" );

    $l_time = $win->add(
        'Time', 'Label',
        -width         => 33,
        -paddingspaces => 1,
    );

    $l_env = $win->add(
        'Env_data', 'Label',
        -y             => 2,
        -x             => 3,
        -width         => 30,
        -height        => 6,
        -paddingspaces => 1,
        -bold          => 1
    );

    $l_meta = $win->add(
        'Env_meta_data', 'Label',
        -y             => 2,
        -x             => 33,
        -width         => 30,
        -height        => 6,
        -paddingspaces => 1,
        -bold          => 1
    );

    $l_brand = $win->add( 
        'Brand', 'Label', 
        -x             => 34, 
        -width         => 35, 
        -text          => "DERP AQUAPONICS", 
        -bold           => 1 
    );
 
    $cui->set_binding( sub { exit(0); }, "\cC" );
    $cui->set_timer( 'update_time', \&updateGui );

    $cui->mainloop()

}

makeGui();
