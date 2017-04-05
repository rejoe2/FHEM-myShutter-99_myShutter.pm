 package main;
 use strict;
 use warnings;
 use POSIX;
 sub
 myUtils_Initialize($$)
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
        #Also erst mal so tun, als wäre es der Rolladen gewesen, der augeslöst hat:
        my $windowcontact = AttrVal($dev,'WindowContactAssociated',"none");
        my $shutter=$dev;
     
        if (!$shutter) {}
        else {       
          #Wir speichern ein paar Infos, damit das nicht zu unübersichtlich wird
          my $position = ReadingsVal($shutter,'level',0);
          my $winState = Value($windowcontact);
          my $maxPosition = AttrVal($shutter,'WindowContactOpenMaxClosed',100);
          my $maxPosTilted = AttrVal($shutter,'WindowContactOpenMaxTilted',100);
          my $onHoldState = AttrVal($shutter,'WindowContactOnHoldState',"none");
          
          #Jetzt können wir nachsehen, ob der Rolladen zu weit unten ist (offen)...
          if($position < $maxPosition && $winState eq "open" && $windowcontact ne "none") {
              fhem("set $shutter $maxPosition");
              if($onHoldState eq "none") { fhem("setreading $shutter:WindowContactOnHoldState $position");}
          }
          #...(gekippt)...
          elsif($position < $maxPosTilted && $winState eq "tilted" && $windowcontact ne "none") {
              fhem("set $shutter $maxPosTilted");
              if($onHoldState eq "none") { fhem("setreading $shutter:WindowContactOnHoldState $position");}
          }
          #...oder ob eine alte Position wegen Schließung des Fensters angefahren werden soll...
          elsif ($event eq "Window" && $winState eq "closed" && $maxPosition ne "none") {
              fhem("set $shutter $onHoldState");
              fhem("setreading $shutter:WindowContactOnHoldState none"); #changed from "attr" 
          }
          #...oder ob die Positionsinfo wegen manueller Änderung gelöscht werden kann.
          elsif ($event eq "Rollo" && $onHoldState ne "none" && $position ne $maxPosition) {
              fhem("setreading $shutter WindowContactOnHoldState none"); #changed from "attr"
          }
        }
    }
}

sub winShutterAssociate($$$) {
    #Als Parameter müssen die Namen vom Fensterkontakt und Rolladen übergeben werden sowie der Maxlevel bei Fensteröffnung
    #Call in FHEMWEB e.g.: { winShutterAssociate("Fenster_Wohnzimmer_SSW","Rolladen_WZ_SSW",10) }
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
            fhem("attr $shutter WindowContactOnHoldState 100");
            if(index($oldAttrRollo,"WindowContactOpenMaxClosed") < 0) {
                fhem("attr $shutter userattr $oldAttrRollo WindowContactOpenMaxClosed");
            }
            fhem("attr $shutter WindowContactOpenMaxClosed $maxPosition");
            if(index($oldAttrRollo,"WindowContactOpenMaxTilted") < 0) {
                fhem("attr $shutter userattr $oldAttrRollo WindowContactOpenMaxTilted");
            }
            fhem("attr $shutter WindowContactOpenMaxTilted $maxPosTilted");
            
        }
        else { return "One of the devices has wrong subtype";}
    }
    else { return "One of the devices does not exist";}
}
 
1;
 
