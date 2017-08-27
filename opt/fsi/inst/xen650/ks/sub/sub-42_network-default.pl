#!/usr/bin/perl -w
#
#   sub-42_network-default.pl - network config
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
our $ver = "1.1.13 - 9.9.2016";
my $retc = 0;
my $vrun = 0;                                                                                                                      # virtual run => 1 means no xe commands, 0 means xe commands
use strict;
use warnings;
use FindBin qw($Bin);
my $fsidir = "/var/fsi";
use lib "/var/fsi/module";
use Config::General;
use English;
use UUID::Tiny;
our $flvl = 0;                                                                                                                     # function level

open my $file, '<', "/etc/redhat-release"; 
my $redhatrel = <$file>; 
close $file;
my ($xenmain) = $redhatrel =~ /(\d+)/;   
my $xencfg = "xen$xenmain";

my $logconf   = "$fsidir/log.cfg";
my $logfile   = "$fsidir/fsixeninst.log";
my $conffile  = "$fsidir/$xencfg.ext";
my $poolfile  = "$fsidir/$xencfg.pool";
my $foundmgmt = 0;                                                                                                                 # mgmt zuerst

use File::Spec;
use File::Basename;
my $rel_path = File::Spec->rel2abs(__FILE__);
my ( $volume, $dirs, $prg ) = File::Spec->splitpath($rel_path);
my $prgname = basename( $prg, '.pl' );
use Log::Log4perl qw(:no_extra_logdie_message);

unless ( -e $logconf ) {
   print "\n ERROR: cannot find config file for logs $logconf !\n\n";
   exit(101);
}
sub get_log_fn { return $logfile }
Log::Log4perl->init($logconf);
our $logger = Log::Log4perl::get_logger();
$logger->info("Starting $prg - v. $ver");

# functions
our $frc = 0;                                                                                                                      # global function return code for cmdget
require "/usr/bin/fsifunc.pl";                                                                                                      # global perl routine

sub conf_dnssearch {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc      = 0;
   my $dnssearch = shift();
   my $net       = shift();
   $logger->debug("$ll  test if dns search setting present");

   if ( $dnssearch ne "" ) {
      $dnssearch =~ s/\s*//g;                                                                                                      # ca - reg to eliminate space
      $logger->info("$ll  dns search configure: $dnssearch");
      my $uuid = xe_piflist("network-name-label=\"$net\"");
      if ( $uuid ne "" ) {
         $logger->trace("$ll  uuid net: $uuid");
         if ($vrun) {
            $logger->warn("$ll vrun mode");
            $logger->trace("$ll xe pif-param-set uuid=$uuid other-config:domain=$dnssearch");
         } else {
            $logger->debug("$ll Set dns search");
            $retc = cmdset("xe pif-param-set uuid=\"$uuid\" other-config:domain=$dnssearch");
         }
      } else {
         $logger->error("cannot detect uuid for $net");
         $retc = 99;
      }
   } else {
      $logger->error("empty parameter to set dns search - abort");
      $retc = 99;
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub conf_dnssearch

sub conf_mtu {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $mtu  = shift();
   my $net  = shift();
   $logger->info("$ll  mtu size configure: $mtu");
   my $uuid = xe_netlist("name-label=\"$net\"");

   if ( $uuid ne "" ) {
      $logger->trace("$ll  uuid net: $uuid");
      my $mtucmd = "xe network-param-set uuid=$uuid MTU=$mtu";
      $logger->trace("$ll  cmd: $mtucmd");
      $retc = cmdset($mtucmd);
      if ($retc) {
         $logger->error("cannot reconfigure mtu - rc=$retc");
      } else {
         $logger->info("$ll set mtu on $net to $mtu");
      }
   } else {
      $logger->error("cannot detect uuid for $net");
      $retc = 99;
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub conf_mtu

sub conf_netdescr {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc  = 0;
   my $net   = shift();
   my $descr = shift();
   $logger->trace("$ll   network: $net");
   $logger->trace("$ll   descr.: $descr");
   my $commando = "xe network-param-set uuid=\$(xe network-list name-label=\"$net\" --minimal) name-description=\"$descr\" ";
   $logger->trace("$ll   cmd: $commando");
   $logger->debug("$ll set description on net now ...");
   $retc = cmdset($commando);

   if ($retc) {
      $logger->error("cannot config network description on $net - rc=$retc");
   } else {
      $logger->debug("$ll set description");
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub conf_netdescr

sub conf_nic {                                                                                                                     # configure speed and duplex
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $nic    = shift();
   my $speed  = shift();
   my $duplex = shift();
   my $retc   = 0;
   $logger->trace("$ll  get uuid from nic");
   my $uuidnic = xe_piflist("device=$nic physical=true");

   if ( $uuidnic ne "" ) {
      $logger->debug("$ll uuid: $uuidnic");
   } else {
      $logger->error("something wrong in get uuid from $nic - abort");
      $retc = 99;
   }
   unless ($retc) {
      $logger->info("$ll  set nic $nic to $speed / $duplex");
      my $niccmd = "xe pif-param-set uuid=$uuidnic other-config:ethtool-autoneg=\"off\" other-config:ethtool-speed=\"$speed\" other-config:ethtool-duplex=\"$duplex\"";
      $retc = cmdset($niccmd);
      if ($retc) {
         $logger->error("cannot reconfigure nic speed/duplex - rc=$retc");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub conf_nic

sub conf_nicnet {                                                                                                                  # configure network label to nic
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $net = shift();                                                                                                              # network label
   $logger->trace("$ll net: [$net]");
   my $nic = shift();                                                                                                              # nic
   $logger->trace("$ll nic: [$nic]");
   my $retc = 0;
   $logger->info("$ll Configure nic [$nic] to net [$net]");
   my $netuuid = cmdget("xe pif-list host-name-label=\$HOSTNAME device=$nic | grep -i network-uuid | awk '{print \$4}'");
   $logger->trace("$ll frc: $frc");

   if ( $netuuid ne "" ) {
      $logger->trace("$ll  uuid: $netuuid");
      my $niccmd = "xe network-param-set uuid=$netuuid name-label=$net";
      $logger->trace("$ll cmd: $niccmd");
      $retc = cmdset($niccmd);
      if ($retc) {
         $logger->error("cannot rename nic to net - rc=$retc");
      } else {
         $logger->info("$ll  nic $nic network renamed to $net");
      }
   } else {
      $logger->error("cannot detect uuid from $nic");
      $retc = 99;
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub conf_nicnet

sub create_bondnet {                                                                                                               # configure network label to create bond
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my %conf      = %{ shift() };
   my $net       = shift();
   my $instmode  = shift();
   my $retc      = 0;
   my $foundbond = 0;
   my $niccount  = 0;
   my $bond;
   my @nics;
   my $nic;
   my $cmd;
   my $uuideth;
   my $bondcreated = 0;

   foreach $bond ( keys %{ $conf{'net'}{$net}{'bond'} } ) {
      $foundbond++;
      foreach $nic ( keys %{ $conf{'net'}{$net}{'bond'}{$bond}{'nic'} } ) {
         $logger->trace("$ll nic found in bond $bond: $nic");
         $logger->debug("$ll get uuid from $nic");
         my $uuidnic = xe_piflist("device=$nic");                                                                                  # nic
         if ( $uuidnic ne "" ) {
            $logger->debug("$ll uuid: $uuidnic");
            @nics = ( @nics, $uuidnic );
            unless ($retc) {                                                                                                       # configure nic speed or duplex
               my $speed  = "auto";
               my $duplex = "auto";
               if ( defined $conf{'net'}{$net}{'bond'}{$bond}{'nic'}{$nic}{'speed'} ) {
                  $speed = $conf{'net'}{$net}{'bond'}{$bond}{'nic'}{$nic}{'speed'};
                  $logger->debug("$ll speed configure: $speed");
                  if ( defined $conf{'net'}{$net}{'bond'}{$bond}{'nic'}{$nic}{'duplex'} ) {
                     $duplex = $conf{'net'}{$net}{'bond'}{$bond}{'nic'}{$nic}{'duplex'};
                     $logger->debug("$ll duplex also configure: $duplex");
                  } else {
                     $logger->debug("$ll no duplex configure - ignore nic settings");
                  }
               } else {
                  $logger->debug("$ll no speed configure - ignore nic settings");
               }
               if ( ( $speed ne "auto" ) && ( $duplex ne "auto" ) ) {
                  $logger->info("$ll nic configure found - run nic config now ...");
                  $retc = conf_nic( $nic, $speed, $duplex );
                  if ($retc) {
                     $logger->error("some wrong during nic config");
                  }
               } ## end if ( ( $speed ne "auto" ) && ( $duplex ne "auto" ) )
            } ## end unless ($retc)
            $logger->trace("$ll add counter");
            $niccount++;
         } else {
            $logger->error("something wrong in get uuid from $nic - abort");
            $retc = 99;
            last;
         }
      } ## end foreach $nic ( keys %{ $conf{'net'}{$net}{'bond'}{$bond}{'nic'} } )
      if ( ( $instmode eq "master" ) || ( $instmode eq "standalone" ) ) {
         $logger->trace("$ll Mode: $instmode - create");
         $logger->info("$ll nics [$niccount] found in bond [$bond] in net [$net]");
         if ( $niccount >= 2 ) {
            $logger->debug("$ll Bond $bond with $niccount nics found");
            unless ($retc) {
               $logger->info("$ll create net $bond");
               $retc = create_net($net);
               my $uuid = "";
               unless ($retc) {
                  $logger->info("$ll get uuid for network label $net");
                  $uuid = xe_netlist("name-label=\"$net\"");
               }
               if ( $uuid ne "" ) {
                  $logger->info("$ll Create network ..");
                  $logger->trace("$ll Create nic uuid list ..");
                  my $niclist = join( ',', @nics );
                  $logger->trace("$ll Nic uuid list: $niclist");
                  if ($vrun) {
                     $logger->warn("$ll vrun mode");
                     $logger->debug( "$ll xe bond-create network-uuid=\"" . $uuid . "\"", "pif-uuids=\"" . $niclist . "\"" );
                     $retc = 0;
                  } else {
                     $logger->trace("$ll Start xe command ...");
                     my $bondcmd = "xe bond-create network-uuid=$uuid pif-uuids=$niclist ";
                     my $bondmode;
                     if ( defined $conf{'net'}{$net}{'bond'}{$bond}{'mode'} ) {                                                    # xe bond-create network-uuid=<network_uuid> pif-uuids=<pif_uuid_1>,<pif_uuid_2> mode=<balance-slb | active-backup>
                        $bondmode = $conf{'net'}{$net}{'bond'}{$bond}{'mode'};
                        $logger->debug("$ll mode define: $bondmode");
                        $logger->debug("$ll extend bond command");
                        $bondcmd = $bondcmd . " mode=$bondmode";
                     } else {
                        $logger->trace("$ll no mode define - ignore");
                     }
                     my $bondmac;
                     if ( defined $conf{'net'}{$net}{'bond'}{$bond}{'mac'} ) {                                                     # xe bond-create network-uuid=<network_uuid> pif-uuids=<pif_uuid_1>,<pif_uuid_2>  mac=<mac>
                        $bondmac = $conf{'net'}{$net}{'bond'}{$bond}{'mac'};
                        $logger->debug("$ll mac define: $bondmac");
                        $logger->debug("$ll extend bond command");
                        $bondcmd = $bondcmd . " mac=$bondmac";
                     } else {
                        $logger->trace("$ll no mac define - ignore");
                     }
                     my $retuuid = cmdget($bondcmd);
                     $logger->trace("$ll frc: $frc");
                     unless ( ($frc) || ( $retuuid eq "" ) ) {
                        $logger->debug("$ll uuid: $retuuid");
                     } else {
                        $logger->error("something wrong creating net [$net] / bond [$bond] - abort");
                        $retc = 99;
                        last;
                     }
                  } ## end else [ if ($vrun) ]
                  unless ($retc) {
                     $logger->info("$ll create bond network ok");
                     $logger->debug("$ll only one bond per network can configure");
                     last;
                  } else {
                     $logger->error("Cannot create bond ($retc) - abort $?");
                  }
               } else {
                  $logger->error("something wrong to get uuid from bond $bond");
                  $retc = 99;
               }
            } ## end unless ($retc)
         } else {
            $logger->warn("$ll Do not configure bond - only 1 nic found!");
         }
      } else {
         $logger->trace("$ll Mode: $instmode - do not create bond");
      }
   } ## end foreach $bond ( keys %{ $conf{'net'}{$net}{'bond'} } )
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub create_bondnet

sub xe_piflist {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $cmd     = shift();
   my $retc    = 0;
   my $uuid    = "";
   my $nochmal = 0;
   do {

      if ( $cmd ne "" ) {
         $logger->debug("$ll cmd: [$cmd]");
         if ($vrun) {
            $logger->warn("$ll vrun mode");
            $logger->trace("$ll xe pif-list host-name-label=\$HOSTNAME $cmd --minimal");
            $uuid = "98ed7f87-3240-aaea-4d9e-cb65120991f4";
         } else {
            $uuid = cmdget("xe pif-list host-name-label=\$HOSTNAME $cmd --minimal");
            $logger->trace("$ll frc: $frc");
         }
         if ( $uuid =~ m/The host toolstack is still initialising/ ) {
            $logger->warn("$ll   xe toolstack is not online - retry");
            if ( $nochmal < 10 ) {
               $nochmal++;
               sleep(10);
            } else {
               $logger->error("to many retries to get toolstack online ...");
               $retc    = 88;
               $nochmal = 0;
            }
         } elsif ($frc) {                                                                                                          # cmdget function return code
            $logger->error("something wrong getting uuid - abort");
            $retc    = 99;
            $nochmal = 0;
         } else {
            if ( $uuid ne "" ) {
               if ( is_UUID_string($uuid) ) {
                  $logger->trace("$ll uuid: [$uuid]");
                  $nochmal = 0;
               } else {
                  $logger->error("return uuid [$uuid] is no valid - abort");
                  $nochmal = 0;
               }
            } else {
               $logger->error("error get uuid - result empty");
               $retc    = 99;
               $nochmal = 0;
            }
         } ## end else [ if ( $uuid =~ m/The host toolstack is still initialising/ ) ]
      } else {
         $logger->error("cmd parameter empty - abort");
         $retc    = 99;
         $nochmal = 0;
      }
   } while $nochmal;
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   unless ($retc) {
      return ($uuid);
   } else {
      return ('');
   }
} ## end sub xe_piflist

sub xe_netlist {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $cmd     = shift();
   my $retc    = 0;
   my $uuid    = "";
   my $nochmal = 0;
   do {

      if ( $cmd ne "" ) {
         $logger->debug("$ll cmd: [$cmd]");
         if ($vrun) {
            $logger->warn("$ll vrun mode");
            $logger->trace("$ll xe network-list $cmd --minimal");
            $uuid = "98ed7f87-3240-aaea-4d9e-cb65120991f4";
         } else {
            $uuid = cmdget("xe network-list $cmd --minimal");
            $logger->trace("$ll cmdget function rc: $frc");
         }
         if ( $uuid =~ m/The host toolstack is still initialising/ ) {
            $logger->warn("$ll   xe toolstack is not online - retry");
            if ( $nochmal < 10 ) {
               $nochmal++;
               sleep(10);
            } else {
               $logger->error("to many retries to get toolstack online ...");
               $retc    = 88;
               $nochmal = 0;
            }
         } elsif ($frc) {                                                                                                          # cmdget function return code
            $logger->error("something wrong getting uuid - abort");
            $retc    = 99;
            $nochmal = 0;
         } else {
            if ( $uuid ne "" ) {
               if ( is_UUID_string($uuid) ) {
                  $logger->trace("$ll uuid: [$uuid]");
                  $nochmal = 0;
               } else {
                  $logger->error("return uuid [$uuid] is no valid - abort");
                  $nochmal = 0;
               }
            } else {
               $logger->error("error get uuid - empty return");
               $retc    = 99;
               $nochmal = 0;
            }
         } ## end else [ if ( $uuid =~ m/The host toolstack is still initialising/ ) ]
      } else {
         $logger->error("cmd parameter empty - abort");
         $retc    = 99;
         $nochmal = 0;
      }
   } while $nochmal;
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   unless ($retc) {
      return ($uuid);
   } else {
      return ('');
   }
} ## end sub xe_netlist

sub conf_mgmtpurpose {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $uuidpif = shift();
   my $retc    = 0;
   my $command;
   if ( $uuidpif ne "" ) {

      if ($vrun) {
         $logger->warn("$ll vrun mode");
         $logger->trace("$ll xe pif-param-set uuid=$uuidpif other-config:management_purpose=\"Storage\"");
      } else {
         $logger->debug("$ll Set management purpose");
         $retc = cmdset("xe pif-param-set uuid=\"$uuidpif\" other-config:management_purpose=\"Storage\"");
      }
   } else {
      $logger->error("empty parameter to set management purpose - abort");
      $retc = 99;
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub conf_mgmtpurpose

sub conf_ipdhcp {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $net  = shift();
   my $mgmt = shift();
   my $retc = 0;
   my @command;
   $logger->info("$ll Configure DHCP IP on [$net]");
   my $uuidpif;
   my $uuidnet = xe_netlist("name-label=\"$net\"");

   if ( $uuidnet ne "" ) {
      $uuidpif = xe_piflist("network-uuid=\"$uuidnet\"");
   }
   if ( $uuidpif ne "" ) {
      if ($vrun) {
         $logger->warn("$ll vrun mode");
         $logger->trace("$ll xe pif-reconfigure-ip uuid=$uuidpif mode=dhcp");
      } else {
         $logger->debug("$ll Reconfigure pif $uuidpif");
         $retc = cmdset("xe pif-reconfigure-ip uuid=\"$uuidpif\" mode=dhcp");
         if ($retc) {
            $logger->error("cannot reconfigure ip on [$net] - rc=$retc");
         }
      } ## end else [ if ($vrun) ]
   } ## end if ( $uuidpif ne "" )
   unless ( $retc && defined $mgmt ) {
      $retc = conf_mgmtpurpose($uuidpif);
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub conf_ipdhcp

sub conf_ipstatic {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $net  = shift();
   my $ip   = shift();
   my $nm   = shift();
   my $gw   = shift();
   my $mgmt = shift();
   my $retc = 0;
   my @command;
   my $cmd;
   $logger->info("$ll Configure Static IP on [$net]");
   my $uuidpif;
   my $uuidnet = xe_netlist("name-label=\"$net\"");

   if ( $uuidnet ne "" ) {
      $uuidpif = xe_piflist("network-uuid=\"$uuidnet\"");
   } else {
      $logger->error("cannot get uuid from $net");
      $retc = 99;
   }
   unless ($retc) {
      if ( $uuidpif ne "" ) {
         if ($vrun) {
            $logger->warn("$ll vrun mode");
            $logger->trace("$ll xe pif-reconfigure-ip uuid=$uuidpif mode=static ip=$ip gateway=$gw netmask=$nm");
         } else {
            $logger->debug("$ll Reconfigure pif $uuidpif");
            if ( $gw ne "none" ) {
               $cmd = "xe pif-reconfigure-ip uuid=\"$uuidpif\" mode=static ip=$ip gateway=$gw netmask=$nm";
            } else {
               $cmd = "xe pif-reconfigure-ip uuid=\"$uuidpif\" mode=static ip=$ip netmask=$nm";
            }
            $retc = cmdset($cmd);
            if ($retc) {
               $logger->error("cannot reconfigure ip on [$net] - rc=$retc");
            }
         } ## end else [ if ($vrun) ]
      } ## end if ( $uuidpif ne "" )
      unless ($retc) {
         $logger->debug("$ll disallow unplug");
         if ($vrun) {
            $logger->warn("$ll vrun mode");
            $logger->trace("$ll xe pif-param-set disallow-unplug=true uuid=$uuidpif");
         } else {
            $logger->debug("$ll set disallow flag now on $uuidpif");
            $cmd  = "xe pif-param-set disallow-unplug=true uuid=$uuidpif";
            $retc = cmdset($cmd);
            if ($retc) {
               $logger->error("cannot set disallow flag on [$net] - rc=$retc");
            }
         } ## end else [ if ($vrun) ]
      } ## end unless ($retc)
   } ## end unless ($retc)
   unless ($retc) {
      if ( defined $mgmt ) {
         $retc = conf_mgmtpurpose($uuidpif);
      } else {
         $logger->info("$ll no management purpose defined - ignore");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub conf_ipstatic

sub conf_vlan {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $uuidnet       = shift();
   my $uuidbondornic = shift();
   my $vlan          = shift();
   my $retc          = 0;
   if ( $uuidnet ne "" ) {
      $logger->trace("$ll uuid net label: [$uuidnet]");
   } else {
      $logger->error("uuid net empty");
      $retc = 44;
   }
   if ( $uuidbondornic ne "" ) {
      $logger->trace("$ll uuid bond/nic: [$uuidbondornic]");
   } else {
      $logger->error("uuid bond/nic empty");
      $retc = 44;
   }
   if ( $vlan ne "" ) {
      $logger->trace("$ll vlan: [$vlan]");
   } else {
      $logger->error("vlan empty");
      $retc = 44;
   }
   unless ($retc) {
      $logger->info("$ll config vlan ...");
      unless ($retc) {
         if ($vrun) {
            $logger->warn("$ll vrun mode");
            $logger->trace("$ll xe vlan-create network-uuid=$uuidnet pif-uuid=$uuidbondornic vlan=$vlan");
         } else {
            $logger->debug("$ll command to set vlan");
            $retc = cmdset("xe vlan-create network-uuid=$uuidnet pif-uuid=$uuidbondornic vlan=$vlan");
            if ($retc) {
               $logger->error("cannot set vlan on nic/bond - abort");
            }
         } ## end else [ if ($vrun) ]
      } ## end unless ($retc)
   } else {
      $logger->error("error - maybe empty parameter");
      $retc = 77;
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub conf_vlan

sub conf_vlannicnet {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $net  = shift();
   my $nic  = shift();
   my $vlan = shift();
   if ( $net ne "" ) {
      $logger->trace("$ll net label: [$net]");
   } else {
      $logger->error("net empty");
      $retc = 44;
   }
   if ( $nic ne "" ) {
      $logger->trace("$ll nic: [$nic]");
   } else {
      $logger->error("nic empty");
      $retc = 44;
   }
   if ( $vlan ne "" ) {
      $logger->trace("$ll vlan: [$vlan]");
   } else {
      $logger->error("vlan empty");
      $retc = 44;
   }
   unless ($retc) {
      my $uuidnic;
      my $uuidnicnet;
      $logger->debug("$ll get [$net] uuid ...");
      my $uuidnet = xe_netlist("name-label=\"$net\"");
      if ( $uuidnet ne "" ) {
         $logger->debug("$ll get net uuid from [$nic]");
         $uuidnic = xe_piflist("device=$nic");                                                                                     # nic
      } else {
         $logger->error("something wrong with uuidnet of [$net]");
         $retc = 44;
      }
      unless ($retc) {
         $retc = conf_vlan( $uuidnet, $uuidnic, $vlan );
         if ($retc) {
            $logger->error("configure vlan/nic/net - rc=$retc");
         }
      } else {
         $logger->error("cannot confige [$net]");
      }
   } else {
      $logger->error("error - maybe empty parameter");
      $retc = 77;
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub conf_vlannicnet

sub conf_vlanbondnet {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $net  = shift();
   my $bond = shift();
   my $vlan = shift();
   my $retc = 0;
   if ( $net ne "" ) {
      $logger->trace("$ll net label: [$net]");
   } else {
      $logger->error("net empty");
      $retc = 44;
   }
   if ( $bond ne "" ) {
      $logger->trace("$ll bond: [$bond]");
   } else {
      $logger->error("bond empty");
      $retc = 44;
   }
   if ( $vlan ne "" ) {
      $logger->trace("$ll vlan: [$vlan]");
   } else {
      $logger->error("vlan empty");
      $retc = 44;
   }
   unless ($retc) {
      my $uuidbond    = "";
      my $uuidbondnet = "";
      $logger->debug("$ll get uuid from [$net]");
      my $uuidnet = xe_netlist("name-label=\"$net\"");
      if ( $uuidnet ne "" ) {
         $logger->debug("$ll get uuid from net $bond");
         $logger->trace("$ll \$uuidbondnet=xe_netlist(\"name-label=\"$bond\"\");");
         $uuidbondnet = xe_netlist("name-label=\"$bond\"");
         if ( $uuidbondnet ne "" ) {
            $logger->debug("$ll get bond pif uuid $bond");
            $logger->trace("$ll \$uuidbond=xe_piflist(\"network-uuid=\"$uuidbondnet\"\");");
            $uuidbond = xe_piflist("network-uuid=\"$uuidbondnet\"");
         } else {
            $logger->error("getting bond uuid ...");
            $retc = 99;
         }
      } else {
         $logger->error("something wrong with uuid net detection - abort");
         $retc = 99;
      }
      if ( $uuidbond ne "" ) {
         $logger->debug("$ll call config vlan ..");
         $retc = conf_vlan( $uuidnet, $uuidbond, $vlan );
         if ($retc) {
            $logger->error("uuid of bond network label [$net] is empty !");
            $logger->error("something wrong in conf_vlan rc=$retc");
         }
      } else {
         $logger->error("cannot get bond uuid - abort");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub conf_vlanbondnet

sub create_net {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $name = shift();
   my $retc = 0;
   $logger->debug("$ll Create network $name ...");
   if ($vrun) {
      $logger->warn("$ll vrun mode");
      $logger->debug( "$ll xe ", "network-create ", "name-label=\"" . $name . "\"" );
   } else {
      $logger->debug("$ll create net $name");
      my $netuuid = cmdget("xe network-create name-label=\"$name\"");
      $logger->trace("$ll frc: $frc");
      if ( $netuuid eq "" ) {
         $logger->error("cannot create network label $name");
         $retc = 99;
      } else {
         $logger->info("$ll create net $name ==> ok");
         $logger->debug("$ll uuid: [$netuuid] ");
      }
   } ## end else [ if ($vrun) ]
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub create_net

sub check_netmask {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $nm   = shift();
   my $retc = 0;

   # check netmask implentation
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub check_netmask

sub check_ip {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $ipadr = shift();
   my $retc  = 0;
   if ( $ipadr !~ /^([\d]+)\.([\d]+)\.([\d]+)\.([\d]+)$/ ) {
      $logger->error("ip [$ipadr] is not a ip v4 adr.");
      $retc = 11;
   } else {
      my $notIP = 0;
      my $s;
      foreach $s ( ( $1, $2, $3, $4 ) ) {
         $logger->trace("$ll s=$s");
         if ( 0 > $s || $s > 255 ) {
            $notIP = 1;
            last;
         }
      } ## end foreach $s ( ( $1, $2, $3, $4 ) )
      if ($notIP) {
         $logger->error("ip [$ipadr] is not a ip v4 adr.");
         $retc = 22;
      } else {
         $logger->debug("$ll ip [$ipadr] ok");
      }
   } ## end else [ if ( $ipadr !~ /^([\d]+)\.([\d]+)\.([\d]+)\.([\d]+)$/ ) ]
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub check_ip

sub create_network {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $conffile = shift();
   my $instmode = shift();
   my $retc     = 0;
   my $conf;
   my %config;
   my %cfgok;                                                                                                                      # welches netz konfiguriert
   my $cfgall = 0;                                                                                                                 # counter wieviel config
   my $net;

   if ( $conffile ne "" ) {
      $logger->debug("$ll check if config file exist");
      if ( -e $conffile ) {
         $logger->info("$ll found $conffile");
         $logger->trace("$ll get all config from $conffile");
         $conf = new Config::General("$conffile");
         $logger->debug("$ll Get all xenserver configurations ...");
         %config = $conf->getall;
         $logger->trace("$ll get network config overview ..");
         foreach $net ( keys %{ $config{'net'} } ) {
            $logger->debug("$ll net found: [$net]");
            $cfgall++;
            $cfgok{$net} = 0;
         }
         $logger->debug("$ll Count network configs: $cfgall");
         $logger->info("$ll First configure mgmt net, than all other ...");
         do {
            foreach $net ( keys %{ $config{'net'} } ) {
               $logger->debug("$ll net found in config: [$net]");
               $logger->trace("$ll foundmgmt: $foundmgmt");
               $logger->trace("$ll cfgall: $cfgall");
               unless ($cfgall) {
                  $logger->info("$ll All found networks configured - end.");
                  last;
               }
               if ( defined $config{'net'}{$net}{'typ'} && not $foundmgmt ) {
                  if ( "$config{'net'}{$net}{'typ'}" eq "mgmt" ) {                                                                 # configure mgmt network first
                     unless ( ( $cfgok{$net} ) || ($retc) ) {
                        $logger->info("$ll  Found mgmt net: $net");
                        unless ($retc) {
                           if ( defined $config{'net'}{$net}{'nic'} ) {
                              if ( $net ne "" ) {
                                 if ( ( $instmode eq "master" ) || ( $instmode eq "standalone" ) ) {
                                    $logger->trace("$ll  Mode: $instmode - create");
                                    $logger->info("$ll  Create network name: [$net]");
                                    $retc = create_net($net);
                                 } else {
                                    $logger->trace("$ll  Mode: $instmode - no need to create");
                                 }
                              } ## end if ( $net ne "" )
                              $logger->info("$ll  found nic - assign mgmt to nic ...");
                              if ( ( $instmode eq "master" ) || ( $instmode eq "standalone" ) ) {
                                 $logger->trace("$ll  Mode: $instmode - create");
                                 $retc = conf_nicnet( $net, $config{'net'}{$net}{'nic'} );
                              } else {
                                 $logger->trace("$ll  Mode: $instmode - no need to create");
                              }
                              unless ($retc) {                                                                                     # configure nic speed or duplex
                                 my $speed  = "auto";
                                 my $duplex = "auto";
                                 if ( defined $config{'net'}{$net}{'speed'} ) {
                                    $speed = $config{'net'}{$net}{'speed'};
                                    $logger->debug("$ll  speed configure: $speed");
                                    if ( defined $config{'net'}{$net}{'duplex'} ) {
                                       $duplex = $config{'net'}{$net}{'duplex'};
                                       $logger->debug("$ll  duplex also configure: $duplex");
                                    } else {
                                       $logger->debug("$ll  no duplex configure - ignore nic settings");
                                    }
                                 } else {
                                    $logger->debug("$ll  no speed configure - ignore nic settings");
                                 }
                                 if ( ( $speed ne "auto" ) && ( $duplex ne "auto" ) ) {
                                    $logger->info("$ll  nic configure found - run nic config now ...");
                                    $retc = conf_nic( $config{'net'}{$net}{'nic'}, $speed, $duplex );
                                    if ($retc) {
                                       $logger->error("some wrong during nic config");
                                    }
                                 } ## end if ( ( $speed ne "auto" ) && ( $duplex ne "auto" ) )
                              } ## end unless ($retc)
                           } else {
                              $logger->info("$ll  try if net conf has a bond ...");
                              $retc = create_bondnet( \%config, $net, $instmode );
                           }
                        } ## end unless ($retc)
                        unless ($retc) {                                                                                           # mtu ?
                           $logger->debug("$ll  test if mtu setting present");
                           if ( defined $config{'net'}{$net}{'mtu'} ) {
                              $retc = conf_mtu( $config{'net'}{$net}{'mtu'}, $net );
                           } else {
                              $logger->debug("$ll  => no mtu setting - ignore");
                           }
                        } ## end unless ($retc)
                        unless ($retc) {                                                                                           # dnssearch ?
                           $logger->debug("$ll  test if dns search setting present");
                           if ( defined $config{'net'}{$net}{'dnssearch'} ) {
                              $retc = conf_dnssearch( $config{'net'}{$net}{'dnssearch'}, $net );
                           } else {
                              $logger->debug("$ll  => no dns search setting - ignore");
                           }
                        } ## end unless ($retc)
                        unless ($retc) {                                                                                           # descr ?
                           $logger->debug("$ll  searching net [$net] descr ...");
                           if ( defined $config{'net'}{$net}{'descr'} ) {
                              $logger->debug("$ll  net descr. configure: $config{'net'}{$net}{'descr'}");
                              $retc = conf_netdescr( $net, $config{'net'}{$net}{'descr'} );
                           } else {
                              $logger->debug("$ll  no descr. configure");
                           }
                        } ## end unless ($retc)
                        unless ($retc) {
                           $logger->trace("$ll  set $net cfgok to 1");
                           $cfgok{$net} = 1;
                           $logger->debug("$ll  mgmt successfull configure!");
                           $foundmgmt = 1;
                           $cfgall--;
                           $logger->trace("$ll cfgall: $cfgall");
                           $logger->debug("$ll wait a few seconds ...");
                           sleep(10);
                           last;
                        } else {
                           $logger->error("mgmt cannot create - abort");
                           $cfgall = 0;                                                                                            # abort
                           last;
                        }
                        $logger->info("SOURCE ERROR -> never come here");
                     } else {
                        $logger->trace("$ll net [$net] already configure");
                     }
                  } else {
                     $logger->debug("$ll Found typ in [$net] but not mgmt");
                  }
               } else {
                  if ($foundmgmt) {                                                                                                # next all other networks
                     unless ( ( $cfgok{$net} ) || ($retc) ) {
                        $logger->info("$ll Config net: [$net]");
                        if ( defined $config{'net'}{$net}{'vlan'} ) {                                                              # new network with vlan ?
                           if ( ( $instmode eq "master" ) || ( $instmode eq "standalone" ) ) {                                     # vlan need no duplex speed config - is already configure in nic / bond definition
                              $logger->trace("$ll  vlan defined");
                              if ( defined $config{'net'}{$net}{'bond'} ) {                                                        # test if var bond=<bondname>
                                 if ( !ref( $config{'net'}{$net}{'bond'} ) ) {                                                     # or hash - if yes no create bond and vlan allowed
                                    $logger->info("$ll  found vlan and bond ...");
                                    if ( $net ne "" ) {
                                       my $targetnet = $config{'net'}{$net}{'bond'};
                                       $logger->trace("$ll  net bind to [$targetnet]");
                                       $logger->trace("$ll  test if target net [$targetnet] exist ...");
                                       if ( defined $cfgok{$targetnet} ) {
                                          $logger->trace("$ll  $targetnet exist in config");
                                          $logger->trace("$ll  status of config of target net: [$cfgok{$targetnet}] ");
                                          if ( $cfgok{$targetnet} ) {                                                              # bond refer net already configure ?
                                             $logger->debug("$ll  network [$targetnet] exist - install $net");
                                             $logger->info("$ll  Create network name: [$net]");
                                             $retc = create_net($net);
                                             unless ($retc) {
                                                $retc = conf_vlanbondnet( $net, $targetnet, $config{'net'}{$net}{'vlan'} );
                                             } else {
                                                $logger->error("creating net [$net]");
                                             }
                                          } else {
                                             $logger->warn("$ll  network [$targetnet] not configure yet");
                                             $logger->warn("$ll   ==> jump over $net");
                                             next;
                                          }
                                       } else {
                                          $logger->error("network [$targetnet] not exist - abort");
                                          $retc   = 99;
                                          $cfgall = 0;
                                          last;
                                       } ## end else [ if ( defined $cfgok{$targetnet} ) ]
                                    } ## end if ( $net ne "" )
                                 } else {
                                    $logger->error("net [$net] with vlan needs existing nic or bond to bind!");
                                    $retc   = 99;
                                    $cfgall = 0;
                                    last;
                                 } ## end else [ if ( !ref( $config{'net'}{$net}{'bond'} ) ) ]
                              } elsif ( defined $config{'net'}{$net}{'nic'} ) {
                                 $logger->info("$ll  found vlan and nic ...");
                                 $logger->info("$ll  Create network name: [$net]");
                                 $retc = create_net($net);
                                 unless ($retc) {
                                    if ( ( $instmode eq "master" ) || ( $instmode eq "standalone" ) ) {
                                       $logger->trace("$ll Mode: $instmode - create network");
                                       $retc = conf_vlannicnet( $net, $config{'net'}{$net}{'nic'}, $config{'net'}{$net}{'vlan'} );
                                    } else {
                                       $logger->trace("$ll Mode: $instmode - do not need to create network");
                                    }
                                    unless ($retc) {                                                                               # configure nic speed or duplex
                                       my $speed  = "auto";
                                       my $duplex = "auto";
                                       if ( defined $config{'net'}{$net}{'speed'} ) {
                                          $speed = $config{'net'}{$net}{'speed'};
                                          $logger->debug("$ll  speed configure: $speed");
                                          if ( defined $config{'net'}{$net}{'duplex'} ) {
                                             $duplex = $config{'net'}{$net}{'duplex'};
                                             $logger->debug("$ll  duplex also configure: $duplex");
                                          } else {
                                             $logger->debug("$ll  no duplex configure - ignore nic settings");
                                          }
                                       } else {
                                          $logger->debug("$ll  no speed configure - ignore nic settings");
                                       }
                                       if ( ( $speed ne "auto" ) && ( $duplex ne "auto" ) ) {
                                          $logger->info("$ll  nic configure found - run nic config now ...");
                                          $retc = conf_nic( $config{'net'}{$net}{'nic'}, $speed, $duplex );
                                          if ($retc) {
                                             $logger->error("some wrong during nic config");
                                          }
                                       } ## end if ( ( $speed ne "auto" ) && ( $duplex ne "auto" ) )
                                    } ## end unless ($retc)
                                 } else {
                                    $logger->error("creating net [$net]");
                                    $retc   = 99;
                                    $cfgall = 0;
                                    last;
                                 } ## end else
                              } else {
                                 $logger->error("net [$net] with vlan need nic, bond or bond to create!");
                                 $retc   = 99;
                                 $cfgall = 0;
                                 last;
                              } ## end else [ if ( defined $config{'net'}{$net}{'bond'} ) ]
                           } else {
                              $logger->debug("$ll  member server do not need to configure VLAN - ignore");
                           }
                        } else {                                                                                                   # or without vlan ?
                           if ( defined $config{'net'}{$net}{'nic'} ) {
                              $logger->info("$ll  found only nic - rename nic network ...");
                              if ( ( $instmode eq "master" ) || ( $instmode eq "standalone" ) ) {
                                 $logger->trace("$ll  Mode: $instmode - create nic net");
                                 $retc = conf_nicnet( $net, $config{'net'}{$net}{'nic'} );
                              } else {
                                 $logger->trace("$ll  Mode: $instmode - do not need to create nic net");
                              }
                              unless ($retc) {                                                                                     # configure nic speed or duplex
                                 my $speed  = "auto";
                                 my $duplex = "auto";
                                 if ( defined $config{'net'}{$net}{'speed'} ) {
                                    $speed = $config{'net'}{$net}{'speed'};
                                    $logger->debug("$ll  speed configure: $speed");
                                    if ( defined $config{'net'}{$net}{'duplex'} ) {
                                       $duplex = $config{'net'}{$net}{'duplex'};
                                       $logger->debug("$ll  duplex also configure: $duplex");
                                    } else {
                                       $logger->debug("$ll  no duplex configure - ignore nic settings");
                                    }
                                 } else {
                                    $logger->debug("$ll  no speed configure - ignore nic settings");
                                 }
                                 if ( ( $speed ne "auto" ) && ( $duplex ne "auto" ) ) {
                                    $logger->info("$ll  nic configure found - run nic config now ...");
                                    $retc = conf_nic( $config{'net'}{$net}{'nic'}, $speed, $duplex );
                                    if ($retc) {
                                       $logger->error("some wrong during nic config");
                                       last;
                                    }
                                 } ## end if ( ( $speed ne "auto" ) && ( $duplex ne "auto" ) )
                              } ## end unless ($retc)
                           } elsif ( defined $config{'net'}{$net}{'bond'} ) {
                              if ( !ref( $config{'net'}{$net}{'bond'} ) ) {                                                        # var and not hash
                                 $logger->error("join to bond without vlan is not correct - abort");
                                 $retc   = 99;
                                 $cfgall = 0;
                                 last;
                              } else {
                                 $logger->info("$ll  try if new bond create exist ...");
                                 $retc = create_bondnet( \%config, $net, $instmode );
                              }
                           } else {
                              if ( defined $config{'net'}{$net}{'ip'} ) {
                                 $logger->debug("$ll  ip config only found - go ahead");
                              } else {
                                 $logger->error("join without vlan and no new bond is not correct - abort");
                                 $retc   = 99;
                                 $cfgall = 0;
                                 last;
                              } ## end else [ if ( defined $config{'net'}{$net}{'ip'} ) ]
                           } ## end else [ if ( defined $config{'net'}{$net}{'nic'} ) ]
                        } ## end else [ if ( defined $config{'net'}{$net}{'vlan'} ) ]
                        unless ($retc) {                                                                                           # mtu ?
                           $logger->debug("$ll  test if mtu setting present");
                           if ( defined $config{'net'}{$net}{'mtu'} ) {
                              $retc = conf_mtu( $config{'net'}{$net}{'mtu'}, $net );
                           } else {
                              $logger->debug("$ll  no mtu setting - ignore");
                           }
                        } ## end unless ($retc)
                        unless ($retc) {
                           if ( defined $config{'net'}{$net}{'ip'} ) {
                              $logger->info("$ll  found ip config - configure ip net ...");
                              my $ip = $config{'net'}{$net}{'ip'};
                              $logger->debug("$ll  check ip");
                              if ( "$ip" eq "dhcp" ) {
                                 $logger->info("$ll new network with dhcp");
                                 if ( defined $config{'net'}{$net}{'typ'} ) {
                                    if ( "$config{'net'}{$net}{'typ'}" eq "storage" ) {
                                       $logger->info("$ll  find typ storage");
                                       $retc = conf_ipdhcp( $net, "storage" );
                                    } else {
                                       $logger->info("$ll  change ip to dhcp");
                                       $retc = conf_ipdhcp($net);
                                    }
                                 } else {
                                    $logger->info("$ll  change ip to dhcp");
                                    $retc = conf_ipdhcp($net);
                                 }
                              } else {
                                 $retc = check_ip($ip);
                                 unless ($retc) {
                                    my $gateway = "none";
                                    if ( defined $config{'net'}{$net}{'gateway'} ) {
                                       $gateway = $config{'net'}{$net}{'gateway'};
                                    }
                                    if ( defined $config{'net'}{$net}{'netmask'} ) {
                                       my $netmask = $config{'net'}{$net}{'netmask'};
                                       $logger->debug("$ll  check netmask");
                                       $retc = check_netmask($netmask);
                                       unless ($retc) {
                                          if ( defined $config{'net'}{$net}{'typ'} ) {
                                             if ( "$config{'net'}{$net}{'typ'}" eq "storage" ) {
                                                $logger->info("$ll  find typ storage");
                                                $retc = conf_ipstatic( $net, $ip, $netmask, $gateway, "storage" );
                                             } else {
                                                $logger->info("$ll  change ip to static");
                                                $retc = conf_ipstatic( $net, $ip, $netmask, $gateway );
                                             }
                                          } else {
                                             $logger->info("$ll  change ip to static");
                                             $retc = conf_ipstatic( $net, $ip, $netmask, $gateway );
                                          }
                                       } ## end unless ($retc)
                                    } else {
                                       $logger->warn("$ll no netmask found - abort static ip conf");
                                    }
                                 } ## end unless ($retc)
                              } ## end else [ if ( "$ip" eq "dhcp" ) ]
                           } ## end if ( defined $config{'net'}{$net}{'ip'} )
                        } ## end unless ($retc)
                        unless ($retc) {                                                                                           # descr ?
                           $logger->debug("$ll  searching net [$net] descr ...");
                           if ( defined $config{'net'}{$net}{'descr'} ) {
                              $logger->debug("$ll  net descr. configure: $config{'net'}{$net}{'descr'}");
                              $retc = conf_netdescr( $net, $config{'net'}{$net}{'descr'} );
                           } else {
                              $logger->debug("$ll  no descr. configure");
                           }
                        } ## end unless ($retc)
                        $logger->trace("$ll [$net] config end rc=$retc");
                        unless ($retc) {
                           $cfgall--;
                           $logger->trace("$ll  cfgall: $cfgall");
                           $logger->trace("$ll  set net [$net] to ok !");
                           $cfgok{$net} = 1;
                           $logger->debug("$ll wait a few seconds ...");
                           sleep(10);
                        } else {
                           $logger->error("abort !");
                           last;
                        }
                     } else {
                        $logger->trace("$ll net [$net] already configure");
                     }
                  } else {
                     $logger->debug("$ll net: [$net] - no mgmt, mgmt first!");
                  }
               } ## end else [ if ( defined $config{'net'}{$net}{'typ'} && not $foundmgmt ) ]
            } ## end foreach $net ( keys %{ $config{'net'} } )
            unless ($foundmgmt) {
               $logger->error("No mgmt net found - abort");
               $cfgall = 0;
               $retc   = 99;
            }
            if ($cfgall) {
               $logger->trace("$ll next complete network config run need ... not all net configured!");
            }
         } while ( ($cfgall) && ( not $retc ) );
         unless ($retc) {
            $logger->info("$ll All config bonds found - finish");
         }
      } else {
         $logger->error("no config file found - abort");
         $retc = 99;
      }
   } else {
      $logger->error("no conffile given ... ");
      $retc = 42;
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub create_network

# main
my $counter = 0;
my $mode    = "none";
my $usage   = "\nPrograme: $prg \nVersion: $ver\nDescript.: configure xenserver network\n\nparameter: --mode [member/master/standalone]\n\n";
if ( $#ARGV eq '-1' ) { print $usage; exit; }
my @ARGS    = @ARGV;
my $numargv = @ARGS;
for ( $counter = 0 ; $counter < $numargv ; $counter++ ) {
   $logger->debug(" Argument: $ARGS[$counter]");
   if ( $ARGS[ $counter ] =~ /^-h$/i ) {
      print $usage;
      exit(0);
   } elsif ( $ARGS[ $counter ] eq "" ) {
      ## Do nothing
   } elsif ( $ARGS[ $counter ] =~ /^--help/ ) {
      print $usage;
      exit(0);
   } elsif ( $ARGS[ $counter ] =~ /^--mode$/ ) {
      $counter++;
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         $mode = $ARGS[ $counter ];
         chomp($mode);
         $mode =~ s/\n|\r//g;
      } else {
         $logger->error("The argument after --mode was not correct - ignore!");
         $counter--;
      }
   } else {
      $logger->warn(" Unknown option [$ARGS[$counter]]- ignore");
   }
} ## end for ( $counter = 0 ; $counter < $numargv ; $counter++ )
$logger->info(" Mode: $mode");
if ( $mode eq "master" || $mode eq "standalone" || $mode eq "member" ) {
   unless ($retc) {
      if ( -e $poolfile ) {
         $logger->info(" Work on pool config ...");
         $retc = create_network( $poolfile, $mode );
      } else {
         $logger->error("no pool config - something wrong - abort");
         $retc = 99;
      }
   } ## end unless ($retc)
   unless ($retc) {
      if ( -e $conffile ) {
         $logger->info(" Work on xenserver config ...");
         $logger->debug(" Mgmt already configure - set to true");
         $foundmgmt = 1;
         $retc = create_network( $conffile, $mode );
      } else {
         $logger->error("o ext config exist - what happens here ?");
         $retc = 98;
      }
   } ## end unless ($retc)
} else {
   $logger->error("no mode set or unknown - abort");
   $retc = 100;
}
unless ($retc) {
   $logger->info(" all networks configure successful");
   $logger->info(" need reboot after network config - set return code to 1");
   $retc = 1;
} else {
   $logger->error(" something wrong - see log file for more detailed errors");
   if ( $retc == 1 ) {
      $logger->error(" err code 1 mean only reboot - set to 999");
      $retc = 999;
   }
} ## end else
$logger->info("End $prg - v.$ver rc=$retc");
exit($retc);
__END__

