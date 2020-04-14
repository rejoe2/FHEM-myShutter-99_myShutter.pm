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

sub flc_next($) {
  my $device = shift (@_);
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

1;
