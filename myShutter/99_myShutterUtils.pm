 package main;
 use strict;
 use warnings;
 use POSIX;
 sub
 myShutterUtils_Initialize($$)
 {
   my ($hash) = @_;
 }

sub winOpenShutterTester($$) {
    #Als Parameter muss der device-Name übergeben werden
    #notify-Definitionen:
    #defmod n_Rolladen_Window notify .*(closed|open|tilted)..to.VCCU. { winOpenShutterTester(AttrVal($NAME,'ShutterAssociated','none'), "Window") }
    #defmod n_Rolladen_Stop notify .*:motor:.stop.* { winOpenShutterTester($NAME, "Rollo")}
    #Hint for window contacts: make sure to modify settings of device wrt. some delay in sending state changes to avoid unnecessary triggers
    my ($dev, $event) = @_;
 
    #Erst mal prüfen, ob das übergebene device überhaupt existiert
    if ($defs{$dev}) {
 
        #Als erstes brauchen wir die Info, welcher Rolladen bzw. welcher Fenster- bzw. Türkontakt
        #betroffen sind
        my $windowcontact = AttrVal($dev,'WindowContactAssociated',"none");
        my $shutter=$dev;
     
        if (!$shutter) {}
        else {       
          #Wir speichern ein paar Infos, damit das nicht zu unübersichtlich wird
          my $position = ReadingsVal($shutter,'level',0);
          my $winState = Value($windowcontact);
          my $maxPosOpen = AttrVal($shutter,'WindowContactOpenMaxClosed',100)+0.5;
          my $maxPosTilted = AttrVal($shutter,'WindowContactTiltedMaxClosed',100)+0.5;
		  my $turnValue = ReadingsVal($shutter,'JalousieTurnValue',0);
		  my $onHoldState = ReadingsVal($shutter,'WindowContactOnHoldState',"none");
          my $turnPosOpen = $maxPosOpen+$turnValue;
		  my $turnPosTilted = $maxPosTilted+$turnValue;
		  my $targetPosOpen = $maxPosOpen+$turnValue;
          my $targetPosTilted = $maxPosTilted+$turnValue;
		  
          #Jetzt können wir nachsehen, ob der Rolladen zu weit unten ist (Fenster offen)...
          if($position < $maxPosOpen && $winState eq "open" && $windowcontact ne "none") {
		      fhem("set $shutter $targetPosOpen");
              if($onHoldState eq "none") { fhem("setreading $shutter WindowContactOnHoldState $position");}
          }
          #...(gekippt)...
          elsif($winState eq "tilted" && $windowcontact ne "none") {
              if($position < $maxPosTilted && $onHoldState eq "none") { fhem("setreading $shutter WindowContactOnHoldState $position");}
			  elsif ($maxPosTilted < $onHoldState) { $maxPosTilted = $onHoldState; }
			  fhem("set $shutter $maxPosTilted");
          }
          #...oder ob eine alte Position wegen Schließung des Fensters angefahren werden soll...
          elsif ($event eq "Window" && $winState eq "closed" && $onHoldState ne "none") {
              fhem("set $shutter $onHoldState");
              fhem("setreading $shutter WindowContactOnHoldState none");  
          }
          #...oder ob es sich um einen Stop zum Drehen der Jalousielamellen handelt...
		  elsif ($event eq "Rollo") {
		  	if ($turnValue > 0 && $position == $turnPosOpen) {fhem("set $shutter $maxPosOpen");}
		  	elsif ($turnValue > 0 && $position == $turnPosTilted) {fhem("set $shutter $maxPosTilted");}
		  #...oder die Positionsinfo wegen manueller Änderung gelöscht werden kann.
		    elsif ($position != $maxPosOpen && $position != $maxPosTilted && $onHoldState ne "none") {
              fhem("setreading $shutter WindowContactOnHoldState none"); 
            }
		  }
        }
    }
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
            fhem("attr $shutter WindowContactOnHoldState none");
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
 
