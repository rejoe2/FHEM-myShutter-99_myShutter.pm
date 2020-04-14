##############################################
# $Id: myUtils_ZWave.pm 2019-07-24 Beta-User $
#

package main;

use strict;
use warnings;

sub
myUtils_ZWave_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.

sub devStateIcon_FGR223($) {
my $levelname = shift(@_);
my $ret ="";
my ($def,$defnr) = split(" ", InternalVal($levelname,"DEF",$levelname));
$defnr++;
my @slatnames = devspec2array("DEF=$def".'.'.$defnr);
my $slatname = shift @slatnames;
my $dimlevel= ReadingsNum($levelname,"dim",0);
my $slatlevel= ReadingsNum($slatname,"state",0);

#levelicon
my $symbol_string = "fts_shutter_";
my $command_string = "dim 99";
$command_string = "dim 0" if $dimlevel > 50;
$symbol_string .= int ((109 - $dimlevel)/10)*10;
$ret .= "<a href=\"/fhem?cmd.dummy=set $levelname $command_string&XHR=1\">" . FW_makeImage($symbol_string,"fts_shutter_10") . "</a> "; 

#stop
$ret .= "<a href=\"/fhem?cmd.dummy=set $levelname stop&XHR=1\">" . FW_makeImage("fts_shutter_shadding_stop","fts_shutter_shadding_stop") . "</a> "; 

#slat
$symbol_string = "fts_blade_arc_close_";
$command_string = "dim ";
$slatlevel > 49 ? $symbol_string .= "00" : $slatlevel > 24 ? $symbol_string .= "50" : $slatlevel < 25 ? $symbol_string .= "100" : undef;
$slatlevel > 49 ? $command_string = "off" : $slatlevel > 24 ? $command_string .= "50" : $slatlevel < 25 ? $command_string .= "25" : undef;
$ret .= "<a href=\"/fhem?cmd.dummy=set $slatname $command_string&XHR=1\">" . FW_makeImage($symbol_string,"fts_blade_arc_close_100") . " $slatlevel \%</a>"; 

return "<div><p style=\"text-align:right\">$ret</p></div>"
;
}


sub checkSlaveMovement($$) {
my ($master,$event) = @_;
return undef unless (ReadingsAge("Schalter_WZ1_Btn_03","triggerTo_$master",1000) < 2 or 
                     ReadingsAge("Schalter_WZ1_Btn_04","triggerTo_$master",1000) < 2 or
					 ReadingsAge("Schalter_WZ1_Btn_05","triggerTo_$master",1000) < 2 or 
					 ReadingsAge("Schalter_WZ1_Btn_06","triggerTo_$master",1000) < 2);
if ($event =~ /stop/) { 						  
  CommandSet(undef,"Jalousie_WZ stop") 
} elsif ($event =~ /up/) {
  CommandSet(undef,"Jalousie_WZ dim 99") 
} else {
  CommandSet(undef,"Jalousie_WZ dim 0") 
}

}

sub checkButtonMovement($$) {
my ($master,$event) = @_;
if ($master =~ /Schalter_WZ1_Btn_03/ && ReadingsAge($master,"triggerTo_Rolladen_WZ_SSO",1000) > 10) {
  CommandSet(undef,"Jalousie_WZ dim 0"); 
} elsif ($master =~ /Schalter_WZ1_Btn_05/ && ReadingsAge($master,"triggerTo_Jalousie_Rechts",1000) > 10) {
  CommandSet(undef,"Jalousie_WZ dim 0"); 
} elsif ($master =~ /Schalter_WZ1_Btn_06/ && ReadingsAge($master,"triggerTo_Jalousie_Rechts",1000) > 10) {
  CommandSet(undef,"Jalousie_WZ dim 99"); 
} elsif ($master =~ /Schalter_WZ1_Btn_04/ && ReadingsAge($master,"triggerTo_Rolladen_WZ_SSO",1000) > 10) {
  CommandSet(undef,"Jalousie_WZ dim 99"); 
} elsif ($master =~ /Schalter_WZ1_Btn_0[56]/ && ReadingsVal("Jalousie_Rechts","motor","stop") =~ /stop/ or $master =~ /Schalter_WZ1_Btn_0[34]/ && ReadingsVal("Rolladen_WZ_SSO","motor","stop") =~ /stop/) {
  CommandSet(undef,"Jalousie_WZ stop") ;
}
}

1;

=pod
=begin html

<a name="myUtils_ZWave"></a>
<h3>myUtils_ZWave</h3>
<ul>
  <b>devStateIcon_FGR223</b>
  <br>
  Use this to get a multifunctional iconset to control Fibaro FGR-223 devices in venetian blind mode<br>
  Examples: 
  <ul>
   <code>attr Jalousie_WZ devStateIcon {devStateIcon_FGR223($name)}<br> attr Jalousie_WZ webCmd dim<br>attr Jalousie_WZ userReadings dim:(dim|reportedState).* {$1 =~ /reportedState/ ? ReadingsNum($name,"reportedState",0):ReadingsNum($name,"state",0)}
</code><br>
   The FHEM device to control slat level has to have a userReadings attribute for state like this:<br>
 <code>attr attr ZWave_SWITCH_MULTILEVEL_8.02 userReadings state:swmStatus.* {ReadingsNum($name,"swmStatus",0)}</code>
  </ul>
</ul>
=end html
=cut
