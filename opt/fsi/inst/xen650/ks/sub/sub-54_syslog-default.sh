#!/bin/sh
#
#   sub_30-syslog-default.sh - configure default syslog server
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
syslogsrv="none"

ver="1.0.6 - 20.07.2016"
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

infmsg "$ls Run default Syslog-Settings v.$ver"

if [ "$syslogsrv" != "none" ]; then
   infmsg "$ls  set syslog parameter"
   tracemsg "$ls   xe host-param-set uuid=$HOSTuuid logging:syslog_destination=$syslogsrv"
   OUTPUT=$(2>&1 xe host-param-set uuid=$HOSTuuid logging:syslog_destination=$syslogsrv)
   retc=$?
   if [ $retc -ne 0 ]; then
      errmsg "cannot set syslog $OUTPUT - abort"
   else
      infmsg "$ls   syslog set ok"
   fi
   
   if [ $retc -eq 0 ]; then
      infmsg "$ls  reconfigure host"
      tracemsg "$ls   xe host-syslog-reconfigure host-uuid=$HOSTuuid"
      OUTPUT=$(2>&1 xe host-syslog-reconfigure host-uuid=$HOSTuuid)
      retc=$?
      if [ $retc -ne 0 ]; then
         errmsg "cannot syslog reconfigure host $OUTPUT - abort"
      else
         infmsg "$ls  syslog reconfigured ok"
      fi
   fi
else
   infmsg "$ls  no syslog server configure - ignore"
fi

if [ $retc -eq 0 ]; then
   infmsg "$ls End default Syslog Config end rc=$retc"
elif [ $retc -eq 1 ]; then
    tracemsg "   rc=1 means reboot, change to 2"
    retc=2
    errmsg "$ls End default Syslog Config with rc=$retc"
else
    errmsg "$ls End default Syslog Config with rc=$retc"
fi      

exit $retc  
   
