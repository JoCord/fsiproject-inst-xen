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
poolcfg="none"

ver="1.0.5 - 14.10.2013"
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


infmsg "$ls Joining domain v.$ver"

if [ "$poolcfg" == "none" ] ; then
   errmsg "no poolconfig set"
   retc=99
else
   if [ -e $poolcfg ] ; then
     infmsg "$ls   pool config: $poolcfg exist"
   else
     errmsg "no pool config file found - abort"
     retc=88
  fi
fi

if [ $retc -eq 0 ]; then
   if [ "$insttyp" != "none" ] ; then
      debmsg "$ls   set install typ to $insttyp"
      installtyp=$insttyp
   else
      errmsg "no insttyp set"
      retc=99
   fi
fi

if [ $retc -eq 0 ]; then
  if [ "$jpfirst" == "true" ] ; then
    infmsg "$ls   join xen pool first"
    installtyp="jpfirst"
  fi

  infmsg "$ls   check if domain settings given"
  debmsg "$ls   pool config: $poolcfg"
  check="</domain>"
  debmsg "$ls   check: $check"
  if [[ -n $(grep "^$check\$" $poolcfg) ]] ; then
    infmsg "$ls   found domain config in pool cfg file"
    export xenauth="ad"
    echo xenauth="ad" >>$fsivars
  else
    infmsg "$ls   no domain config found in pool cfg file"
    infmsg "$ls   no join domain need - local auth"
    installtyp="authlocal"
    export xenauth="loc"
    echo xenauth="loc" >>$fsivars
    export jpfirst="false"
    echo jpfirst="false" >>$fsivars
  fi
fi

if [ $retc -eq 0 ]; then
  debmsg "$ls    => install type: $installtyp"
  if [ "$installtyp" == "jpfirst" ] ; then
    infmsg "$ls   call domain script later"
  elif [ "$installtyp" == "authlocal" ] ; then
    infmsg "$ls   xen auth set to local - no join domain need"
  elif [ "$xenenv" != "none" ] ; then
    sysconf="/usr/bin/fsijoinad"
    infmsg "$ls   search for domain join script"
    infmsg "$ls   script: $sysconf"
    if [ -f $sysconf ] ; then
         infmsg "$ls   found script - run it"
         /usr/bin/perl $sysconf --sub --mode $installtyp
         retc=$?
         if [ $retc -eq 0 ]; then
             infmsg "$ls   joining domain successful end"
         else
             errmsg "joining domain - abort $retc"
         fi      
    else
      errmsg "cannot find domain join script - abort"
      retc=99
    fi
  else
   warnmsg "$ls   undefine vi environment"
  fi
fi

infmsg "$ls End domain routine rc=$retc"
exit $retc


