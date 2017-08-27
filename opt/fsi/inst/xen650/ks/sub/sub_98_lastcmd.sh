#!/bin/sh
#
#   sub_98_lastcmd.sh - send last commands to execute
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
lastcmds="no"

ver="1.0.09 - 9.9.2016"
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

infmsg "$ls send last commands v.$ver"

if [ $retc -eq 0 ]; then
   if [ "$lastcmds" == "no" ]; then
      infmsg "$ls  no last commands found"
   else
      infmsg "$ls  found last commands - call they"
      for ((i=0; i<${#lastcmds[*]}; i++)); do
          infmsg "$ls   cmd: ${lastcmds[$i]}"
          OUTPUT=$(2>&1 ${lastcmds[$i]})
          retc=$?
          if [ $retc -ne 0 ]; then
            errmsg "execute cmd [$1]"
            errmsg "output: [$OUTPUT]"
            break
          else
            debmsg "$ls   ok "
            tracemsg "$ls   output: [$OUTPUT]"
          fi
      done
   fi
fi

if [ $retc -eq 0 ]; then
   infmsg "$ls   Check if external last scripts exist"
   lastfile=(
      "$kspath/sub/sub-98_lastcmd.sh"
      "$kspath/pool/$pool/pool.sh"
      "$fsidir/$xencfg.sh"
   )
   for ((i=0; i<${#lastfile[*]}; i++)); do
      infmsg "$ls    check if ${lastfile[$i]} exist"
      if [ -f ${lastfile[$i]} ]; then
         debmsg "$ls    set execute flag on file"
         OUTPUT=$(2>&1 chmod +x ${lastfile[$i]})
         retc=$?
         if [ $retc -ne 0 ]; then
            errmsg "execute cmd [$1]"
            errmsg "output: [$OUTPUT]"
            break
         else
            debmsg "$ls    ok "
            tracemsg "$ls   output: [$OUTPUT]"
         fi
         
         infmsg "$ls    call file: ${lastfile[$i]}"
         OUTPUT=$(2>&1 ${lastfile[$i]})
         retc=$?
         if [ $retc -ne 0 ]; then
            errmsg "execute cmd [$1]"
            errmsg "output: [$OUTPUT]"
            break
         else
            debmsg "$ls    ok "
            tracemsg "$ls   output: [$OUTPUT]"
         fi
      else
         debmsg "$ls    not exist - ignore"
      fi
   done
fi

if [ $retc -eq 0 ]; then
   infmsg "$ls   Check if post dir exist"
   if [ -d "$kspath/post" ]; then
      infmsg "$ls   Check if external last scripts found in post dir"
      searchlast="$kspath/post/last_*.sh"
      if [ "`ls -A $searchlast 2>/dev/null`" ]; then
         for Scripts in $searchlast ; do
            if [ $retc -eq 0 ]; then     
              tracemsg "$ls     call script $Scripts"
              $Scripts 
              retc=$?
              if [ $retc -ne 0 ]; then
                 errmsg "running $Scripts rc=$retc"
              fi   
            fi
            ifdebug
         done
      else
         infmsg "$ls   no last scripts found"
      fi
   else
      debmsg "$ls  no post dir found - ignore"
   fi
fi

infmsg "$ls End send last commands routine rc=$retc"
exit $retc

