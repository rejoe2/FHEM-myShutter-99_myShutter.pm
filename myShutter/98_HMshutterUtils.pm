# $Id: 98_HMshutterTools.pm $
####################################################################################################
#
#	98_HMshutterTools.pm
#
#	Tools for easier configuration of homematic shutter devices
#	https://forum.fhem.de/index.php/topic,69704.0.html
#	use forum contact to Beta-User if necessary
#
#	http://www.wiki.fhem.de
#
#	This file is free contribution and not part of fhem.
#
#	Fhem is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 2 of the License, or
#	(at your option) any later version.
#
#	Fhem is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with fhem.  If not, see <http://www.gnu.org/licenses/>.
#
####################################################################################################

package main;
use strict;
use warnings;
use POSIX;

sub HMshutterUtils_Initialize($) {
   	my ($hash) = @_;	
	$hash->{DefFn}	  = "HMshutterUtils_Define";
	$hash->{UndefFn}  = "HMshutterUtils_Undef";
	#$hash->{DeleteFn}  = "HMshutterUtils_Delete";
	$hash->{SetFn}	  = "HMshutterUtils_Set";
	#$hash->{GetFn}   = "HMshutterUtils_Get";
	#$hash->{AttrFn}  = "HMshutterUtils_Attr";
	#$hash->{ReadFn}  = "HMshutterUtils_Read";
	#$hash->{ReadyFn} = "HMshutterUtils_Ready";
	$hash->{NotifyFn} = "HMshutterUtils_Notify";
	$hash->{AttrList} = 	" defaultOpenPosition" 
				." defaultTiltedPosition" 
				." defaultJalousieTurnValue";
	$hash->{parseParams} = 1;
	$hash->{NotifyOrderPrefix} = "45-"  # Alle Definitionen des Moduls werden bei der Eventverarbeitung zuerst geprüft
	}

sub HMshutterUtils_Define($$) {
	#Als Parameter darf nur Modulname und Name angegeben werden
	my ($hash, $def) = @_;
	my @a = split("[ \t][ \t]*", $def);
#	Das funktioniert aus noch ungeklärten Gründen nicht:
	return "Wrong syntax: use define <name> HMshutterUtils" if (@a != 1);
	readingsSingleUpdate($hash, "state", "initialized",1);
	my $name   = $a[0];
	my $module = $a[1];

	#$hash->{NOTIFYDEV} = "global"; #,subType=(blindActuator|threeStateSensor),.*(closed|open|tilted)|(Rolladen_.*|Jalousie_.*).(motor:.stop.*|set_.*|motor..down.*)";
	Log3($name, 4, "HM_ShutterUtils $name has been defined");
	return undef; 	
	}

sub HM_ShutterUtils_Undef($$) {
    my ($hash, $arg) = @_;

    RemoveInternalTimer($hash);
    Log3 $hash->{NAME}, 4, "Instance :: Closed module 'HM_ShutterUtils': ".Dumper($hash);

    return undef;
}
	
	
sub HMshutterUtils_Notify($$) {
	my ($own_hash, $dev_hash) = @_;
	my $ownName = $own_hash->{NAME}; # own name / hash
 
	return "" if(IsDisabled($ownName)); # Return without any further action if the module is disabled
 
	my $devName = $dev_hash->{NAME}; # Device that created the events
	my $events = deviceEvents($dev_hash, 1);

	#my $rawEvent = $dev_hash;
	
	if($devName eq "global" && grep(m/^INITIALIZED|REREADCFG|MODIFIED$/, @{$events})) {
		#my $event_regex = ".*(closed|open|tilted)|(Rolladen_.*|Jalousie_.*).(motor:.stop.*|set_.*|motor..down.*)";
		#my $event_regex = "subType=(blindActuator|threeStateSensor)";
		#notifyRegexpChanged($own_hash, $event_regex);
		HMshutterUtils_updateTimer();
		readingsSingleUpdate($own_hash, "state", "active",1);
	#	 X_FunctionWhoNeedsAttr($hash);
		return undef;
	}
	
	#Als Parameter muss der device-Name sowie der Event übergeben werden
	#notify-Definition:
	#defmod n_Rolladen_Window notify .*(closed|open|tilted)|(Rolladen_.*|Jalousie_.*).(motor:.stop.*|set_.*|motor..down.*) { HM_ShutterUtils_Notify($NAME,$EVENT) }
	
	#Ein "set" löst zwei Events aus, einmal beim (logischen) Gerät direkt, und dann beim entsprechenden Aktor.
	#Wir brauchen nur einen (den ersten).
	elsif (grep(m/^level:.set_/, @{$events})){
		Log3 $devName, 4, "Doppelevent: $events";
		readingsSingleUpdate($own_hash, "state", "Doppelevent",1);
		return; 
	}
	else {
		#readingsSingleUpdate($own_hash, "state", "@{$events}",1);
	
		#Als erstes brauchen wir die Info, welcher Rolladen bzw. welcher Fenster- bzw. Türkontakt
		#betroffen sind

		my $shutter = $devName;
		my $textEvent = "Rollo";
	
		if (AttrVal($shutter,'subType', undef) ne "blindActuator"){
			$shutter = AttrVal($devName,'ShutterAssociated',undef);
			$textEvent = "Window";
		} 
		my $windowcontact = AttrVal($shutter,'WindowContactAssociated',"none");
		my $readingsAge = ReadingsAge($shutter,'WindowContactOnHoldState',60);
		my $readingsAgeLimit = 5;	
		if (!$shutter) {}
       
		#Ausfiltern von Selbsttriggern!
		elsif ($readingsAge < $readingsAgeLimit) {
#			readingsSingleUpdate($own_hash, "state", "Readingsage: $readingsAge!",1);
			Log3 $devName, 4, "Most likely we are triggering ourself: $devName $events";
			return;
		}
	
		elsif (AttrVal($shutter,'subType', undef) eq "blindActuator"){       
			#Wir speichern ein paar Infos, damit das nicht zu unübersichtlich wird
			my $position = ReadingsVal($shutter,'pct',0);
			my $winState = Value($windowcontact);
			my $maxPosOpen = AttrVal($shutter,'WindowContactOpenMaxClosed',100)+0.5;
			my $maxPosTilted = AttrVal($shutter,'WindowContactTiltedMaxClosed',100)+0.5;
			my $turnValue = AttrVal($shutter,'JalousieTurnValue',0);
			my $onHoldState = ReadingsVal($shutter,'WindowContactOnHoldState',"-1")+0;
			my $turnPosOpen = $maxPosOpen+$turnValue;
			my $turnPosTilted = $maxPosTilted+$turnValue;
			my $targetPosOpen = $maxPosOpen+$turnValue;
			my $targetPosTilted = $maxPosTilted+$turnValue;
			my $motorReading = ReadingsVal($shutter,'motor',0);
			my $event = "none";
	  		my $setPosition = Value($shutter);
			my $setFhem = 0;
			my $shutterHash = $defs{$shutter};

			if($setPosition =~ /set_/) { #FHEM-Befehl
				$setPosition = substr $setPosition, 4, ;
				$setFhem = 1 if ($setPosition != $turnPosOpen && $setPosition != $turnPosTilted && $setPosition != $targetPosOpenPosOpen && $setPosition != $targetPosOpenPosOpen && $setPosition != $onHoldState);
#			readingsSingleUpdate($own_hash, "state", "@{$events}; $devName: $setPosition; if für Value",1);
#			return;
			}
			$setPosition = 100 if ($setPosition eq "on");
			$setPosition = 0 if ($setPosition eq "off");
			 
	    	#dann war der Trigger über Tastendruck oder Motor-Bewegung
			if ($motorReading =~ /down/ && $setFhem == 0) { $setPosition = -1;}
			readingsSingleUpdate($own_hash, "state", "@{$events}; $devName: $setPosition; OnHold: $onHoldState, Age: $readingsAge; $winState",1);
			Log3 $devName, 4, "$shutter setPosition: $setPosition, Age: $readingsAge; Window: $winState";
#	  	return ;
			#Unterscheidung nach Event-Art: Fahrbefehl oder stop/FK
			if (grep(m/^motor:.down/, @{$events}) || $setFhem == 1){
				#Fahrbefehl über FHEM oder Tastendruck?
				#Fährt der Rolladen aufwärts, gibt es nichts zu tun...
				if ($setPosition >= $position) {
#					readingsSingleUpdate($own_hash, "state", "Nothing to do, $devName moving upwards",1);
					Log3 $devName, 4, "Nothing to do, $devName moving upwards";
					return;
				}
								  
				#Jetzt können wir nachsehen, ob der Rolladen zu weit nach unten soll
				#(Fenster offen)...
				if($setPosition < $maxPosOpen && $winState eq "open" && $windowcontact ne "none") {
					if ($position > $maxPosOpen){
						AnalyzeCommand($shutterHash,"set $shutter $maxPosOpen");
					} else {
						AnalyzeCommand($shutterHash,"set $shutter $targetPosOpen");
					}
					
					if ($setPosition == -1){
						readingsSingleUpdate($shutterHash, "WindowContactOnHoldState", "$onHoldState",1);
					} else {readingsSingleUpdate($shutterHash, "WindowContactOnHoldState", "$setPosition",1);}
				}
				#...(gekippt)...
				elsif($winState eq "tilted" && $windowcontact ne "none") {
					if($setPosition < $maxPosTilted ) { 
						if ($setPosition == -1) {
							readingsSingleUpdate($shutterHash, "WindowContactOnHoldState", "$onHoldState",1);
						} else {
							readingsSingleUpdate($shutterHash, "WindowContactOnHoldState", "$setPosition",1);
						}
						if ($position > $maxPosTilted){
							AnalyzeCommand($shutterHash,"set $shutter $maxPosTilted");
						} else {
							AnalyzeCommand($shutterHash,"set $shutter $targetPosTilted");
						}
					}
					else {readingsSingleUpdate($shutterHash, "WindowContactOnHoldState", "$onHoldState",1)}
				}
				#...(geschlossen) = nur ReadingsAge-update, um Selbsttriggerung zu verhindern
				elsif ($winState eq "closed") {
					readingsSingleUpdate($shutterHash, "WindowContactOnHoldState", "$onHoldState",1);  
				}
			}	 
			
			#stop/FK
			elsif (grep(m/^motor:.stop/, @{$events}) || grep(m/^closed|open|tilted/, @{$events})){
				readingsSingleUpdate($own_hash, "state", "stop/FK @{$events}; $devName: $setPosition; OnHold: $onHoldState, Age: $readingsAge; $winState",1);
							
				#Jetzt können wir nachsehen, ob der Rolladen zu weit unten ist (Fenster offen)...
				if($setPosition < $maxPosOpen && $winState eq "open" && $windowcontact ne "none") {
					AnalyzeCommand($shutterHash,"set $shutter $targetPosOpen");
					if($onHoldState > -1 && $motorReading =~ /stop/) { 
						readingsSingleUpdate($shutterHash, "WindowContactOnHoldState", "$setPosition",1);
					}
				}
				#...(gekippt)...
				elsif($winState eq "tilted" && $windowcontact ne "none") {
					if($onHoldState > -1) { 
						if ($maxPosTilted < $onHoldState) { 
							AnalyzeCommand($shutterHash,"set $shutter $onHoldState");
							readingsSingleUpdate($shutterHash, "WindowContactOnHoldState", "-1",1);
						}
						else {
							if ($readingsAge < $readingsAgeLimit) {return "Most likely we are triggering ourself";}
							AnalyzeCommand($shutterHash,"set $shutter $maxPosTilted");
							readingsSingleUpdate($shutterHash, "WindowContactOnHoldState", "$onHoldState",1);
						}
					}	
					if ($setPosition < $maxPosTilted) {
						if ($readingsAge < $readingsAgeLimit) {return "Most likely we are triggering ourself";}
						AnalyzeCommand($shutterHash,"set $shutter $maxPosTilted");			  
						if ($onHoldState > -1 && $motorReading =~ /stop/) {readingsSingleUpdate($shutterHash, "WindowContactOnHoldState", "$setPosition",1);}
						elsif ($position > $onHoldState && $motorReading =~ /stop/) {readingsSingleUpdate($shutterHash, "WindowContactOnHoldState", "$setPosition",1);}
					}
				}
				#...oder ob eine alte Position wegen Schließung des Fensters angefahren werden soll...
				elsif ($textEvent eq "Window" && $winState eq "closed" && $onHoldState > -1) {
					AnalyzeCommand($shutterHash,"set $shutter $onHoldState");
					readingsSingleUpdate($shutterHash, "WindowContactOnHoldState", "-1",1);  
				}
				#...oder ob es sich um einen Stop zum Drehen der Jalousielamellen handelt...
				elsif ($textEvent eq "Rollo") {
					if ($turnValue > 0 && $position == $turnPosOpen) {AnalyzeCommand($shutterHash,"set $shutter $maxPosOpen");}
					elsif ($turnValue > 0 && $position == $turnPosTilted) {AnalyzeCommand($shutterHash,"set $shutter $maxPosTilted");}
					#...oder die Positionsinfo wegen manueller Änderung gelöscht werden kann.
					elsif ($position != $maxPosOpen && $position != $maxPosTilted && $onHoldState > -1) {
						readingsSingleUpdate($shutterHash, "WindowContactOnHoldState", "-1",1);
					}
				}
			}
		}
	}	
	return undef;
}

sub HMshutterUtils_updateTimer(){
	return undef;
}

sub HMshutterUtils_set($$@) 
{
	#Als Parameter müssen die Namen vom Fensterkontakt und Rolladen übergeben werden sowie der Maxlevel bei Fensteröffnung und tilted
	#Call in FHEMWEB e.g.: { winShutterAssociate("Fenster_Wohnzimmer_SSW","Rolladen_WZ_SSW",90,20) }
	my $param;
	my ($hash, $setFunction, @param) = @_;
	my %sets = (inactive=>0, active=>0, Test=>0, softpeer=>0, setJalousieType=>0);
	if($setFunction eq "?"){
	return "Unknown argument $setFunction, choose one of ".join(" ", sort keys %sets)
		if(!defined($sets{$setFunction}));
	}
	
	#Erst mal prüfen, ob die Parameter sinnvoll sind
	elsif ($setFunction == "Test"){
		my ($shutter, $windowcontact, $maxPosition, $maxPosTilted) = @param;
		readingsSingleUpdate($hash, "state", "Set aufgerufen, Parameter: @{$param}",1); 
	}
	if($setFunction eq "inactive") {
    readingsSingleUpdate($hash, "state", "inactive", 1);

  }
  elsif($setFunction eq "active") {
    readingsSingleUpdate($hash, "state", "defined", 1)
        if(!AttrVal($hash->{NAME}, "disable", undef));
  }
	elsif ($setFunction == "setTypeJalousie"){
		my ($shutter, $turnValue) = @param;
		if ($defs{$shutter}) {
        	if (AttrVal($shutter,'subType', undef) eq "blindActuator") {
            	my $oldAttrRollo = AttrVal($shutter,'userattr',undef);

            	#Jetzt können wir sehen, ob das notwendige userattr vorhanden ist
				#und ggf. den Wert zuweisen
				if(index($oldAttrRollo,"JalousieTurnLevel") < 0){
					readingsSingleUpdate($defs{$shutter}, "userattr", "$oldAttrRollo JalousieTurnValue",1);	
            	}
				$turnValue = AttrVal($hash,"defaultJalousieTurnValue",undef) if (!$turnValue);
				readingsSingleUpdate($defs{$shutter}, "JalousieTurnValue", "$turnValue",1);
			}
			else { return "Device has wrong subtype";}
		}	
		else { return "Devices does not exist";}
	}
	elsif ($setFunction == "softpeer"){
		my ($shutter, $windowcontact, $maxPosition, $maxPosTilted) = @param;
	
		if ($defs{$windowcontact} && $defs{$shutter}) {

			if (AttrVal($shutter,'subType', undef) eq "blindActuator" && AttrVal($windowcontact,'subType',undef) eq "threeStateSensor") {
				my $oldAttrWin = AttrVal($windowcontact,'userattr',undef);
				my $oldAttrRollo = AttrVal($shutter,'userattr',undef);
				$maxPosition = AttrVal($hash,"defaultOpenPosition",undef) if (!$maxPosition);
				$maxPosTilted = AttrVal($hash,"defaultTiltedPosition",undef) if (!$maxPosTilted);

				#Jetzt können wir sehen, ob und welche notwendigen userattr vorhanden sind
				#und ggf. Werte zuweisen
				if(index($oldAttrWin,"ShutterAssociated") < 0){
					readingsSingleUpdate($defs{$windowcontact}, "userattr", "$oldAttrWin ShutterAssociated:$shutter",1);
				}
				if(index($oldAttrRollo,"WindowContactAssociated") < 0) {
					readingsSingleUpdate($defs{$shutter}, "userattr", "$oldAttrRollo WindowContactAssociated:$windowcontact",1);
					$oldAttrRollo = AttrVal($shutter,'userattr',undef);
            	}
				if(index($oldAttrRollo,"WindowContactOnHoldState") < 0) {
					readingsSingleUpdate($defs{$shutter}, "userattr", "$oldAttrRollo WindowContactOnHoldState:none",1);
					$oldAttrRollo = AttrVal($shutter,'userattr',undef);
				}
				if(index($oldAttrRollo,"WindowContactOpenMaxClosed") < 0) {
					readingsSingleUpdate($defs{$shutter}, "userattr", "$oldAttrRollo WindowContactOpenMaxClosed:$maxPosition",1);
					$oldAttrRollo = AttrVal($shutter,'userattr',undef);
				}
				if(index($oldAttrRollo,"WindowContactTiltedMaxClosed") < 0) {
					readingsSingleUpdate($defs{$shutter}, "userattr", "$oldAttrRollo WindowContactTiltedMaxClosed:$maxPosTilted",1);	
				}
			}
			else { return "One of the devices has wrong subtype";}
		}
		else { return "One of the devices does not exist";}
	}	

	#Erst mal prüfen, ob die Parameter sinnvoll sind
	elsif ($setFunction == "setTypeJalousie"){
		my ($shutter, $turnValue) = @param;
		if ($defs{$shutter}) {
        	if (AttrVal($shutter,'subType', undef) eq "blindActuator") {
            	my $oldAttrRollo = AttrVal($shutter,'userattr',undef);

            	#Jetzt können wir sehen, ob das notwendige userattr vorhanden ist
				#und ggf. den Wert zuweisen
				if(index($oldAttrRollo,"JalousieTurnLevel") < 0){
					readingsSingleUpdate($defs{$shutter}, "userattr", "$oldAttrRollo JalousieTurnValue",1);	
            	}
				$turnValue = AttrVal($hash,"defaultJalousieTurnValue",undef) if (!$turnValue);
				readingsSingleUpdate($defs{$shutter}, "JalousieTurnValue", "$turnValue",1);
			}
			else { return "Device has wrong subtype";}
		}	
		else { return "Devices does not exist";}
	}
	return undef;
}

1;

=pod
=item helper
=item summary Offers additional functionality of Homematic shutter devices 
=item summary_DE Stellt erweiterte Möglichkeiten der Konfiguration von Homematic Rolladenaktoren bereit
=begin html
<a name="HM_ShutterUtils"></a>
<h3>HM_ShutterUtils</h3>
<ul>
<p>HM_ShutterUtils offer easy access to additional functionality for Homematic shutter actors as window contact based open- and close actions, timer settings and shadowing presets. The idea behind this module is to store all needed info as attributes of each shutter device. This allows easy configuration, especially when module readingsgroup is used. Other hardware is not supported (yet)<br />
	
</ul>
=end html

=begin html_DE
<a name="HM_ShutterUtils"></a>
<h3>HM_ShutterUtils</h3>
<ul>
<p>HM_ShutterUtils stellen auf einfachem Weg erweiterte Konfigurationsmoeglichkeiten und Funktionalitaet für Homematic Rolladenaktoren bereit, wie z.B. Positionsaenderungen abhaengig vom Status eines zugeordneten Fensterkontakts, Timer-gesteuerter Aktionen zum Oeffnen und Schließen oder zur Beschattung. Das Modulkonzept ist, alle relevanten Informationen als Attribute bei dem jeweiligen Aktor-Device zu hinterlegen, so dass auf andere Hilfskonstrukte wie Dummies usw. verzichtet werden kann. Das ermoeglichteine einfache Erstkonfiguration, gute Skalierbarkeit und simple Zugriffe auf die Einstellungen bei spaeteren Aenderungen, insbesondere, wenn das Modul "readingsgroup" zur Aenderung der Einstellungen verwendet wird. HM_ShutterUtils ist rein perl-basiert und benoetigt für den Betrieb keine anderen Abhaengigkeiten oder Module. Andere Hardware als Homematic wird derzeit nicht unterstützt.<br />
<a name="HM_ShutterUtils_define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; HM_ShutterUtils</code><br>
    <br>
    Erstellt ein Helper-Geraet. Dieses beinhaltet zum einen die erorderliche Notify-Funktionalität, um auf Tuer- oder Fensteroeffnungen zu reagieren und ermoeglicht, default-Werte für die weitere Konfiguration von Rolladenaktoren zu setzen. Ueber das Device koennen auch die zu verwaltenden Rolladenaktoren mit den Attributen versehen werden. Geplant ist außerdem, daraeber die interneren Timer zu setzen, die geplante Oeffnen-, Schließen- und Beschattungs-Funktionen ausfuehren.<br>
  </ul>

  <a name="HM_ShutterUtils_set"></a>
  <b>Set </b>
  <ul>
    <li>inactive<br>
        Deaktiviert das entsprechende Ger&auml;t. Beachte den leichten
        semantischen Unterschied zum disable Attribut: "set inactive"
        wird bei einem shutdown automatisch in fhem.state gespeichert, es ist
        kein save notwendig.<br>
        Der Einsatzzweck sind Skripte, um das notify tempor&auml;r zu
        deaktivieren.<br>
        Das gleichzeitige Verwenden des disable Attributes wird nicht empfohlen.
        </li>
    <li>active<br>
        Aktiviert das entsprechende Ger&auml;t, siehe inactive.
        </li>
    <li>softpeer<br>
        <code>set &lt;name&gt; softpeer &lt;Rolladenaktor&gt; &lt;Fensterkontakt&gt; &lt;Level Fenster offen&gt; &lt;Level Fenster gekippt&gt;</code><br>
		Setzt die erforderlichen wechselseitigen Attribute, um automatisch auf Fensteroeffnung zu reagieren (Aussperrschutz und Lueftungsfunktion) und ein vollst&auml;ndiges Schließen des Rolladens bei geoeffnetem Fenster zu verhindern. Wird das Fenster geschlossen, wird der Rolladen automatisch weiter geschlossen, sofern dies noch der "Soll"-Position entspricht.<br>
        </li>
    <li>setTypeJalousie<br>
        <code>set &lt;name&gt; setJalousieType &lt;Rolladenaktor&gt; &lt;Differenzwert&gt;</code><br>
		Bewirkt das automatische Drehen für Jalousien nach automatischer nach-oben-Fahrt bei Lueftungsfunktionftungsfunktion.
        </li>
  </ul>
  <br>
</ul>
=end html_DE
=cut
