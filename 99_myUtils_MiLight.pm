##############################################
# $Id: myUtils_MiLight.pm 2019-09-09 Beta-User $
#

package main;

use strict;
use warnings;
use POSIX;

sub
myUtils_MiLight_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.

sub milight_toggle_indirect($) {
  my ($name) = @_;
  my $Target_Devices = AttrVal($name,"Target_Device","devStrich0");
  my $dimmLevel;
  my $hash;
  foreach my $setdevice (split (/,/,$Target_Devices)) {
    $hash = $defs{$setdevice};
	if(ReadingsVal($setdevice,"state","OFF") =~ /OFF|off/) {
      CommandSet(undef, "$setdevice on");
      readingsSingleUpdate($hash,"myLastShort","1", 0);
      AnalyzeCommandChain(undef, "sleep 1; set $setdevice brightness 220");
    } elsif (ReadingsAge($setdevice,"myLastShort","100") < 3) {
       my $lastToggle = ReadingsNum($setdevice, "myLastShort","0");
       if ($lastToggle == 1) {
         readingsSingleUpdate($hash,"myLastShort","2",0);
         $dimmLevel = 110;
       } else {
         $dimmLevel = 45;
       }
       CommandSet(undef, "$setdevice brightness $dimmLevel");
    } else {
       readingsSingleUpdate($hash,"myLastShort","0",0);
       CommandSet(undef, "$setdevice off");
    }
  }
}

sub milight_dimm_indirect($$) {
  my ($name,$event) = @_;
  my $Target_Devices = AttrVal($name,"Target_Device","devStrich0");
  foreach my $setdevice (split (/,/,$Target_Devices)) {
    if ($event =~ m/LongRelease/) {
	  AnalyzeCommand(undef,"deleteReading $setdevice myLastdimmLevel");
	} else {
      milight_dimm($setdevice);
	}
  }
}

sub milight_dimm($) {
  my ($Target_Device) = @_;
  my $dimmDir = ReadingsVal($Target_Device,"myDimmDir","up");
  my $dimmLevel = ReadingsVal($Target_Device,"myLastdimmLevel",ReadingsNum($Target_Device,"brightness","255"));
  if ($dimmDir ne "up") { 
    if ($dimmLevel < 4) { 
      readingsSingleUpdate($defs{$Target_Device}, "myDimmDir", "up", 0);
    } else {
      $dimmLevel -= $dimmLevel < 30 ? 3 : $dimmLevel < 70 ? 5 : $dimmLevel < 120 ? 7 : 15;
    }
  } else {
    if ($dimmLevel > 244) {
      readingsSingleUpdate($defs{$Target_Device}, "myDimmDir", "down", 0);
    } else {
      $dimmLevel += $dimmLevel < 30 ?  3 : $dimmLevel < 70 ? 5 : $dimmLevel < 120 ? 7 : 15;
    }
  }
  CommandSet(undef, "$Target_Device brightness $dimmLevel");
  readingsSingleUpdate($defs{$Target_Device}, "myLastdimmLevel",$dimmLevel, 0);
}

sub milight_FUT_to_RGBW($$) {
  my ($name,$Event) = @_;
  #return "" if ReadingsVal($name,"presence","absent") eq "absent";
  $Event =~ s/://g;
  if($Event =~ /OFF|ON/) {
    my $command = lc ($Event);
    CommandSet(undef, "$name $command");
  } elsif ($Event =~ /brightness|hue/)  {
    $Event =~ s/brightness/bri/g if (InternalVal($name,"TYPE","MQTT2_DEVICE") eq "HUEDevice"); 
    CommandSet(undef, "$name $Event");
  } elsif ($Event =~ /command set_white/)  {
    CommandSet(undef, "$name command Weiss");
  } else {

  }  
}

sub milight_to_MPD($$) {
  my ($name,$Event) = @_;
  return "" if ReadingsVal($name,"presence","absent") eq "absent";
  if($Event =~ /ON/) {
    CommandSet(undef, "$name play") if ReadingsVal($name,"state","play") =~ /pause|stop/;
  } elsif ($Event =~ /OFF/) {
    my $command = (ReadingsVal($name,"state","play") eq "pause" ) ? "stop" : "pause";
    CommandSet(undef, "$name $command");
  } elsif ($Event =~ /brightness/)  {
    my ($reading,$value) = split (/ /,$Event);
    my $volume = int (round ($value/2,55)); 
    CommandSet(undef, "$name volume $volume");
  } elsif ($Event =~ /mode_speed_down/)  {
    CommandSet(undef, "$name previous");

  } elsif ($Event =~ /mode_speed_up/)  {
    CommandSet(undef, "$name next");

  } elsif ($Event =~ /mode: [0-8]/)  {
    my $gainmode = CommandSet(undef, "$name mpdCMD replay_gain_status") =~ /album/ ? "auto" : "album"; 
    
    CommandSet(undef, "$name mpdCMD replay_gain_mode $gainmode");
 	
  } elsif ($Event =~ /bulb_mode.*white/)  {
    my $consumer = CommandSet(undef, "$name mpdCMD status") =~ /consume. 0/ ? "1" : "0"; 
    CommandSet(undef, "$name mpdCMD consume $consumer");

  } else {

  }  
}

sub milight_to_shutter($$) {
  #foreach my $setdevice (split (/ /,$Target_Devices)) {
  my ($name,$event) = @_;
  my $type = InternalVal($name,"TYPE","MQTT2_DEVICE"); 
  my $moving = ReadingsVal($name,"motor","stop") =~ /stop/ ? 0 : 1;
  $moving = 1 if (ReadingsNum($name,"power",0) > 1 && $type eq "ZWave");
  
  my $com = lc($event);
  my $now = gettimeofday;
  if (!$moving && $event =~ m/ON|OFF/) {
    if ($now - ReadingsVal($name, "myLastRCOnOff",$now) < 5) {
	  CommandSet(undef,"$name $com");
      CommandSetReading(undef,"$name myLastRCOnOff $now");
	} else {
      CommandSetReading(undef,"$name myLastRCOnOff $now");
	} 
  } elsif ($event =~ m/ON|OFF/) { 
    CommandSet(undef,"$name stop");
	CommandSetReading(undef,"$name myLastRCOnOff $now");
  } elsif ($event =~ /brightness/) {
	my ($reading,$value) = split (/ /,$event);
    my $level = int (round ($value/2,55));
    $com = $type eq "ZWave" ? "dim" : "pct"; 
	$level = 99 if ($level == 100 && $type eq "ZWave");
    CommandSet(undef, "$name $com $level");
  } elsif ($event =~ /saturation/) {
	my ($reading,$value) = split (/ /,$event);
    my $slatname = $name;
	my $slatlevel = 100 - $value;
    $com = $type eq "ZWave" ? "dim" : "slats"; 
	$slatlevel = 99 if ($slatlevel == 100 && $type eq "ZWave");
    my ($def,$defnr) = split(" ", InternalVal($name,"DEF",$name));
    $defnr++;
    my @slatnames = devspec2array("DEF=$def".'.'.$defnr);
    $slatname = shift @slatnames;
    
	CommandSet(undef, "$slatname $com $slatlevel");
	
  } 
}

sub milight_Deckenlichter ($) {
  my $Event = shift @_;
  if ($Event =~ /mode_speed_up/){
    CommandSet(undef, "Licht_WoZi_Hinten_Aussen toggle");
  } elsif ($Event =~ /mode_speed_down/){
    CommandSet(undef, "Licht_WoZi_Vorn_Aussen toggle");
  } elsif ($Event =~ /command: set_white/){
    CommandSet(undef, "Licht_WoZi_Vorn_Mitte toggle");
  } elsif ($Event =~ /mode: [0-8]/){
    CommandSet(undef, "Licht_WoZi_Hinten_Mitte toggle");
  } else {
    my @ondevs = devspec2array("Licht_WoZi_(Hinten|Vorn)_(Aussen|Mitte):FILTER=state=on");
    if (@ondevs) {
      CommandSet(undef, "Licht_WoZi_(Hinten|Vorn)_(Aussen|Mitte):FILTER=state=on off") if ($Event eq "OFF");
    } else {
      CommandSet(undef, "Licht_WoZi_Vorn_Aussen on");
    } 
  }
}

1;


=pod
=begin html

<a name="myUtils_MiLight"></a>
<h3>myUtils_MiLight</h3>
<ul>
  <b>Routines to handle remote control signals in MiLight context</b><br> 
  All MiLight hardware (bulbs and remotes) are represented by MQTT2_DEVICE using a esp8266_milight_hub as described here: https://github.com/sidoh/esp8266_milight_hub.<br>
  This pieces of code offer options to build links between MiLight@MQTT2_DEVICE and "other" FHEM devices (e.g. HUE bulbs, shutter devices, Homematic remotes) and can also be used to built an indirect bridge between V6 remotes and V5 bulbs.
  <ul>
    <b>Routines to use MiLight remotes as input device</b><br>
	NOTE: As one has to press the "on" button to activate a specific layer of the remote, often the first "on" command received will be ignored. You have to press the key twice within a few seconds in these cases. This is especially the case, when controlling other devices than lights to avoid unexpected or unintended behaviour (like starting a music player when only reduction of volume is intended as first step).  <br><br>
	All remote keys are configured as seperate MQTT2_DEVICE instances like this one:<br>
	<code>defmod MiLight_RC1_0 MQTT2_DEVICE milight_0xABCD_0
    attr MiLight_RC1_0 readingList milight/updates/0xABCD/fut089/0:.* { json2nameValue($EVENT) }\
    milight/states/0xABCD/fut089/0:.* {}</code><br><br>
	The Perl routines typically are called from within a notify listining to just one of the MQTT2_DEVICEs, not all of the buttons might be used:<br>
	<code>defmod n_MiLight_RC1_1 notify MiLight_RC1_1:(ON|OFF|(brightness|command|bulb_mode|hue|mode|saturation).*) {milight_to_MPD("myHueDevice",$EVENT)}</code><br>
	<code>defmod n_MiLight_RC1_0 notify MiLight_RC1_0:(ON|OFF|(brightness|command|bulb_mode|mode).*) {milight_to_MPD("myMPD",$EVENT)}</code><br>
		Typically the device to switch and the $EVENT are handed over to the routines, in case it's just one parameter, it's $EVENT only.<br><br>
	<ul>
      <b>milight_FUT_to_RGBW($$)</b><br>
	  Allows indirect control of 
	  <li>other MiLight devices using a different protocol or </li> 
	  <li>other light devices. Especially HUEDevice should work also for brightness and hue commands.</li> 
	  <code>milight_dimm_indirect($$)</code> and <code>milight_toggle_indirect($)</code> are intended for the use in notify code to derive commands to one or multiple bulbs. Parameter typically is $NAME or $EVTPART0.<br>
    </ul>
	<ul>
      <b>milight_to_shutter($$)</b><br>
	  Allows control of shutter devices. Tested with following devices:<br>
	  <li>HM-LC-Bl1PBU-FM as CUL_HM, shutters only</li> 
	  <li>ZWave actor FGR-223 in venetian mode - lamella position can be controlled via saturation slider</li> <br>
    </ul>
	<ul>
      <b>milight_Deckenlichter ($)</b><br>
	  Allows control of a group of 4 channels of on/off devices.<br>
    </ul>
	<ul>
      <b>milight_to_MPD($$)</b><br>
	  Allows control of a MusicPlayerDeamon - basics like play, pause, stop and volume.<br>
	  Additionally toggle two replay gain modes and "consumer" setting.
    </ul>
  </ul>
  <br><br>
  <ul>
  <b>Routines to use other remote types to control MiLight bulbs</b><br>
  <code>milight_dimm_indirect($$)</code> and <code>milight_toggle_indirect($)</code> are intended for the use in notify code to derive commands to one or multiple bulbs. Parameter typically is $NAME or $EVTPART0.<br>
  To get the logical link, e.g. from a button to a specific bulb, a userattr value is used, multiple bulbs have to be comma-separated.<br>
  Examples: 
  <ul>
   <code>attr Schalter_Spuele_Btn_04 userattr Target_Device<br>attr Schalter_Spuele_Btn_04 Target_Device Licht_Essen</code><br>
   This way, one notify can be used to derive actions on various devices
  </ul>
    <ul>
     <code>defmod MiLight_dimm notify Schalter_Spuele_Btn_0[124]:Long..*[\d]+_[\d]+.\(to.VCCU\) {milight_dimm_indirect($NAME,$EVENT)}<br>defmod MiLight_toggle notify Schalter_Spuele_Btn_0[124]:Short.[\d]+_[\d]+.\(to.VCCU\) {milight_toggle_indirect($NAME)}</code><br>
    </ul>
  </ul>
</ul>
=end html
=cut
