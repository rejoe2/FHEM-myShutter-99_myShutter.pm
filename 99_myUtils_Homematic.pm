##############################################
# $Id: myUtils_Homematic.pm 08-15 2019-10-08 11:55:42Z Beta-User $
#

package main;

use strict;
use warnings;

sub
myUtils_Homematic_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.

sub myWinContactNotify ($$;$) {
  my ($window, $event, $timeout) = @_;
  $timeout = 90 unless $timeout;
  my @virtuals = devspec2array("TYPE=CUL_HM:FILTER=model=VIRTUAL:FILTER=myRealFK=.*$window.*");
  foreach my $virtual (@virtuals) {
    my $myreals = AttrVal($virtual,"myRealFK","");
	if ($event =~ /open|tilted/) {
	  my $checktime = gettimeofday()+$timeout;
      InternalTimer($checktime,"myTimeoutWinContact",$virtual);	
	} else {
	  my @wcs = split(',',$myreals); 
      my $openwc = 0;
      foreach my $wc (@wcs) {
	    $openwc++ if (ReadingsVal($wc,"state","closed") ne "closed");
	  }
	  CommandSet (undef,"$virtual geschlossen") unless ( $openwc );
	}	
  }	
}	

sub myTimeoutWinContact ($) {
  my $name = shift(@_);
  #my $name = $hash{NAME};
  return unless (ReadingsVal("Heizperiode","state","off") eq "on");
  my $myreals = AttrVal($name,"myRealFK","");
  my @wcs = split(',',$myreals); 
  my $openwc = 0;
  foreach my $wc (@wcs) {
    $openwc++ if (ReadingsVal($wc,"state","closed") ne "closed");
  }
  CommandSet (undef,"$name offen") if ( $openwc );
}

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
 $symbol_string = "temp_temperature";
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
  #$startTime = roundTime2fiveMinutes($startTime);
  #$endTime = roundTime2fiveMinutes($endTime);
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

sub hm_firmware_update_httpmod_stateFormat ($) {	
  my $name = shift @_;
  my $lastCheck = ReadingsTimestamp($name,"MATCHED_READINGS","???"); 	
  my $ret .= '<div style="text-align:left">last <a title="eq3-downloads" href="http://www.eq-3.de/service/downloads.html">homematic</a>-fw-check => '.$lastCheck; 	
  $ret .= '<br><br><pre>'; 	
  $ret .= "| device                  | model                   | cur_fw | new_fw | release    |<br>"; 	
  $ret .= "------------------------------------------------------------------------------------<br>"; 	
  my $check = ReadingsVal($name,"newFwForDevices","error => no or wrong data from eq3-server!"); 	
  if($check eq "no fw-updates needed!") {
    $ret .= '| ';
    $ret .= '<b style="color:green">';
    $ret .= sprintf("%-80s",$check);
    $ret .= '</b> |';
  } elsif($check eq "error => no or wrong data from eq3-server!") {
    $ret .= '| <b style="color:red">';
    $ret .= sprintf("%-80s",$check);
    $ret .= '</b> |';
  } else { 		
    my @devices = split(',',$check); 		
    foreach my $devStr (@devices) { 			
      my ($dev,$md,$ofw,$idx,$nfw,$date) = $devStr =~ m/^([^\s]+)\s\(([^\s]+)\s\|\sfw_(\d+\.\d+)\s=>\sfw(\d\d)_([\d\.]+)\s\|\s([^\)]+)\)$/; 			
      my $link = ReadingsVal($name,"fw_link-".$idx,"???"); 			
      $ret .= '| <a href="/fhem?detail='.$dev.'">';  			
      $ret .= sprintf("%-23s",$dev); 			
      $ret .= '</a> | <b';  			
      $ret .= (($md eq "?")?' title="missing attribute model => set device in teach mode to receive missing data" style="color:yellow"':' style="color:lightgray"').'>';  			
      $ret .= sprintf("%-23s",$md); 			
      $ret .= '</b> | <b'.(($ofw eq "0.0")?' title="missing attribute firmware => set device in teach mode to receive missing data" style="color:yellow"':' style="color:lightgray"').'>';  			
      $ret .= sprintf("%6s",$ofw); 			
      $ret .= '</b> | <a title="eq3-firmware.tgz" href="'.$link.'"><b style="color:red">';  			
      $ret .= sprintf("%6s",$nfw); 			
      $ret .= '</b></a> | ';  			
      $ret .= sprintf("%-10s",$date); 			
      $ret .= " |<br>";  	
    } 	
  } 	
  $ret .= '</pre></div>'; 	
  return $ret;
}

sub hm_firmware_update_httpmod_newFwForDevices ($) {	
  my $name = shift @_;
	my $ret = "";
	my @data;
	if (ReadingsVal($name,"UNMATCHED_READINGS","?") eq "") {
		my @eq3FwList = map{@data = ReadingsVal($name,"fw_link-".$_,"?") =~ m/firmware\/(.*?)_update_[vV]([\d_]+)_(\d\d)(\d\d)(\d\d)/;
							$data[0] =~ s/_/-/g;
							sprintf("%s:%s:%s.%s.%s:%s",$data[0],$data[1],$data[4],$data[3],"20".$data[2],$_);
							} ReadingsVal($name,"MATCHED_READINGS","?") =~ m/fw_link-(\d\d)/g;

		foreach my $dev (devspec2array("TYPE=CUL_HM:FILTER=DEF=......:FILTER=subType!=(virtual|)")) {
			my $md = AttrVal($dev,"model","?");
			my $v = AttrVal($dev,"firmware","0.0");
			my ($h,$l) = split('\.',$v);
			foreach my $newFw (grep m/^${md}:/i,@eq3FwList) {
				my ($nh,$nl,$no,$date,$idx) = $newFw =~ m/^[^:]+:(\d+)_(\d+)_?(\d*):([^:]+):(\d\d)$/;
				if(($nh > $h) || (($nh == $h) && ($nl > $l))) {
					$ret .= "," if($ret ne "");
					$ret .= $dev." (".$md." | fw_".$v." => fw".$idx."_".$nh.".".$nl.($no?sprintf(".%d",$no):"")." | ".$date.")";
				}
			}
		}
	} else {
		$ret = "error => no or wrong data from eq3-server!";
	}
	return ($ret eq "")?"no fw-updates needed!":$ret;
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

<a name="myUtils_Homematic"></a>
<h3>myUtils_Homematic</h3>
<ul>
  <b>devStateIcon_Clima</b>
  <br>
  Use this to get a multifunctional iconset to control HM-CC-RT-DN or HM-TC-IT-WM-W-EU devices<br>
  Examples: 
  <ul>
   <code>attr Thermostat_Esszimmer_Gang_Clima devStateIcon {devStateIcon_Clima($name)}<br> attr Thermostat_Esszimmer_Gang_Clima webCmd desired-temp</code><br>
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
