#!/bin/sh
#
#   inst_05_dmidecode.sh - install dmidecode
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

infmsg "$ls Install xapi plugin dmidecode"

if [ -z $kspath ]; then
    errmsg "ks path empty - abort"
    retc=99
fi

if [ $retc -eq 0 ]; then
    infmsg "$ls  copy dmidecode "
    CP_OUTPUT=$(2>&1 cp -f $kspath/rpm/dmidecode /etc/xapi.d/plugins/)
    if [ $? -ne 0 ]; then
       errmsg "copy dmidecoe: $CP_OUTPUT - abort"
       retc=98
    else
       infmsg "$ls  dmidecod install ok"
    fi
fi

if [ $retc -eq 0 ]; then
    infmsg "chmod dmidecode script"
    OUTPUT=$(2>&1 chmod +x /etc/xapi.d/plugins/dmidecode)
    if [ $? -ne 0 ]; then
       errmsg "cannot chmod dmidecode script $OUTPUT - abort"
       retc=1
    fi 
fi

infmsg "End xapi plugin installation rc=$retc "
exit $retc



