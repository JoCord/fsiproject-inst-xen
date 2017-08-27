#!/bin/sh
#
#   sub_99_finish.sh - finish installation
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
ver="0.0.2 - 14.10.2013"
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

infmsg "$ls Configure WLB v.$ver"

# 
#  function activate-wlb {
#     # activating workloadbalancing for xendesktop hosts
#     if [ "$INSTALLTYPE" = "master" ] && [ "$specification" = "XenDesktop" ];then
#        if [ ! -f $LogPath/wlb ];then
#           xe pool-initialize-wlb wlb_url=$WLBSrv:8012 wlb_username=$WLBuser wlb_password=$WLBPass xenserver_username=$ROOTUSER xenserver_password=$ROOTPASSWORD
#           xe pool-param-set wlb-enabled=true uuid=`xe pool-list --minimal`
#           echo "WLB activated"
#           date >> $LogPath/wlb
#           else
#           echo "WLB already activated"
#        fi
#        else
#        echo "WLB activation during master setup and only for xendesktop hosts"
#     fi
#  }
# 
   infmsg "$ls  not implemented now"
infmsg "$ls End WLB routine rc=$retc"
exit $retc



