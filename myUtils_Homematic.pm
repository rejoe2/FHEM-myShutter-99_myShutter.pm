##############################################
# $Id: myUtils_Homematic.pm 08-15 2019-01-21 08:30:44Z Beta-User $
#

package main;

use strict;
use warnings;
use POSIX;

sub
myUtils_Homematic($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.

sub devStateIcon_RT_DN($) {
my $name = shift(@_);
my $ret ="";
my $climaname = $name."_Clima";
my $TC = AttrVal($name,"model","HM-CC-RT-DN") eq "HM-TC-IT-WM-W-EU" ? 1:0;
$climaname = $name."_Climate" if $TC;

#Battery
my $batval  = ReadingsVal($name,"battery","");
my $symbol_string = "measure_battery_0";
$batval eq "ok" ? $symbol_string = "measure_battery_75" : $batval eq "low" ? $symbol_string = "measure_battery_25":undef;
$ret .= "<a href=\"/fhem?cmd.dummy=set $name clear msgEvents&XHR=1\">" . FW_makeImage($symbol_string,"measure_battery_50") . "</a>"; 

#Lock Mode
my $btnLockval = ReadingsVal($name,".R-btnLock","on") ;
my $btnLockvalSet = $btnLockval eq "on" ? "off":"on";
$symbol_string = $btnLockval eq "on"? "secur_locked": "secur_open";
$ret .= " " . "<a href=\"/fhem?cmd.dummy=set $name regSet btnLock $btnLockvalSet&XHR=1\">" . FW_makeImage($symbol_string, "locked")."</a>";

#ControlMode
my $controlval = ReadingsVal($climaname,"controlMode","manual") ;
my $controlvalSet = ($controlval eq "manual")? "auto":"manual";
$symbol_string = $controlval eq "manual" ? "sani_heating_manual" : "sani_heating_automatic";
$ret .= " " . "<a href=\"/fhem?cmd.dummy=set $climaname controlMode $controlvalSet&XHR=1\">" . FW_makeImage($symbol_string,"sani_heating_manual")."</a>";
#my $symbol_mode = "<a href=\"/fhem?cmd.dummy=set $climaname controlMode $controlvalSet&XHR=1\">" . FW_makeImage($mode_symbol_string,"sani_heating_manual")."</a>";

#Humidity or actuator
if ($TC) {
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


#my $symbol_bat = "<a href=\"/fhem?cmd.dummy=set $name getConfig&XHR=1\">" . FW_makeImage($bat_symbol_string,"measure_battery_50") . "</a>"; 
#

#desired temperature: getConfig
my $desired_temp = ReadingsVal($name,"desired-temp","21") ;
my $state = ReadingsVal($name,"state","NACK");
$symbol_string = "edit_settings" if $state eq "CMDs_pending";
$symbol_string = "edit_settings" if $state eq "NACK";
$symbol_string = "temp_control" if $state eq "CMDs_done";
$ret .= "<a href=\"/fhem?cmd.dummy=set $name getConfig&XHR=1\">" . FW_makeImage($symbol_string,"temp_control") . "</a>";

#$ret .= FW_widgetOverride($climaname,"selectnumbers,4.5,0.5,30.5,1,lin");

return "<div>$ret</div>"
;
}


#Aufruf:   {HM_TC_Holiday (<Thermostat>,"16", "06.12.13", "16:30", "09.12.13" ,"05:00")}
sub HM_TC_Holiday($$$$$$)
{
  my ($rt, $temp, $startDate, $startTime, $endDate, $endTime) = @_;
  my $climaname = $rt."_Clima";
  $climaname = $rt."_Climate" if (AttrVal($rt,"model","HM-CC-RT-DN") eq "HM-TC-IT-WM-W-EU");

  # HM-CC-RT-DN and HM-TC-IT-WM-W-EU accept time arguments only in HH:00 or HH:30 format
  # So we have to round down $startTime und $endTime
  $startTime =~ s/\:[0-2].$/:00/;
  $startTime =~ s/\:[3-5].$/:30/;
  $endTime =~ s/\:[0-2].$/:00/;
  $endTime =~ s/\:[3-5].$/:30/;
  CommandSet (undef, $climaname controlParty $temp $startDate $startTime $endDate $endTime);
}

1;
