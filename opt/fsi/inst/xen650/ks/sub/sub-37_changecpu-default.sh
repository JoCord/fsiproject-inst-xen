#!/bin/sh
#
#   set cpu mask
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
cpumask="none"
reboot=0

ver="1.0.6 - 01.02.2017"
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

infmsg "$ls Run Change CPU Mask v.$ver"

if [ "$cpumask" != "none" ]; then
   infmsg "$ls  set cpu mask parameter found [$cpumask]"

   tracemsg "$ls   xe host-set-cpu-features features=$cpumask"
   OUTPUT=$(2>&1 xe host-set-cpu-features features=$cpumask)
   retc=$?
   if [ $retc -ne 0 ]; then
      errmsg "cannot set cpu mask [$OUTPUT] - abort"
   else
      activmask=$(xe host-cpu-info --minimal)
      if [ "$activmask" == "$cpumask" ]; then
         infmsg "$ls   set cpu mask ok - set reboot"
         reboot=1
      else
         errmsg "the new cpu mask is not the same we set before - abort"
         retc=99
      fi
   fi
else
   infmsg "$ls  no cpu mask found in config - ignore"
fi

if [ $retc -eq 0 ]; then
   infmsg "$ls End change cpu mask rc=$retc"
   if [ $reboot -eq 1 ]; then
      infmsg "$ls   change cpu mask needs reboot - set rc=1"
      retc=1
   fi
elif [ $retc -eq 1 ]; then
    tracemsg "   rc=1 means reboot, change to 2"
    retc=2
    errmsg "End change cpu mask with rc=$retc"
else
    errmsg "End change cpu mask with rc=$retc"
fi      

exit $retc  
   
