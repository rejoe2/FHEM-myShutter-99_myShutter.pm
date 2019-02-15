##############################################
# $Id: myUtils_Homematic.pm 08-15 2019-02-15 09:30:42Z Beta-User $
#

package main;

use strict;
use warnings;
use POSIX;

sub
myUtils_Homematic_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.

sub devStateIcon_Clima($) {
my $climaname = shift(@_);
my $ret ="";
my $name = InternalVal($climaname,"device",$climaname);
my $TC = AttrVal($name,"model","HM-CC-RT-DN") eq "HM-TC-IT-WM-W-EU" ? 1:0;
my $state = ReadingsVal($name,"state","NACK");

#Battery
my $batval  = ReadingsVal($name,"batteryLevel","");
my $symbol_string = "measure_battery_";
my $command_string = "getConfig";
if ($batval >=3) {$symbol_string .= "100"} elsif ($batval >2.6) {$symbol_string .= "75"} elsif ($batval >2.4) {$symbol_string .= "50"} elsif ($batval >2.1) {$symbol_string .= "25"} else {$symbol_string .= '0@red'};

if ($state =~ /CMDs_p/) {
  $symbol_string = "edit_settings";
  $command_string = "clear msgEvents"; 
} elsif ($state =~ /RESPONSE|NACK/) {
  $command_string = "clear msgEvents"; 
  $symbol_string = 'edit_settings@red' ;
}
$ret .= "<a href=\"/fhem?cmd.dummy=set $name $command_string&XHR=1\">" . FW_makeImage($symbol_string,"measure_battery_50") . "</a>"; 

#Lock Mode
my $btnLockval = ReadingsVal($name,".R-btnLock","on") ;
#$btnLockval = InternalVal($name,".R-btnLock","on") if ($TC);
my $btnLockvalSet = $btnLockval =~ /on/ ? "off":"on";
$symbol_string = $btnLockval =~ /on/ ? "secur_locked": "secur_open";
$ret .= " " . "<a href=\"/fhem?cmd.dummy=set $name regSet btnLock $btnLockvalSet&XHR=1\">" . FW_makeImage($symbol_string, "locked")."</a>";

#ControlMode
my $controlval = ReadingsVal($climaname,"controlMode","manual") ;
my $controlvalSet = ($controlval =~ /manual/)? "auto":"manual";
$symbol_string = $controlval =~ /manual/ ? "sani_heating_manual" : "sani_heating_automatic";
$ret .= " " . "<a href=\"/fhem?cmd.dummy=set $climaname controlMode $controlvalSet&XHR=1\">" . FW_makeImage($symbol_string,"sani_heating_manual")."</a>";
#my $symbol_mode = "<a href=\"/fhem?cmd.dummy=set $climaname controlMode $controlvalSet&XHR=1\">" . FW_makeImage($mode_symbol_string,"sani_heating_manual")."</a>";

#Humidity/program or actuator
if ($TC) {
  #progSelect
  #Reading: R-weekProgSel  (z.B. prog1) Bild: rc_1 usw., 
  my $progVal = ReadingsVal($climaname,"R-weekPrgSel","none") ;
  my $progValSet = $progVal =~ /prog1/ ? "prog2" : $progVal =~ /prog2/ ? "prog3":"prog1" ;
  $symbol_string = $progVal =~ /prog1/ ? "rc_1" : $progVal =~ /prog2/ ? "rc_2": $progVal =~ /prog3/ ?"rc_3":"unknown" ;
  $ret .= " " . "<a href=\"/fhem?cmd.dummy=set $climaname regSet weekPrgSel $progValSet&XHR=1\">" . FW_makeImage($symbol_string, "rc_1")."</a> ";
  #humidity
  my $humval = ReadingsVal($climaname,"humidity","") ;
  #my $humcolor = "";
  $symbol_string = "humidity";
  $ret .= " " . FW_makeImage($symbol_string,"humidity") . " $humval%rH";
} else {
  my $actorval = ReadingsVal($name,"actuator","");
  my $actor_rounded = int (($actorval +5)/10)*10;
  $symbol_string = "sani_heating_level_$actor_rounded";
  $ret .= " " . FW_makeImage($symbol_string,"sani_heating_level_40") ;
}

#measured temperature
my $tempval = ReadingsVal($climaname,"measured-temp",0) ;
my $tempcolor ="";
my $symbol_string = "temp_temperature";
 $symbol_string .= "@".$tempcolor if ($tempcolor);
$ret .= FW_makeImage($symbol_string,"temp_temperature") . "$tempval°C ";

#desired temperature: getConfig
my $desired_temp = ReadingsVal($name,"desired-temp","21") ;
$symbol_string = "temp_control";# if $state eq "CMDs_done";
$symbol_string = "sani_heating_boost" if $controlval =~ /boost/;
my $boostname = $TC ? $climaname : $name;
$ret .= "<a href=\"/fhem?cmd.dummy=set $boostname controlMode boost&XHR=1\">" . FW_makeImage($symbol_string,"temp_control") . "</a>";

return "<div><p style=\"text-align:right\">$ret</p></div>"
;
}


#Aufruf:   {HM_TC_Holiday (<Thermostat>,"16", "06.12.13", "16:30", "09.12.13" ,"05:00")}
sub HM_TC_Holiday($$$$$$) {
  my ($rt, $temp, $startDate, $startTime, $endDate, $endTime) = @_;
  my $climaname = $rt."_Clima";
  $climaname = $rt."_Climate" if (AttrVal($rt,"model","HM-CC-RT-DN") eq "HM-TC-IT-WM-W-EU");

  # HM-CC-RT-DN and HM-TC-IT-WM-W-EU accept time arguments only in HH:00 or HH:30 format
  # So we have to round down $startTime und $endTime
  $startTime =~ s/\:[0-2].$/:00/;
  $startTime =~ s/\:[3-5].$/:30/;
  $endTime =~ s/\:[0-2].$/:00/;
  $endTime =~ s/\:[3-5].$/:30/;
  CommandSet (undef,"$climaname controlParty $temp $startDate $startTime $endDate $endTime");
}

sub easy_HM_TC_Holiday($$;$$) {
  my ($rt, $temp, $strt, $duration) = @_;
  $duration = 3*3600 unless defined $duration; # 3 hours
  $strt = gettimeofday() unless defined $strt;
  $duration = 0 if $strt eq "stop";
  $strt = gettimeofday() if $strt eq "now";
  $strt = gettimeofday() if $strt eq "stop";
    my ($startDate, $startTime) = split(' ', sec2time_date($strt));
  my ($endDate, $endTime) = split(' ', sec2time_date($strt+$duration));
  #Log3 ($rt, 3, "myHM-utils $rt: Dauer: $duration, Start: $startDate, $startTime, Ende: $endDate, $endTime");
  #return "myHM-utils $rt: Dauer: $duration, Start: $startDate, $startTime, Ende: $endDate, $endTime"
  HM_TC_Holiday($rt,$temp,$startDate,$startTime,$endDate,$endTime);
}

sub sec2time_date($) {
  my ($seconds) = @_;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($seconds);
  $year = sprintf("%02d", $year % 100); #shorten to 2 digits
  $mon   = $mon+1; #range in localtime is 0-11
  $mon   = "0" . $mon   if ( $mon < 10 );
  $hour   = "0" . $hour   if ( $hour < 10 );
  $min = "0" . $min if ( $min < 10 );
  my $date = $mday.".".$mon.".".$year;
  my $time = $hour.":".$min;
  return "$date $time";
}
1;
