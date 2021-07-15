##############################################
# $Id: attrTmqtt2_ebus_Utils.pm 2021-07-15 Beta-User $
#

package FHEM::aTm2u_ebus;    ## no critic 'Package declaration'

use strict;
use warnings;

use GPUtils qw(GP_Import);

#-- Run before package compilation
BEGIN {

    # Import from main context
    GP_Import(
        qw(
            json2nameValue
          )
    );
}

sub ::attrTmqtt2_ebus_Utils_Initialize { goto &Initialize }
sub ::attrTmqtt2_ebus_createBarView { goto &createBarView }

# initialize ##################################################################
sub Initialize {
  my $hash = shift;
  return;
}
# Enter you functions below _this_ line.

sub j2nv {
    my $EVENT = shift // return;
    my $pre   = shift;
    my $filt  = shift;
    my $not   = shift;
    $EVENT=~ s{[{]"value":\s("[^"]+")[}]}{$1}g;
    return json2nameValue($EVENT, $pre, $filt, $not);
}

sub createBarView {
  my ($val,$maxValue,$color) = @_;
  $maxValue = $maxValue//100;
  $color = $color//"red";
  my $percent = $val / $maxValue * 100;
  # Definition des valueStyles
  my $stylestring = 'style="'.
    'width: 200px; '.
    'text-align:center; '.
    'border: 1px solid #ccc ;'. 
    "background-image: -webkit-linear-gradient(left,$color $percent".'%, rgba(0,0,0,0) '.$percent.'%); '.
    "background-image:    -moz-linear-gradient(left,$color $percent".'%, rgba(0,0,0,0) '.$percent.'%); '. 
    "background-image:     -ms-linear-gradient(left,$color $percent".'%, rgba(0,0,0,0) '.$percent.'%); '. 
    "background-image:      -o-linear-gradient(left,$color $percent".'%, rgba(0,0,0,0) '.$percent.'%); '. 
    "background-image:         linear-gradient(left,$color $percent".'%, rgba(0,0,0,0) '.$percent.'%);"';
    # Rückgabe des definierten Strings
  return $stylestring;
}

1;

__END__
=pod
=begin html

<a name="attrTmqtt2_ebus_Utils"></a>
<h3>attrTmqtt2_ebus_Utils</h3>
<ul>
  <b>Functions to support attrTemplates for ebusd</b><br> 
</ul>
<ul>
  <li><b>aTm2u_ebus::j2nv</b><br>
  <code>aTm2u_ebus::j2nv($,$$$)</code><br>
  This ist just a wrapper to fhem.pl json2nameValue() to prevent the "_value" postfix. It will first clean the first argument by applying <code>$EVENT=~ s{[{]"value":\s("[^"]+")[}]}{$1}g;</code>. 
  </li>
  <li><b>aTm2u_ebus::createBarView</b><br>
  <code>aTm2u_ebus::createBarView($,$$)</code><br>
  Parameters are 
  <ul>
    <li>$value (required)</li> 
    <li>$maxvalue (optional), defaults to 100</li> 
    <li>$color, (optional), defaults to red</li> 
  </ul>
  For compability reasons, function will also be exported as attrTmqtt2_ebus_createBarView(). Better use package version to call it... 
  </li>
</ul><br>
=end html
=cut
