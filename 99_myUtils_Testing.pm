##############################################
# $Id: myUtils_Testing.pm 2019-10-30 Beta-User $
#

package main;

use strict;
use warnings;

sub
myUtils_Testing_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.

sub flc_next {
  my $device = shift // return;
  my $regxp = AttrVal($device,"myRegex",".*");
  my $myfiles = AttrVal($device,"myFiles","");
  my @files = split(' ',$myfiles);
  return undef unless (@files);
  my $file = shift (@files);
  CommandSet(undef, "$device import2DbLog $file $regxp");
  if (@files) {
    $file = join (" ",@files);
  } else {
    $file = "";
  }
  CommandAttr(undef, "$device myFiles $file");
}

sub myASC_slat_command {
  my $target = shift // return;
  my $slatlevel = shift // return;

  my $type = InternalVal($target,'TYPE','');
  return if !$type;

  my $dispatch = {
    CUL_HM => \&myASC_slat_CUL_HM,
  };
  ref $dispatch->{$type} eq 'CODE' 
  ?   $dispatch->{$type}->($target, $slatlevel)
  : Log3($target, 3, "$target: No dispatch routine for setting slats to >$type< available");
}
 
sub myASC_slat_CUL_HM {
  my $target = shift // return;
  my $slatlevel = shift // return;
  
  my $target_pct = ReadingsNum($target,'state',100);
  my $direction = ReadingsNum($target,'pct',100) < $target_pct ? "up" : "down";
  #get the difference in pct rounded to .5 values
  $slatlevel = $direction eq "up" ? 100 - $slatlevel : $slatlevel; 
  my $turn_pct = int(AttrVal($target,"myASC_Turn_Pct",2.3)*$slatlevel/50)/2;
  my $intermediate = $direction eq "up" ? $target_pct + $turn_pct : $target_pct - $turn_pct ;
  my $sleepname = qq(myASC_slat_$target) ;
  CommandSet(undef, "$target pct $intermediate");
  CommandDefMod(undef,"-temporary $sleepname notify $target.motor..stop.$intermediate set $target pct $target_pct");
  $attr{$sleepname}{ignore} = 1;
  #Log3($target, 3, "$target (CUL_HM): slat $slatlevel, start $start_pct, target $target_pct, dir $direction");

}


1;
