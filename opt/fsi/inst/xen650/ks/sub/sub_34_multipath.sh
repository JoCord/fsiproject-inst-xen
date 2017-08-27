#!/bin/sh
#
#   sub_34_multipath.sh - enable multipath
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
multipath="none"                                                              # multipath=off (default if not set / none)
                                                                              #          =dmp

ver="1.0.1 - 2.2.2016"
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


infmsg "$ls Configure multipath v.$ver"


debmsg "$ls multipath handle: $multipath"
if [ "$multipath" != "none" ] ; then
    infmsg "$ls  multipath enabled with handle: $multipath"
    /usr/bin/fsimultipath $multipath
else
    infmsg "$ls  no multipath configure needed - ignore"
fi

infmsg "$ls End multipath configure rc=$retc"
exit $retc



