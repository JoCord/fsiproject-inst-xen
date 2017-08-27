#!/bin/sh
#
#   sub_33_lic.sh - register lic
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
licsrv="none"
licport=27000
liced="none"

ver="1.0.7 - 5.7.2016"
retc=0
ls=""
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


infmsg "$ls Configure license v.$ver"

debmsg "$ls lic server: $licsrv"
if [ "$licsrv" != "none" ] ; then
    infmsg "$ls  found lic server $licsrv"
    if [ $liced == "none" ] ; then
        warnmsg "$ls   no lic edition given - no xen reg"
    else 
        infmsg "$ls  lic server port $licport"
        infmsg "$ls  set xenserver to lic server ..."
        cmd="xe host-apply-edition host-uuid=$HOSTuuid edition=$liced license-server-address=$licsrv license-server-port=$licport"
        tracemsg "$ls cmd: $cmd"
        OUTPUT=$(2>&1 $cmd)
        retc=$?
        if [ $retc -ne 0 ]; then
            errmsg "cannot register lic [$OUTPUT] - abort $retc"
            if [ $retc -eq 1 ]; then
               errmsg "change from rc=1 to 99 - abort !"
               retc=99
            fi
        else
            infmsg "$ls  host successful register lic"
        fi   
    fi
else
    warnmsg "$ls  no license server set in config file - ignore"
fi

infmsg "$ls End lic routine rc=$retc"
exit $retc



