package main;
use strict;
use warnings;
use POSIX;

sub HMshutterUtils_Initialize($) {
   	my ($hash) = @_;	
	$hash->{DefFn}         = "HMshutterUtils_Define";
	#$hash->{UndefFn}       = "HMshutterUtils_Undef";
	#$hash->{DeleteFn}      = "HMshutterUtils_Delete";
	#$hash->{SetFn}         = "HMshutterUtils_Set";
	#$hash->{GetFn}         = "HMshutterUtils_Get";
	#$hash->{AttrFn}        = "HMshutterUtils_Attr";
	#$hash->{ReadFn}        = "HMshutterUtils_Read";
	#$hash->{ReadyFn}       = "HMshutterUtils_Ready";
	$hash->{NotifyFn}      = "HMshutterUtils_Notify";
	$hash->{AttrList} = " defaultOpenPosition" . 
	" defaultTiltedPosition" . 
	" defaultJalousieTurnValue";
	$hash->{parseParams} = 1;
	$hash->{NotifyOrderPrefix} = "55-"  # Alle Definitionen des Moduls werden bei der Eventverarbeitung zuerst geprüft
	}

sub HMshutterUtils_Define($$) {
	#Als Parameter darf nur Modulname und Name angegeben werden
	my ($hash, $def) = @_;
	my @a = split("[ \t][ \t]*", $def);
#	Das funktioniert aus noch ungeklärten Gründen nicht:
#	return "Wrong syntax: use define <name> HMshutterUtils" if (@a != 2);
	readingsSingleUpdate($hash, "state", "initialized",1);
	my $name   = $a[0];
	my $module = $a[1];

	#$hash->{NOTIFYDEV} = "global"; #,subType=(blindActuator|threeStateSensor),.*(closed|open|tilted)|(Rolladen_.*|Jalousie_.*).(motor:.stop.*|set_.*|motor..down.*)";
	Log3($name, 4, "HM_ShutterUtils $name has been defined");
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
		my $event_regex = "subType=(blindActuator|threeStateSensor)";
		notifyRegexpChanged($own_hash, $event_regex);
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
	
		if (!$shutter) {}
       
		#Ausfiltern von Selbsttriggern!
		elsif ($readingsAge < 10) {
			readingsSingleUpdate($own_hash, "state", "Readingage!",1);
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
			my $onHoldState = AttrVal($shutter,'WindowContactOnHoldState',"none");
			my $turnPosOpen = $maxPosOpen+$turnValue;
			my $turnPosTilted = $maxPosTilted+$turnValue;
			my $targetPosOpen = $maxPosOpen+$turnValue;
			my $targetPosTilted = $maxPosTilted+$turnValue;
			my $motorReading = ReadingsVal($shutter,'motor',0);
			my $event = "none";
	  		my $setPosition = $position;
			readingsSingleUpdate($own_hash, "state", "$devName: $position, $winState, OnHold: $onHoldState",1);
			if(grep(m/^set_/, @{$events})) { 
				$setPosition = substr grep(m/^set_/, @{$events}), 4, ; #FHEM-Befehl
				if ($setPosition eq "on") {$setPosition = 100;}
				elsif ($setPosition eq "off") {$setPosition = 0;}
				#dann war der Trigger über Tastendruck oder Motor-Bewegung
				} 
	    	elsif ($motorReading =~ /down/) { $setPosition = -1;}
			#$winState = $rawEvent if (grep(m/^closed|open|tilted/, @{$events}));
		
			Log3 $devName, 4, "$shutter setPosition: $setPosition, Age: $readingsAge; Window: $winState";
	  	
			#Unterscheidung nach Event-Art: Fahrbefehl oder stop/FK
			if (grep(m/^motor:.down/, @{$events}) || grep(m/^set_/, @{$events})){
				#Fahrbefehl über FHEM oder Tastendruck?
				#Fährt der Rolladen aufwärts, gibt es nichts zu tun...
				if ($setPosition >= $position) {
					Log3 $devName, 4, "Nothing to do, moving upwards";
					return;
				}
								  
				#Jetzt können wir nachsehen, ob der Rolladen zu weit nach unten soll
				#(Fenster offen)...
				if($setPosition < $maxPosOpen && $winState eq "open" && $windowcontact ne "none") {
					if ($position > $maxPosOpen){
						AnalyzeCommand(undef, set $shutter $maxPosOpen);
					} else {
						AnalyzeCommand(undef, set $shutter $targetPosOpen);
					}
					
					if ($setPosition == -1){
						readingsSingleUpdate($shutter, "WindowContactOnHoldState", "$onHoldState",1);
						#fhem("setreading $shutter WindowContactOnHoldState $onHoldState");
					} else {readingsSingleUpdate($shutter, "WindowContactOnHoldState", "$setPosition",1);}
				}
				#...(gekippt)...
				elsif($winState eq "tilted" && $windowcontact ne "none") {
					if($setPosition < $maxPosTilted ) { 
						if ($setPosition == -1) {
							readingsSingleUpdate($shutter, "WindowContactOnHoldState", "$onHoldState",1);
							#fhem("setreading $shutter WindowContactOnHoldState $onHoldState");
						} else {
							readingsSingleUpdate($shutter, "WindowContactOnHoldState", "$setPosition",1);
						}
						if ($position > $maxPosTilted){
							AnalyzeCommand(undef, set $shutter $maxPosTilted);
						} else {
							AnalyzeCommand(undef, set $shutter $targetPosTilted);
						}
					}
					else {readingsSingleUpdate($shutter, "WindowContactOnHoldState", "$onHoldState",1)}
				}
				#...(geschlossen) = nur ReadingsAge-update, um Selbsttriggerung zu verhindern
				elsif ($winState eq "closed") {
					readingsSingleUpdate($shutter, "WindowContactOnHoldState", "$onHoldState",1);  
				}
			}	 
			
			#stop/FH
			elsif (grep(m/^motor: stop/, @{$events}) || grep(m/^closed|open|tilted/, @{$events})){
							
				#Jetzt können wir nachsehen, ob der Rolladen zu weit unten ist (Fenster offen)...
				if($setPosition < $maxPosOpen && $winState eq "open" && $windowcontact ne "none") {
					AnalyzeCommand(undef, set $shutter $targetPosOpen);
					if($onHoldState eq "none" && $motorReading =~ /stop/) { 
						readingsSingleUpdate($shutter, "WindowContactOnHoldState", "$setPosition",1);
					}
				}
				#...(gekippt)...
				elsif($winState eq "tilted" && $windowcontact ne "none") {
					if($onHoldState ne "none") { 
						if ($maxPosTilted < $onHoldState) { 
							AnalyzeCommand(undef, set $shutter $onHoldState);
							readingsSingleUpdate($shutter, "WindowContactOnHoldState", "none",1);
						}
						else {
							if ($readingsAge < 2) {return "Most likely we are triggering ourself";}
							AnalyzeCommand(undef, set $shutter $maxPosTilted);
							readingsSingleUpdate($shutter, "WindowContactOnHoldState", "$onHoldState",1);
						}
					}	
					if ($setPosition < $maxPosTilted) {
						if ($readingsAge < 2) {return "Most likely we are triggering ourself";}
						AnalyzeCommand(undef, set $shutter $maxPosTilted);			  
						if ($onHoldState eq "none" && $motorReading =~ /stop/) {readingsSingleUpdate($shutter, "WindowContactOnHoldState", "$setPosition",1);}
						elsif ($position > $onHoldState && $motorReading =~ /stop/) {readingsSingleUpdate($shutter, "WindowContactOnHoldState", "$setPosition",1);}
					}
				}
				#...oder ob eine alte Position wegen Schließung des Fensters angefahren werden soll...
				elsif ($textEvent eq "Window" && $winState eq "closed" && $onHoldState ne "none") {
					AnalyzeCommand(undef, set $shutter $onHoldState);
					readingsSingleUpdate($shutter, "WindowContactOnHoldState", "none",1);  
				}
				#...oder ob es sich um einen Stop zum Drehen der Jalousielamellen handelt...
				elsif ($textEvent eq "Rollo") {
					if ($turnValue > 0 && $position == $turnPosOpen) {AnalyzeCommand(undef, set $shutter $maxPosOpen);}
					elsif ($turnValue > 0 && $position == $turnPosTilted) {AnalyzeCommand(undef, set $shutter $maxPosTilted);}
					#...oder die Positionsinfo wegen manueller Änderung gelöscht werden kann.
					elsif ($position != $maxPosOpen && $position != $maxPosTilted && $onHoldState ne "none") {
						readingsSingleUpdate($shutter, "WindowContactOnHoldState", "none",1);
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

sub HMshutterUtils_softPeer($$;$;$) {
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

sub HMshutterUtils_setTypeJalousie($$) {
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
