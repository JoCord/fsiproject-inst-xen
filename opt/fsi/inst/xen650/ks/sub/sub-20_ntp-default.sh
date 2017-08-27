#!/bin/sh
#
#   sub-20_ntp-default.sh - ntp default config
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
ntpsrv="none"                                                       # ntp server for default config

ver="1.0.4 - 02.03.2017"
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

infmsg "$ls Configure default NTP Installation v.$ver"

infmsg "$ls   stop ntp service first"
OUTPUT=$(2>&1 service ntpd stop)
retc=$?
if [ $retc -ne 0 ]; then
   errmsg "cannot stop ntpd dameon"
else
   infmsg "$ls   config ntpd to start at boot"
   OUTPUT=$(2>&1 chkconfig --level 345 ntpd on)
   retc=$?
   if [ $retc -ne 0 ]; then
      errmsg "cannot set startoption for service $OUTPUT - abort"
   else
      infmsg "$ls   startoption set ok"
      infmsg "$ls   delete empty and comment lines in ntp.conf"
      OUTPUT=$(sed -i -e 's/#.*$//' -e '/^$/d' /etc/ntp.conf)
      retc=$?
      if [ $retc -eq 0 ]; then
         infmsg "$ls   ok"
         infmsg "$ls   restart ntpd service"      
         OUTPUT=$(2>&1 service ntpd start)
         retc=$?
         if [ $retc -ne 0 ]; then
             errmsg "cannot restart ntpd service $OUTPUT - abort"
         else
             infmsg "$ls   ntpd restarted"
         fi
      else
            errmsg "ntp.conf not created - abort"
            retc=2
       fi
   fi
fi

if [ $retc -eq 0 ]; then
   infmsg "$ls Configure NTP end rc=$retc"
elif [ $retc -eq 1 ]; then
   tracemsg "   rc=1 means reboot, change to 2"
   retc=2
   errmsg "End configure NTP with rc=$retc"
else
   errmsg "End configure NTP with rc=$retc"
fi      

exit $retc     
