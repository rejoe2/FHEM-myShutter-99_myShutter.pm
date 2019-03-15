##############################################
# $Id: myUtils_ebusd.pm 08-15 2019-03-15 11:00:42Z Beta-User $
#

package main;

use strict;
use warnings;
use POSIX;

sub
myUtils_ebusd_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.

######################################
#NOTE: This is only a fragment....
######################################

### alternative color Icon:
#{ my $vP = ReadingsVal($name, "WPPWMPower_percent0_value", "4448"); my $colPower = substr(Color::pahColor(0,2000,4449,$vP,0),0,6); my $iconPower = 'sani_pump@'.$colPower; my $vFS = ReadingsVal($name, "FanSpeed_0_value", "3001"); my $colFSpeed = substr(Color::pahColor(0,1500,4000,$vFS,0),0,6); my $iconFSpeed =  'vent_ventilation_level_'; $iconFSpeed .=  $vFS < 499 ? '0@' : $vFS <1699 ? '1@' : $vFS <3001 ? '2@' : '3@'; $iconFSpeed .= $colFSpeed; "<div style=\"text-align:right\" > Heizungspumpe: " . FW_makeImage("$iconPower",'file_unknown@grey') . " ($vP Watt)<br>Ventilatordrehzahl: " . FW_makeImage("$iconFSpeed",'vent_ventilation_level_3@red') . " ($vFS Upm)</div>"}

##########################
####list of ebus-Device with some more state info:
defmod MQTT2_ebusd_430 MQTT2_DEVICE ebusd_430
attr MQTT2_ebusd_430 IODev ebusMQTT
attr MQTT2_ebusd_430 getList Hc1HeatCurve:noArg Hc1HeatCurve_curve_value ebusd/430/Hc1HeatCurve/get\
HwcTempDesired:noArg HwcTempDesired_temp1_value ebusd/430/HwcTempDesired/get
attr MQTT2_ebusd_430 icon message_tendency_steady
attr MQTT2_ebusd_430 readingList ebusd/430/Hc1HeatCurve:.* { json2nameValue($EVENT, 'Hc1HeatCurve_', $JSONMAP) }\
ebusd/430/HwcTempDesired:.* { json2nameValue($EVENT, 'HwcTempDesired_', $JSONMAP) }\
ebusd/430/Hc1HeatCurve/set:.* set\
ebusd/430/HwcTempDesired/set:.* set\
ebusd/430/PumpEnergySaveStateMonitor:.* { json2nameValue($EVENT, 'PumpEnergySaveStateMonitor_', $JSONMAP) }\
ebusd/430/CirPump:.* { json2nameValue($EVENT, 'CirPump_', $JSONMAP) }\
ebusd/430/Hc1Pump:.* { json2nameValue($EVENT, 'Hc1Pump_', $JSONMAP) }
attr MQTT2_ebusd_430 room MQTT2_DEVICE
attr MQTT2_ebusd_430 setList Hc1HeatCurve_curve_value:0.20,0.70,0.90,1.00,1.10,1.20,1.30,1.40,1.50,1.60,1.70 ebusd/430/Hc1HeatCurve/set $EVTPART1\
    HwcTempDesired_temp1_value:50.0,51.0,52.0,53.0,54.0,55.0,56.0,57.0,58.0,59.0,60.0 ebusd/430/HwcTempDesired/set $EVTPART1
attr MQTT2_ebusd_430 stateFormat Pumpe: \
Hc1Pump_onoff_value\
<br>Energiesparmodus Pumpe: \
PumpEnergySaveStateMonitor_0_value
attr MQTT2_ebusd_430 webCmd Hc1HeatCurve_curve_value:HwcTempDesired_temp1_value
attr MQTT2_ebusd_430 webCmdLabel Hc1HeatCurve\
:HwcTempDesired

setstate MQTT2_ebusd_430 Pumpe: \
on\
<br>Energiesparmodus Pumpe: \
1
setstate MQTT2_ebusd_430 2019-03-13 15:55:54 CirPump_onoff_value on
setstate MQTT2_ebusd_430 2019-03-15 09:59:01 Hc1HeatCurve_curve_value 1.00
setstate MQTT2_ebusd_430 2019-03-13 15:56:04 Hc1Pump_onoff_value on
setstate MQTT2_ebusd_430 2019-03-15 09:59:01 HwcTempDesired_temp1_value 56.0
setstate MQTT2_ebusd_430 2019-03-13 15:55:09 PumpEnergySaveStateMonitor_0_name 
setstate MQTT2_ebusd_430 2019-03-13 15:55:09 PumpEnergySaveStateMonitor_0_value 1
setstate MQTT2_ebusd_430 2019-03-13 15:56:04 associatedWith MQTT2_ebusd
setstate MQTT2_ebusd_430 2019-03-10 08:39:55 get 
setstate MQTT2_ebusd_430 2019-03-08 18:22:10 set 56.0
setstate MQTT2_ebusd_430 2019-03-14 08:32:50 state Hc1HeatCurve_curve_value

################### end list


sub devStateIcon_ebus($$,$) {
my $name = shift(@_);
my $type = shift(@_);
my $color = shift(@_);
my $ret ="";

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

  # HM-CC-RT-DN and HM-TC-IT-WM-W-EU accept time arguments only as plain five minutes
  # So we have to round down $startTime und $endTime
  $startTime = roundTime2fiveMinutes($startTime);
  $endTime = roundTime2fiveMinutes($endTime);
  #$startTime =~ s/\:[0-2].$/:00/;
  #$startTime =~ s/\:[3-5].$/:30/;
  #$endTime =~ s/\:[0-2].$/:00/;
  #$endTime =~ s/\:[3-5].$/:30/;
  CommandSet (undef,"$climaname controlParty $temp $startDate $startTime $endDate $endTime");
}

sub easy_HM_TC_Holiday($$;$$) {
  my ($rt, $temp, $strt, $duration) = @_;
  $duration = 3*3600 unless defined $duration; # 3 hours
  $strt = gettimeofday() unless defined $strt;
  $duration = 0 if $strt eq "stop";
  $strt = gettimeofday() if $strt eq "now";
  $strt = gettimeofday() if $strt eq "stop";
  if ($strt =~ /^(\d+):(\d+)$/) {
    $strt = $1*DAYSECONDS + $2*HOURSECONDS;
  };
  if ($duration =~ /^(\d+):(\d+)$/) {
    $duration = $1*DAYSECONDS + $2*HOURSECONDS;
  };
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

sub roundTime2fiveMinutes($)
{
  my ($time) = @_;
  if ($time =~ /^([0-2]\d):(\d)(\d)$/)
  {
    my $n = $3;
    $n = "0" if ($n<5);
    $n = "5" if ($n>5);
    return "$1:$2$n";
  }
  return undef;
}

1;

=pod
=begin html

<a name="myUtils_ebusd"></a>
<h3>myUtils_ebusd</h3>
<ul>
  <b>devStateIcon_ebusd</b>
  <br>
  Use this to get a multifunctional iconset to control HM-CC-RT-DN or HM-TC-IT-WM-W-EU devices<br>
  Examples: 
  <ul>
   <code>attr Thermostat_Esszimmer_Gang_Clima devStateIcon {devStateIcon_Clima($name, "TYPE"[,<true for color>])}<br> attr Thermostat_Esszimmer_Gang_Clima webCmd desired-temp</code><br>
  </ul>
  <b>HM_TC_Holiday</b>
  <br>
  Use this to set one RT or WT device in party mode<br>
  Parameters: Device, Temperature, start date, start time, end date, end time<br>
  NOTE: as these devices only accept time settings to 00 minutes and 30 minutes, all other figures will be rounded down to 00 or 30 minutes. Don't bother to do it by yourself, but note, effectively, the result could be a shorter periode of party mode.<br>
  Example: 
  <ul>
   <code>{HM_TC_Holiday ("Thermostat_Esszimmer_Gang","16", "14.02.19", "16:30", "15.02.19" ,"05:00")}</code><br>
  </ul>
  <b>easy_HM_TC_Holiday</b>
  <br>
  Use this to set one RT or WT device in party mode (or end it) without doing much calculation in advance<br>
  Parameters: Device, Temperature. Optional: starttime in seconds or as days:hours - may also be "now" (default, when no argument is given), and duration in seconds or as days:hours (defaults to 3 hours).<br>
    NOTE: rounding is applied as described at HM_TC_Holiday.<br>
  Examples: 
  <ul>
   <code>{easy_HM_TC_Holiday("Thermostat_Esszimmer_Gang","16")}</code><br>
   <code>{easy_HM_TC_Holiday("Thermostat_Esszimmer_Gang","16","now")}</code><br>
   <code>{easy_HM_TC_Holiday("Thermostat_Esszimmer_Gang","16","stop")}</code><br>
   <code>{easy_HM_TC_Holiday("Thermostat_Esszimmer_Gang","16","now","9000"])}</code><br>
   <code>{easy_HM_TC_Holiday("Thermostat_Esszimmer_Gang","21.5","3600","9000")}</code><br>
   <code>{easy_HM_TC_Holiday("Thermostat_Esszimmer_Gang","21.5","1:5","32:14")}</code><br>
  </ul>
</ul>
=end html
=cut
