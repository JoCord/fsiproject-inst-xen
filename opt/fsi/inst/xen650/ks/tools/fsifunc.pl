#
#   sub-func - global function file
#
#   This program is free software; you can redistribute it and/or modify it under the
#   terms of the GNU General Public License as published by the Free Software Foundation;
#   either version 3 of the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
#   without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#   See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License along with this program;
#   if not, see <http://www.gnu.org/licenses/>.
#
#   1.010 - 17.10.2016
#

our %color = (
               "green"  => "\033[32;1m",
               "red"    => "\033[31;1m",
               "cyan"   => "\033[36;1m",
               "white"  => "\033[37;1m",
               "normal" => "\033[m",
               "bold"   => "\033[1m",
               "nobold" => "\033[0m",
               );


sub TimeStamp {
   my ($format) = $_[ 0 ];
   my ($rettime);
   ( my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst ) = localtime();
   $year = $year + 1900;
   $mon  = $mon + 1;
   if ( length($mon) == 1 )  { $mon     = "0$mon"; }
   if ( length($mday) == 1 ) { $mday    = "0$mday"; }
   if ( length($hour) == 1 ) { $hour    = "0$hour"; }
   if ( length($min) == 1 )  { $min     = "0$min"; }
   if ( length($sec) == 1 )  { $sec     = "0$sec"; }
   if ( $format == 1 )       { $rettime = "$year\-$mon\-$mday $hour\:$min\:$sec"; }
   if ( $format == 2 )       { $rettime = $mon . $mday . $year; }
   if ( $format == 3 ) { $rettime = substr( $year, 2, 2 ) . $mon . $mday; }
   if ( $format == 4 ) { $rettime = $mon . $mday . substr( $year, 2, 2 ); }
   if ( $format == 5 ) { $rettime = $year . $mon . $mday . $hour . $min . $sec; }
   if ( $format == 6 ) { $rettime = $year . $mon . $mday; }
   if ( $format == 7 ) { $rettime = $mday . '/' . $mon . '/' . $year . ' ' . $hour . ':' . $min . ':' . $sec; }
   if ( $format == 8 ) { $rettime = $year . $mon . $mday . $hour . $min; }
   if ( $format == 9 ) { $rettime = $mday . '/' . $mon . '/' . $year; }
   if ( $format == 10 ) { $rettime = "$hour\:$min\:$sec"; }
   return $rettime;
} ## end sub TimeStamp


our $camel      = "\N{U+1F42A}";
our $camelcount = 0;

sub camel {
   $| = 1;
   if ( $camelcount == 0 ) {
      print("\010");                                                                                                               # backspace
      print "$camel";
      $camelcount = 1;
   } elsif ( $camelcount == 1 ) {
      print("\010");                                                                                                               # backspace
      print " ";
      $camelcount = 0;
   } else {
      print "\\\b";
      $camelcount = 0;
   }
   $| = 0;
} ## end sub camel


sub stackon {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $counter    = 2000;
   my $waitsec    = 2;
   my $nochmal    = 0;
   my $retc       = 0;
   my $xapicookie = "/var/run/xapi_init_complete.cookie";                                                                          # xapi toolstack init flag file

   unless ( -f $xapicookie ) {
      use utf8;
      binmode STDOUT, ":utf8";

      $logger->trace("$ll   check if xapi toolstack online");
      system("setterm -cursor off");
      print TimeStamp('10') . " INFO   :    Waiting for toolstack: $camel";

      do {
         if ( -f $xapicookie ) {
            $logger->trace("$ll  xapi online");
            print("\010");                                                                                                         # backspace
            print "ok\n";
            $nochmal = 0;
         } else {
            camel();
            if ( $nochmal < $counter ) {
               $nochmal++;
               camel();
               $logger->trace("$ll   wait $waitsec seconds for toolstack init complete");
               sleep($waitsec);
            } else {
               print("\010");                                                                                                      # backspace
               print "failed\n";
               $logger->error("to many retries to get toolstack online ...");
               $retc    = 88;
               $nochmal = 0;
            } ## end else [ if ( $nochmal < $counter ) ]
         } ## end else [ if ( -f $xapicookie ) ]
      } while $nochmal;

      system("setterm -cursor on");
   } ## end unless ( -f $xapicookie )

   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub stackon


sub stackon_old {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $counter    = 200;
   my $waitsec    = 5;
   my $nochmal    = 0;
   my $retc       = 0;
   my $xapicookie = "/var/run/xapi_init_complete.cookie";                                                                          # xapi toolstack init flag file

   do {
      if ( -f $xapicookie ) {
         $logger->trace("$ll  xapi online");
         $nochmal = 0;
      } else {
         $logger->trace("$ll   xapi toolstack not online - wait for init end");
         if ( $nochmal < $counter ) {
            $nochmal++;
            $logger->trace("$ll   wait $waitsec seconds for toolstack init complete");
            sleep($waitsec);
         } else {
            $logger->error("to many retries to get toolstack online ...");
            $retc    = 88;
            $nochmal = 0;
         }
      } ## end else [ if ( -f $xapicookie ) ]
   } while $nochmal;

   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub stackon_old

sub cmdset {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc    = 0;
   my $command = shift();
   $logger->trace("$ll  cmd: [$command]");
   if ( substr( $command, 0, 2 ) eq "xe" ) {
      $logger->trace("$ll   xe command - check if xapi online");
      $retc = stackon();
   } elsif ( substr( $command, 0, 4 ) eq "ssh " ) {
      if ( $command =~ /xe / ) {
         $logger->trace("$ll   remote ssh xe command");
      } else {
         $logger->trace("$ll   remote ssh normal command - no xe");
      }
   } else {
      $logger->trace("$ll   no xe command");
   }
   my $eo;
   $logger->trace("$ll   cmd: $command");
   unless ($retc) {
      $eo = qx($command  2>&1);
      $eo =~ s/^\s+//;
      $eo =~ s/\s+$//;
      $eo =~ s/\n//;
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
   } ## end unless ($retc)
   $logger->trace("$ll   [$eo]");
   unless ($retc) {
      $logger->trace("$ll  ok");
   } else {
      if ( $eo ne "" ) {
         $logger->error("$ll  rc=$retc / output: [$eo]");
      } else {
         $logger->error("$ll  rc=$retc / empty output");
      }
   } ## end else
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub cmdset

sub cmdget {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc    = 0;
   my $command = shift();
   $logger->trace("$ll  cmd: [$command]");
   if ( substr( $command, 0, 2 ) eq "xe" ) {
      $logger->trace("$ll   xe command - check if xapi online");
      $retc = stackon();
   } elsif ( substr( $command, 0, 4 ) eq "ssh " ) {
      if ( $command =~ /xe / ) {
         $logger->trace("$ll   remote ssh xe command");
      } else {
         $logger->trace("$ll   remote ssh normal command - no xe");
      }
   } else {
      $logger->trace("$ll   no xe command");
   }
   my $eo;
   unless ($retc) {
      $eo   = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
   }
   unless ($retc) {
      $logger->trace("$ll  ok");
      $eo =~ s/^\s+//;
      $eo =~ s/\s+$//;
      $eo =~ s/\n//;
      if ( $eo ne "" ) {
         $logger->trace("$ll  [$eo]");
      } else {
         $logger->trace("$ll  empty return");
      }
   } else {
      $logger->debug("$ll  failed cmd [$eo]");
      if ( "$eo" eq "" ) {
         $logger->debug("$ll  no return string - add fsi error return message");
         $eo = "fsi error in cdmget without output";
      }
   } ## end else
   $frc = $retc;
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($eo);
} ## end sub cmdget

sub read_config {                                                                                                                  # $retc=read_config($cfgfile,\%g_cfg);
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   my ( $configfile, $config_ref ) = @_;
   $logger->debug("$ll find config file [$configfile]");
   if ( -e $configfile ) {
      $logger->debug("$ll found config file - try to open ..");
      open CONFIG, "$configfile" or $retc = 99;
      if ($retc) {
         $logger->error("cannot open config file [$configfile]");
      } else {
         $logger->debug("$ll open ok");
      }
   } else {
      $logger->error("cannot find config file [$configfile]");
      $retc = 88;
   }
   unless ($retc) {
      $logger->debug("$ll Read config file ..");
      while (<CONFIG>) {
         chomp;                                                                                                                    # no newline
         s/#.*//;                                                                                                                  # no comments
         s/^\s+//;                                                                                                                 # no leading white
         s/\s+$//;                                                                                                                 # no trailing white
         next unless length;                                                                                                       # anything left?
         my ( $var, $value ) = split( /\s*=\s*/, $_, 2 );
         if ( defined($value) ) {
            $value =~ s/^'//;                                                                                                      # remove starting '
            $value =~ s/'$//;                                                                                                      # remove ending '
            $value =~ s/^"//;                                                                                                      # remove starting "
            $value =~ s/"$//;                                                                                                      # remove ending "
            ${$config_ref}{$var} = $value;
            $logger->trace("$ll  ==> key: [$var] = [$value]");
         } else {
            $logger->trace("$ll  var: [$var] without value");
         }
      } ## end while (<CONFIG>)
      $logger->debug("$ll all read");
      $logger->debug("$ll close config file");
      close CONFIG;
   } ## end unless ($retc)
                                                                                                                                   #print Dumper( \$config_ref );
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub read_config


return 1;
