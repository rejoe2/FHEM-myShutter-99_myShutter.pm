 package main;
 use strict;
 use warnings;
 use POSIX;
 sub
 myShutterUtils_Initialize($$)
 {
   my ($hash) = @_;
 }

sub myShutterUtils_MovementCheck($$) {
	#Als Parameter muss der device-Name sowie der Event übergeben werden
	#notify-Definitionen:
	#defmod n_Rolladen_CheckSet notify (Rolladen_.*|Jalousie_.*).(set_.*|motor..down.*) { myShutterUtils_MovementCheck($NAME,$EVENT)}
	#Testnotify: (Rolladen_.*|Jalousie_.*).motor..down.* sleep 2;;{ myShutterUtils_MovementCheck($NAME,$EVENT)}
	my ($dev, $rawEvent) = @_;
	
	#Ein "set" löst zwei Events aus, einmal beim (logischen) Gerät direkt, und dann beim entsprechenden Aktor.
	#Wir brauchen nur einen (den ersten).
	return "Doppelevent: $rawEvent" if ($rawEvent =~ /level:/); 
	
	#Erst mal prüfen, ob das übergebene device überhaupt existiert
	if ($defs{$dev}) {
		
		#Als erstes brauchen wir die Info, welcher Rolladen bzw. welcher Fenster- bzw. Türkontakt
		#betroffen sind
		my $windowcontact = AttrVal($dev,'WindowContactAssociated',"none");
		my $shutter=$dev;
		my $readingsAge = ReadingsAge($shutter,'WindowContactOnHoldState',60);
		
		if (!$shutter) {}
        
		#Ausfiltern von Selbsttriggern!
		elsif ($readingsAge < 6) {return "Most likely we are triggering ourself";}
	
		else {       
			#Wir speichern ein paar Infos, damit das nicht zu unübersichtlich wird
			my $position = ReadingsVal($shutter,'pct',0);
			my $winState = Value($windowcontact);
			my $maxPosOpen = AttrVal($shutter,'WindowContactOpenMaxClosed',100)+0.5;
			my $maxPosTilted = AttrVal($shutter,'WindowContactTiltedMaxClosed',100)+0.5;
			my $turnValue = AttrVal($shutter,'JalousieTurnValue',0);
			my $onHoldState = ReadingsVal($shutter,'WindowContactOnHoldState',"none");
			my $turnPosOpen = $maxPosOpen+$turnValue;
			my $turnPosTilted = $maxPosTilted+$turnValue;
			my $targetPosOpen = $maxPosOpen+$turnValue;
			my $targetPosTilted = $maxPosTilted+$turnValue;
			my $motorReading = ReadingsVal($shutter,'motor',0);
			my $event = "none";
		  	my $setPosition = Value($shutter);
			
			#Fahrbefehl über FHEM oder Tastendruck?
			if($setPosition =~ /set_/) { 
				$setPosition = substr $setPosition, 4, ; #FHEM-Befehl
				if ($setPosition eq "on") {$setPosition = 100;}
				elsif ($setPosition eq "off") {$setPosition = 0;}
				#Fährt der Rolladen aufwärts, gibt es nichts zu tun...
				if ($setPosition >= $position) {return "Nothing to do, moving upwards";}
			}
			#dann war der Trigger über Tastendruck oder Motor-Bewegung
			else { $setPosition = -1;}
		    
			#Alte Option zur Auswertung von Zwischenereignissen
			#if (ReadingsAge('Rolladendummy','state',60) < 10) {fhem ("set Rolladendummy $shutter wurde erst kürzlich verändert");} #return;
			#fhem ("set Rolladendummy $shutter, setPosition: $setPosition, Age: $readingsAge!");return;
		  		  
			#Jetzt können wir nachsehen, ob der Rolladen zu weit nach unten soll
			#(Fenster offen)...
			if($setPosition < $maxPosOpen && $winState eq "open" && $windowcontact ne "none") {
				fhem("set $shutter $maxPosOpen");
				if ($setPosition = -1){
					fhem("setreading $shutter WindowContactOnHoldState $onHoldState");
				} else {fhem("setreading $shutter WindowContactOnHoldState $setPosition");}
			}
			#...(gekippt)...
			elsif($winState eq "tilted" && $windowcontact ne "none") {
				if($setPosition < $maxPosTilted ) { 
					if ($setPosition = -1) {
						fhem("setreading $shutter WindowContactOnHoldState $onHoldState");
					} else {fhem("setreading $shutter WindowContactOnHoldState $setPosition");}
					fhem("set $shutter $maxPosTilted");
				}
				else {fhem("setreading $shutter WindowContactOnHoldState $onHoldState");}
			}
			#...(geschlossen) = nur ReadingsAge-update, um Selbsttriggerung zu verhindern
			elsif ($winState eq "closed") {
				fhem("setreading $shutter WindowContactOnHoldState $onHoldState");  
			}
		}	
	}
return undef;
}


sub winOpenShutterTester($$) {
	#Als Parameter muss der device-Name übergeben werden
	#notify-Definition:
	#defmod n_Rolladen_Window notify .*(closed|open|tilted)|(Rolladen_.*|Jalousie_.*).motor:.stop.* { winOpenShutterTester($NAME,$EVENT) }
	#Hint for window contacts: make sure to modify settings of device wrt. some delay in sending state changes to avoid unnecessary triggers
	my ($dev, $event) = @_;
 
	#Erst mal prüfen, ob das übergebene device überhaupt existiert
	if ($defs{$dev}) {
 
		#Als erstes brauchen wir die Info, welcher Rolladen bzw. welcher Fenster- bzw. Türkontakt
		#betroffen sind
		my $shutter = $dev;
		my $textEvent = "Rollo";
		
		if (AttrVal($shutter,'subType', undef) ne "blindActuator"){
			$shutter = AttrVal($dev,'ShutterAssociated',undef);
			$textEvent = "Window";
		} 
		my $windowcontact = AttrVal($shutter,'WindowContactAssociated',"none");
		
		unless (!$shutter) {  
			#Wir speichern ein paar Infos, damit das nicht zu unübersichtlich wird
			my $position = ReadingsVal($shutter,'pct',0);
			#return "set command, nothing meaningfull to do" if ($position =~ /set_/);  
			my $motorReading = ReadingsVal($shutter,'motor',0);
			my $winState = Value($windowcontact);
			my $maxPosOpen = AttrVal($shutter,'WindowContactOpenMaxClosed',100)+0.5;
			my $maxPosTilted = AttrVal($shutter,'WindowContactTiltedMaxClosed',100)+0.5;
			my $turnValue = ReadingsVal($shutter,'JalousieTurnValue',0);
			my $onHoldState = ReadingsVal($shutter,'WindowContactOnHoldState',"none");
			my $turnPosOpen = $maxPosOpen+$turnValue;
			my $turnPosTilted = $maxPosTilted+$turnValue;
			my $targetPosOpen = $maxPosOpen+$turnValue;
			my $targetPosTilted = $maxPosTilted+$turnValue;
			my $readingsAge = ReadingsAge($shutter,'WindowContactOnHoldState',60);
		
			#Jetzt können wir nachsehen, ob der Rolladen zu weit unten ist (Fenster offen)...
			if($position < $maxPosOpen && $winState eq "open" && $windowcontact ne "none") {
				fhem("set $shutter $targetPosOpen");
				if($onHoldState eq "none" && $motorReading =~ /stop/) { 
					fhem("setreading $shutter WindowContactOnHoldState $position");
				}
			}
			#...(gekippt)...
			elsif($winState eq "tilted" && $windowcontact ne "none") {
				if($onHoldState ne "none") { 
					if ($maxPosTilted < $onHoldState) { 
						fhem("set $shutter $onHoldState");
						fhem("setreading $shutter WindowContactOnHoldState none");
					}
					else {
						if ($readingsAge < 10) {return "Most likely we are triggering ourself";}
						fhem("set $shutter $maxPosTilted");
						fhem("setreading $shutter WindowContactOnHoldState $onHoldState");
					}
				}	
				if ($position < $maxPosTilted) {
					if ($readingsAge < 10) {return "Most likely we are triggering ourself";}
					fhem("set $shutter $maxPosTilted");			  
					if ($position > $onHoldState && $motorReading =~ /stop/) {fhem("setreading $shutter WindowContactOnHoldState $position");}
				}
			}
			#...oder ob eine alte Position wegen Schließung des Fensters angefahren werden soll...
			elsif ($textEvent eq "Window" && $winState eq "closed" && $onHoldState ne "none") {
				fhem("set $shutter $onHoldState");
				fhem("setreading $shutter WindowContactOnHoldState none");  
			}
			#...oder ob es sich um einen Stop zum Drehen der Jalousielamellen handelt...
			elsif ($textEvent eq "Rollo") {
				if ($turnValue > 0 && $position == $turnPosOpen) {fhem("set $shutter $maxPosOpen");}
				elsif ($turnValue > 0 && $position == $turnPosTilted) {fhem("set $shutter $maxPosTilted");}
				#...oder die Positionsinfo wegen manueller Änderung gelöscht werden kann.
				elsif ($position != $maxPosOpen && $position != $maxPosTilted && $onHoldState ne "none") {
					fhem("setreading $shutter WindowContactOnHoldState none"); 
				}
			}
        }
    }
return undef;
}


sub winShutterAssociate($$$$) {
	#Als Parameter müssen die Namen vom Fensterkontakt und Rolladen übergeben werden sowie der Maxlevel bei Fensteröffnung und tilted
	#Call in FHEMWEB e.g.: { winShutterAssociate("Fenster_Wohnzimmer_SSW","Rolladen_WZ_SSW",90,20) }
	my ($windowcontact, $shutter, $maxPosition, $maxPosTilted) = @_;
	my ($hash, @param) = @_;
	#Erst mal prüfen, ob die Parameter sinnvoll sind
	if ($defs{$windowcontact} && $defs{$shutter}) {

		if (AttrVal($shutter,'subType', undef) eq "blindActuator" && AttrVal($windowcontact,'subType',undef) eq "threeStateSensor") {
			my $oldAttrWin = AttrVal($windowcontact,'userattr',undef);
			my $oldAttrRollo = AttrVal($shutter,'userattr',undef);

			#Jetzt können wir sehen, ob und welche notwendigen userattr vorhanden sind
			#und ggf. Werte zuweisen
			if(index($oldAttrWin,"ShutterAssociated") < 0){
				fhem("attr $windowcontact userattr $oldAttrWin ShutterAssociated");
			}
			fhem("attr $windowcontact ShutterAssociated $shutter");
			if(index($oldAttrRollo,"WindowContactAssociated") < 0) {
				fhem("attr $shutter userattr $oldAttrRollo WindowContactAssociated");
				$oldAttrRollo = AttrVal($shutter,'userattr',undef);
            }
			fhem("attr $shutter WindowContactAssociated $windowcontact");
			if(index($oldAttrRollo,"WindowContactOnHoldState") < 0) {
				fhem("attr $shutter userattr $oldAttrRollo WindowContactOnHoldState");
				$oldAttrRollo = AttrVal($shutter,'userattr',undef);
			}
			#fhem("attr $shutter WindowContactOnHoldState none");
			fhem("setreading $shutter WindowContactOnHoldState none");
			if(index($oldAttrRollo,"WindowContactOpenMaxClosed") < 0) {
				fhem("attr $shutter userattr $oldAttrRollo WindowContactOpenMaxClosed");
			}
			fhem("attr $shutter WindowContactOpenMaxOpen $maxPosition");
			if(index($oldAttrRollo,"WindowContactTiltedMaxOpen") < 0) {
				fhem("attr $shutter userattr $oldAttrRollo WindowContactTiltedMaxClosed");
			}
			fhem("attr $shutter WindowContactTiltedMaxClosed $maxPosTilted");

		}
		else { return "One of the devices has wrong subtype";}
	}
	else { return "One of the devices does not exist";}
}

sub attrShutterTypeJalousie($$) {
	#Als Parameter muss der Namen vom Rolladen übergeben werden sowie 
	#der Wert, um den zum Drehen nach oben gefahren werden soll
	#Call in FHEMWEB e.g.: { attrShutterTypeJalousie ("Jalousie_WZ",3) }
	my ($shutter, $turnValue) = @_;
	my ($hash, @param) = @_;
	#Erst mal prüfen, ob die Parameter sinnvoll sind
	if ($defs{$shutter}) {

        if (AttrVal($shutter,'subType', undef) eq "blindActuator") {
            my $oldAttrRollo = AttrVal($shutter,'userattr',undef);

            #Jetzt können wir sehen, ob das notwendige userattr vorhanden ist
			#und ggf. den Wert zuweisen
			if(index($oldAttrRollo,"JalousieTurnLevel") < 0){
                fhem("attr $shutter userattr $oldAttrRollo JalousieTurnValue");
            }
			fhem("attr $shutter JalousieTurnValue $turnValue");
		}
		else { return "Device has wrong subtype";}
	}
	else { return "Devices does not exist";}
}


1;
