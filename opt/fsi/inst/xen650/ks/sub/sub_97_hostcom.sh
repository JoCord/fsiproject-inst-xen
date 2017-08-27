#!/bin/sh
#
#   sub_97_hostcom.sh - set host comment
#
#   This program is free software; you can redistribute it and/or modify it under the 
#   terms of the GNU General Public License as published by the Free Software Foundation;
#   either ver 3 of the License, or (at your option) any later ver.
#
#   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
#   without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
#   See the GNU General Public License for more details.
#  
#   You should have received a copy of the GNU General Public License along with this program; 
#   if not, see <http://www.gnu.org/licenses/>.
#
hostcomment="none"
HOSTuuid="none"

ver="1.0.2 - 14.10.2013"
retc=0
ls="    "
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

infmsg "$ls Set Host Comments v.$ver"

if [ $retc -eq 0 ]; then
    if [ "$hostcomment" = "none" ] ; then
        hostcomment=" ==> comment not configure "
    fi
    infmsg "$ls  host comment: $hostcomment"
fi

if [ $retc -eq 0 ]; then
    if [ "$HOSTuuid" = "none" ] ; then
        errmsg "no host uuid found - abort"
        restc=97
    fi
fi

if [ $retc -eq 0 ]; then
    infmsg "$ls  set host comment now ..."
    debmsg "$ls  Host uuid: $HOSTuuid"
    debmsg "$ls  Host comment: $hostcomment"
    tracemsg "$ls  xe host-param-set uuid=$HOSTuuid name-description=$hostcomment"
    OUTPUT=$(2>&1 xe host-param-set uuid=$HOSTuuid name-description="$hostcomment")
    if [ $? -ne 0 ]; then
       errmsg "cannot set host comment $OUTPUT - abort"
       retc=99
    else
        infmsg "$ls  set host comment ok"
    fi
fi

infmsg "$ls End Set Host Comments rc=$retc"
exit $retc
