#!/bin/sh
#
#   sub_32-patchclean-default.sh - patch clean server
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
ver="1.0.2 - 26.04.2017"
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

infmsg "$ls Run default patch clean script v.$ver"

infmsg "$ls   call patch clean on server"
traceoutput=$(xe patch-list params=name-label --minimal)
tracemsg "$ls   patch list: $traceoutput"
traceoutput=$(xe patch-list params=uuid --minimal)
tracemsg "$ls   patch uuid list: $traceoutput"
if [ -d /var/patch ]; then
   traceoutput=$(ls -x /var/patch)
   tracemsg "$ls   patch dir content: $traceoutput"
fi
if [ -d /var/update ]; then
   traceoutput=$(ls -x /var/update)
   tracemsg "$ls   update dir content: $traceoutput"
fi

xenver=$(sed -n 's/^.*[ ]\([0-9]*\)\.\([0-9]*\)[ .].*/\1\2/p' /etc/redhat-release)
if [ "$xenver" == "" ]; then
   infmsg "$ls  cannot detect xenserver version"
   xenver=0
fi

if [ $xenver -lt 71 ]; then
   infmsg "$ls  clean XenServer < 7.1 patches"
   for patchuuid in $(xe patch-list params=uuid --minimal | tr , "\n"); do
      tracemsg "$ls    clean patch uuid $patchuuid"
      output=$(xe patch-pool-clean uuid=$patchuuid)
      retc=$?
      if [ $retc -ne 0 ]; then
         errmsg "cannot clean patch dir rc=$retc"
         errmsg "output: [$output]"
         break
      else
         tracemsg "$ls   rc=0, ok"
      fi
   done
else
   infmsg "$ls  clean XenServer >= 7.1 patches"
   for patchuuid in $(xe update-list params=uuid --minimal | tr , "\n"); do
      tracemsg "$ls    clean patch uuid $patchuuid"
      output=$(xe update-pool-clean uuid=$patchuuid)
      retc=$?
      if [ $retc -ne 0 ]; then
         errmsg "cannot clean patch dir rc=$retc"
         errmsg "output: [$output]"
         break
      else
         tracemsg "$ls   rc=0, ok"
      fi
   done
fi


if [ -d /var/patch ]; then
   traceoutput=$(ls -x /var/patch)
   tracemsg "$ls   patch dir content: $traceoutput"
fi
if [ -d /var/update ]; then
   traceoutput=$(ls -x /var/update)
   tracemsg "$ls   update dir content: $traceoutput"
fi

infmsg "$ls   end default clean end rc=$retc"
exit $retc  
   
