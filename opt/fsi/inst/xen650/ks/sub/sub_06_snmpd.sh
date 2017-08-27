#!/bin/sh
#
#   sub_06_snmpd.sh - config
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

infmsg "$ls Set SNMPD Daemon Config v.$ver"

if [ $retc -eq 0 ]; then
    infmsg "$ls  set snmpd options now ..."
    OUTPUT=$(2>&1 echo OPTIONS=\"-Lf /dev/null -p /var/run/snmpd.pid\" >>/etc/sysconfig/snmpd.options)
    if [ $? -ne 0 ]; then
       errmsg "cannot set snmpd options $OUTPUT - abort"
       retc=99
    else
        infmsg "$ls  set snmpd options ok"
    fi
fi

infmsg "$ls End Set SNMPD Daemon Config rc=$retc"
exit $retc
