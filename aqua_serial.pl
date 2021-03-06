#!/usr/bin/env perl
#===============================================================================
#
#         FILE: aqua_serial.pl
#
#        USAGE: ./aqua_serial.pl
#
#  DESCRIPTION: Logs data from BME280 I2C Temperature Humidity Pressure Sensor
#  				Shows the data in Curses::UI, and logs to sparkfun.com
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Tor Stefan Lura (), torstefan@gmail.com
# ORGANIZATION: DERP Engineering
#      VERSION: 1.0
#      CREATED: 16/10/16 14:11:59
#     REVISION: ---
#===============================================================================
use strict;
use warnings;
use utf8;
use Curses::UI;

local $main::label;
local $main::label2;
local $main::hisTemp;
local $main::hisHum;
local $main::hisPres;
local $main::logStatus;
local $main::brand;
local $main::weatherRep;
local $main::aquaRep;

use Device::SerialPort::Arduino;

my @dev = split /\n/, `ls /dev/ttyUSB*`;

my $Arduino = Device::SerialPort::Arduino->new(
    port     => $dev[0],
    baudrate => 9600,

    databits => 8,
    parity   => 'none',
);

#Temperature = 26.58 *C
#Pressure = 1028.01 hPa
#Approx. Altitude = -122.14 m
#Humidity = 26.96 %

#
# Logging to data.sparkfun.com
#
# http://data.sparkfun.com/input/g6bMwKan7QtY50REgoxK?private_key=qzl96oj1RwfpZPWne1Rg&humidity=[value]&pressure=[value]&temp=[value]
#
my $s_humidity;
my $s_pressure;
my $s_temp;
my $s_ambience;
my $s_proximity;
my $s_time         	= 0;
my $log_int_in_sec 	= 60;
my $s_spark_resp   	= "";

sub spark_log {
    my ( $type, $value ) = @_;
    my $logStatus = "IOT STATUS\n";
    $logStatus .= $s_spark_resp . "\n";

    if ( !defined $s_humidity and $type eq "%" ) {
        $s_humidity = $value if defined $value;
    }

    if ( !defined $s_pressure and $type eq "hPa" ) {
        $s_pressure = $value if defined $value;
    }

    if ( !defined $s_temp and $type eq "*C" ) {
        $s_temp = $value if defined $value;
    }

    if ( defined $s_humidity and defined $s_pressure and defined $s_temp ) {
        my $time   = time;
        my $d_time = $time - $s_time;

        if ( $d_time > $log_int_in_sec ) {
            $logStatus .= "Logging values to sparkfun\n";
            $logStatus .= "$s_humidity $s_pressure $s_temp\n";
	        $s_spark_resp = spark_send();

            $s_humidity = undef;
            $s_pressure = undef;
            $s_temp     = undef;
            $s_time     = $time;
        }
        else {
            $logStatus .=
              "Next log cycle in: " . ( $log_int_in_sec - $d_time ) . "s";
        }
    }
    else {
        $logStatus .= "Waiting for values";
    }

    $main::logStatus->text($logStatus);
}

sub spark_send {
    my $url =
"http://data.sparkfun.com/input/g6bMwKan7QtY50REgoxK?private_key=qzl96oj1RwfpZPWne1Rg";
    $url .= "&humidity=$s_humidity";
    $url .= "&pressure=$s_pressure";
    $url .= "&temp=$s_temp";

    my $ping = `sudo ping -W1 -q -c1 8.8.8.8 2>/dev/null`;

    if ( $ping =~ m/1\sreceived/xm ) {
        return `curl -X GET '${url}' 2>/dev/null`;
    }
    else {
        return "NO INTERNETZ!\n";
    }

}

my $h_value_of;

sub store_value {
    my ( $type, $value ) = @_;

    spark_log( $type, $value );
    push @{ $h_value_of->{$type} }, $value;

    if ( 30000 < scalar @{ $h_value_of->{$type} } ) {
        shift @{ $h_value_of->{$type} };
    }
}    ## --- end sub store_value

sub get_wind_speed_d1h{
	my $d_hpa = shift;

	
	if ( $d_hpa > 1.3 and $d_hpa < 2 ) {
		return "6 - 7 Bft";
	}
	if ( $d_hpa > 2 and $d_hpa < 3.3 ) {
		return "8 - 9 Bft";
	}
	if ( $d_hpa > 3.3 ) {
		return "10+ Bft!";
	}

}

sub get_wind_speed_d3h{
	my $d_hpa = shift;

	
	if ( $d_hpa > 4 and $d_hpa < 6 ) {
		return "6 - 7 Bft";
	}
	if ( $d_hpa > 6 and $d_hpa < 10 ) {
		return "8 - 9 Bft";
	}
	if ( $d_hpa > 10 ) {
		return "10+ Bft!";
	}

}

my $current_hpa;
sub weatherRep{
	my $hpa = shift;
	my $min_ago = shift;
	my $d_hpa;
	my $report = "NoData";

	if ( $min_ago eq 0 ) {
		$current_hpa = $hpa;
		return "Current hPa: $hpa";
	}
	
	if ( $min_ago eq 60 ) {
		$d_hpa = ($hpa - $current_hpa);
		$report =  "Delta hPa -1h". $d_hpa . 
				"\n". get_wind_speed_d1h($d_hpa) ;
		$report .= "\n";
	}

	if ( $min_ago eq (60 * 3) ) {
		$d_hpa = ($hpa - $current_hpa);
		$report .= "Delta hPa -3h". $d_hpa . 
				"\n". get_wind_speed_d3h($d_hpa) ;
	}
	return $report;

}
sub get_history_list {
    my ($type) = @_;
    my $list = "NoData";
    my $seconds_ago;
    return $list if not defined $type;
    return $list if not exists $h_value_of->{$type};

   #	return scalar @{$h_value_of->{$type}};
   # Newest values are on the top of list. List was updated with 8 sec interval,
   # due to single line arduino serial read.
    my @values = @{ $h_value_of->{$type} };
    $list =~ s/NoData//;
    while ( my $v = pop @values ) {
        $seconds_ago += 8;

        # 0 min
        if ( $seconds_ago eq 8 ) {
            $list .= "-" . ($seconds_ago) . "s $v$type\n";
			if ( $type eq "hPa" ) {
				$main::weatherRep->text("WEATHER\n" . weatherRep($v, 0));
			}
        }

        # 1 min
        if ( $seconds_ago eq 8 * 8 ) {
            $list .= "-" . sprintf( "%.f", $seconds_ago / 60 ) . "m $v$type\n";
        }

        # 5 min
        if ( $seconds_ago eq 8 * 38 ) {
            $list .= "-" . sprintf( "%.f", $seconds_ago / 60 ) . "m $v$type\n";
        }

        # 1 hours
        if ( $seconds_ago eq 8 * 450 ) {
            $list .=
              "-" . sprintf( "%.f", $seconds_ago / 60 / 60 ) . "h $v$type\n";
			if ( $type eq "hpa" ) {
				$main::weatherRep->text("WEATHER\n" .weatherRep($v, 60));
			}
        }

        # 3 hours
        if ( $seconds_ago eq 8 * 1350 ) {
            $list .=
              "-" . sprintf( "%.f", $seconds_ago / 60 / 60 ) . "h $v$type\n";
			if ( $type eq "hpa" ) {
				$main::weatherRep->text("WEATHER\n" .weatherRep($v, 60 * 3));
			}
        }

        # 6 hours
        if ( $seconds_ago eq 8 * 2700 ) {
            $list .=
              "-" . sprintf( "%.f", $seconds_ago / 60 / 60 ) . "h $v$type\n";
        }

        # 12 hours
        if ( $seconds_ago eq 8 * 5400 ) {
            $list .=
              "-" . sprintf( "%.f", $seconds_ago / 60 / 60 ) . "h $v$type\n";
        }

        # 24 hours
        if ( $seconds_ago eq 8 * 10800 ) {
            $list .=
              "-" . sprintf( "%.f", $seconds_ago / 60 / 60 ) . "h $v$type\n";
        }
        
        # 48 hours
        if ( $seconds_ago eq 8 * 10800 * 2 ) {
            $list .=
              "-" . sprintf( "%.f", $seconds_ago / 60 / 60 ) . "h $v$type\n";
        }


    }
    return $list;
}    ## --- end sub get_history_list

sub displayTime {
	my $text;
    my $rcv = $Arduino->receive();
    $main::label2->text(`date`);
    if ( $rcv =~ m/T=(\d{1,}\.\d{1,}).*/xm ) {
        my $v = $1;
        store_value( "*C", $v );
        my $d = `date "+%H:%M:%S"`;
        chomp $d;

        $text .= "Temp:     ${v}*C\n";
    }
    if ( $rcv =~ m/H=(\d{1,}\.\d{1,}).*/xm ) {
        my $v = $1;
        store_value( "%", $v );

        $text .= "Humidity: ${v}%\n";
    }
    if ( $rcv =~ m/P=(\d{1,}\.\d{1,}).*/xm ) {
        my $v = $1;
        store_value( "hPa", $v );

        $text .= "Pressure: ${v}hPa\n";
    }

    if ( $rcv =~ m/Lx=(\d{1,}).*/xm ) {
        my $v = $1;
        store_value( "lx", $v );

        $text .= "Ambience: ${v}lx\n";
    }


    if ( $rcv =~ m/Pr=(\d{1,}).*/xm ) {
        my $v = $1;
        store_value( "waterLev", $v );

        $text .= "Water lvl: ${v}\n";
        $main::label->text($text);
        $text = "";
    }

	
	if ( $rcv =~ m/EV=(.*?)\s/xm ) {
		$main::aquaRep->text($1);
	}
    $main::hisHum->text( "Humidity\n" . get_history_list("%") );
    $main::hisTemp->text( "Temp\n" . get_history_list("*C") );
    $main::hisPres->text( "Pressure\n" . get_history_list("hPa") );

    #		$main::hisTemp->text("Temp\n");
    #		$main::hisHum->text("Humidity\n");
    #		$main::hisPres->text("Pressure\n");
    sleep(1);
}

sub myProg {
    my $cui = new Curses::UI( -color_support => 1 );

    my $win = $cui->add( "win", "Window", -border => 1, -bfg => "red" );

    $main::label2 = $win->add(
        'Time', 'Label',
        -width         => 33,
        -paddingspaces => 1,
    );

    $main::label = $win->add(
        'Temp', 'Label',
        -y             => 2,
        -x             => 3,
        -width         => 30,
        -height        => 6,
        -paddingspaces => 1,
        -bold          => 1
    );
    $main::logStatus = $win->add(
        'LogStatus', 'Label',
        -y             => 9,
        -x             => 3,
        -width         => 30,
        -height        => 6,
        -paddingspaces => 1,
        -text          => "STATUS:"
    );

    $main::weatherRep = $win->add(
        'WeatherRep', 'Label',
        -y             => 15,
        -x             => 3,
        -width         => 30,
        -height        => 3,
        -paddingspaces => 1,
        -text          => "WEATHER"
    );
    $main::aquaRep = $win->add(
        'AquaRep', 	'Label',
        -y             => 22,
        -x             => 3,
        -width         => 30,
        -height        => 10,
        -paddingspaces => 1,
        -text          => "FISK!"
    );

    $main::hisHum = $win->add(
        'HisHum', 'Label',
        -y             => 2,
        -x             => 30,
        -width         => 20,
        -height        => 10,
        -paddingspaces => 1,
    );

    $main::hisTemp = $win->add(
        'HisTemp', 'Label',
        -y             => 2,
        -x             => 45,
        -width         => 20,
        -height        => 10,
        -paddingspaces => 1,
    );

    $main::hisPres = $win->add(
        'HisPres', 'Label',
        -y             => 2,
        -x             => 60,
        -width         => 20,
        -height        => 10,
        -paddingspaces => 1,
    );

    $main::brand = $win->add(
        'Brand', 'Label',
        -x             => 34,
        -width         => 35,
		-text		   => "DERP AQUAPONICS",
		-bold			=> 1
    );
    $cui->set_binding( sub { exit(0); }, "\cC" );
    $cui->set_timer( 'update_time', \&displayTime );

    $cui->mainloop();

}

myProg();

