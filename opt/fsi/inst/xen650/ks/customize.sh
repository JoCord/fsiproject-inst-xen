#!/bin/sh
#
#   customize.sh - post installation xen server
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
version="1.3.15 - 17.05.2017"
retc=0
progname=${0##*/}

export debug="trace" # debug, trace, press, sleep, no
export fsidir="/var/fsi"
export logfile="$fsidir/fsixeninst.log"
export xensource="xen$(sed -n 's/^.*[ ]\([0-9]\.[0-9]*\)[ .].*/\1/p' /etc/redhat-release| sed 's/\.//')0"             # xen650
export xenmain="$(sed -n 's/^.*[ ]\([0-9]*\)[ .].*/\1/p' /etc/redhat-release)"                                        # 6
export xencfg="xen$xenmain"                                                                                           # xen6

visrvfile="$fsidir/fsisrv"
vimountfile="$fsidir/vimount"
tempdir="/tmp/"
export stagefile="$fsidir/vistage"
stage=0
stagefirst=2
stagewait=38                                                                                                                      # stage/sub level to wait for pool free -1
kspath="none"
pool="none"
ppath="none"
flag_poolok="none"
flag_poolmaster="none"
flag_poolrun="none"
flag_pool="none"
flag_poolha="none"
flag_poolmhf="none"
poolcfg="none"
master="none"
masterip="none"
dnsdom="none"
mac="none"
macd="none"
hasr="none"
xenauth="none"

if [ -z $fsivars ]; then export fsivars="$fsidir/$xencfg.conf"; fi

xenenv="none"
xenmp="none"
fsisrv="none"
createvmscript="/usr/bin/fsimgmtvm"
updatescript="/usr/bin/fsiupdate"
insttyp="none"


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

function getmaster() {
    retc=0
    master="none"
    local counter=0
    local retryget=3
    
    while [ "$master" == "none" ]; do 
       if [ -e $flag_poolmaster ]; then
           infmsg " get master [$counter]"
           while read line; do
               master=$line
           done < "$flag_poolmaster"
           if [ "$master" == "none" ]; then
               errmsg "cannot get master from flag file"
               retc=43
           else
               infmsg " ==> pool master: [$master]"
           fi
       else
          if [ $count -le $retryget ]; then
             counter=$((counter+1))
             sleep 1
          else
             errmsg "I am member, but no poolmaster flagfile exist - abort"
             errmsg "pool: [$flag_pool]"
             errmsg "pool ok: [$flag_poolok]"
             errmsg "pool master: [$flag_poolmaster]"
             retc=99
             master="abort"
          fi
       fi
    done
    return $retc
}

function testpoolok() {
   infmsg "Test if pool master finish"
   echo -n $(date +%H:%M:%S)" INFO   :  Waiting ."
   while ! [ -e $flag_poolok ]; do 
       sleep 30
       echo -n "."
   done
   echo " ok"
   infmsg "  Can start now ..."
}

function restart() {
    retc=0
    if [ -d "$kspath/log/" ]; then
        infmsg "Returncode before log copy rc=[$retc]"
        infmsg "  copy log file to fsi server"
        OUTPUT=$(2>&1 cat $logfile >$kspath/log/${HOSTNAME%%.*}.log)
        if [ $? -ne 0 ] ; then
            errmsg "cannot copy logfile to fsi server $OUTPUT - abort"
            retc=99
        fi 
    fi
    infmsg "Wait 10 sec to reboot !"
    sleep 10
    reboot
    read -p "Waiting for reboot ..."      
    exit $retc  # never come here
}

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
   if  [ "$tmp" != "DEBUG" ] && [ "$tmp" != "TRACE" ]; then
      tput setaf $2
      echo $timestamp "$1"
      tput sgr0
   fi
   local progname=${0##*/}
   local pidnr=$$
   printf "%-19s : %-6d - %-30s %s\n" $datetimestamp,000 $pidnr $progname "$1" >>$logfile
   if [ -d "$kspath/log" ]; then
      printf "%-19s : %-6d - %-30s %s\n" $datetimestamp,000 $pidnr $progname "$1" >>$kspath/log/${HOSTNAME%%.*}.log
   fi
   tput sgr0
}

function ifdebug() {
    if [ "$debug" == "press" ] ; then read -p "Press any key ..." ; fi
    if [ "$debug" == "sleep" ] ; then sleep 5 ; fi
}
export -f errmsg
export -f ifdebug
export -f restart
export -f tracemsg
export -f debmsg
export -f warnmsg
export -f infmsg
export -f logmsg


# main
#----------------------------------------------------------------------------------------------------------------------------------------------------------
infmsg ""
infmsg "Start XenServer customize script - v$version" 
if [ "$xenmain" != "6" ] && [ "$xenmain" != "7" ]; then
   errmsg "unsupported xenserver version [$xenmain]"
   exit 99
else
   infmsg " xenserver main [$xenmain]"
fi
if [ "$xensource" != "" ]; then
   infmsg " xensource: $xensource"
else
   errmsg "cannot find xensource"
   exit 99
fi

# Stage run ?
if [ -e $stagefile ] ; then
    while read line ; do stage=$line ; done < $stagefile
    debmsg "Stage $stage"
else
    errmsg "something wrong - no stage file."
    read -p "ERROR"      
    exit 99
fi

infmsg "Running on ${HOSTNAME%%.*}"

# Read config
if [ -f $fsivars ] ; then
    debmsg "set conf vars"
    . $fsivars
else
    errmsg "cannot set conf variables"
    exit 99
fi

if [ "$pool" == "none" ]; then
   infmsg "no pool define - stand alone server"
   export $insttyp="standalone"
   echo insttyp=$insttyp >>$fsivars
fi


if [ $retc -eq 0 ] && [ "$kspath" == "none" ]; then
  debmsg "no kspath set"
  export kspath="/mnt/ks"
  echo kspath=$kspath >>$fsivars
fi
tracemsg "kspath: [$kspath]"

if [ -d $kspath ]; then
   debmsg "VI Template mount dir exist"
else
   debmsg "Create VI Template mount dir"   
   OUTPUT=$(2>&1 mkdir -v $kspath)
   if [ $? -ne 0 ]; then
      logmsg "ERROR cannot create dir $kspath = $OUTPUT - abort"
      retc=1
   fi 
fi

   
if [ $retc -eq 0 ] && [ "$ppath" == "none" ]; then
  debmsg "no ppath set"
  export ppath=$kspath"/pool"
  echo ppath=$ppath >>$fsivars
fi
tracemsg "ppath: [$ppath]"


# Get fsi server
if [ $retc -eq 0 ] ; then
   if [ -f $visrvfile ]; then
       if [ "$fsisrv" == "none" ] ; then
           debmsg "Find template server conf file"
           while read line; do
               fsisrv=$(echo $line| tr "[:upper:]" "[:lower:]")
               debmsg "  fsi server $fsisrv"
           done < $visrvfile
           echo fsisrv=$fsisrv >>$fsivars
       else
           debmsg " get fsi server from conf: $fsisrv"
       fi
   else
       retc=1
       errmsg "cannot find fsi server - abort"
   fi
fi


if [ $retc -eq 0 ] ; then
   infmsg "  start detecting network ..."
   waitcount=0
   waitend=50
   while [ $waitcount -le $waitend ]; do
      out=$(ping -c 1 $fsisrv)
      online=$?
      if [ $online -eq 0 ]; then
         infmsg "   network online ($waitcount)"
         break
      else
         sleep 1
         waitcount=$((waitcount+1))
      fi
   done
   if [ $online -ne 0 ]; then
      errmsg "network still offline or cannot connect to fsi server ($waitcount)"
      retc=99
   fi
fi

# get mac
if [ $retc -eq 0 ] ; then
   if [ "$mac" == "none" ]; then
      if [ "$xenmain" == "6" ]; then
         tracemsg "  xenserver 6 - count :$waitcount"
         macp=$(/sbin/ifconfig xenbr0 | /bin/grep -m 1 HWaddr | tr -s " " | cut -d " " -f 5 )
         tracemsg "  macp [$macp]"
         if [ "$macp" != "" ]; then
            tracemsg "  macp [$macp]"
            export mac=${macp//:/}
            export macd=$(/sbin/ifconfig xenbr0 | grep -m 1 HWaddr | tr -s " " | cut -d " " -f 5 | tr '[:upper:]' '[:lower:]' | tr ':' '-')
            break
         else
            errmsg "cannot detect MAC - abort"
            retc=77
         fi
      elif  [ "$xenmain" == "7" ]; then
         tracemsg "  xenserver 7 - count :$waitcount"
         macp=$(/sbin/ifconfig xenbr0 | /bin/grep -m 1 ether | tr -s " " | cut -d " " -f 3)
         tracemsg "  macp [$macp]"
         if [ "$macp" != "" ]; then
            tracemsg "  macp [$macp]"
            export mac=${macp//:/}
            export macd=$(/sbin/ifconfig xenbr0 | /bin/grep -m 1 ether | tr -s " " | cut -d " " -f 3 | tr '[:upper:]' '[:lower:]' | tr ':' '-')
            break
         else
            errmsg "cannot detect MAC - abort"
            retc=77
         fi
      fi
      if [ "$mac" != "" ]; then
         infmsg "mac found [$mac]"
         echo mac=$mac >>$fsivars
         infmsg "mac found [$macd]"
         echo macd=$macd >>$fsivars
      else
         errmsg "cannot detect MAC - abort"
         retc=44
      fi
   else
      debmsg "get mac from config"
      infmsg "mac found [$mac]"
      infmsg "mac found [$macd]"
   fi
fi

# check dns search domain
if [ $retc -eq 0 ] ; then
   if [ "$dnsdom" == "none" ]; then
       infmsg "no dns search domain set - del var."
       dnsdom=""
   else
       infmsg "dns search domain: $dnsdom"
   fi
fi 

# Get Xen Environment
if [ $retc -eq 0 ] ; then
   if [ $stage -eq $stagefirst ] ; then   
       debmsg "check config vars"
       if [ "$xenenv" = "none" ] ; then
           retc=99
           errmsg "no xen environment define - abort install"
       else
           infmsg "found xen environment [$xenenv]"
       fi
       infmsg "   write xen env in var file"
       echo xenenv=$xenenv >>$fsivars
   fi
   debmsg "   export xen env"
   export xenenv=$xenenv
fi

# Get VI Template mount point
if [ $retc -eq 0 ] ; then
   if [ -f $vimountfile ]; then
       if [ "$xenmp" == "none" ]; then
           debmsg "found config for mountpoint - read it ..."
           while read line; do
               xenmp=$(echo $line)
               debmsg "  get xen mount point $xenmp"
           done < $vimountfile
           echo xenmp=$xenmp >>$fsivars
       else
           debmsg "  get xen mount point from conf: $xenmp"
       fi
   else
       retc=1
       errmsg "cannot find mount point - abort"
   fi
fi

if [ $retc -eq 0 ] ; then
    infmsg "found fsisrv and mount point - start now ..."
    export xenmp=$xenmp
    export fsisrv=$fsisrv
fi

# Mount fsi server
if [ $retc -eq 0 ]; then
    infmsg "mount fsi server now .."
    OUTPUT=$(2>&1 mount -t nfs $fsisrv":"$xenmp $kspath)
    if [ $? -ne 0 ]; then
       errmsg "cannot create fsisrv mount [$OUTPUT] - abort"
       retc=99
    else
       infmsg "mount ok"
    fi 
    ifdebug
fi



# Pool Flagfiles 
if [ $retc -eq 0 ] && [ "$flag_poolrun" == "none" ]; then
    infmsg "pool run flag not in config - create"
    export flag_poolrun=$ppath"/"$pool"/pool.run"
    echo flag_poolrun=$flag_poolrun >>$fsivars
fi
debmsg "pool runflag: [$flag_poolrun]"

if [ $retc -eq 0 ] && [ "$flag_poolok" == "none" ] ; then
    infmsg "pool flag file not in config - create"
    export flag_poolok=$ppath"/"$pool"/pool.ok"
    echo flag_poolok=$flag_poolok >>$fsivars
fi
debmsg "pool finish ok flag: [$flag_poolok]"

if [ $retc -eq 0 ] && [ "$flag_poolmaster" == "none" ] ; then
    infmsg "pool master flag not in config - create"
    export flag_poolmaster=$ppath"/"$pool"/pool.master"
    echo flag_poolmaster=$flag_poolmaster >>$fsivars
fi
debmsg "pool master flag: [$flag_poolmaster]"

if [ $retc -eq 0 ] && [ "$flag_poolha" == "none" ] ; then
    infmsg "pool ha flag not configure yet - create"
    export flag_poolha=$ppath"/"$pool"/pool.ha"
    echo flag_poolha=$flag_poolha >>$fsivars
fi
debmsg "pool ha flag [$flag_poolha]"

if [ $retc -eq 0 ] && [ "$flag_poolmhf" == "none" ] ; then
    infmsg "pool ha mhf flag not configure yet - create"
    export flag_poolmhf=$ppath"/"$pool"/pool.mhf"
    echo flag_poolmhf=$flag_poolmhf >>$fsivars
fi
debmsg "pool mhf flag [$flag_poolmhf]"




if [ $retc -eq 0 ] && [ "$flag_pool" == "none" ]; then
    infmsg "no pool flag define on this server"
    export flag_pool=$ppath"/"$pool
    echo flag_pool=$flag_pool >>$fsivars
fi
debmsg "pool flag dir: [$flag_pool]"

if [ $retc -eq 0 ] && [ "$poolcfg" == "none" ]; then
    infmsg "no pool config set"
    export poolcfg="$fsidir/$xencfg.pool"
    echo poolcfg=$poolcfg >>$fsivars
fi
debmsg "pool cfg: [$poolcfg]"
ifdebug

# test if tool stack online
if [ $retc -eq 0 ]; then
   infmsg "Test if toolstack online"
   wait_toolstack
   retc=$?
   if [[ $retc -ne 0 ]] ; then
      errmsg "something wrong with toolstack - abort"
   fi
fi


# Get HOSTuuid
if [ $retc -eq 0 ] ; then
   if [ $stage -eq $stagefirst ] ; then
       debmsg "export host uuid"
       export HOSTuuid=$(xe host-list name-label=${HOSTNAME%%.*} --minimal)
       if [ "HOSTuuid" == "" ]; then
         errmsg "getting host uuid - abort"
         retc=88
       else
         echo HOSTuuid=$HOSTuuid >>$fsivars
       fi
   fi
fi


# Who is master ?
if [ $retc -eq 0 ]; then
    ifdebug
    if [ "$insttyp" == "none" ]; then
        infmsg "no install typ found - try to detect type"
        if [ "$pool" == "none" ]; then
            infmsg "no pool define - stand alone server"
            export insttyp="standalone"
            echo insttyp=$insttyp >>$fsivars
        else
            if [ -d $ppath ]; then
                debmsg "connect to pool dir ok"

                if [ -e $poolcfg ]; then
                    debmsg "test if I am master ?"
                    mkdir $flag_pool > /dev/null 2>&1
                    if [ $? -eq 0 ]; then
                        infmsg "I am master - jippi"
                        export insttyp="master"
                        echo insttyp=$insttyp >>$fsivars
                        echo ${HOSTNAME%%.*} >$flag_poolmaster
                        export master=${HOSTNAME%%.*}
                    else
                        infmsg "I am a member"
                        export insttyp="member"
                        echo insttyp=$insttyp >>$fsivars
                        getmaster && retc=0 || retc=99
                        if [ $retc -eq 0 ] ; then
                            if [ "$master" != "none" ]; then
                                export master=$master
                            else
                                retc=99
                                errmsg "cannot detect master"
                            fi
                        else
                            errmsg "cannot detect master - abort"
                            retc=33
                        fi
 
                    fi
                else
                    infmsg "I am a member due to the fact that no pool config exist"
                    export insttyp="member"
                    echo insttyp=$insttyp >>$fsivars
                    testpoolok
                    getmaster && retc=0 || retc=99
                    if [ $retc -eq 0 ] ; then
                        if [ "$master" != "none" ]; then
                            export master=$master
                        else
                            retc=99
                            errmsg "cannot detect master"
                        fi
                    else
                        errmsg "cannot detect master - abort"
                        retc=44
                    fi
                fi


            else
                errmsg "cannot connect to pool dir - abort"
                retc=44
            fi
        fi
    fi
fi


# 3rd Party RPMS
if [ $retc -eq 0 ]; then
    if [ $stage -eq $stagefirst ]; then
        infmsg "first customize boot ..."
        if [ $retc -eq 0 ]; then
           files=$(shopt -s nullglob dotglob; echo $kspath/rpm/*.rpm)
           if (( ${#files} )); then
              infmsg "Copy 3rd party RPMs"
              OUTPUT=$(2>&1 cp -p -f $kspath/rpm/*.rpm ${tempdir})
              if [ $? -ne 0 ]; then
                 errmsg "cannot copy rpm files $OUTPUT - abort"
                 retc=1
              fi   
           else
              infmsg "no 3rd party RPMs found"
           fi
        fi
        if [ $retc -eq 0 ]; then
           files=$(shopt -s nullglob dotglob; echo $kspath/rpm/*.tgz)
           if (( ${#files} )); then
              infmsg "Copy 3rd party tgz"
              OUTPUT=$(2>&1 cp -p -f $kspath/rpm/*.tgz ${tempdir})
              if [ $? -ne 0 ]; then
                 errmsg "cannot copy tgz files $OUTPUT - abort"
                 retc=1
              fi   
           else
              infmsg "no 3rd party tgz found"
           fi
        fi
        if [ $retc -eq 0 ]; then
           files=$(shopt -s nullglob dotglob; echo $kspath/inst/inst*.sh)
           if (( ${#files} )); then
              infmsg "Copy 3rd party install routines"
              OUTPUT=$(2>&1 cp -p -f $kspath/inst/inst*.sh ${tempdir})
              if [ $? -ne 0 ]; then
                 errmsg "cannot copy install files $OUTPUT - abort $?"
                 retc=1
              fi   
              if [ $retc -eq 0 ]; then
                  infmsg "Install 3rd party packages"
                  for Scripts in ${tempdir}inst_*.sh; do
                     if [ $retc -eq 0 ]; then     
                       tracemsg "  call script $Scripts"
                       $Scripts 
                       retc=$?
                       if [ $retc -ne 0 ]; then
                          errmsg "running $Scripts - abort $retc"
                          break;
                       fi   
                     fi
                     ifdebug
                  done
              fi
           else
              infmsg "no 3rd party install routines found"
           fi
        fi
    else
        infmsg "reboot ... no 3rd party install needed anymore"
    fi
    ifdebug
fi

# Copy tools - fsiupdate, createvm
if [ $retc -eq 0 ]; then
   if [ $stage -eq $stagefirst ]; then
      infmsg "first customize boot .."
      if [ $retc -eq 0 ]; then
         infmsg "Copy tools"
         OUTPUT=$(2>&1 cp -p -f $kspath/tools/* /usr/bin/)
         if [ $? -ne 0 ] ; then
            errmsg "cannot copy tool files $OUTPUT - abort"
            retc=99
         fi 
      fi
   else
       infmsg "reboot ... no copy tools needed anymore"
   fi
   ifdebug
   if [ $retc -eq 0 ]; then
      infmsg "all tools copy successful"
   fi
fi

# Pool install finish ?
if [ $retc -eq 0 ] && [ "$insttyp" == "member" ]; then
   infmsg "Test if pool master finish"

   infmsg "copy log file to fsi server"
   OUTPUT=$(2>&1 cat $logfile >$kspath/log/${HOSTNAME%%.*}.log)
   if [ $? -ne 0 ] ; then
       errmsg "cannot copy logfile to fsi server $OUTPUT - abort"
       retc=99
   fi 

   echo -n $(date +%H:%M:%S)" INFO   :  Waiting ."
   while ! [ -e $flag_poolok ]; do 
       sleep 30
       echo -n "."
   done
   echo " ok"
   infmsg "  Can start now ..."
else
   infmsg "No member server - do not need to test if pool finish"
fi

if [ $retc -eq 0 ]; then
   if [ "$insttyp" != "standalone" ] ; then    
      if [ "$hasr" == "none" ]; then
         debmsg "no pool ha configure yet - try to configure ..."
         if [ -e $flag_poolha ]; then
            infmsg "Pool HA configure exist - copy flag file ..."
            OUTPUT=$(2>&1 cp -p -f $flag_poolha $fsidir/$xencfg.ha)
            if [ $? -ne 0 ]; then
                errmsg "cannot copy flag file $OUTPUT - abort"
                retc=66
            fi   
            hasr=`head $flag_poolha`
            if [ -z $hasr ]; then
                errmsg "no pool ha sr set in flag file - abort"
                retc=55
            else
                debmsg "Pool HA storage repository: [$hasr]"
                echo hasr=$hasr >>$fsivars
                export hasr=$hasr
            fi
         else
           infmsg "No pool ha flag exist - maybe no pool ha activate"
         fi
      else
         debmsg "pool ha sr [$hasr] set already"
      fi
   else
      infmsg "standalone xenserver need no ha config"
   fi
fi


# Get poolmaster ip
if [ $retc -eq 0 ] ; then
   if [ "$insttyp" != "standalone" ] ; then    
      if [ "$master" == "none" ]; then
         infmsg "no master define - try to get it ..."
         getmaster && retc=0 || retc=99
         if [ $retc -eq 0 ] ; then
            if [ "$master" != "none" ]; then
               export master=$master
            else
               retc=99
               errmsg "cannot detect master"
            fi
         else
            errmsg "cannot detect master - abort"
         fi
      else
         infmsg "==> pool master: $master"
      fi
  
      if [ "$master" != "none" ] && [ $retc -eq 0 ]; then
         if [ -z $dnsdom ]; then
            dnsmaster=$master
         else
            dnsmaster=$master"."$dnsdom
         fi
         infmsg "Searching for master $dnsmaster ip ..."
         masterip=`/usr/bin/nslookup $dnsmaster | grep Add | grep -v '#' | cut -f 2 -d ' '`
         if [ "$masterip" == "none" ] || [ "$masterip" == "" ]; then
            errmsg "cannot detect master ip for $master"
            retc=22
         else
            infmsg "master ip [$masterip]"
            export masterip=$masterip
         fi
      else
         errmsg "no master given or empty - abort"
         retc=23
      fi
   else
      infmsg "standalone xenserver need no master ip detection"
   fi
fi




# Subroutines copy
if [ $retc -eq 0 ]; then
    if [ $stage -eq $stagefirst ] ; then
        infmsg "first customize boot .."
        if [ $retc -eq 0 ]; then
            infmsg "Copy sub routines"
            OUTPUT=$(2>&1 cp -p -f $kspath/sub/sub*.* ${tempdir})
            if [ $? -ne 0 ]; then
              errmsg "cannot copy subroutine files $OUTPUT - abort"
              retc=1
            fi   
        fi
    else
        infmsg "reboot ... no copy subroutines needed anymore"
    fi
    ifdebug
fi

# Subroutines start
if [ $retc -eq 0 ] && [ $stage -le 100 ]; then
    infmsg "Start sub routines"
    infmsg "   Start at stage $stage"
    for Subs in ${tempdir}sub_*.sh; do
       if [ $retc -eq 0 ]; then
          tracemsg "   found [$Subs]"
          level=${Subs:9:2}
          level=${level##+(0)}
          echo $level >$stagefile
          tracemsg "   Set stage: $level"
          tracemsg "   Stage first: $stagefirst"
          tracemsg "   Org stage: $stage"

          # Running alone ?
          if [ "$insttyp" == "member" ] ; then    
             if [ $level -lt $stagewait ]; then
                infmsg "Server not in xen pool yet ... go on"
             else
                debmsg "Test if member install run alone ..."
                /usr/bin/fsipoolrun check sub
                retc=$?
                if [ $retc -ne 0 ]; then
                    errmsg "checking xen pool run flag - abort"
                fi
             fi
          fi

          if [[ $stage -eq $stagefirst ]] || [[ $level -gt $stage ]] ; then     
             infmsg "   call script [$Subs] now ..."
             $Subs
             retc=$?
             tracemsg "   rc=[$retc]"
             if [ $retc -eq 0 ]; then
               infmsg "   script [$Subs] ended with rc=0"
               sleep 5
             elif [ $retc -eq 1 ] ; then
               infmsg "   reboot now!"
               ifdebug
               restart
             else   
               errmsg "running $Subs rc=$retc"
               break;
             fi  

             OUTPUT=$(2>&1 cat $logfile >$kspath/log/${HOSTNAME%%.*}.log)
             if [ $? -ne 0 ] ; then
               errmsg "cannot copy logfile to fsi server $OUTPUT - abort"
               retc=99
             fi 

          else
             tracemsg "   $Subs already run"
          fi 
       fi
       ifdebug
    done
    if [ $retc -eq 0 ]; then
       infmsg "End sub routine installation"
       stage=100
       echo $stage >$stagefile
       ifdebug
    else
      errmsg "Sub routine ended with error [$retc]"   
    fi
fi  


# Master ? yes = create pool ok flag
#tracemsg "Stage: [$stage]"
#tracemsg "Insttyp: [$insttyp]"
#tracemsg "retc: [$retc]"
#tracemsg "Poolflag: [$flag_poolok]"

if [ $retc -eq 0 ] && [ $stage -ge 100 ] ; then 
   infmsg "Stage: $stage"
   if [ "$insttyp" != "standalone" ] ; then
      infmsg "I am a master ?"
      if [ "$insttyp" != "member" ] ; then    
         infmsg "  yes : create pool ok flag"
         debmsg "Poolflag : $flag_poolok"
         OUTPUT=$(2>&1 echo $(date +%H:%M:%S) $pool master finish >$flag_poolok)
         retc=$?
         if [ $retc -ne 0 ] ; then
            errmsg "cannot create ok flag for pool $flag_poolok - [$OUTPUT] abort"
            retc=44
         else
            infmsg "Pool Installation finish - start member installations"
         fi 
      else
         infmsg "=> no : remove host install wait flag"
         /usr/bin/fsipoolrun remove sub
         retc=$?
         if [ $retc -eq 0 ] ; then
            infmsg "removed - other server can start installation"
         else
            errmsg "something wrong removing flag."
         fi
      fi
   else
      infmsg "Standalone server - no pool ok flag"
   fi
fi

if [ $retc -eq 0 ] ; then 
   infmsg "Remove unneeded files"
   
   if [ $retc -eq 0 ] ; then 
      files=$(shopt -s nullglob dotglob; echo ${tempdir}sub[_-][0-9][0-9]*)
      if (( ${#files} )); then
         infmsg " Remove sub functions"
         OUTPUT=$(2>&1 rm ${tempdir}sub[_-][0-9][0-9]*)
         retc=$?
         if [ $retc -ne 0 ] ; then 
            errmsg "removing ${tempdir}sub[_-][0-9][0-9]*"
            retc=22
         fi
      else 
         infmsg " no sub functions to delete found"
      fi
   fi
   if [ $retc -eq 0 ] ; then 
      files=$(shopt -s nullglob dotglob; echo ${tempdir}inst*.sh)
      if (( ${#files} )); then
         infmsg " Remove inst functions"
         OUTPUT=$(2>&1 rm -rf ${tempdir}inst*.sh)
         retc=$?
         if [ $retc -ne 0 ] ; then 
            errmsg "removing ${tempdir}inst*.sh"
            retc=22
         fi
      else
         infmsg " no inst functions to delete found"
      fi
   fi
   if [ $retc -eq 0 ] ; then 
      files=$(shopt -s nullglob dotglob; echo ${tempdir}*.rpm)
      if (( ${#files} )); then
         infmsg " Remove temp rpm packages"
         OUTPUT=$(2>&1 rm -rf ${tempdir}*.rpm)
         retc=$?
         if [ $retc -ne 0 ] ; then 
            errmsg "removing ${tempdir}*.rpm"
            retc=22
         fi
      else
         infmsg " no rpm packages found to remove"
      fi
   fi
   if [ $retc -eq 0 ] ; then 
      files=$(shopt -s nullglob dotglob; echo ${tempdir}*.tgz)
      if (( ${#files} )); then
         infmsg " Remove temp tgz packages"
         OUTPUT=$(2>&1 rm -rf ${tempdir}*.tgz)
         retc=$?
         if [ $retc -ne 0 ] ; then 
            errmsg "removing ${tempdir}*.tgz"
            retc=22
         fi
      else
         infmsg " no tgz packages found to remove"
      fi
   fi
fi

if [ $retc -eq 0 ] ; then 
   # restore rc.local - no install needed
   infmsg "Restore rc.local for next boot"
   OUTPUT=$(2>&1 cp -p -f $kspath/rpm/rc.local /etc/rc.d/rc.local)
   if [ $? -ne 0 ] ; then
      errmsg "cannot restore rc.local $OUTPUT - abort"
      retc=99
   else
      infmsg "Restore ok - level 1000"
      echo 1000 >$stagefile
   fi
fi

# copy log to install srv
infmsg "Returncode before log copy rc=[$retc]"
infmsg "copy log file to fsi server"
infmsg "- - - - - - - - - - - - - - - - - - - - - - - - - - -"
infmsg "XenServer Installation ended rc=[$retc]"
OUTPUT=$(2>&1 cat $logfile >$kspath/log/${HOSTNAME%%.*}.log)
copyretc=$?
if [ $copyretc -ne 0 ] ; then
   errmsg "cannot copy logfile to fsi server $OUTPUT - abort"
fi 

# all ok - reboot server
if [ $retc -eq 0 ]; then
   infmsg "all ok - reboot now"
   ifdebug
   restart
else
   infmsg "copy messages file to fsi server"
   OUTPUT=$(2>&1 cat /var/log/messages >$kspath/log/${HOSTNAME%%.*}-messages.log)
   if [ $? -ne 0 ] ; then
        errmsg "cannot copy messages log to fsi server $OUTPUT - abort"
        retc=99
   fi 
   infmsg "copy xensource.log file to fsi server"
   OUTPUT=$(2>&1 cat /var/log/xensource.log >$kspath/log/${HOSTNAME%%.*}-xensource.log)
   if [ $? -ne 0 ] ; then
        errmsg "cannot copy xensource.log to fsi server $OUTPUT - abort"
        retc=99
   fi 
   errmsg "one or more error exist - stop"
   echo " "
   read -p "Press any key ..."
fi

exit $retc
# end


