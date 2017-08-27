#!/bin/sh
#
#   sub_70_ha.sh - create ha
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
ver="1.0.1 - 14.10.2013"
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

infmsg "$ls Create HA v.$ver"

if [ "$insttyp" == "master" ] || [ "$insttyp" == "member" ]; then  
    if [ "$xenenv" != "none" ] ; then
      sysconf="/tmp/sub-70_ha-$xenenv.sh"
      infmsg "  search for ha script for environement "
      infmsg "  script: $sysconf"
      if [ -f $sysconf ] ; then
           infmsg "  found env script - run it"
           $sysconf
           retc=$?
           if [ $retc -eq 0 ]; then
               infmsg "  ha successful configure"
           elif [ $retc -eq 1 ]; then
               infmsg "  creating ha successful - reboot needed"
           else
               errmsg "error creating ha - abort $retc"
           fi      
      else
        sysconf="/tmp/sub-70_ha-default.sh"
        infmsg "  search for default ha script "
        infmsg "  script: $sysconf"       
        if [ -f $sysconf ] ; then
           infmsg "  found ha default script - run it"
           /usr/bin/perl $sysconf
           retc=$?
           if [ $retc -eq 0 ]; then
               infmsg "  creating ha successful end"
           elif [ $retc -eq 1 ]; then
               infmsg "  creating ha successful - reboot needed"
           else
               errmsg "error creating ha - abort $retc"
           fi          
        else
          warnmsg "   no ha script found for [$xenenv] or default"
        fi
      fi
    else
      warnmsg "   unknown vi environment"
    fi
else
    infmsg "$ls  stand alone ? Need no ha action"
fi

infmsg "$ls End HA routine rc=$retc"
exit $retc



