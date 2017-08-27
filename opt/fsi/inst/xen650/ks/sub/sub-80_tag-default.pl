#!/usr/bin/perl -w
# 
#   sub-80_tag-default.pl - tag different things
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
our $ver = "1.0.6 - 9.9.2016";
my $retc = 0;
my $vrun = 0;                                                                                   # virtual run => 1 means no xe commands, 0 means xe commands
my $ll = " ";

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
my $poolfile = "$fsidir/$xencfg.pool";
my $conffile = "$fsidir/$xencfg.ext";

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

use Sys::Hostname;

$logger->info("Starting $prg - v.$ver");


# functions
our $frc  = 0;                                                                                                                      # global function return code for cmdget
require "/usr/bin/fsifunc.pl";  # global perl routine


sub do_tag {
   my $fc=(caller(0))[3];
   $flvl++;
   my $ll=" " x $flvl;
   my $retc=0;

   $logger->trace("$ll func start: [$fc]");   

   my $typ=shift();
   my $uuid=shift();
   my $do=shift();
   my $key=shift();

   if ( $uuid eq "" ) {
      $logger->error("empty uuid");
      $retc=99;
   }
   if ( $typ eq "" ) {
      $logger->error("empty typ");
      $retc=99;
   }
   if ( $do eq "" ) {
      $logger->error("empty doing");
      $retc=99;
   }
   if ( $key eq "" ) {
      $logger->error("empty key");
      $retc=99;
   }

   unless ( $retc ) {
      my $param=$typ . "-param-" . $do;

      $logger->debug("$ll $do tag $key ...");
      if ( $vrun ) {
         $logger->warn("$ll vrun mode");
         $logger->trace("$ll xe $param uuid=$uuid param-name=tags param-key=\"$key\"");
         $retc=0;
      } else {
         $retc=cmdset("xe $param uuid=$uuid param-name=tags param-key=\"$key\"");
      }
   }


   $logger->trace("$ll func end: [$fc] rc: [$retc]");   
   $flvl--;
   return($retc);
}

sub do_oc {
   my $fc=(caller(0))[3];
   $flvl++;
   my $ll=" " x $flvl;
   my $retc=0;

   $logger->trace("$ll func start: [$fc]");   

   my $typ=shift();
   my $uuid=shift();
   my $do=shift();
   my $key=shift();
   my $oc=shift();

   if ( $uuid eq "" ) {
      $logger->error("empty uuid");
      $retc=99;
   }
   if ( $typ eq "" ) {
      $logger->error("empty typ");
      $retc=99;
   }
   if ( $do eq "" ) {
      $logger->error("empty doing");
      $retc=99;
   }
   if ( $key eq "" ) {
      $logger->error("empty key");
      $retc=99;
   }
   if ( $oc eq "" ) {
      $logger->error("empty other config");
      $retc=99;
   }

   unless ( $retc ) {
      my $param=$typ . "-param-" . $do;

      $logger->debug("$ll $do other config $oc of $key");
      if ( $vrun ) {
         $logger->warn("$ll vrun mode");
         $logger->trace("$ll xe $param uuid=$uuid other-config:$oc=\"$key\"");
         $retc=0;
      } else {
         $retc=cmdset("xe $param uuid=$uuid other-config:$oc=\"$key\"");
      }
   }

   $logger->trace("$ll func end: [$fc] rc: [$retc]");   
   $flvl--;
   return($retc);
}


sub create_tags {
   my $fc=(caller(0))[3];
   $flvl++;
   my $ll=" " x $flvl;

   $logger->trace("$ll func start: [$fc]");   

   my $conffile=shift();

   $logger->info(" search tags");
   
   my $conf;
   my %config;
   my $tag;
   my $host=hostname();
   my $uuid="none";
   
   if ( $conffile ne "" ) {
      $logger->debug("$ll check if config file exist");
      if ( -e $conffile ) {
         $logger->info("$ll found $conffile");
         $logger->trace("$ll get all config from $conffile");
         $conf = new Config::General("$conffile");
         $logger->debug("$ll Get all xenserver configurations ...");
         %config = $conf->getall;
   
         foreach $tag (keys %{$config{'tag'}} ) {
            $logger->info("$ll ==> found tag config $tag");
            my $typ="none";
            if ( defined $config{'tag'}{$tag}{'typ'} ) {
               $typ=$config{'tag'}{$tag}{'typ'};
               $logger->trace("$ll typ: $typ");
            } else {
               $logger->error("no typ define");
               $retc=87;
            }
   
            my $to="none";
            if ( $typ ne "none" ) {
               if ( ( $typ eq "sr" ) || ( $typ eq "network" ) ) {
                  if ( defined $config{'tag'}{$tag}{'to'} ) {
                     $to=$config{'tag'}{$tag}{'to'};
                     $logger->trace("$ll to: $to");
                  } else {
                     $logger->error("typ storage/net but no to - abort");
                     $retc=88;
                     last;
                  }
                  unless ( $retc ) {
                     if ( $typ eq "sr" ) {
                        $logger->trace("$ll get uuid from sr ...");
                        if ( $vrun ) {
                           $logger->warn("$ll vrun mode");
                           $logger->trace("$ll xe sr-list name-label=\"$to\" --minimal");
                           $uuid = "kdfasdkfjasdfkj";
                        } else {
                           $uuid=cmdget("xe sr-list name-label=\"$to\" --minimal");
                        }
                        if ( $uuid ) {
                           $logger->debug("$ll uuid: [$uuid]");
                        } else {
                           $logger->error("cannot detect uuid from [$to] - abort");
                           $retc=45;
                           last;
                        }
                     } else {
                        $logger->trace("$ll get uuid from net ...");
                        if ( $vrun ) {
                           $logger->warn("$ll vrun mode");
                           $logger->trace("$ll xe network-list name-label=\"$to\" --minimal");
                           $uuid = "kdfasd123123213kj";
                        } else {
                           $uuid=cmdget("xe network-list name-label=\"$to\" --minimal");
                        }
                        if ( $uuid ) {
                           $logger->debug("$ll uuid: [$uuid]");
                        } else {
                           $logger->error("cannot detect uuid from [$to] - abort");
                           $retc=45;
                           last;
                        }
                     }
                  }
               } elsif ( $typ eq "host" ) { 
                  $logger->debug("$ll get host uuid ...");
                  if ( $vrun ) {
                     $logger->warn("$ll vrun mode");
                     $logger->trace("$ll xe host-list name-label=$host --minimal");
                     $uuid = "kdfasd123123213kj";
                  } else {
                     $uuid=cmdget("xe host-list name-label=$host --minimal");
                  }
                  if ( $uuid ) {
                     $logger->debug("$ll uuid: [$uuid]");
                  } else {
                     $logger->error("cannot detect uuid from [$host] - abort");
                     $retc=44;
                     last;
                  }
   
               } else {
                  $logger->error("unknown typ - abort");
                  $retc=45;
                  last;
               }
            } else {
               $logger->error("no typ found - abort");
               $retc=87;
               last;
            }
   
            my $do="none";
            if ( defined $config{'tag'}{$tag}{'do'} ) {
               $do=$config{'tag'}{$tag}{'do'};
               $logger->trace("$ll do: $do");
            } else {
               $logger->error("no do define");
               $retc=89;
            }
   
            my $key="none";
            if ( defined $config{'tag'}{$tag}{'key'} ) {
               $key=$config{'tag'}{$tag}{'key'};
               $logger->trace("$ll key: $key");
            } else {
               $logger->error("no key define");
               $retc=84;
            }
   
            my $oc="none";
            if ( defined $config{'tag'}{$tag}{'oc'} ) {
               $oc=$config{'tag'}{$tag}{'oc'};
               $logger->trace("$ll oc: $oc");
            } 
   
            unless ( $retc ) {
               if ( $uuid ne "none" ) {
                  $logger->trace("$ll ==> typ: $typ");
                  $logger->trace("$ll ==> do: $do");
                  $logger->trace("$ll ==> uuid: $uuid");
                  $logger->trace("$ll ==> key: $key");
                  if ( $oc eq "none" ) {
                     $logger->info("$ll call tag set ...");
                     $retc=do_tag($typ, $uuid, $do, $key);
                     if ( $retc ) {
                        $logger->error("something wrong do tag - rc=$retc");
                        last;
                     }
                  } else {
                     $logger->trace("$ll ==> oc: $oc");
                     $logger->info("$ll call other-config set ...");
                     $retc=do_oc($typ, $uuid, $do, $key, $oc);
                     if ( $retc ) {
                        $logger->error("something wrong do tag - rc=$retc");
                        last;
                     }
                  }
               }
            }
         }
      } else {
         $logger->error("no config file $conffile found - abort");
         $retc=88;
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
my $usage = "\nPrograme: $prg \nVersion: $ver\nDescript.: tag configure\n\nparameter: --mode [member/master/standalone]\n\n";
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
   if ( $mode eq "master" ) {
      if ( -e $poolfile ) {
         $logger->info(" Work on pool config ...");
         $retc=create_tags($poolfile);
      } else {
         $logger->error("master mode, but no pool config - something wrong - abort");
         $retc=99;
      }
   } else {
      $logger->info(" member need no pool config");
   }
   
   unless ( $retc ) {
      if ( $mode eq "master" || $mode eq "standalone" || $mode eq "member" ) {
         if ( -e $conffile ) {
            $logger->info(" Work on xenserver config ...");
            $retc=create_tags($conffile);
         } else {
            $logger->error("No network config exist - what happens here ?");
            $retc=99;
         }
      } else {
         $logger->error("unknown mode - abort");
         $retc=100;
      }
   }
} else {
   $logger->error("no mode set - abort");
   $retc=100;
}

unless ( $retc ) {
   $logger->info(" all tags successful processed");
} else {
   $logger->error("something wrong - see log file for more detailed errors");
}

$logger->info("End $prg - v.$ver rc=$retc");
exit ($retc);


__END__

