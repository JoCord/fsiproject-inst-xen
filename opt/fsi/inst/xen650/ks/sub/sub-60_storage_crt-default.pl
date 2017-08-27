#!/usr/bin/perl -w
#
#   create storage repositories
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
our $ver = "1.0.12 - 9.9.2016";
my $retc = 0;
my $vrun = 0;                                                                                                                      # virtual run => 1 means no xe commands, 0 means xe commands
use strict;
use warnings;
use FindBin qw($Bin);
my $fsidir = "/var/fsi";
use lib "/var/fsi/module";
use Config::General;
use English;
our $flvl = 0;                                                                                                                     # function level

open my $file, '<', "/etc/redhat-release"; 
my $redhatrel = <$file>; 
close $file;
my ($xenmain) = $redhatrel =~ /(\d+)/;   
my $xencfg = "xen$xenmain";

my $logconf  = "$fsidir/log.cfg";
my $logfile  = "$fsidir/fsixeninst.log";
my $conffile = "$fsidir/$xencfg.ext";
my $poolfile = "$fsidir/$xencfg.pool";
my $confxen  = "$fsidir/$xencfg.conf";
my $pool     = "none";
my %cfg;
my $n_locmount = "$fsidir/tmpnfs";
use Net::Ping;
use File::Path;
use Sys::Hostname;
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
$logger->info("Starting $prg - v.$ver");

# functions
our $frc = 0;                                                                                                                      # global function return code for cmdget
require "/usr/bin/fsifunc.pl";                                                                                                     # global perl routine

sub set_defaultsr {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc    = 0;
   my $sr      = shift();
   my $poolcmd = "xe pool-list --minimal";
   $logger->trace("$ll  cmd: $poolcmd");
   my $pooluuid = cmdget($poolcmd);
   my $srcmd    = "xe sr-list name-label=$sr --minimal";
   $logger->trace("$ll  cmd: $srcmd");
   my $sruuid     = cmdget($srcmd);
   my $defaultcmd = "xe pool-param-set uuid=$pooluuid default-SR=$sruuid";
   $logger->trace("$ll  cmd: $defaultcmd");
   $retc = cmdset($defaultcmd);
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub set_defaultsr

sub check_ip {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $ipadr = shift();
   my $retc  = 0;
   if ( $ipadr !~ /^([\d]+)\.([\d]+)\.([\d]+)\.([\d]+)$/ ) {
      $logger->error("$ll ip [$ipadr] is not a ip v4 adr.");
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
         $logger->error("$ll ip [$ipadr] is not a ip v4 adr.");
         $retc = 22;
      } else {
         $logger->debug("$ll ip [$ipadr] ok");
      }
   } ## end else [ if ( $ipadr !~ /^([\d]+)\.([\d]+)\.([\d]+)\.([\d]+)$/ ) ]
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub check_ip

sub check_srv {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   my $srv = shift();
   if ( $srv ne "" ) {
      $logger->trace("$ll srv: [$srv]");
   } else {
      $logger->error("$ll srv empty");
      $retc = 44;
   }
   unless ($retc) {
      my $p = Net::Ping->new();
      $retc = $p->ping($srv);
      if ( defined $retc ) {
         if ($retc) {
            $logger->debug("$ll srv [$srv] ping successful");
            $retc = 0;
         }
      } else {
         $logger->error("srv not pingable");
         $retc = 99;
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub check_srv

sub create_path {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   my $path = shift();
   unless ( -d $path ) {
      $logger->debug("$ll path [$path] does not exist - create");
      eval { mkpath($path) };
      if ($@) {
         $logger->error("problem creating $path");
         $retc = 99;
      } else {
         $logger->debug("$ll path created sucessful");
      }
   } else {
      $logger->debug("$ll path already created");
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub create_path

sub delete_path {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   my $path = shift();
   if ( -d $path ) {
      $logger->debug("$ll path [$path] exist - delete");
      eval { rmtree($path) };
      if (@$) {
         $logger->error("problem deleting $path");
         $retc = 98;
      } else {
         $logger->debug("$ll path deleted sucessful");
      }
   } else {
      $logger->debug("$ll path does not exist");
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub delete_path

sub check_locmount {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   my $tmpmount = shift();
   $retc = create_path($tmpmount);
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub check_locmount

sub umount_path {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll       = " " x $flvl;
   my $retc     = 0;
   my $tmpmount = shift();
   $logger->trace("$ll func start: [$fc]");
   $logger->debug("$ll try to umount $tmpmount now ..");
   my $command = "umount $tmpmount";
   $logger->trace("$ll cmd: $command");
   my $result = qx($command  2>&1);
   $retc = $?;
   $retc = $retc >> 8 unless ( $retc == -1 );

   unless ($retc) {
      $logger->debug("$ll umount ok");
   } else {
      $logger->error("umount error [$retc]");
      $result =~ s/^\s+//;
      $result =~ s/\s+$//;
      $result =~ s/\n//;
      $logger->error("[$result]");
   } ## end else
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub umount_path

sub mount_path {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   my $srv  = shift();
   my $path = shift();
   $logger->trace("$ll call check mount point");
   $retc = check_locmount($n_locmount);

   unless ($retc) {
      $logger->debug("$ll try to mount $srv:$path now ..");
      my $command = "mount -t nfs $srv:$path $n_locmount";
      $logger->trace("$ll cmd: $command");
      my $result = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->debug("$ll mount ok");
      } else {
         $logger->error("mount error [$retc]");
         $result =~ s/^\s+//;
         $result =~ s/\s+$//;
         $result =~ s/\n//;
         $logger->error("[$result]");
      } ## end else
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub mount_path

sub get_hostuuid {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc     = 0;
   my $host     = hostname();
   my $hostuuid = "";
   my $command  = "xe host-list name-label=$host --minimal";
   $logger->trace("$ll cmd: $command");

   if ($vrun) {
      $logger->warn("$ll vrun mode");
      $logger->trace("$ll $command");
      $hostuuid = "0ds9fa0sd9f8a0df98asd0f";
   } else {
      $hostuuid = cmdget($command);
   }
   if ( $hostuuid ne "" ) {
      $logger->debug("$ll host uuid: $hostuuid");
   } else {
      $logger->error("$ll cannot get uuid from host");
   }
   $logger->trace("$ll func end: [$fc]- [$hostuuid]");
   $flvl--;
   return ($hostuuid);
} ## end sub get_hostuuid

sub set_haflag {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $sr   = shift();
   my $mhf  = shift();
   $logger->info("$ll sr $sr define as ha sr");
   my $command = "echo hasr=$sr >>$fsidir/$xencfg.conf";
   $logger->trace("$ll cmd: $command");
   $retc = cmdset($command);

   if ($retc) {
      $logger->error("cannot set ha sr name");
   }
   if ( $pool ne "none" ) {
      $logger->debug("$ll pool configure - create ha flag");
      my $command = "echo $sr >/mnt/ks/pool/$pool/pool.ha";
      $logger->trace("$ll cmd: $command");
      $retc = cmdset($command);
      if ($retc) {
         $logger->error("cannot set ha sr in pool flag file");
      }
   } ## end if ( $pool ne "none" )
   unless ($retc) {
      $logger->info("$ll max host failure define - set in varcons");
      my $command = "echo MHF=$mhf >>$fsidir/$xencfg.conf";
      $retc = cmdset($command);
      if ($retc) {
         $logger->error("cannot set max host failure");
      }
   } ## end unless ($retc)
   unless ($retc) {
      $logger->info("$ll max host failure define - set in pool config");
      my $command = "echo $mhf >/mnt/ks/pool/$pool/pool.mhf";
      $retc = cmdset($command);
      if ($retc) {
         $logger->error("cannot set max host failure in pool config");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub set_haflag

sub sr_nfs {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   my $sr     = shift();
   my $do     = shift();
   my $srv    = shift();
   my $path   = shift();
   my $shared = shift();
   my $mhf    = shift();
   unless ( defined $sr ) {
      $logger->error("sr empty");
      return 44;
   }
   unless ( defined $do ) {
      $logger->error("do empty");
      return 44;
   }
   unless ( defined $srv ) {
      $logger->error("srv empty");
      return 44;
   }
   unless ( defined $path ) {
      $logger->error("path empty");
      return 44;
   }
   unless ( defined $mhf ) {
      $logger->error("mhf empty");
      return 44;
   }
   if ( $sr ne "" ) {
      $logger->trace("$ll sr: [$sr]");
   } else {
      $logger->error("$ll sr empty");
      $retc = 44;
   }
   if ( $do ne "" ) {
      $logger->trace("$ll doing: [$do]");
   } else {
      $logger->error("$ll do empty");
      $retc = 44;
   }
   if ( $srv ne "" ) {
      $logger->trace("$ll srv: [$srv]");
   } else {
      $logger->error("$ll srv empty");
      $retc = 44;
   }
   if ( $path ne "" ) {
      $logger->trace("$ll path: [$path]");
   } else {
      $logger->error("$ll path empty");
      $retc = 44;
   }
   if ( $shared ne "" ) {
      $logger->trace("$ll shared: [$shared]");
      if ( $shared eq "ha" ) {
         $logger->info("$ll sr $sr configure as ha sr !");
         $retc = set_haflag( $sr, $mhf );
         $shared = "true";
      } elsif ( $shared eq "true" ) {
         $logger->info("$ll sr $sr configure shared");
      } elsif ( $shared eq "false" ) {
         $logger->info("$ll sr $sr configure non shared");
      } else {
         $logger->warn("$ll sr $sr unknown config [$shared] - take false");
         $shared = "false";
      }
   } else {
      $logger->error("$ll shared empty");
      $retc = 44;
   }
   $retc = create_srpath( $sr, $do, $srv, $path );
   my $hostuuid = get_hostuuid;
   if ( $hostuuid eq "" ) { $retc = 99; }
   unless ($retc) {
      $logger->debug("$ll Create sr in pool dir on nfs");
      $logger->trace("$ll    => sr: $sr");
      $logger->trace("$ll    => pool: $cfg{'pool'}");
      $logger->trace("$ll    => path: $path");
      my $cpath = $path . "/" . $cfg{'pool'} . "/" . $sr;
      $logger->debug("$ll    => complete sr path: $cpath");
      if ($vrun) {
         $logger->warn("$ll vrun mode");
         $logger->trace("$ll xe sr-create host-uuid=$hostuuid content-type=user name-label=\"$sr\" shared=$shared device-config:server=$srv device-config:serverpath=$cpath type=nfs");
         $retc = 0;
      } else {
         $retc = cmdset("xe sr-create host-uuid=$hostuuid content-type=user name-label=\"$sr\" shared=$shared device-config:server=$srv device-config:serverpath=$cpath type=nfs");
      }
   } ## end unless ($retc)
   unless ($retc) {
      $logger->info("$ll sr $sr created!");
      $logger->info("$ll change description of sr ...");
      my $cpath = $path . "/" . $cfg{'pool'} . "/" . $sr;
      my $desc  = "SR: $srv:$cpath";
      $logger->trace("$ll    => desc: $desc");
      $logger->debug("$ll    => complete sr path: $cpath");
      $retc = cmdset("xe sr-param-set uuid=\$(xe sr-list name-label=\"$sr\" --minimal) name-description=\"$desc\" ");
      unless ($retc) {
         $logger->debug("$ll changed");
      } else {
         $logger->error("error changing $sr descr. to $desc");
      }
   } else {
      $logger->error("sr $sr created failed");
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub sr_nfs

sub create_srpath {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   my $sr   = shift();
   my $do   = shift();
   my $srv  = shift();
   my $path = shift();
   if ( $sr ne "" ) {
      $logger->trace("$ll sr: [$sr]");
   } else {
      $logger->error("$ll sr empty");
      $retc = 44;
   }
   if ( $do ne "" ) {
      $logger->trace("$ll doing: [$do]");
   } else {
      $logger->error("$ll do empty");
      $retc = 44;
   }
   if ( $srv ne "" ) {
      $logger->trace("$ll srv: [$srv]");
   } else {
      $logger->error("$ll srv empty");
      $retc = 44;
   }
   if ( $path ne "" ) {
      $logger->trace("$ll path: [$path]");
   } else {
      $logger->error("$ll path empty");
      $retc = 44;
   }
   unless ($retc) {
      $logger->info("$ll check srv $srv");
      $retc = check_srv($srv);
   } else {
      $logger->error("Error during sub call - parameter mismatcht - abort");
   }
   unless ($retc) {
      $logger->info("$ll mount path $path");
      $retc = mount_path( $srv, $path );
   }
   my $poolpath;
   unless ($retc) {
      $logger->trace("$ll Pool: $cfg{'pool'}");
      $poolpath = $n_locmount . "/" . $cfg{'pool'};
      $logger->debug("$ll pool path: $poolpath");
      $retc = create_path($poolpath);
   } ## end unless ($retc)
   unless ($retc) {
      my $nfspath = $poolpath . "/" . $sr;
      $logger->debug("$ll nfs path: $nfspath");
      $logger->debug("$ll what doing ? [$do]");
      if ( $do eq "override" ) {
         $logger->info("$ll Do override - delete old if exist ...");
         $retc = delete_path($nfspath);
         unless ($retc) {
            $logger->info("$ll Create new path [$nfspath]");
            $retc = create_path($nfspath);
         }
      } elsif ( $do eq "new" ) {
         $logger->info("$ll Do new - only create if not exist ...");
         $retc = create_path($nfspath);
      } elsif ( $do eq "restore" ) {
         $logger->info("$ll Do restore - do not create new ...");
      } else {
         $logger->error("do not know what to do - override/new/resore");
         $retc = 99;
      }
   } ## end unless ($retc)
   unless ($retc) {
      $logger->info("$ll umount path $n_locmount");
      $retc = umount_path($n_locmount);
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub create_srpath

sub sr_niso {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $sr     = shift();
   my $do     = shift();
   my $srv    = shift();
   my $path   = shift();
   my $shared = shift();
   unless ( defined $sr ) {
      $logger->error("sr empty");
      return 44;
   }
   unless ( defined $do ) {
      $logger->error("do empty");
      return 44;
   }
   unless ( defined $srv ) {
      $logger->error("srv empty");
      return 44;
   }
   unless ( defined $path ) {
      $logger->error("path empty");
      return 44;
   }
   if ( $sr ne "" ) {
      $logger->trace("$ll sr: [$sr]");
   } else {
      $logger->error("$ll sr empty");
      $retc = 44;
   }
   if ( $do ne "" ) {
      $logger->trace("$ll doing: [$do]");
   } else {
      $logger->error("$ll do empty");
      $retc = 44;
   }
   if ( $srv ne "" ) {
      $logger->trace("$ll srv: [$srv]");
   } else {
      $logger->error("$ll srv empty");
      $retc = 44;
   }
   if ( $path ne "" ) {
      $logger->trace("$ll path: [$path]");
   } else {
      $logger->error("$ll path empty");
      $retc = 44;
   }
   if ( $shared ne "" ) {
      $logger->trace("$ll shared: [$shared]");
      if ( $shared eq "ha" ) {
         $logger->warn("$ll sr $sr configure ha => wrong, change to false");
         $shared = "true";
      } elsif ( $shared eq "true" ) {
         $logger->info("$ll sr $sr configure shared");
      } elsif ( $shared eq "false" ) {
         $logger->info("$ll sr $sr configure non shared");
      } else {
         $logger->warn("$ll sr $sr unknown config [$shared] - take false");
         $shared = "false";
      }
   } else {
      $logger->warn("$ll shared empty - use false");
      $shared = "false";
   }
   $retc = create_srpath( $sr, $do, $srv, $path );
   my $hostuuid = get_hostuuid;
   if ( $hostuuid eq "" ) { $retc = 99; }
   unless ($retc) {
      $logger->debug("$ll Create sr in pool dir on nfs");
      $logger->trace("$ll    => sr: $sr");
      $logger->trace("$ll    => pool: $cfg{'pool'}");
      $logger->trace("$ll    => path: $path");
      my $cpath = $path . "/" . $cfg{'pool'} . "/" . $sr;
      $logger->debug("$ll    => complete sr path: $cpath");
      if ($vrun) {
         $logger->warn("$ll vrun mode");
         $logger->trace("$ll xe sr-create host-uuid=$hostuuid content-type=iso type=iso name-label=\"$sr\" shared=$shared device-config:location=$srv:$cpath");
         $retc = 0;
      } else {
         $retc = cmdset("xe sr-create host-uuid=$hostuuid content-type=iso type=iso name-label=\"$sr\" shared=$shared device-config:location=$srv:$cpath");
      }
   } ## end unless ($retc)
   unless ($retc) {
      $logger->info("$ll sr $sr created!");
      $logger->info("$ll change description of sr ...");
      my $cpath = $path . "/" . $cfg{'pool'} . "/" . $sr;
      my $desc  = "SR: $srv:$cpath";
      $logger->trace("$ll    => desc: $desc");
      $logger->debug("$ll    => complete sr path: $cpath");
      $retc = cmdset("xe sr-param-set uuid=\$(xe sr-list name-label=\"$sr\" --minimal) name-description=\"$desc\" ");
      unless ($retc) {
         $logger->debug("$ll changed");
      } else {
         $logger->error("error changing $sr descr. to $desc");
      }
   } else {
      $logger->error("sr $sr created failed");
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub sr_niso

sub create_sr {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $conffile = shift();
   my $retc     = 0;
   my $sr;
   my $typ;
   my $conf;
   my %config;
   my $do;
   my $srv;
   my $path;
   my $mhf;
   my $srdefault;

   if ( $conffile ne "" ) {
      $logger->debug("$ll check if config file exist");
      if ( -e $conffile ) {
         $logger->info("$ll found $conffile");
         $logger->trace("$ll get all config from $conffile");
         $conf = new Config::General("$conffile");
         $logger->debug("$ll Get all xenserver configurations ...");
         %config = $conf->getall;
         foreach $sr ( keys %{ $config{'storage'} } ) {
            $logger->debug("$ll ===> sr found: [$sr]");
            $logger->info("$ll read config for $sr");
            if ( defined $config{'storage'}{$sr}{'typ'} ) {                                                                        # which type of storage
               $typ = $config{'storage'}{$sr}{'typ'};
               if ( $typ eq "nfs" ) {
                  $logger->info("$ll nfs storage [$sr] found");
                  if ( defined $config{'storage'}{$sr}{'do'} ) {
                     $do = $config{'storage'}{$sr}{'do'};
                     if ( $do eq "new" ) {
                        $logger->trace("$ll create new sr and leave old one");
                     } elsif ( $do eq "override" ) {
                        $logger->trace("$ll create new sr and delete all other");
                     } elsif ( $do eq "restore" ) {
                        $logger->trace("$ll create new and if old exist restore");
                     } elsif ( $do eq "old" ) {
                        $logger->trace("$ll do not create new - take only old one");
                     } else {
                        $logger->error("unknown do [$do} - abort");
                        $retc = 99;
                        last;
                     }
                  } else {
                     $logger->debug("no doing define - take default new");
                     $do = "new";
                  }
                  if ( defined $config{'storage'}{$sr}{'srv'} ) {
                     $srv = $config{'storage'}{$sr}{'srv'};
                  } else {
                     $logger->error("no server define - abort");
                     $retc = 99;
                     last;
                  }
                  if ( defined $config{'storage'}{$sr}{'path'} ) {
                     $path = $config{'storage'}{$sr}{'path'};
                  } else {
                     $logger->error("no path define - abort");
                     $retc = 99;
                     last;
                  }
                  if ( defined $config{'storage'}{$sr}{'mhf'} ) {
                     $mhf = $config{'storage'}{$sr}{'mhf'};
                     $logger->debug("$ll mhf: $mhf");
                  } else {
                     $mhf = 0;
                     $logger->debug("$ll mhf: - none -");
                  }
                  if ( defined $config{'storage'}{$sr}{'shared'} ) {
                     $retc = sr_nfs( $sr, $do, $srv, $path, $config{'storage'}{$sr}{'shared'}, $mhf );
                  } else {
                     $logger->debug("$ll no shared key found - default no");
                     $retc = sr_nfs( $sr, $do, $srv, $path, "no", $mhf );
                  }
                  $logger->trace("$ll nfs [$sr] config end rc=$retc");
               } elsif ( $typ eq "niso" ) {
                  $logger->info("$ll nfs iso storage [$sr] found");
                  if ( defined $config{'storage'}{$sr}{'do'} ) {
                     $do = $config{'storage'}{$sr}{'do'};
                     if ( $do eq "new" ) {
                        $logger->trace("$ll create new sr and leave old one");
                     } elsif ( $do eq "override" ) {
                        $logger->trace("$ll create new sr and delete all other");
                     } elsif ( $do eq "restore" ) {
                        $logger->trace("$ll create new and if old exist restore");
                     } elsif ( $do eq "old" ) {
                        $logger->trace("$ll do not create new - take only old one");
                     } else {
                        $logger->error("unknown do [$do} - abort");
                        $retc = 99;
                        last;
                     }
                  } else {
                     $logger->debug("$ll no doing define - take default new");
                     $do = "new";
                  }
                  if ( defined $config{'storage'}{$sr}{'srv'} ) {
                     $srv = $config{'storage'}{$sr}{'srv'};
                  } else {
                     $logger->error("no server define - abort");
                     $retc = 99;
                     last;
                  }
                  if ( defined $config{'storage'}{$sr}{'path'} ) {
                     $path = $config{'storage'}{$sr}{'path'};
                  } else {
                     $logger->error("no path define - abort");
                     $retc = 99;
                     last;
                  }
                  $logger->trace("$ll nfs iso [$sr] config read end");
                  $retc = sr_niso( $sr, $do, $srv, $path, $config{'storage'}{$sr}{'shared'} );
               } elsif ( $typ eq "ciso" ) {
                  $logger->warn("$ll cifs iso storage not supported - ignore");
                  next;
               } elsif ( $typ eq "iscsi" ) {
                  $logger->warn("$ll iscsi not supported - ignore");
                  next;
               } elsif ( $typ eq "ext" ) {
                  $logger->warn("$ll local ext not supported - ignore");
                  next;
               } elsif ( $typ eq "lvm" ) {
                  $logger->warn("$ll lvm not supported - ignore");
                  next;
               } else {
                  $logger->error("unknown storage typ - abort");
                  $retc = 99;
                  last;
               }
               unless ($retc) {
                  if ( defined $config{'storage'}{$sr}{'default'} ) {
                     $srdefault = $config{'storage'}{$sr}{'default'};
                     $logger->debug("$ll sr default set");
                     if ( "$srdefault" eq "true" ) {
                        $logger->debug("$ll  default sr found");
                        $retc = set_defaultsr($sr);
                     } elsif ( "$srdefault" eq "false" ) {
                        $logger->debug("$ll  set to NOT default sr found");
                     } else {
                        $logger->warn("$ll wrong default perameter for sr [$srdefault]");
                     }
                  } else {
                     $logger->debug("$ll default not set - not default sr");
                  }
               } ## end unless ($retc)
            } else {
               $logger->warn("$ll no storage typ given - ignore");
               next;
            }
            if ( $retc ) {
               $logger->error("error retc=$retc");
               last;
            }
         } ## end foreach $sr ( keys %{ $config{'storage'} } )
         unless ( $retc ) {
            $logger->debug("$ll all storage blocks processed");
         } else {
            $logger->error("abort storage creation");
         }
      } else {
         $logger->error("no config file [$conffile] found - abort");
         $retc = 99;
      }
   } else {
      $logger->error("empty config parameter - abort");
      $retc = 99;
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub create_sr

# ----------------------------------[ main ]----------------------------------
my $counter = 0;
my $mode    = "none";
my $usage   = "\nPrograme: $prg \nVersion: $ver\nDescript.: configure xenserver sr\n\nparameter: --mode [member/master/standalone]\n           --pool [poolname] \n\n";
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
   } elsif ( $ARGS[ $counter ] =~ /^--pool$/ ) {
      $counter++;
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         $pool = $ARGS[ $counter ];
         chomp($mode);
         $pool =~ s/\n|\r//g;
      } else {
         $logger->error("The argument after --pool was not correct - ignore!");
         $counter--;
      }
   } else {
      $logger->warn(" Unknown option [$ARGS[$counter]]- ignore");
   }
} ## end for ( $counter = 0 ; $counter < $numargv ; $counter++ )
$logger->info(" Mode: $mode");
if ( $pool ne "none" ) {
   $logger->debug(" Pool: $pool");
}
if ( $mode ne "none" ) {
   $retc=read_config($confxen,\%cfg);
} else {
   $logger->error("no mode set - abort");
   $retc = 100;
}
unless ($retc) {
   if ( $mode eq "master" || $mode eq "standalone" ) {
      if ( -e $poolfile ) {
         $logger->info(" Work on pool config ...");
         $retc = create_sr($poolfile);
      } else {
         $logger->error("master mode, but no pool config - something wrong - abort");
         $retc = 99;
      }
   } else {
      $logger->info(" member need no pool config");
   }
   unless ($retc) {
      if ( $mode eq "master" || $mode eq "standalone" || $mode eq "member" ) {
         if ( -e $conffile ) {
            $logger->info(" Work on xenserver config ...");
            $retc = create_sr($conffile);
         } else {
            $logger->error("No network config exist - what happens here ?");
            $retc = 99;
         }
      } else {
         $logger->error("unknown mode - abort");
         $retc = 100;
      }
   } ## end unless ($retc)
} ## end unless ($retc)
unless ($retc) {
   $logger->info(" all storage repositories configure successful");
} else {
   $logger->error("something wrong - see log file for more detailed errors");
   if ( $retc == 1 ) {
      $logger->error("err code 1 mean only reboot - set to 999");
      $retc = 999;
   }
} ## end else
$logger->debug("retc= $retc");
$logger->info("End $prg - v.$ver rc=$retc");
exit($retc);
__END__

