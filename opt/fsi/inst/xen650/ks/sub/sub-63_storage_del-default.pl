#!/usr/bin/perl -w
# 
#   sub-63_storage-del-default.pl - del storage repositories
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
our $ver = "1.0.4 - 9.9.2016";
my $retc = 0;
my $vrun = 0;                                                                                   # virtual run => 1 means no xe commands, 0 means xe commands


use strict;
use warnings;
use FindBin qw($Bin);
my $fsidir="/var/fsi";
use lib "/var/fsi/module";
use Config::General;
use English;

our $flvl = 0;                                                                                   # function level

open my $file, '<', "/etc/redhat-release"; 
my $redhatrel = <$file>; 
close $file;
my ($xenmain) = $redhatrel =~ /(\d+)/;   
my $xencfg = "xen$xenmain";

my $logconf = "$fsidir/log.cfg";
my $logfile = "$fsidir/fsixeninst.log";
my $conffile = "$fsidir/$xencfg.ext";
my $poolfile = "$fsidir/$xencfg.pool";
my $confxen = "$fsidir/$xencfg.conf";
my $pool= "none";
my %cfg;

use Sys::Hostname;

use File::Spec; 
use File::Basename;
my $rel_path = File::Spec->rel2abs( __FILE__ );
my ($volume,$dirs,$prg) = File::Spec->splitpath( $rel_path );
my $prgname = basename($prg, '.pl');

use Log::Log4perl qw(:no_extra_logdie_message);
unless (-e $logconf) {
   print "\n ERROR: cannot find config file for logs $logconf !\n\n";
   exit(101);
}
sub get_log_fn { return  $logfile };

Log::Log4perl->init( $logconf );
our $logger = Log::Log4perl::get_logger();

$logger->info("Starting $prg - v.$ver");

# functions
our $frc  = 0;                                                                                                                      # global function return code for cmdget
require "/usr/bin/fsifunc.pl";  # global perl routine

sub delete_sr {
   my $fc=(caller(0))[3];
   $flvl++;
   my $ll=" " x $flvl;

   $logger->trace("$ll func start: [$fc]");   

   my $srdel=shift();
   my $host=hostname();
   my $sruuid;
   my $hostuuid;
   my $pbduuid;
   
   unless ( $retc ) {
      $sruuid=cmdget("xe sr-list host=$host name-label=\"$srdel\" --minimal");
      if ( $sruuid ne "" ) {
         $logger->debug("$ll sruuid: $sruuid");
      } else {
         $logger->error("$ll cannot get sr uuid - abort");
         $retc=99;
      }
   }
   
   unless ( $retc ) {
      $hostuuid=cmdget("xe host-list name-label=$host --minimal");
      if ( $hostuuid ne "" ) {
         $logger->debug("$ll hostuuid: $hostuuid");
      } else {
         $logger->error("$ll cannot get host uuid - abort");
         $retc=99;
      }
   }
   
   unless ( $retc ) {
      $pbduuid=cmdget("xe pbd-list host-uuid=$hostuuid sr-uuid=$sruuid --minimal");
      if ( $hostuuid ne "" ) {
         $logger->debug("$ll pbduuid: $hostuuid");
      } else {
         $logger->error("$ll cannot get pbd uuid - abort");
         $retc=99;
      }
   }
   
   unless ( $retc ) {
      $retc=cmdset("xe pbd-unplug uuid=$pbduuid");
      if ( $retc) {
         $logger->error("cannot unplug pbd ");
      }
   } 

   unless ( $retc ) {
      $retc=cmdset("xe pbd-destroy uuid=$pbduuid");
      if ( $retc) {
         $logger->error("cannot destroy pbd");
      }
   }

   unless ( $retc ) {
      $retc=cmdset("xe sr-forget uuid=$sruuid");
      if ( $retc) {
         $logger->error("cannot remove / forget sr");
      }
   }

   $logger->trace("$ll func end: [$fc] rc: [$retc]");   
   $flvl--;
   return($retc);
}


sub del_sr {
   my $fc=(caller(0))[3];
   $flvl++;
   my $ll=" " x $flvl;

   $logger->trace("$ll func start: [$fc]");   

   my $conffile=shift();
   my $mode=shift();
   my $retc=0;
   
   
   my $sr;
   my $conf;
   my %config;
   
   if ( $conffile ne "" ) {
      $logger->debug("$ll check if config file exist");
      if ( -e $conffile ) {
         $logger->info("$ll found $conffile");
         $logger->trace("$ll get all config from $conffile");
         $conf = new Config::General("$conffile");
         $logger->debug("$ll Get all xenserver configurations ...");
         %config = $conf->getall;   

         foreach $sr (keys %{$config{'srdel'}}) {
            $logger->debug("$ll ===> sr to del found: [$sr]");
            if ( defined $config{'srdel'}{$sr}{'sr'} ) {                                 # sr given ?
               my $srdel=$config{'srdel'}{$sr}{'sr'};
               $logger->trace("$ll sr to del: $srdel");
               my $srexist;
               my $command="xe sr-list host=\$HOSTNAME name-label=\"$srdel\" --minimal";
               if ( $vrun ) {
                  $logger->warn("$ll vrun mode");
                  $logger->trace("$ll $command");
                  $srexist="0ds9fa0sd9f8a0df98asd0f";
               } else {
                  $srexist=cmdget($command);
               }
               if ( $srexist ne "" ) {
                  if ( $mode eq "del" ) {
                     $logger->info("$ll try to delete $srdel");
                     $retc=delete_sr($srdel);
                  } else {
                     $logger->info("$ll $srdel must be delete");
                  }
               } else {
                  $logger->info("$ll $srdel does not exist");
               }
            } else {
               $logger->warn("$ll found sr to del, but no sr name defined");
            }
         } # foreach $sr
      } else {
         $logger->error("cannot find config file $conffile");
         $retc=99;
      }
   } else {
      $logger->error("no config file given - abort");
      $retc=99;
   }
   
   $logger->trace("$ll func end: [$fc] rc: [$retc]");   
   $flvl--;
   return($retc);
}

# main
my $counter = 0;
my $mode="none";
my $usage = "\nPrograme: $prg \nVersion: $ver\nDescript.: delete sr\n\nparameter: --mode [del/check]\n\n";
if ($#ARGV eq '-1') {print $usage; exit;}

my @ARGS = @ARGV; 
my $numargv = @ARGS;

for ($counter = 0; $counter < $numargv; $counter++) {
    $logger->debug(" Argument: $ARGS[$counter]");
    if ($ARGS[$counter] =~ /^-h$/i) {                
       print $usage; 
       exit(0);
    }
    elsif ($ARGS[$counter] eq "") {                  
        ## Do nothing
    }
    elsif ($ARGS[$counter] =~ /^--help/) {           
       print $usage; 
       exit(0);
    }
    elsif ($ARGS[$counter] =~ /^--mode$/) {           
        $counter++;
        if ($ARGS[$counter] && $ARGS[$counter] !~ /^-/) {
            $mode = $ARGS[$counter];
            chomp($mode);
            $mode =~ s/\n|\r//g;
        } else { 
           $logger->error("The argument after --mode was not correct - ignore!"); 
           $counter--; 
        }
    }
    else {
       $logger->warn(" Unknown option [$ARGS[$counter]]- ignore");
    }
}

$logger->info(" Mode: $mode");
if ( $mode ne "none") {
   $retc=read_config($confxen,\%cfg);
} else {
   $logger->error("no mode set - abort");
   $retc=100;
}

unless ( $retc ) {
   if ( $mode eq "del" || $mode eq "check" ) {
     $retc=del_sr($poolfile, $mode);
     
     unless ( $retc ) {
         $retc=del_sr($conffile, $mode);
     }
   
   } else {
      $logger->warn(" unknown mode [$mode]");
   }
}

unless ( $retc ) {
   $logger->info(" all storage repositories successful delete");
} else {
   if ( $retc == 1 ) {
      $logger->error("something wrong - rc=1 means reboot, change this");
      $retc=77;
   } else {
      $logger->error("something wrong - see log file for more detailed errors");
   }
}

$logger->debug("retc= $retc");
$logger->info("End $prg - v.$ver rc=$retc");
exit ($retc);

__END__

