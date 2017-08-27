#!/bin/sh
#
#   sub_51_pool_create.sh - create pool 
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
ver="1.0.5 - 14.10.2013"
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


infmsg "Create pool v.$ver"

if [ "$insttyp" == "master" ] ; then  
    if [ "$xenenv" != "none" ] ; then
      sysconf="/tmp/sub-51_pool_create-$xenenv.sh"
      infmsg "  search for pool script for environement "
      infmsg "  script: $sysconf"
      if [ -f $sysconf ] ; then
           infmsg "  found env script - run it"
           $sysconf
           retc=$?
           if [ $retc -eq 0 ]; then
               infmsg "  creating pool successful end"
           elif [ $retc -eq 1 ]; then
               infmsg "  creating pool successful - reboot needed"
           else
               errmsg "error creating pool - abort $retc"
           fi      
      else
        sysconf="/tmp/sub-51_pool_create-default.sh"
        if [ -f $sysconf ] ; then
           infmsg "  found pool default script - run it"
           /usr/bin/perl $sysconf
           retc=$?
           if [ $retc -eq 0 ]; then
               infmsg "  creating pool successful end"
           elif [ $retc -eq 1 ]; then
               infmsg "  creating pool successful - reboot needed"
           else
               errmsg "error creating pool - abort $retc"
           fi          
        else
          warnmsg "   no pool script found for [$xenenv] or default"
        fi
      fi
    else
      warnmsg "   unknown vi environment"
    fi
elif [ "$insttyp" == "member" ] ; then
    infmsg "$ls  a member do not create pool - already joined"
else
    infmsg "$ls  stand alone ? Need no pool action"
fi

infmsg "$ls End finish routine rc=$retc"
exit $retc



