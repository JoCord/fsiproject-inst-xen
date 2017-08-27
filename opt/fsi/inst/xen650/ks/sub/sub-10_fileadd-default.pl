#!/usr/bin/perl -w
# 
#   sub-10_fileadd-default.pl - add hosts entries
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
our $ver = "1.0.5 - 28.8.2015";
my $retc = 0;
my $ll = " ";

use strict;
use warnings;
use FindBin qw($Bin);
my $fsidir="/var/fsi";
use lib "/var/fsi/module";
use Config::General;
use English;

our $flvl = 0;                                                                                   # function level
my $logconf = "$fsidir/log.cfg";
my $logfile = "$fsidir/fsixeninst.log";

open my $file, '<', "/etc/redhat-release"; 
my $redhatrel = <$file>; 
close $file;
my ($xenmain) = $redhatrel =~ /(\d+)/;   
my $xencfg = "xen$xenmain";

my $conffile = "$fsidir/$xencfg.pool";

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


sub addline {
   my $fc=(caller(0))[3];
   $flvl++;
   my $ll=" " x $flvl;

   my $line = shift();
   my $file = shift();
   
   $logger->trace("$ll func start: [$fc]");   
   $logger->info("$ll  search xen pool conf");
   
   $retc=cmdset("echo $line >>$file");
   unless ( $retc ) {
      $logger->debug("$ll  add ok");
   } else {
      $logger->error("cannot add [$line] to [$file]");
   }

   $logger->trace("$ll func end: [$fc] rc: [$retc]");   
   $flvl--;
   return($retc);
}

sub delfile {
   my $fc=(caller(0))[3];
   $flvl++;
   my $ll=" " x $flvl;

   $logger->trace("$ll func start: [$fc]");   
   $logger->info("$ll  search xen pool conf");
   
   my $file = shift();
   my $retc=0;
   
   $logger->debug("$ll del file $file");
   unless (unlink ($file)) {
      $logger->error("deleting " . $file . "[$!]");
   } else {
      $logger->info("$ll deleted!");
   }


   $logger->trace("$ll func end: [$fc] rc: [$retc]");   
   $flvl--;
   return($retc);
}


sub add_entries {
   my $fc=(caller(0))[3];
   $flvl++;
   my $ll=" " x $flvl;

   $logger->trace("$ll func start: [$fc]");   
   $logger->info("$ll  search xen pool conf");
   
   my $conf;
   my %config;
   my $file;
   my $line;
   my $delfile="add";
   my $retc=0;

   if ( -e $conffile ) {
      $logger->info("$ll  found $conffile");
      $logger->trace("$ll  get all config from $conffile");
      $conf = new Config::General("$conffile");
      $logger->debug("$ll  Get all xenserver configurations ...");
      %config = $conf->getall;

      foreach $file (keys %{$config{'fileadd'}} ) {
         $logger->info("$ll  found file add config $file");
         
         if ( defined $config{'fileadd'}{$file}{'file'} ) {
            $delfile=$config{'fileadd'}{$file}{'file'};
            $logger->debug("$ll  found file tag [$delfile]");   
         } else {
            $logger->debug("$ll  no file tag found - take default [$delfile]");
         }

         if ( $delfile eq "new" ) {
            $retc=delfile($file);
         }
         
         unless ( $retc ) {
            foreach $line (keys %{$config{'fileadd'}{$file}{'line'}} ) {
               $logger->debug("$ll  found add line definition [$line]");
               if ( -e $file ) {
                  $logger->info("$ll  existing file $file");
                  my $command="grep -q \"^$line\" $file";
                  $logger->trace("$ll  command: $command");
                  my $eo = qx($command 2>&1);
                  my $filexist = $?;
                  $logger->trace("$ll  file exist rc: $filexist");
                  unless ( $filexist ) {
                     $logger->info("$ll  line already exist in file");
                  } else {
                     $logger->debug("$ll  add line:[$line] to file:[$file]");
                     $retc=addline($line,$file);
                  }
               } else {
                  $logger->info("$ll  new file $file");
                  $logger->debug("$ll  add line:[$line] to file:[$file]");
                  $retc=addline($line,$file);
               }
            }
         } else {
            $logger->error("Cannot delete file: $file");
         }
      }
       
   } else {
      $logger->error("no config file $conffile found - abort");
      $retc=88;
   }
 
   $logger->trace("$ll func end: [$fc] rc: [$retc]");   
   $flvl--;
   return($retc);
}



# main

$retc=add_entries;

unless ( $retc ) {
   $logger->info(" all entries added");
} else {
   $logger->error("something wrong - see log file for more detailed errors");
}

$logger->info("End $prg - v.$ver rc=$retc");
exit ($retc);


__END__

