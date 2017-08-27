#!/bin/sh
#
#   sub_35_domain.sh - join domain and crate groups
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
insttyp="none"
xenauth="none"

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

infmsg "$ls Joining domain v.$ver"

if [ "$insttyp" != "none" ] ; then
    debmsg "$ls  set install typ to $insttyp"
    installtyp=$insttyp
else
  errmsg "no insttyp set"
  retc=99
fi

if [ $retc -eq 0 ]; then
  if [ "$xenauth" != "none" ] ; then
    debmsg "$ls    => xen auth: $xenauth"
    
    if [ "$xenauth" == "ad" ] ; then
      infmsg "$ls  domain auth configure"
      if [ "$jpfirst" == "true" ] ; then
        infmsg "$ls  join domain after xen pool join configure"
        if [ "$xenenv" != "none" ] ; then
         /usr/bin/fsipoolauth -c loc -i
          retc=$?
          if [ $retc -eq 0 ]; then
            debmsg "$ls  pool in loc auth - enable external auth to ad"
            sysconf="/usr/bin/fsijoinad"
            debmsg "$ls  search for domain join script"
            debmsg "$ls  script: $sysconf"
            if [ -f $sysconf ] ; then
                 debmsg "$ls  found script - run it"
                 /usr/bin/perl $sysconf --sub --mode master
                 retc=$?
                 if [ $retc -eq 0 ]; then
                     infmsg "$ls  joining domain successful end"
                 else
                     errmsg "joining domain - abort $retc"
                 fi      
            else
              errmsg "cannot find domain join script - abort"
              retc=99
            fi
          elif [ $retc -eq 1 ]; then
            debmsg "$ls  pool not configure to local auth - maybe ad ..."
            /usr/bin/fsipoolauth -c ad -i
            retc=$?
            if [ $retc -eq 0 ]; then
               infmsg "$ls  pool already joined to ad - pool auth ad"
            else
               errmsg "something wrong - abort"
               retc=99
            fi
          else
            errmsg "pool auth setting is either local nor ad - abort"
            retc=99
          fi 
        else 
          warnmsg "$ls  undefine vi environment"
        fi
      else
        infmsg "$ls  xen pool already joined xen pool"
      fi
    else
      infmsg "$ls  no ad auth configure set, no domain join need"
    fi  
  else
   errmsg "no xen server auth configure - abort"
   retc=77
  fi
fi

debmsg "$ls End domain routine rc=$retc"
exit $retc


