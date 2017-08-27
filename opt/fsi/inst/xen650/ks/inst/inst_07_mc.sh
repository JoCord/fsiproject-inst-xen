#!/bin/sh
#
#   inst_07_mc.sh - install mc
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
inst_mc=""

ver="1.0.6 - 13.9.2016"
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

if [ -f $fsivars ] ; then
    . $fsivars
else
   errmsg "ERROR cannot load fsi vars $fsivars"
   exit 99
fi

infmsg "$ls Install mc"

if [ "$inst_mc" == "true" ] || [ "$inst_mc" == "yes" ]; then
   infmsg "$ls  call rpm install routine"

   MC_OUTPUT=$(2>&1 yum -y install mc)
   if [ $? -ne 0 ]; then
      errmsg "error rpm install: $MC_OUTPUT - abort"
      retc=99
   else
      infmsg "$ls  install rpm ok"
      infmsg "$ls  create config dir"
      MD_OUTPUT=$(2>&1 mkdir /root/.mc)
      if [ $? -ne 0 ]; then
         errmsg "creating mc config dir: $MD_OUTPUT - abort"
         retc=97
      else
         infmsg "$ls  config dir created"
         infmsg "$ls  copy mc settings in config dir"
         CP_OUTPUT=$(2>&1 cp -f $kspath/rpm/ini.mc /root/.mc/ini)
         if [ $? -ne 0 ]; then
            errmsg "creating mc config dir: $CP_OUTPUT - abort"
            retc=98
         else
            infmsg "$ls  mc settings copy ok"
         fi
      fi
   fi
else
   infmsg "$ls  config mc flag not found - no installation needed"
fi

infmsg "$ls End mc installation rc=$retc "
exit $retc