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
ver="1.0.8 - 13.03.2017"

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

infmsg " Configure Finish"
infmsg "   Hostname: "${HOSTNAME%%.*}

if [ -z $maintenancemode ] ; then 
   debmsg "   maintenance mode not configure - ignore"
else
   if [ "$maintenancemode" == "yes" ] ; then 
      if [ "$insttyp" == "member" ]; then
         infmsg "   Maintenance mode configure for this member server"
         OUTPUT=$(2>&1 xe host-disable host=${HOSTNAME%%.*})
         retc=$?
         tracemsg "    rc=$retc"
         if [ $retc -ne 0 ]; then
            if [[ "$OUTPUT"  =~ 'This operation cannot be performed because it would invalidate VM failover' ]]; then
               warnmsg "   to less server to set this in maintenance mode - ignore"
               retc=0
            else
               errmsg "cannot set maintenance mode - abort"
               retc=99 # rc=1 means reboot, not abort
            fi
         else
            if [ $retc -eq 0 ]; then
               infmsg "   evacuate host ..."
               OUTPUT=$(2>&1 xe host-evacuate host=${HOSTNAME%%.*})
               retc=$?
               tracemsg "    rc=$retc"
               if [ $retc -ne 0 ]; then
                  errmsg "cannot evacuate host - abort"
                  retc=99
               fi
            else
               errmsg "cannot disable host $server"
            fi

            infmsg "   set server in maintenance mode"
         fi
      else
         infmsg "   Master Server cannot set to maintenance mode - ignore"
      fi
   fi
fi

if [ $retc -eq 0 ]; then
   if [ -f /etc/yum.repos.d/CentOS-Base.repo ]; then
      OUTPUT=$(echo >/etc/yum.repos.d/CentOS-Base.repo)
      retc=$?
      if [ $retc -ne 0 ]; then
         errmsg "cannot delete /etc/yum.repos.d/CentOS-Base.repo - abort"
      fi
   fi
fi

if [ $retc -eq 1 ]; then
  errmsg "something wrong - 1 means reboot, but error - set to 2"
  retc=2
fi

infmsg " End finish routine rc=$retc"
exit $retc



