#!/bin/sh
#
#   sub-51_pool_create-default.sh - create pool
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
HOSTuuid="none"
pool="none"

ver="1.0.4 - 14.10.2013"
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

infmsg "$ls Create pool on master xenserver v.$ver"

if [ "$HOSTuuid" == "none" ]; then
    errmsg "no HOSTuuid found - abort"
    retc=99
fi

if [ "$pool" == "none" ]; then
    errmsg "no pool found - abort"
    retc=99
fi

if [ $retc -eq 0 ]; then
    infmsg "$ls  set pooluuid"
    POOLUUID=`xe pool-list --minimal`
    if [ $? -ne 0 ]; then
       errmsg "cannot get poolid - abort"
       retc=88
    else
       infmsg "$ls  pooluuid ok"
    fi 
fi

if [ "$debug" == "sleep" ] ; then sleep 5 ; fi
    
if [ $retc -eq 0 ]; then
    infmsg "$ls set pool parameter"
    OUTPUT=$(2>&1 xe pool-param-set uuid=$POOLUUID name-label=$pool)
    retc=$?
    if [ $retc -ne 0 ]; then
      errmsg "cannot set pool parameter $OUTPUT - abort"
      retc=89
    else
        infmsg "$ls  set ok"
    fi   
fi
             
if [ $retc -eq 0 ]; then
   infmsg "$ls  join host"
   OUTPUT=$(2>&1 xe host-param-add uuid=$HOSTuuid param-name=tags param-key=Poolmaster)
   retc=$?
   if [ $retc -ne 0 ]; then
     errmsg "cannot tag pool master [$OUTPUT] - abort"
     retc=89
   else
     infmsg "$ls  tag pool master ok"
   fi   
fi


infmsg "$ls End create pool routine rc=$retc"
exit $retc         

