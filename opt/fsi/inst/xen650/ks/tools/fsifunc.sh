# 
#   fsi functions for xenserver installation
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
#   Version: 1.0.09 - 02.02.2017
#
export debug="trace" # yes, no, press, sleep, no
export fsibin="/usr/bin"
export fsidir="/var/fsi"

export xensource="xen$(sed -n 's/^.*[ ]\([0-9]\.[0-9]*\)[ .].*/\1/p' /etc/redhat-release| sed 's/\.//')0"             # xen650
export xenmain="$(sed -n 's/^.*[ ]\([0-9]*\)[ .].*/\1/p' /etc/redhat-release)"                                        # 6
export xencfg="xen$xenmain"                                                                                           # xen6

export fsivars="$fsidir/$xencfg.conf"
export deb2scr="yes"
export g_ssh_options="-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
export regex_ip='\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b'
export regex_ip_dns='^(((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))|((([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])))$'
export waitend=10
export waittime=15
export waitcount=0


if ! [ -f $fsivars ] ; then
   errmsg "cannot set fsi conf variables $fsivars"
   exit 99
fi


#### functions
function tracemsg() {
   if [ "$debug" == "trace" ] || [ "$debug" == "press" ] || [ "$debug" == "sleep" ]; then
      logmsg "TRACE  :  $1" 3
   fi
}
function debmsg() {
   if [ "$debug" == "debug" ] || [ "$debug" == "trace" ] || [ "$debug" == "press" ] || [ "$debug" == "sleep" ]; then
      logmsg "DEBUG  :  $1" 7
   fi
}
function warnmsg() {
    logmsg "WARN   :  $1" 4
}
function errmsg() {
    logmsg "ERROR  :  $1" 5
}
function infmsg() {
    logmsg "INFO   :  $1" 2
}

function logmsg() {
   local timestamp=$(date +%H:%M:%S)
   local datetimestamp=$(date +%Y.%m.%d)"-"${timestamp}
   tmpmsg=$1
   tmp=${tmpmsg:0:5}
#   if  [ "$tmp" != "DEBUG" ] && [ "$tmp" != "TRACE" ]; then
   local progname=${0##*/}
   local pidnr=$$
   if [ "$deb2scr" == "yes" ]; then
      if [ ! "$nocolor" == "true" ]; then 
         tput -T xterm setaf $2
         echo $timestamp "$1"
         tput -T xterm sgr0
      else
         printf "%-19s : %-6d - %-30s %s\n" $datetimestamp,000 $pidnr $progname "$1" 
      fi
   fi
   printf "%-19s : %-6d - %-30s %s\n" $datetimestamp,000 $pidnr $progname "$1" >>$logfile
   if [ "$logfile" = "/var/fsi/fsixeninst.log" ]; then
      if [ -d "$kspath/log" ]; then
         printf "%-19s : %-6d - %-30s %s\n" $datetimestamp,000 $pidnr $progname "$1" >>$kspath/log/${HOSTNAME%%.*}.log
      fi
   fi
}

function warte() {
   echo -n $(date +%H:%M:%S)" INFO   : $ls     Waiting ."
   while [ $waitcount -le $waitend ]; do
      echo -n "."
      sleep $waittime
      waitcount=$((waitcount+1))
   done
   echo " ok"
}


function ifdebug() {
    if [ "$debug" == "press" ] ; then read -p "Press any key ..." ; fi
    if [ "$debug" == "sleep" ] ; then sleep 5 ; fi
}

change_param() {
   local suche=$1
   local param=$2
   local datei=$3
   local retc=0
   OUTPUT=$(2>&1 sed -i '/^'$suche'=/{h;s/=.*/='$param'/};${x;/^$/{s//'$suche'='$param'/;H};x}' $datei)
   return $?
}

function wait_toolstack() {
   retc=0
   local warte=20
   local count=0
   local abbruch=15
   local stack="offline"
    
   echo -n $(date +%H:%M:%S)" INFO   : $ls  Waiting for XE stack ."
   while [ "$stack" == "offline" ]; do
      toolstackstatus=$(2>&1 xe host-list name-label=$HOSTNAME --minimal)
      retc=$?
      if [ $retc -ne 0 ] ; then
         if [ $count -le $abbruch ] ; then
            echo -n "."   
            sleep $warte
            count=$((count+1))
         else
            stack="failed - to much retries."
            retc=99
         fi
      else
         stack="online"
      fi
   done
   echo " $stack"
   return $retc
}

function check_all_srv_on() {
   local xecmd=$@
   if [ "$xecmd" == "" ]; then return 99; fi
   local retc=1
   local offline=99

   local warte=30
   local count=0
   local abbruch=40
   #tracemsg "$ls  cmd: $xecmd"
   if [ "$debug" == "info" ]; then
      echo -n $(date +%H:%M:%S)" INFO   : $ls  Check if all server in pool online ."
   else 
      debmsg "$ls  Check if all server in pool online:"
   fi
   until !(($offline)); do
      offline=0
      for i in $($xecmd host-list params=name-label --minimal | sed 's/\,/\n/g'); do 
         if [ "$debug" != "info" ]; then
            debmsg "$ls   host: $i"
            tracemsg "$ls    cmd: ssh $g_ssh_options $i xe host-list"
         fi
         output=$(ssh $g_ssh_options $i xe host-list)
         if (($?)); then
            if [[ $i =~ \\. ]]; then
               if [ "$debug" != "info" ]; then
                  debmsg "$ls   [$i] = fqdn and offline"
               fi
               offline=$((offline+1))
            else
               if ! [ -f $fsivars ] ; then
                  warnmsg "$ls   cannot find $fsivars to get dnsdom"
               else
                  . $fsivars
                  if ! [ -z $dnsdom ]; then
                     ifqdn=$i"."$dnsdom
                     output=$(ssh $g_ssh_options $ifqdn xe host-list)
                     if (($?)); then
                        if [ "$debug" != "info" ]; then
                           debmsg "$ls   [$ifqdn] = fqdn and offline"
                        fi
                        offline=$((offline+1))
                     fi
                  else
                     if [ "$debug" != "info" ]; then
                        warnmsg "$ls no dns search found"
                        debmsg "$ls   [$i] = short name and offline"
                     fi
                     offline=$((offline+1))
                  fi
               fi
            fi
         fi
      done
      if (($offline)); then
         if [ $count -le $abbruch ] ; then
            if [ "$debug" == "info" ]; then
               echo -n "."$offline"."   
            fi
            sleep $warte
            count=$((count+1))
         else
            if [ "$debug" == "info" ]; then
               echo " failed - to much retries."
            else
               errmsg "failed - to much retries - some server still offline"
            fi
            retc=0
            offline=0
         fi
      else 
         echo " all online"
      fi
   done

   return $retc
}

#### function export
export -f errmsg
export -f tracemsg
export -f debmsg
export -f warnmsg
export -f infmsg
export -f logmsg
export -f warte
export -f ifdebug
export -f change_param
export -f wait_toolstack
export -f check_all_srv_on