#!/bin/sh
#
#   sub_42_network.sh - create network
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
ver="1.0.8 - 20.7.2016"
retc=0
ls="  "
progname=${0##*/}
SOURCE="${BASH_SOURCE[0]}"
DIR="$( dirname "$SOURCE" )"
while [ -h "$SOURCE" ]; do 
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
done
export progdir="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
if [ -z $fsifunc ]; then export fsifunc="/usr/bin/fsifunc.sh"; fi
if [ -f $fsifunc ]; then
   . $fsifunc
   . $fsivars
else
   echo "ERROR cannot load fsi functions $fsifunc"
   exit 99
fi
export logfile="$fsidir/fsixeninst.log"

infmsg "$ls Configure network v.$ver"
infmsg "$ls   inst type: [$insttyp]"

if [ "$xenenv" != "none" ] ; then
  sysconf="/tmp/sub-42_network-$xenenv.pl"
  infmsg "$ls   search for network script for environement "
  infmsg "$ls   script: $sysconf"
  if [ -f $sysconf ] ; then
       infmsg "$ls   found env script - run it"
       /usr/bin/perl $sysconf --mode $insttyp
       retc=$?
       if [ $retc -eq 0 ]; then
           infmsg "$ls   creating network successful end"
       elif [ $retc -eq 1 ]; then
           infmsg "$ls   creating network successful - reboot needed"
       else
           errmsg "error creating network - abort $retc"
       fi      
  else
    sysconf="/tmp/sub-42_network-default.pl"
    if [ -f $sysconf ] ; then
       infmsg "$ls   found network default script - run it"
       /usr/bin/perl $sysconf --mode $insttyp 
       retc=$?
       if [ $retc -eq 0 ]; then
           infmsg "$ls   creating network successful end"
       elif [ $retc -eq 1 ]; then
           infmsg "$ls   creating network successful - reboot needed"
       else
           errmsg "error creating network - abort $retc"
       fi          
    else
      warnmsg "$ls   no network script found for [$xenenv] or default"
    fi
  fi
  if [ $retc -eq 0 ]; then
     if [ "$insttyp" == "member" ]; then
        infmsg "$ls   member need patch for dns search"
        /usr/bin/fsiaddsearch $dnsdom sub
        retc=$?
        if [ $retc -eq 0 ]; then
           infmsg "$ls   dns search changed"
        else
           errmsg "$ls   cannot set dns search"
        fi
     fi
   fi
else
  warnmsg "$ls   unknown vi environment"
fi

infmsg "$ls End finish routine rc=$retc"
exit $retc

