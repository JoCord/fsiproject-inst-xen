#!/bin/sh
#
#   inst_04_bin.sh - install bind utils
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
xensource="none"

ver="1.0.6 - 03.03.2017"
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

if [ -f $fsivars ] ; then
    . $fsivars
else
   errmsg "ERROR cannot load fsi vars $fsivars"
   exit 99
fi

infmsg "$ls Install bind utils"

if [ "$xensource" == "none" ]; then
   errmsg "no xensource given - abort"
   retc=88
fi

if [ $retc -eq 0 ]; then
   
   infmsg "$ls   remove repos"
   OUTPUT=$(2>&1 rm -f /etc/yum.repos.d/*)
   if [ $? -ne 0 ]; then
      errmsg "cannot delete old repos: $OUTPUT - abort"
      retc=99
   else
      infmsg "$ls   ok"
   fi
fi

if [ $retc -eq 0 ]; then
   infmsg "$ls   set new centos repo"

   cat > /etc/yum.repos.d/CentOS-Base.repo <<EOF2
[fsi]
name=CentOS 
baseurl=file:///mnt/ks/yum
enabled=1
exclude=kernel-xen*,*xen*
gpgcheck=0

EOF2
fi

if [ $retc -eq 0 ]; then
   infmsg "$ls   call yum install routine"
   OUTPUT=$(2>&1 yum install bind-utils -qy)
   if [ $? -ne 0 ]; then
      errmsg "error yum install: $OUTPUT - abort"
      retc=99
   else
      infmsg "$ls   install yum ok"
   fi
fi

infmsg "$ls End bind installation rc=$retc "
exit $retc