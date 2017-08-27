#!/bin/sh
#
#   sub_38_pool_join.sh - join pool
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
jpfirst="false"

ver="1.0.8 - 7.12.2016"
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

infmsg "$ls Joining pool v.$ver"

if [ "$jpfirst" == "true" ] ; then
   infmsg "$ls   first join pool mode"
   if [ "$insttyp" == "member" ] ; then
      infmsg "$ls   check if local auth enable"
      /usr/bin/fsipoolauth -c loc -i
      retc=$?
      if [ $retc -eq 0 ]; then
         infmsg "$ls   pool is set to local auth"
      else
         infmsg "$ls   pool auth not local - try to set"
         /usr/bin/fsipoolauth -s loc -i
         retc=$?
         if [ $retc -eq 0 ]; then
            infmsg "$ls   pool auth set to local"        
         else
            errmsg "cannot set pool auth to local - abort"
         fi
      fi      
   fi
fi  
      

if [ $retc -eq 0 ]; then      
  if [ "$insttyp" == "member" ] ; then
     if [ "$xenenv" != "none" ] ; then
     
       ### debug
       cp /etc/xensource/pool.conf $fsidir/pool.conf.org
     
       sysconf="/tmp/sub-38_pool_join-$xenenv.sh"
       infmsg "$ls   search for pool script for environement "
       infmsg "$ls   script: $sysconf"
       if [ -f $sysconf ] ; then
            infmsg "$ls   found env script - run it"
            $sysconf
            retc=$?
            if [ $retc -eq 0 ]; then
                infmsg "$ls   creating pool successful end"
            elif [ $retc -eq 1 ]; then
                infmsg "$ls   creating pool successful - reboot needed"
            else
                errmsg "error creating pool - abort $retc"
            fi      
       else
         sysconf="/tmp/sub-38_pool_join-default.sh"
         if [ -f $sysconf ] ; then
            infmsg "$ls   found pool default script - run it"
            $sysconf
            retc=$?
            if [ $retc -eq 0 ]; then
                infmsg "$ls   creating pool successful end"
            elif [ $retc -eq 1 ]; then
                infmsg "$ls   creating pool successful - reboot needed"
            else
                errmsg "error creating pool - abort $retc"
            fi          
         else
           warnmsg "$ls   no pool script found for [$xenenv] or default"
         fi
       fi
     else
       warnmsg "$ls   unknown vi environment"
     fi
  else
      infmsg "$ls   stand alone or master server need no pool action"
  fi
fi

infmsg "$ls End finish routine rc=$retc"
exit $retc



