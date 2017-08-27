#!/bin/sh
#
#   sub-55_ha-default.sh default ha configuration
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
hasr="none"
MHF="none"
flag_poolmhf="none"

ver="1.0.4 - 22.7.2016"
retc=0
ls="    "
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


infmsg "$ls Create HA on Pool v.$ver"

tracemsg "$ls    ==> hasr [$hasr]"
tracemsg "$ls    ==> MHF [$MHF]"
tracemsg "$ls    ==> inst typ [$insttyp]"
tracemsg "$ls    ==> mhf file [$flag_poolmhf]"

if [ $retc -eq 0 ] && [ "$hasr" == "none" ]; then
   infmsg "$ls  no ha - no enable need"
else
   infmsg "$ls  ha sr found [$hasr] - enable ha"
   if [ $retc -eq 0 ] && [ "$flag_poolmhf" == "none" ] ; then
      errmsg "no mhf flag file set, need for pool ha configure - abort"
      retc=99
   fi

   if [ $retc -eq 0 ] && [ "$MHF" == "none" ] && [ "$insttyp" == "member" ]; then
      infmsg "$ls  member - read mhf config from pool"
      
      if [ -e $flag_poolmhf ]; then
         while read line; do
             MHF=$line
         done < "$flag_poolmhf"
         if [ "$MHF" == "none" ]; then
             errmsg "cannot read mhf pool config file - abort"
             retc=97
         else
             infmsg "$ls  get mhf from pool config [$MHF]"
             export MHF=$MHF
             echo MHF=$MHF >>$fsivars
         fi
      else
         infmsg "$ls  no pool config, but HA enabled - set mhf=2"
         export MHF=2
         echo MHF=$MHF >>$fsivars
      fi
   fi


   if [ $retc -eq 0 ] && [ "$insttyp" == "master" ]; then
      if [ "$MHF" == "none" ] || [ "$MHF" -eq 0 ]; then
         infmsg "$ls  master - no MHF found but HA enabled, set mhf=2"
         export MHF=2
         echo MHF=$MHF >>$fsivars
      else
         infmsg "$ls  master - MHF already configure [$MHF]"
      fi   
   fi


   if [ $retc -eq 0 ]; then
      infmsg "$ls  ha sr found [$hasr] - call fsichha"
      /usr/bin/fsichha -a -s 2
      retc=$?
      tracemsg "$ls  rc=$retc"
      if [ $retc -eq 0 ]; then
         infmsg "$ls  ha enabled"
      elif [ $retc -eq 2 ]; then
         warnmsg "$ls  no ha config found - ignore"
         retc=0
      elif [ $retc -eq 3 ]; then
         warnmsg "$ls  not enough xenserver in pool - ignore"
         retc=0
      else
         errmsg "$ls something wrong with ha"
      fi
   fi    
fi

infmsg "$ls End ha routine rc=$retc"
exit $retc         

