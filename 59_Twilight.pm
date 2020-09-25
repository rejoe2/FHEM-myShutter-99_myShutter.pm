# $Id: 59_Twilight.pm Testversion cloudCover 2 2020-09-25 Beta-User $
##############################################################################
#
#     59_Twilight.pm
#     Copyright by Sebastian Stuecker
#     erweitert von Dietmar Ortmann
#     Orphan module, maintained by Beta-User since 09-2020
#
#     used algorithm see:          http://lexikon.astronomie.info/zeitgleichung/
#
#     Sun position computing
#     Copyright (C) 2013 Julian Pawlowski, julian.pawlowski AT gmail DOT com
#     based on Twilight.tcl  http://www.homematic-wiki.info/mw/index.php/TCLScript:twilight
#     With contribution from http://www.ip-symcon.de/forum/threads/14925-Sonnenstand-berechnen-(Azimut-amp-Elevation)
#
#     e-mail: omega at online dot de
#
#     This file is part of fhem.
#
#     Fhem is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 2 of the License, or
#     (at your option) any later version.
#
#     Fhem is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with fhem.  If not, see <http://www.gnu.org/licenses/>.
#
##############################################################################

package FHEM::Twilight;    ## no critic 'Package declaration'

use strict;
use warnings;

use HttpUtils;
use Math::Trig;
use Time::Local qw(timelocal_nocheck);
use List::Util qw(max min);
use GPUtils qw(GP_Import GP_Export);

## Import der FHEM Funktionen
#-- Run before package compilation
BEGIN {

    # Import from main context
    GP_Import(
        qw(
          defs
          attr
          init_done
          DAYSECONDS
          HOURSECONDS
          MINUTESECONDS
          sr_alt
          CommandAttr
          CommandModify
          looks_like_number
          notifyRegexpChanged
          deviceEvents
          readingFnAttributes
          readingsSingleUpdate
          readingsBulkUpdate
          readingsBeginUpdate
          readingsEndUpdate
          AttrVal
          ReadingsVal
          ReadingsNum
          IsDisabled
          Log3
          InternalTimer
          RemoveInternalTimer
          hms2h
          h2hms_fmt
          FmtTime
          FmtDateTime
          strftime
          stacktrace 
          HttpUtils_BlockingGet
          HttpUtils_NonblockingGet
          )
    );
}

sub ::Twilight_Initialize { goto &Initialize }
sub ::twilight { goto &twilight }


################################################################################
sub Initialize {
    my $hash = shift // return;

    # Consumer
    $hash->{DefFn}    = \&Twilight_Define;
    $hash->{UndefFn}  = \&Twilight_Undef;
    $hash->{GetFn}    = \&Twilight_Get;
    $hash->{NotifyFn} = \&Twilight_Notify;
    $hash->{AttrFn}   = \&Twilight_Attr;
    $hash->{AttrList} = "$readingFnAttributes " . "useExtWeather indoorHorizon:selectnumbers,-6,1,20,1,lin";
    return;
}

################################################################################
sub Twilight_Define {
    my $hash = shift;
    my $def  = shift // return;
    my @arr  = split m{\s+}xms, $def;

    return "syntax: define <name> Twilight [<latitude> <longitude>]"
      if ( int(@arr) < 1 && int(@arr) > 6 );
    
    my $DEFmayChange = int(@arr) == 4 ? 1 : 0;
    
    $hash->{STATE} = "0";
    my $name      = shift @arr;
    my $type      = shift @arr;
    my $latitude  = shift @arr // AttrVal( 'global', 'latitude', 50.112 );
    my $longitude = shift @arr // AttrVal( 'global', 'longitude', 8.686 );

    my $indoor_horizon = shift @arr // 0;
    my $weather        = shift @arr // 0;

    return "Argument Latitude is not a valid number"
      if !looks_like_number($latitude);
    return "Argument Longitude is not a valid number"
      if !looks_like_number($longitude);
    return "Argument Indoor_Horizon is not a valid number"
      if !looks_like_number($indoor_horizon);

    $latitude  = min( 90,  max( -90,  $latitude ) );
    $longitude = min( 180, max( -180, $longitude ) );
    $indoor_horizon =
      min( 20, max( -6, $indoor_horizon ) );

    $hash->{WEATHER_HORIZON} = 0;
    CommandAttr( undef, "$name indoorHorizon $indoor_horizon") if $indoor_horizon; 
    $hash->{helper}{'.LATITUDE'}        = $latitude;
    $hash->{helper}{'.LONGITUDE'}       = $longitude;
    $hash->{SUNPOS_OFFSET} = 5 * 60;

    $attr{$name}{verbose} = 4 if ( $name =~ m/^tst.*$/x );

    Log3( $hash, 1, "[$hash->{NAME}] Note: Twilight formerly used weather info from yahoo, but source is offline. Info will be removed from DEF!"
    ) if $weather;
    
    Log3( $hash, 1, "[$hash->{NAME}] Note: DEF syntax has changed, indoor_horizon now is assigned by attribute indoorHorizon. Info will be removed from DEF!"
    )if ($indoor_horizon); 

    my $useTimer = $weather || $indoor_horizon || ( $DEFmayChange && $latitude  == AttrVal( 'global', 'latitude', 50.112 ) && $longitude == AttrVal( 'global', 'longitude', 8.686 ) ) ? 1 : 0;
    
    InternalTimer(time(), \&Twilight_Change_DEF,$hash,0) if $useTimer;
    
    $hash->{DEFINE} = 1;
    return InternalTimer( time()+$useTimer, \&Twilight_Firstrun,$hash,0) if !$init_done || $useTimer;
    return Twilight_Firstrun($hash);
}

################################################################################
sub Twilight_Undef {
    my $hash = shift;
    my $arg = shift // return;

    for my $key ( keys %{ $hash->{TW} } ) {
        myRemoveInternalTimer( $key, $hash );
    }
    myRemoveInternalTimer( "Midnight", $hash );
    myRemoveInternalTimer( "weather",  $hash );
    myRemoveInternalTimer( "sunpos",   $hash );
    notifyRegexpChanged( $hash, "" );
    delete $hash->{helper}{extWeather}{regexp};
    delete $hash->{helper}{extWeather}{Device};
    delete $hash->{helper}{extWeather}{Reading};
    delete $hash->{helper}{extWeather};

    return;
}

################################################################################
sub Twilight_Change_DEF {
    my $hash  = shift // return;
    my $name = $hash->{NAME};
    my $newdef = "";
    $newdef = "$hash->{helper}{'.LATITUDE'} $hash->{helper}{'.LONGITUDE'}" if $hash->{helper}{'.LATITUDE'} != AttrVal( 'global', 'latitude', 50.112 ) || $hash->{helper}{'.LONGITUDE'} != AttrVal( 'global', 'longitude', 8.686 );

    return CommandModify(undef, "$name $newdef");
}

################################################################################
sub Twilight_Notify {
    my $hash  = shift;
    my $whash = shift // return;
    
    return if !exists $hash->{helper}{extWeather};
    
    my $name = $hash->{NAME};
    return if(IsDisabled($name));

    my $wname = $whash->{NAME};
    my $events = deviceEvents( $whash, 1 );

    my $re = $hash->{helper}{extWeather}{regexp} // "unknown";

    return if(!$events); # Some previous notify deleted the array.
    my $max = int(@{$events});
    my $ret = "";
    for (my $i = 0; $i < $max; $i++) {
        my $s = $events->[$i];
        $s = "" if(!defined($s));
        my $found = ($wname =~ m/^$re$/x || "$wname:$s" =~ m/^$re$/sx);
    
        if($found) {
        
            #### tbd; this is the place to update ss_wather and sr_weather
            my $extWeather = ReadingsNum($hash->{helper}{extWeather}{Device}, $hash->{helper}{extWeather}{Reading},-1);
            my $last = ReadingsNum($name, "cloudCover", -1);
            return if $last - 6 < $extWeather && $last + 6 > $extWeather;
            
            readingsSingleUpdate ($hash, "cloudCover", $extWeather, 1);
            Twilight_getWeatherHorizon( $hash, $extWeather );
            
            my $swip = $hash->{SWIP};
            $hash->{SWIP} = 1 if !$swip;
            Twilight_TwilightTimes( $hash, "weather", $extWeather );
            $hash->{SWIP} = 0 if !$swip;
            
            myRemoveInternalTimer ("sunpos", $hash);
            myInternalTimer ("sunpos", time()+1, \&Twilight_sunpos, $hash, 0);
        }
    }
    return;
}

sub Twilight_Firstrun {
    my $hash     = shift // return;
    my $name = $hash->{NAME};
    $hash->{SWIP} = 0;

    my $attrVal = AttrVal( $name,'useExtWeather', undef );
    if ($attrVal) {
        my ($extWeather, $extWReading) = split( ":", $attrVal ); 
        notifyRegexpChanged($hash, $attrVal.":.*");
        $hash->{helper}{extWeather}{regexp} = qq($attrVal:.*);
        $hash->{helper}{extWeather}{Device} = $extWeather;
        $hash->{helper}{extWeather}{Reading} = $extWReading;

        my $extWeatherVal = ReadingsVal($extWeather, $extWReading,"-1");
        readingsSingleUpdate ($hash,  "cloudCover", $extWeatherVal, 0);
        Twilight_getWeatherHorizon( $hash, $extWeatherVal );
        Twilight_TwilightTimes( $hash, "weather", $extWeatherVal );
    }

    $hash->{INDOOR_HORIZON}  = min( 20, max( -6, AttrVal( $name,'indoorHorizon', 0) ) );
    
    my $mHash = { HASH => $hash };
    Twilight_sunpos($mHash);
    Twilight_Midnight($mHash);
    delete $hash->{DEFINE};

    return;
}

################################################################################
sub Twilight_Attr {
    my ( $cmd, $name, $attrName, $attrVal ) = @_;
    return if (!$init_done);
    my $hash = $defs{$name};

    if ( $attrName eq 'useExtWeather' ) {
        if ( $cmd eq "set" ) {
            my ($extWeather, $extWReading) = split( ":", $attrVal ); 
            return "External weather device seems not to exist" if (!defined $defs{$extWeather} && $init_done);
            notifyRegexpChanged($hash, $attrVal.":.*");
            $hash->{helper}{extWeather}{regexp} = qq($attrVal:.*);
            $hash->{helper}{extWeather}{Device} = $extWeather;
            $hash->{helper}{extWeather}{Reading} = $extWReading;
            return InternalTimer( time(), \&Twilight_Firstrun,$hash,0) if $init_done;

        } elsif ($cmd eq "del") {
            notifyRegexpChanged( $hash, "" );
            delete $hash->{helper}{extWeather}{regexp};
            delete $hash->{helper}{extWeather}{Device};
            delete $hash->{helper}{extWeather}{Reading};
            delete $hash->{helper}{extWeather};
        }
       
    }

    if ( $attrName eq 'indoorHorizon' ) {
        if ( $cmd eq "set" ) {
            return "indoorHorizon is not a valid number" if !looks_like_number($attrVal);
            $hash->{INDOOR_HORIZON}  = min( 20, max( -6, $attrVal ) );
        } elsif ($cmd eq "del") {
            $hash->{INDOOR_HORIZON}  = 0;
        }
        return InternalTimer( time(), \&Twilight_Firstrun,$hash,0) if $init_done;
    }

    return;
}

################################################################################
sub Twilight_Get {
    my ( $hash, @a ) = @_;
    return "argument is missing" if ( int(@a) != 2 );

    my $reading = $a[1];
    my $value;

    if ( defined( $hash->{READINGS}{$reading} ) ) {
        $value = $hash->{READINGS}{$reading}{VAL};
    }
    else {
        return "no such reading: $reading";
    }
    return "$a[0] $reading => $value";
}

################################################################################
sub myInternalTimer {
    my ( $modifier, $tim, $callback, $hash, $waitIfInitNotDone ) = @_;

    my $timerName = "$hash->{NAME}_$modifier";
    my $mHash     = {
        HASH     => $hash,
        NAME     => "$hash->{NAME}_$modifier",
        MODIFIER => $modifier
    };
    if ( defined( $hash->{TIMER}{$timerName} ) ) {
        Log3( $hash, 1, "[$hash->{NAME}] possible overwriting of timer $timerName - please delete first" );
        stacktrace();
    }
    else {
        $hash->{TIMER}{$timerName} = $mHash;
    }

    Log3( $hash, 5, "[$hash->{NAME}] setting  Timer: $timerName " . FmtDateTime($tim) );
    InternalTimer( $tim, $callback, $mHash, $waitIfInitNotDone );
    return $mHash;
}

################################################################################
sub myRemoveInternalTimer {
    my $modifier = shift;
    my $hash = shift // return;

    my $timerName = "$hash->{NAME}_$modifier";
    my $myHash    = $hash->{TIMER}{$timerName};
    if ( defined($myHash) ) {
        delete $hash->{TIMER}{$timerName};
        Log3( $hash, 5, "[$hash->{NAME}] removing Timer: $timerName" );
        RemoveInternalTimer($myHash);
    }
    return;
}

################################################################################
sub myGetHashIndirekt {
    my $myHash = shift;
    my $function = shift // return;

    if ( !defined( $myHash->{HASH} ) ) {

        #Log3 ($hash, 5, "[$function] myHash not valid");
        return;
    }
    return $myHash->{HASH};
}
################################################################################

sub Twilight_midnight_seconds {
    my $now  = shift // return;
    my @time = localtime($now);
    my $secs = ( $time[2] * 3600 ) + ( $time[1] * 60 ) + $time[0];
    return $secs;
}

################################################################################
sub Twilight_calc {
    my $hash = shift;
    my $deg  = shift;
    my $idx  = shift // return;

    my $midnight = time() - Twilight_midnight_seconds( time() );
    my $lat      = $hash->{helper}{'.LATITUDE'};
    my $long     = $hash->{helper}{'.LONGITUDE'};

    #my $sr = sunrise_abs("Horizon=$deg");
    my $sr =
      sr_alt( time(), 1, 0, 0, 0, "Horizon=$deg", undef, undef, undef, $lat,
        $long );

    my $ss =
      sr_alt( time(), 0, 0, 0, 0, "Horizon=$deg", undef, undef, undef, $lat,
        $long );

    my ( $srhour, $srmin, $srsec ) = split( ":", $sr );
    $srhour -= 24 if ( $srhour >= 24 );
    my ( $sshour, $ssmin, $sssec ) = split( ":", $ss );
    $sshour -= 24 if ( $sshour >= 24 );

    my $sr1 = $midnight + 3600 * $srhour + 60 * $srmin + $srsec;
    my $ss1 = $midnight + 3600 * $sshour + 60 * $ssmin + $sssec;

    return ( 0, 0 ) if ( abs( $sr1 - $ss1 ) < 30 );
    return ( $sr1 + 0.01 * $idx ), ( $ss1 - 0.01 * $idx );
}

################################################################################
sub Twilight_TwilightTimes {
    my ( $hash, $whitchTimes, $xml ) = @_;

    my $Name = $hash->{NAME};

    my $horizon = $hash->{HORIZON};
    my $swip    = $hash->{SWIP};

    my $lat  = $hash->{helper}{'.LATITUDE'};
    my $long = $hash->{helper}{'.LONGITUDE'};

# ------------------------------------------------------------------------------
    my $idx      = -1;
    my $indoor_horizon = $hash->{INDOOR_HORIZON};
    #$indoor_horizon = 0.02 if !$indoor_horizon; #equals to 0; not needed as Twilight_calc this already reflects in $idx?
    my $weather_horizon = $hash->{WEATHER_HORIZON};
    #$weather_horizon = 0.01 if !$weather_horizon; #equals to 0, s.a.

    my @horizons = (
        "_astro:-18", "_naut:-12", "_civil:-6", ":0",
        "_indoor:$indoor_horizon",
        "_weather:$weather_horizon"
    );
    for my $horizon (@horizons) {
        $idx++;
        next if ( $whitchTimes eq "weather" && !( $horizon =~ m/weather/ ) );

        my ( $name, $deg ) = split( ":", $horizon );
        my $sr = "sr$name";
        my $ss = "ss$name";
        $hash->{TW}{$sr}{NAME}  = $sr;
        $hash->{TW}{$ss}{NAME}  = $ss;
        $hash->{TW}{$sr}{DEG}   = $deg;
        $hash->{TW}{$ss}{DEG}   = $deg;
        $hash->{TW}{$sr}{LIGHT} = $idx + 1;
        $hash->{TW}{$ss}{LIGHT} = $idx;
        $hash->{TW}{$sr}{STATE} = $idx + 1;
        $hash->{TW}{$ss}{STATE} = 12 - $idx;
        $hash->{TW}{$sr}{SWIP}  = $swip;
        $hash->{TW}{$ss}{SWIP}  = $swip;

        ( $hash->{TW}{$sr}{TIME}, $hash->{TW}{$ss}{TIME} ) =
          Twilight_calc( $hash, $deg, $idx );

        if ( $hash->{TW}{$sr}{TIME} == 0 ) {
            Log3( $hash, 4, "[$Name] hint: $hash->{TW}{$sr}{NAME},  $hash->{TW}{$ss}{NAME} are not defined(HORIZON=$deg)" );
        }
    }

# ------------------------------------------------------------------------------
    readingsBeginUpdate($hash);
    for my $ereignis ( keys %{ $hash->{TW} } ) {
        next if ( $whitchTimes eq "weather" && !( $ereignis =~ m/weather/ ) );
        readingsBulkUpdate( $hash, $ereignis,
            $hash->{TW}{$ereignis}{TIME} == 0
            ? "undefined"
            : FmtTime( $hash->{TW}{$ereignis}{TIME} ) );
    }

    readingsEndUpdate( $hash, defined( $hash->{LOCAL} ? 0 : 1 ) );

# ------------------------------------------------------------------------------
    my @horizonsOhneDeg =
      map { my ( $e, $deg ) = split( ":", $_ ); "$e" } @horizons;
    my @ereignisse = (
        ( map { "sr$_" } @horizonsOhneDeg ),
        ( map { "ss$_" } reverse @horizonsOhneDeg ),
        "sr$horizonsOhneDeg[0]"
    );
    map { $hash->{TW}{ $ereignisse[$_] }{NAMENEXT} = $ereignisse[ $_ + 1 ] }
      0 .. $#ereignisse - 1;

# ------------------------------------------------------------------------------
    my $myHash;
    my $now              = time();
    my $secSinceMidnight = Twilight_midnight_seconds($now);
    my $lastMitternacht  = $now - $secSinceMidnight;
    my $nextMitternacht =
      ( $secSinceMidnight > 12 * 3600 )
      ? $lastMitternacht + 24 * 3600
      : $lastMitternacht;
    my $jetztIstMitternacht = abs( $now + 5 - $nextMitternacht ) <= 10;

    my @keyListe = qw "DEG LIGHT STATE SWIP TIME NAMENEXT";
    for my $ereignis ( sort keys %{ $hash->{TW} } ) {
        next if ( $whitchTimes eq "weather" && !( $ereignis =~ m/weather/ ) );

        myRemoveInternalTimer( $ereignis, $hash );  # if(!$jetztIstMitternacht);
        if ( $hash->{TW}{$ereignis}{TIME} > 0 ) {
            $myHash = myInternalTimer( $ereignis, $hash->{TW}{$ereignis}{TIME},
                \&Twilight_fireEvent, $hash, 0 );
            map { $myHash->{$_} = $hash->{TW}{$ereignis}{$_} } @keyListe;
        }
    }

# ------------------------------------------------------------------------------
    return 1;
}
################################################################################
sub Twilight_fireEvent {
    my $myHash = shift // return;

    my $hash = myGetHashIndirekt( $myHash, ( caller(0) )[3] );
    return if ( !defined($hash) );

    my $name = $hash->{NAME};

    my $event = $myHash->{MODIFIER};
    my $deg   = $myHash->{DEG};
    my $light = $myHash->{LIGHT};
    my $state = $myHash->{STATE};
    my $swip  = $myHash->{SWIP};

    my $eventTime = $myHash->{TIME};
    my $nextEvent = $myHash->{NAMENEXT};

    my $delta = int( $eventTime - time() );
    my $oldState = ReadingsVal( $name, "state", "0" );

    my $nextEventTime =
      ( $hash->{TW}{$nextEvent}{TIME} > 0 )
      ? FmtTime( $hash->{TW}{$nextEvent}{TIME} )
      : "undefined";

    my $doTrigger = !( defined( $hash->{LOCAL} ) )
      && ( abs($delta) < 6 || $swip && $state gt $oldState );

    Log3(
        $hash, 4,
        sprintf( "[$hash->{NAME}] %-10s %-19s  ",
            $event, FmtDateTime($eventTime) )
          . sprintf( "(%2d/$light/%+5.1f°/$doTrigger)   ", $state, $deg )
          . sprintf( "===> %-10s %-19s  ", $nextEvent, $nextEventTime )
    );

    readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, "state",         $state );
    readingsBulkUpdate( $hash, "light",         $light );
    readingsBulkUpdate( $hash, "horizon",       $deg );
    readingsBulkUpdate( $hash, "aktEvent",      $event );
    readingsBulkUpdate( $hash, "nextEvent",     $nextEvent );
    readingsBulkUpdate( $hash, "nextEventTime", $nextEventTime );

    return readingsEndUpdate( $hash, $doTrigger );

}

################################################################################
sub Twilight_Midnight {
    my $myHash = shift // return;
    my $firstrun = shift // 0;
    
    my $hash = myGetHashIndirekt( $myHash, ( caller(0) )[3] );
    return if ( !defined($hash) );

    $hash->{SWIP} = 0;

    return Twilight_WeatherCallbackNew( $hash, "Mid" );
}

################################################################################
sub Twilight_WeatherTimerUpdate {
    my $myHash = shift // return;
    my $hash = myGetHashIndirekt( $myHash, ( caller(0) )[3] );
    return if ( !defined($hash) );

    $hash->{SWIP} = 1;

    return Twilight_WeatherCallbackNew( $hash, "weather" );
}

################################################################################

sub Twilight_WeatherCallbackNew {
    my $hash = shift;
    my $mode = shift // return;
    my $cloudCover = shift;

    Twilight_getWeatherHorizon( $hash, $cloudCover );
    Twilight_TwilightTimes( $hash, $mode, $cloudCover );
    return Twilight_StandardTimerSet( $hash );

}

################################################################################
sub Twilight_RepeatTimerSet {
    my $hash = shift;
    my $mode = shift // return;

    my $midnight = time() + 60;

    myRemoveInternalTimer( "Midnight", $hash );
    return myInternalTimer( "Midnight", $midnight, \&Twilight_Midnight, $hash,
        0 )
      if $mode eq "Mid";

    return myInternalTimer( "Midnight", $midnight,
        \&Twilight_WeatherTimerUpdate, $hash, 0 );
}

################################################################################
sub Twilight_StandardTimerSet {
    my $hash = shift // return;
    my $midnight = time() - Twilight_midnight_seconds( time() ) + 24 * 3600 + 1;

    myRemoveInternalTimer( "Midnight", $hash );
    myInternalTimer( "Midnight", $midnight, \&Twilight_Midnight, $hash, 0 );
    return Twilight_WeatherTimerSet($hash);
}

################################################################################
sub Twilight_WeatherTimerSet {
    my $hash = shift // return;
    my $now = time();

    myRemoveInternalTimer( "weather", $hash );
    for my $key ( "sr_weather", "ss_weather" ) {
        my $tim = $hash->{TW}{$key}{TIME};
        if ( $tim - 60 * 60 > $now + 60 ) {
            myInternalTimer( "weather", $tim - 60 * 60,
                \&Twilight_WeatherTimerUpdate, $hash, 0 );
            last;
        }
    }
    
    return;
}

################################################################################
sub Twilight_sunposTimerSet {
    my $hash = shift // return;

    myRemoveInternalTimer( "sunpos", $hash );
    return myInternalTimer( "sunpos", time() + $hash->{SUNPOS_OFFSET},
        \&Twilight_sunpos, $hash, 0 );
}

################################################################################
sub Twilight_getWeatherHorizon {
    my $hash = shift;
    my $result = shift // return;
    
    return if !looks_like_number($result) || $result < 0 || $result > 100;
    $hash->{WEATHER_CORRECTION} = $result / 12.5;
    $hash->{WEATHER_HORIZON}    = $hash->{WEATHER_CORRECTION} + $hash->{INDOOR_HORIZON};
    my $doy = strftime("%j",localtime);
    my $declination =  0.4095*sin(0.016906*($doy-80.086));
    if($hash->{WEATHER_HORIZON} > (89-$hash->{helper}{'.LATITUDE'}+$declination) ){
        $hash->{WEATHER_HORIZON} =  89-$hash->{helper}{'.LATITUDE'}+$declination;
    };

    return;
}

################################################################################
sub Twilight_sunpos {
    my $myHash = shift // return;
    
    my $hash = myGetHashIndirekt( $myHash, ( caller(0) )[3] );
    return if ( !defined($hash) );

    my $hashName = $hash->{NAME};
    return if(IsDisabled($hashName));

    my (
        $dSeconds, $dMinutes, $dHours, $iDay, $iMonth,
        $iYear,    $wday,     $yday,   $isdst
    ) = gmtime(time);
    $iMonth++;
    $iYear += 100;

    my $dLongitude = $hash->{helper}{'.LONGITUDE'};
    my $dLatitude  = $hash->{helper}{'.LATITUDE'};
    Log3( $hash, 5,
        "Compute sunpos for latitude $dLatitude , longitude $dLongitude" )
      if $dHours == 0 && $dMinutes <= 6;

    my $pi                = 3.14159265358979323846;
    my $twopi             = ( 2 * $pi );
    my $rad               = ( $pi / 180 );
    my $dEarthMeanRadius  = 6371.01;                  # In km
    my $dAstronomicalUnit = 149597890;                # In km

    # Calculate difference in days between the current Julian Day
    # and JD 2451545.0, which is noon 1 January 2000 Universal Time

    # Calculate time of the day in UT decimal hours
    my $dDecimalHours = $dHours + $dMinutes / 60.0 + $dSeconds / 3600.0;

    # Calculate current Julian Day
    my $iYfrom2000 = $iYear;                        #expects now as YY ;
    my $iA         = ( 14 - ($iMonth) ) / 12;
    my $iM         = ($iMonth) + 12 * $iA - 3;
    my $liAux3     = ( 153 * $iM + 2 ) / 5;
    my $liAux4     = 365 * ( $iYfrom2000 - $iA );
    my $liAux5     = ( $iYfrom2000 - $iA ) / 4;
    my $dElapsedJulianDays =
      ( $iDay + $liAux3 + $liAux4 + $liAux5 + 59 ) + -0.5 +
      $dDecimalHours / 24.0;

    # Calculate ecliptic coordinates (ecliptic longitude and obliquity of the
    # ecliptic in radians but without limiting the angle to be less than 2*Pi
    # (i.e., the result may be greater than 2*Pi)

    my $dOmega = 2.1429 - 0.0010394594 * $dElapsedJulianDays;
    my $dMeanLongitude =
      4.8950630 + 0.017202791698 * $dElapsedJulianDays;    # Radians
    my $dMeanAnomaly = 6.2400600 + 0.0172019699 * $dElapsedJulianDays;
    my $dEclipticLongitude =
      $dMeanLongitude +
      0.03341607 * sin($dMeanAnomaly) +
      0.00034894 * sin( 2 * $dMeanAnomaly ) - 0.0001134 -
      0.0000203 * sin($dOmega);
    my $dEclipticObliquity =
      0.4090928 - 6.2140e-9 * $dElapsedJulianDays + 0.0000396 * cos($dOmega);

    # Calculate celestial coordinates ( right ascension and declination ) in radians
    # but without limiting the angle to be less than 2*Pi (i.e., the result may be
    # greater than 2*Pi)

    my $dSin_EclipticLongitude = sin($dEclipticLongitude);
    my $dY1             = cos($dEclipticObliquity) * $dSin_EclipticLongitude;
    my $dX1             = cos($dEclipticLongitude);
    my $dRightAscension = atan2( $dY1, $dX1 );
    if ( $dRightAscension < 0.0 ) {
        $dRightAscension = $dRightAscension + $twopi;
    }
    my $dDeclination =
      asin( sin($dEclipticObliquity) * $dSin_EclipticLongitude );

    # Calculate local coordinates ( azimuth and zenith angle ) in degrees
    my $dGreenwichMeanSiderealTime =
      6.6974243242 + 0.0657098283 * $dElapsedJulianDays + $dDecimalHours;

    my $dLocalMeanSiderealTime =
      ( $dGreenwichMeanSiderealTime * 15 + $dLongitude ) * $rad;
    my $dHourAngle         = $dLocalMeanSiderealTime - $dRightAscension;
    my $dLatitudeInRadians = $dLatitude * $rad;
    my $dCos_Latitude      = cos($dLatitudeInRadians);
    my $dSin_Latitude      = sin($dLatitudeInRadians);
    my $dCos_HourAngle     = cos($dHourAngle);
    my $dZenithAngle       = (
        acos(
            $dCos_Latitude * $dCos_HourAngle * cos($dDeclination) +
              sin($dDeclination) * $dSin_Latitude
        )
    );
    my $dY = -sin($dHourAngle);
    my $dX =
      tan($dDeclination) * $dCos_Latitude - $dSin_Latitude * $dCos_HourAngle;
    my $dAzimuth = atan2( $dY, $dX );
    if ( $dAzimuth < 0.0 ) { $dAzimuth = $dAzimuth + $twopi }
    $dAzimuth = $dAzimuth / $rad;

    # Parallax Correction
    my $dParallax =
      ( $dEarthMeanRadius / $dAstronomicalUnit ) * sin($dZenithAngle);
    $dZenithAngle = ( $dZenithAngle + $dParallax ) / $rad;
    my $dElevation = 90 - $dZenithAngle;

    my $twilight = int( ( $dElevation + 12.0 ) / 18.0 * 1000 ) / 10;
    $twilight = 100 if ( $twilight > 100 );
    $twilight = 0   if ( $twilight < 0 );

    my $twilight_weather;

    if ( ( my $ExtWeather = AttrVal( $hashName, "useExtWeather", "" ) ) eq "" )
    {
        $twilight_weather =
          int( ( $dElevation - $hash->{WEATHER_HORIZON} + 12.0 ) / 18.0 * 1000 )
          / 10;
        Log3( $hash, 5, "[$hash->{NAME}] " . "Original weather readings" );
    }
    else {
        my ( $extDev, $extReading ) = split( ":", $ExtWeather );
        my $extWeatherHorizont = ReadingsVal( $extDev, $extReading, -1 );
        if ( $extWeatherHorizont >= 0 ) {
            $extWeatherHorizont = min (100, $extWeatherHorizont);
            Log3( $hash, 5,
                    "[$hash->{NAME}] "
                  . "New weather readings from: "
                  . $extDev . ":"
                  . $extReading . ":"
                  . $extWeatherHorizont );
            $twilight_weather = $twilight -
              int( 0.007 * ( $extWeatherHorizont**2 ) )
              ;    ## SCM: 100% clouds => 30% light (rough estimation)
        }
        else {
            $twilight_weather =
              int( ( $dElevation - $hash->{WEATHER_HORIZON} + 12.0 ) / 18.0 *
                  1000 ) / 10;
            Log3( $hash, 3,
                    "[$hash->{NAME}] "
                  . "Error with external readings from: "
                  . $extDev . ":"
                  . $extReading
                  . " , taking original weather readings" );
        }
    }

    $twilight_weather =
      min( 100, max( $twilight_weather, 0 ) );

    #  set readings
    $dAzimuth   = int( 100 * $dAzimuth ) / 100;
    $dElevation = int( 100 * $dElevation ) / 100;

    my $compassPoint = Twilight_CompassPoint($dAzimuth);

    readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, "azimuth",          $dAzimuth );
    readingsBulkUpdate( $hash, "elevation",        $dElevation );
    readingsBulkUpdate( $hash, "twilight",         $twilight );
    readingsBulkUpdate( $hash, "twilight_weather", $twilight_weather );
    readingsBulkUpdate( $hash, "compasspoint",     $compassPoint );
    readingsEndUpdate( $hash, defined( $hash->{LOCAL} ? 0 : 1 ) );

    Twilight_sunposTimerSet($hash);

    return;
}
################################################################################
sub Twilight_CompassPoint {
    my $azimuth = shift // return;

    return "unknown" if !looks_like_number($azimuth) || $azimuth < 0;
    return "north" if $azimuth < 22.5;
    return "north-northeast" if $azimuth < 45;
    return "northeast"       if $azimuth < 67.5;
    return "east-northeast"  if $azimuth < 90;
    return "east"            if $azimuth < 112.5;
    return "east-southeast"  if $azimuth < 135;
    return "southeast"       if $azimuth < 157.5;
    return "south-southeast" if $azimuth < 180;
    return "south"           if $azimuth < 202.5;
    return "south-southwest" if $azimuth < 225;
    return "southwest"       if $azimuth < 247.5;
    return "west-southwest"  if $azimuth < 270;
    return "west"            if $azimuth < 292.5;
    return "west-northwest"  if $azimuth < 315;
    return "northwest"       if $azimuth < 337.5;
    return "north-northwest" if $azimuth <= 361;
    return "unknown";
}

sub twilight {
    my ( $twilight, $reading, $min, $max ) = @_;

    my $t = hms2h( ReadingsVal( $twilight, $reading, 0 ) );

    $t = hms2h($min) if ( defined($min) && ( hms2h($min) > $t ) );
    $t = hms2h($max) if ( defined($max) && ( hms2h($max) < $t ) );

    return h2hms_fmt($t);
}

1;

__END__


=pod
=encoding utf8
=item helper
=item summary generate twilight & sun related events; check alternative Astro.
=item summary_DE liefert Dämmerungs Sonnen basierte Events. Alternative: Astro
=begin html

<a name="Twilight"></a>
<h3>Twilight</h3>
<ul>
  <br>
  <a name="Twilightgeneral"></a>
  <b>General Remarks</b><br>
  This module profited much from the use of the yahoo weather API. Unfortunately, this service is no longer available, so Twilight functionality is very limited nowerdays. To some extend, the use of <a href="#Twilightattr">useExtWeather</a> may compensate to dect cloudy skys. If you just want to have astronomical data available, consider using Astro instead.<br><br>
  <a name="Twilightdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; Twilight [&lt;latitude&gt; &lt;longitude&gt; [&lt;indoor_horizon&gt; [&lt;Weather_Position&gt;]]]</code><br>
    <br>
    Defines a virtual device for Twilight calculations <br><br>

  <b>latitude, longitude</b>
  <br>
    The parameters <b>latitude</b> and <b>longitude</b> are decimal numbers which give the position on earth for which the twilight states shall be calculated. They are optional, but necessary in case you also want to set an indoor horizon. If not set, global values will be used instead (global itself defaults to Frankfurt/Main).
    <br>
    <br>
  <b>indoor_horizon</b>
  <br>
       The parameter <b>indoor_horizon</b> gives a virtual horizon, that shall be used for calculation of indoor twilight. Minimal value -6 means indoor values are the same like civil values.
       indoor_horizon 0 means indoor values are the same as real values. indoor_horizon > 0 means earlier indoor sunset resp. later indoor sunrise.
    <br><br>
  <b>Weather_Position</b>
  <br>
       The parameter <b>Weather_Position</b> is the yahoo weather id used for getting the weather condition. Go to http://weather.yahoo.com/ and enter a city or zip code. In the upcoming webpage, the id is a the end of the URL. Example: Munich, Germany -> 676757
    <br><br>
    NOTE: As yahoo weather service is no longer available, this setting will not be used any longer; consider using useExtWeather attribute to partly compensate.
    <br>
    A Twilight device periodically calculates the times of different twilight phases throughout the day.
    It calculates a virtual "light" element, that gives an indicator about the amount of the current daylight.
    Besides the location on earth it is influenced by a so called "indoor horizon" (e.g. if there are high buildings, mountains) as well as by weather conditions. Very bad weather conditions lead to a reduced daylight for nearly the whole day.
    The light calculated spans between 0 and 6, where the values mean the following:
 <br><br>
  <b>light</b>
  <br>
    <code>0 - total night, sun is at least -18 degree below horizon</code><br>
    <code>1 - astronomical twilight, sun is between -12 and -18 degree below horizon</code><br>
    <code>2 - nautical twilight, sun is between -6 and -12 degree below horizon</code><br>
    <code>3 - civil twilight, sun is between 0 and -6 degree below horizon</code><br>
    <code>4 - indoor twilight, sun is between the indoor_horizon and 0 degree below horizon (not used if indoor_horizon=0)</code><br>
    <code>5 - weather twilight, sun is between indoor_horizon and a virtual weather horizon (the weather horizon depends on weather conditions (optional)</code><br>
    <code>6 - maximum daylight</code><br>
    <br>
 <b>Azimut, Elevation, Twilight</b>
 <br>
   The module calculates additionally the <b>azimuth</b> and the <b>elevation</b> of the sun. The values can be used to control a roller shutter.
   <br><br>
   As a new (twi)light value the reading <b>Twilight</b> ist added. It is derived from the elevation of the sun with the formula: (Elevation+12)/18 * 100). The value allows a more detailed
   control of any lamp during the sunrise/sunset phase. The value ist betwenn 0% and 100% when the elevation is between -12&deg; and 6&deg;.
   <br><br>
   You must know, that depending on the latitude, the sun will not reach any elevation. In june/july the sun never falls in middle europe
   below -18&deg;. In more northern countries(norway ...) the sun may not go below 0&deg;.
   <br><br>
   Any control depending on the value of Twilight must
   consider these aspects.
     <br><br>

    Example:
    <pre>
      define myTwilight Twilight 49.962529  10.324845 3 676757
    </pre>
  </ul>
  <br>

  <a name="Twilightset"></a>
  <b>Set </b>
  <ul>
    N/A
  </ul>
  <br>


  <a name="Twilightget"></a>
  <b>Get</b>
  <ul>

    <code>get &lt;name&gt; &lt;reading&gt;</code><br><br>
    <table>
    <tr><td><b>light</b></td><td>the current virtual daylight value</td></tr>
    <tr><td><b>nextEvent</b></td><td>the name of the next event</td></tr>
    <tr><td><b>nextEventTime</b></td><td>the time when the next event will probably happen (during light phase 5 and 6 this is updated when weather conditions change</td></tr>
    <tr><td><b>sr_astro</b></td><td>time of astronomical sunrise</td></tr>
    <tr><td><b>sr_naut</b></td><td>time of nautical sunrise</td></tr>
    <tr><td><b>sr_civil</b></td><td>time of civil sunrise</td></tr>
    <tr><td><b>sr</b></td><td>time of sunrise</td></tr>
    <tr><td><b>sr_indoor</b></td><td>time of indoor sunrise</td></tr>
    <tr><td><b>sr_weather</b></td><td>time of weather sunrise</td></tr>
    <tr><td><b>ss_weather</b></td><td>time of weather sunset</td></tr>
    <tr><td><b>ss_indoor</b></td><td>time of indoor sunset</td></tr>
    <tr><td><b>ss</b></td><td>time of sunset</td></tr>
    <tr><td><b>ss_civil</b></td><td>time of civil sunset</td></tr>
    <tr><td><b>ss_nautic</b></td><td>time of nautic sunset</td></tr>
    <tr><td><b>ss_astro</b></td><td>time of astro sunset</td></tr>
    <tr><td><b>azimuth</b></td><td>the current azimuth of the sun 0&deg; ist north 180&deg; is south</td></tr>
    <tr><td><b>compasspoint</b></td><td>a textual representation of the compass point</td></tr>
    <tr><td><b>elevation</b></td><td>the elevaltion of the sun</td></tr>
    <tr><td><b>twilight</b></td><td>a percetal value of a new (twi)light value: (elevation+12)/18 * 100) </td></tr>
    <tr><td><b>twilight_weather</b></td><td>a percetal value of a new (twi)light value: (elevation-WEATHER_HORIZON+12)/18 * 100). So if there is weather, it
                                     is always a little bit darker than by fair weather</td></tr>
    <tr><td><b>condition</b></td><td>the yahoo condition weather code</td></tr>
    <tr><td><b>condition_txt</b></td><td>the yahoo condition weather code as textual representation</td></tr>
    <tr><td><b>horizon</b></td><td>value auf the actual horizon 0&deg;, -6&deg;, -12&deg;, -18&deg;</td></tr>
    </table>

  </ul>
  <br>

  <a name="Twilightattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
    <li><b>useExtWeather &lt;device&gt;:&lt;reading&gt;</b></li>
    use data from other devices to calculate <b>twilight_weather</b>.<br/>
    The reading used shoud be in the range of 0 to 100 like the reading <b>c_clouds</b>    in an <b><a href="#openweathermap">openweathermap</a></b> device, where 0 is clear sky and 100 are overcast clouds.<br/>
    With the use of this attribute weather effects like heavy rain or thunderstorms are neglegted for the calculation of the <b>twilight_weather</b> reading.<br/>
  </ul>
  <br>

  <a name="Twilightfunc"></a>
  <b>Functions</b>
  <ul>
     <li><b>twilight</b>(<b>$twilight</b>, <b>$reading</b>, <b>$min</b>, <b>$max</b>)</li> - implements a routine to compute the twilighttimes like sunrise with min max values.<br><br>
     <table>
     <tr><td><b>$twilight</b></td><td>name of the twilight instance</td></tr>
     <tr><td><b>$reading</b></td><td>name of the reading to use example: ss_astro, ss_weather ...</td></tr>
     <tr><td><b>$min</b></td><td>parameter min time - optional</td></tr>
     <tr><td><b>$max</b></td><td>parameter max time - optional</td></tr>
     </table>
  </ul>
  <br>
Example:
<pre>
    define BlindDown at *{twilight("myTwilight","sr_indoor","7:30","9:00")} set xxxx position 100
    # xxxx is a defined blind
</pre>

</ul>

=end html

=begin html_DE

<a name="Twilight"></a>
<h3>Twilight</h3>
<ul>
  <b>Akkgemeine Hinweise</b><br>
  Dieses Modul nutzte früher Daten von der Yahoo Wetter API. Diese ist leider nicht mehr verfügbar, daher ist die heutige Funktionalität deutlich eingeschränkt. Dies kann zu einem gewissen Grad kompensiert werden, indem man <a href="#Twilightattr">useExtWeather</a> setzt, um Bedeckungsgrade mit Wolken zu berücksichtigen. Falls Sie nur Astronomische Daten benötigen, wäre Astro hierfür eine genauere Alternative.<br><br>

  <br>

  <a name="Twilightdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; Twilight [&lt;latitude&gt; &lt;longitude&gt;]</code><br>
    <br>
    Erstellt ein virtuelles Device f&uuml;r die D&auml;mmerungsberechnung (Zwielicht)<br><br>

  <b>latitude, longitude (geografische L&auml;nge & Breite)</b>
  <br>
    Die Parameter <b>latitude</b> und <b>longitude</b> sind Dezimalzahlen welche die Position auf der Erde bestimmen, f&uuml;r welche der Dämmerungs-Status berechnet werden soll. Sie sind optional, wenn nicht vorhanden, werden die Angaben in global berücksichtigt, bzw. ohne weitere Angaben die Daten von Frankfurt/Main.
    <br><br>
  <b>indoor_horizon</b>
  <br>
       Der Parameter <b>indoor_horizon</b> bestimmt einen virtuellen Horizont, der f&uuml;r die Berechnung der D&auml;mmerung innerhalb von R&auml;men genutzt werden kann. Minimalwert ist -6 (ergibt gleichen Wert wie Zivile D&auml;mmerung). Bei 0 fallen
       indoor- und realer D&aumlmmerungswert zusammen. Werte gr&oumlsser 0 ergeben fr&uumlhere Werte für den Abend bzw. sp&aumltere f&uumlr den Morgen.
    <br><br>
  <b>Weather_Position</b>
  <br>
       Der Parameter <b>Weather_Position</b> ist die Yahoo! Wetter-ID welche f&uuml;r den Bezug der Wetterinformationen gebraucht wird. Gehe auf http://weather.yahoo.com/ und gebe einen Ort (ggf. PLZ) ein. In der URL der daraufhin geladenen Seite ist an letzter Stelle die ID. Beispiel: München, Deutschland -> 676757
    <br><br>
    Hinweis: Da der Yahoo-Wetterdienst nicht mehr zur Verfügung steht, ist dieses Attribut nutzlos. Siehe useExtWeather als Alternative.<br>
    Ein Twilight-Device berechnet periodisch die D&auml;mmerungszeiten und -phasen w&auml;hrend des Tages.
    Es berechnet ein virtuelles "Licht"-Element das einen Indikator f&uuml;r die momentane Tageslichtmenge ist.
    Neben der Position auf der Erde wird es vom sog. "indoor horizon" (Beispielsweise hohe Geb&auml;de oder Berge)
    und dem Wetter beeinflusst. Schlechtes Wetter f&uuml;hrt zu einer Reduzierung des Tageslichts f&uuml;r den ganzen Tag.
    Das berechnete Licht liegt zwischen 0 und 6 wobei die Werte folgendes bedeuten:<br><br>
  <b>light</b>
  <br>
    <code>0 - Totale Nacht, die Sonne ist mind. -18 Grad hinter dem Horizont</code><br>
    <code>1 - Astronomische D&auml;mmerung, die Sonne ist zw. -12 und -18 Grad hinter dem Horizont</code><br>
    <code>2 - Nautische D&auml;mmerung, die Sonne ist zw. -6 and -12 Grad hinter dem Horizont</code><br>
    <code>3 - Zivile/B&uuml;rgerliche D&auml;mmerung, die Sonne ist zw. 0 and -6 hinter dem Horizont</code><br>
    <code>4 - "indoor twilight", die Sonne ist zwischen dem Wert indoor_horizon und 0 Grad hinter dem Horizont (wird nicht verwendet wenn indoor_horizon=0)</code><br>
    <code>5 - Wetterbedingte D&auml;mmerung, die Sonne ist zwischen indoor_horizon und einem virtuellen Wetter-Horizonz (der Wetter-Horizont ist Wetterabh&auml;ngig (optional)</code><br>
    <code>6 - Maximales Tageslicht</code><br>
    <br>
 <b>Azimut, Elevation, Twilight (Seitenwinkel, Höhenwinkel, D&auml;mmerung)</b>
 <br>
   Das Modul berechnet zus&auml;tzlich Azimuth und Elevation der Sonne. Diese Werte k&ouml;nnen zur Rolladensteuerung verwendet werden.<br><br>

Das Reading <b>Twilight</b> wird als neuer "(twi)light" Wert hinzugef&uuml;gt. Er wird aus der Elevation der Sonne mit folgender Formel abgeleitet: (Elevation+12)/18 * 100). Das erlaubt eine detailliertere Kontrolle der Lampen w&auml;hrend Sonnenauf - und untergang. Dieser Wert ist zwischen 0% und 100% wenn die Elevation zwischen -12&deg; und 6&deg;

   <br><br>
Wissenswert dazu ist, dass die Sonne, abh&auml;gnig vom Breitengrad, bestimmte Elevationen nicht erreicht. Im Juni und Juli liegt die Sonne in Mitteleuropa nie unter -18&deg;. In n&ouml;rdlicheren Gebieten (Norwegen, ...) kommt die Sonne beispielsweise nicht &uuml;ber 0&deg.
   <br><br>
   All diese Aspekte m&uuml;ssen ber&uuml;cksichtigt werden bei Schaltungen die auf Twilight basieren.
     <br><br>

    Beispiel:
    <pre>
      define myTwilight Twilight 49.962529  10.324845 3 676757
    </pre>
  </ul>
  <br>

  <a name="Twilightset"></a>
  <b>Set </b>
  <ul>
    N/A
  </ul>
  <br>


  <a name="Twilightget"></a>
  <b>Get</b>
  <ul>

    <code>get &lt;name&gt; &lt;reading&gt;</code><br><br>
    <table>
    <tr><td><b>light</b></td><td>der aktuelle virtuelle Tageslicht-Wert</td></tr>
    <tr><td><b>nextEvent</b></td><td>Name des n&auml;chsten Events</td></tr>
    <tr><td><b>nextEventTime</b></td><td>die Zeit wann das n&auml;chste Event wahrscheinlich passieren wird (w&auml;hrend Lichtphase 5 und 6 wird dieser Wert aktualisiert wenn sich das Wetter &auml;ndert)</td></tr>
    <tr><td><b>sr_astro</b></td><td>Zeit des astronomitschen Sonnenaufgangs</td></tr>
    <tr><td><b>sr_naut</b></td><td>Zeit des nautischen Sonnenaufgangs</td></tr>
    <tr><td><b>sr_civil</b></td><td>Zeit des zivilen/b&uuml;rgerlichen Sonnenaufgangs</td></tr>
    <tr><td><b>sr</b></td><td>Zeit des Sonnenaufgangs</td></tr>
    <tr><td><b>sr_indoor</b></td><td>Zeit des "indoor" Sonnenaufgangs</td></tr>
    <tr><td><b>sr_weather</b></td><td>"Wert" des Wetters beim Sonnenaufgang</td></tr>
    <tr><td><b>ss_weather</b></td><td>"Wert" des Wetters beim Sonnenuntergang</td></tr>
    <tr><td><b>ss_indoor</b></td><td>Zeit des "indoor" Sonnenuntergangs</td></tr>
    <tr><td><b>ss</b></td><td>Zeit des Sonnenuntergangs</td></tr>
    <tr><td><b>ss_civil</b></td><td>Zeit des zivilen/b&uuml;rgerlichen Sonnenuntergangs</td></tr>
    <tr><td><b>ss_nautic</b></td><td>Zeit des nautischen Sonnenuntergangs</td></tr>
    <tr><td><b>ss_astro</b></td><td>Zeit des astro. Sonnenuntergangs</td></tr>
    <tr><td><b>azimuth</b></td><td>aktueller Azimuth der Sonne. 0&deg; ist Norden 180&deg; ist S&uuml;den</td></tr>
    <tr><td><b>compasspoint</b></td><td>Ein Wortwert des Kompass-Werts</td></tr>
    <tr><td><b>elevation</b></td><td>the elevaltion of the sun</td></tr>
    <tr><td><b>twilight</b></td><td>Prozentualer Wert eines neuen "(twi)light" Wertes: (elevation+12)/18 * 100) </td></tr>
    <tr><td><b>twilight_weather</b></td><td>Prozentualer Wert eines neuen "(twi)light" Wertes: (elevation-WEATHER_HORIZON+12)/18 * 100). Wenn ein Wetterwert vorhanden ist, ist es immer etwas dunkler als bei klarem Wetter.</td></tr>
    <tr><td><b>condition</b></td><td>Yahoo! Wetter code</td></tr>
    <tr><td><b>condition_txt</b></td><td>Yahoo! Wetter code als Text</td></tr>
    <tr><td><b>horizon</b></td><td>Wert des aktuellen Horizont 0&deg;, -6&deg;, -12&deg;, -18&deg;</td></tr>
    </table>

  </ul>
  <br>

  <a name="Twilightattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
    <li><b>useExtWeather &lt;device&gt;:&lt;reading&gt;</b></li>
    Nutzt Daten von einem anderen Device um <b>twilight_weather</b> zu berechnen.<br/>
    Das Reading sollte sich im Intervall zwischen 0 und 100 bewegen, z.B. das Reading <b>c_clouds</b> in einem<b><a href="#openweathermap">openweathermap</a></b> device, bei dem 0 heiteren und 100 bedeckten Himmel bedeuten.
    Wird diese Attribut genutzt , werden Wettereffekte wie Starkregen oder Gewitter fuer die Berechnung von <b>twilight_weather</b> nicht mehr herangezogen.
  </ul>
  <br>

  <a name="Twilightfunc"></a>
  <b>Functions</b>
  <ul>
     <li><b>twilight</b>(<b>$twilight</b>, <b>$reading</b>, <b>$min</b>, <b>$max</b>)</li> - implementiert eine Routine um die D&auml;mmerungszeiten wie Sonnenaufgang mit min und max Werten zu berechnen.<br><br>
     <table>
     <tr><td><b>$twilight</b></td><td>Name der twiligh Instanz</td></tr>
     <tr><td><b>$reading</b></td><td>Name des zu verwendenden Readings. Beispiel: ss_astro, ss_weather ...</td></tr>
     <tr><td><b>$min</b></td><td>Parameter min time - optional</td></tr>
     <tr><td><b>$max</b></td><td>Parameter max time - optional</td></tr>
     </table>
  </ul>
  <br>
Anwendungsbeispiel:
<pre>
    define BlindDown at *{twilight("myTwilight","sr_indoor","7:30","9:00")} set xxxx position 100
    # xxxx ist ein definiertes Rollo
</pre>

</ul>

=end html_DE
=cut
