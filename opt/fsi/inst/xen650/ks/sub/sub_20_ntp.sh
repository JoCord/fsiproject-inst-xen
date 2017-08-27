#!/bin/sh
#
#   sub_20_ntp.sh - ntp config
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
ver="1.0.6 - 7.3.2016"
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

infmsg "$ls Configure NTP Installation v.$ver"

if [ "$xenenv" != "none" ] ; then
  sysconf="/tmp/sub-20_ntp-$xenenv.sh"
  infmsg "$ls  search for time srv config for environement [$xenenv]"
  infmsg "$ls  script: [$sysconf]"
  if [ -f $sysconf ] ; then
      infmsg "$ls  found env script - run it"
      $sysconf
      retc=$?
      if [ $retc -eq 0 ]; then
         infmsg "$ls  env script end"
      else
         errmsg "env script ended with rc $retc"
      fi    
  else
    sysconf="/tmp/sub-20_ntp-default.sh"
    if [ -f $sysconf ] ; then
       infmsg "$ls  found ntp default script - run it"
       $sysconf
       retc=$?
       if [ $retc -eq 0 ]; then
          infmsg "$ls  env script end"
       else
          errmsg "env script ended with rc $retc"
       fi    
    else
      warnmsg "$ls  no ntp script found for [$xenenv] or default"
    fi
  fi
else
  warnmsg "$ls  unknown vi environment, no ntp config"
fi
infmsg "$ls End NTP config"