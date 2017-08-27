#!/bin/sh
#
#   sub_07_banner.sh - if banner configure write down
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
banner="none"

ver="1.0.1 - 7.3.2016"
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



infmsg "$ls Set banner v.$ver"

if [ $retc -eq 0 ]; then
   infmsg "$ls  banner configure ?"
   if [ "$banner" == "none" ]; then
      infmsg "$ls  no banner configure - ignore"
   else
      infmsg "$ls  banner configure - set it now ..."
      
      OLD_IFS=$IFS
      IFS=""
      OUTPUT=$(2>&1 echo $banner >/etc/ssh/banner)
      if [ $? -ne 0 ]; then
         errmsg "cannot create banner file $OUTPUT - abort"
         retc=99
      else
         infmsg "$ls  banner ok"
      fi
      IFS=$OLD_IFS
      
      if [ $retc -eq 0 ]; then
         infmsg "$ls  set banner active ..."
         OUTPUT=$(2>&1 echo Banner /etc/ssh/banner >>/etc/ssh/sshd_config)
         if [ $? -ne 0 ]; then
            errmsg "cannot activate banner in ssh config $OUTPUT - abort"
            retc=99
         else
            infmsg "$ls  banner in sshd config activ"
         fi
      fi      
   fi
fi

infmsg "$ls End set banner config rc=$retc"
exit $retc
