#!/bin/sh
#
#   create-customize.sh - post installation xen server
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
# fsi server ip list
viips=( 10.10.10.60 172.16.1.3 192.168.3 172.16.202.60 )

# Misc variables
version="1.2.02 - 03.03.2017"

rootdir="/tmp/root"
xensource="xen$(sed -n 's/^.*[ ]\([0-9]\.[0-9]*\)[ .].*/\1/p' $rootdir/etc/redhat-release| sed 's/\.//')0"              # xen650
xenmain="$(sed -n 's/^.*[ ]\([0-9]*\)[ .].*/\1/p' $rootdir/etc/redhat-release)"                                         # 6
xencfg="xen$xenmain"                                                                                                    # xen6
regex_ip='\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b'
regex_mac='^([0-9a-f]{2}[:-]){5}([0-9a-f]{2})$'

kspath="$rootdir/mnt/ks"
syspath="$rootdir/mnt/sys"
mountp="/opt/fsi/inst/$xensource/ks"
mountsys="/opt/fsi/pxe/sys"
fsidir="/var/fsi"
visrvfile=$rootdir"$fsidir/fsisrv"
vimountfile=$rootdir"$fsidir/vimount"
logfile=$rootdir"$fsidir/fsixeninst.log"
stagefile=$rootdir"$fsidir/vistage"
progname=${0##*/}
fsisrv=""
debug="no"
retc=0

# functions
logmsg() {
   local timestamp=$(date +%H:%M:%S)
   local datetimestamp=$(date +%Y.%m.%d)"-"${timestamp}
   local pidnr=$$
   local progname=${0##*/}
   tput setaf 2
   echo $timestamp "$1"
   tput sgr0
   printf "%-19s : %-6d - %-30s %s\n" $datetimestamp,000 $pidnr $progname "$1" >>$logfile
}

if [ $retc -eq 0 ]; then
   OUTPUT=$(2>&1 mkdir -v $rootdir$fsidir)
   if [ $? -ne 0 ]; then
      logfile="/root/fsixeninst-error.log"
      logmsg "ERROR  : cannot create VI dir = $OUTPUT - abort"
      retc=88
   fi
fi

# main
logmsg "INFO   :  - - - - - - - - - - - - - - - - - - - - - - - - - - -"
logmsg "INFO   :  Start post xen server install - Version $version"
logmsg "INFO   :   Stage: 1"
logmsg "INFO   :    test vars"
if [ "$xenmain" != "6" ] && [ "$xenmain" != "7" ]; then
   logmsg "ERROR  : unsupported xenserver version [$xenmain]"
   exit 99
else
   logmsg "INFO   : os main [$xenmain]"
fi
if [ "$xensource" != "" ]; then
   logmsg "INFO   :  xensource: $xensource"
else
   logmsg "ERROR  : cannot find xensource"
   exit 99
fi

logmsg "INFO   :  detec mac"
if [ "$xenmain" == "6" ]; then
   mac=$(ifconfig eth0 | grep -m 1 HWaddr | tr -s " " | cut -d " " -f 5 | tr '[:upper:]' '[:lower:]' | tr ':' '-')
   elif  [ "$xenmain" == "7" ]; then
   mac=$(ifconfig eth0 | grep -m 1 ether | tr -s " " | cut -d " " -f 3 | tr '[:upper:]' '[:lower:]' | tr ':' '-')
fi
if [ "$mac" != "" ]; then
   if [[ ! $mac =~ $regex_mac ]]; then
      logmsg "ERROR [$mac] is not a valid MAC - abort"
      retc=99
   else
      logmsg "INFO   :  mac found [$mac]"
   fi
else
   retc=99
fi

if [ $retc -eq 0 ]; then
   myip=$(ip addr show eth0 | grep -i inet | cut -d " " -f 6 | cut -d "/" -f 1)
   myip=$(echo $myip|sed 's/[ ].*$//')        # delete all after space (or line feed)
   if [ "$myip" != "" ]; then
      if [[ ! $myip =~ $regex_ip ]]; then
         logmsg "ERROR: ip is not valid [$myip]"
         retc=66
      else
         logmsg "INFO   :  ip found [$myip]"
      fi
   else
      logmsg "ERROR: cannot detect my ip"
      retc=66
   fi
fi

if [ $retc -eq 0 ]; then
   mynet=${myip%.*}
   logmsg "INFO   :  ip subnet found [$mynet]"
   mynm=$(ip addr show eth0 | grep -i inet | cut -d " " -f 6 | cut -d "/" -f 2)
   mynm=$(echo $mynm|sed 's/[ ].*$//')        # delete all after space (or line feed)
   logmsg "INFO   :  nm found [$mynm]"
   myroute=$(ip route)
   logmsg "INFO   :  route found [$myroute]"
fi

if [ $retc -eq 0 ]; then
   for ((l=0; l<${#viips[*]}; l++)); do
      viip=${viips[$l]}
      vinet=${viip%.*}
      if [ "$vinet" == "$mynet" ]; then
         logmsg "INFO   :  set found fsi server ip in mgmt net [$viip]"
         fsisrv=$viip
      fi
   done
fi

if [ "$fsisrv" == "" ]; then
   logmsg "WARN   : cannot find fsi server ip - take first as default"
   fsisrv=${viips[0]}
else
   logmsg "INFO   :   fsi srv ip: $fsisrv"
fi

# customize.sh
if [ $retc -eq 0 ]; then
   if [ "$debug" == "yes" ] ; then read -p "Press any key ..." ; fi
   logmsg "INFO   :  Create temp ks dir"
   OUTPUT=$(2>&1 mkdir -v $kspath)
   if [ $? -ne 0 ]; then
      logmsg "ERROR  : cannot create dir = $OUTPUT - abort"
      retc=88
   fi
fi

if [ $retc -eq 0 ]; then
   if [ "$debug" == "yes" ] ; then read -p "Press any key ..." ; fi
   logmsg "INFO   :  mount fsi server ks dir"
   OUTPUT=$(2>&1 mount -t nfs $fsisrv":"$mountp $kspath)
   if [ $? -ne 0 ]; then
      logmsg "ERROR  : cannot mount fsisrv [$OUTPUT] - abort"
      retc=99
   else
      logmsg "INFO   : mount ok"
   fi
fi

if [ $retc -eq 0 ]; then
   logmsg "INFO   :  copy customize script"
   if [ -f ${kspath}/$xensource/ks/customize.sh ]; then
      logmsg "INFO   :    found on nfs and copy"
      OUTPUT=$(cp -f ${kspath}/$xensource/ks/customize.sh $rootdir$fsidir/customize.sh)
      retc=$?
      if [ $retc -ne 0 ]; then
         logmsg "ERROR  : cannot copy customize script [$OUTPUT] - abort"
         retc=77
      fi
   else
      logmsg "INFO   :    do not find on nfs export, try http"
      OUTPUT=$(2>&1 wget -P $rootdir$fsidir/ http://$fsisrv/fsi/$xensource/ks/customize.sh)
      retc=$?
      if [ $retc -ne 0 ]; then
         logmsg "ERROR  : cannot get customize script [$OUTPUT] - abort"
         retc=78
      fi
   fi
fi

if [ $retc -eq 0 ]; then
   if [ "$debug" == "yes" ] ; then read -p "Press any key ..." ; fi
   logmsg "INFO   :  chmod customize script"
   OUTPUT=$(2>&1 chmod 077 $rootdir$fsidir/customize.sh)
   if [ $? -ne 0 ]; then
      logmsg "ERROR  : cannot get chmod customize script $OUTPUT - abort"
      retc=66
   fi
fi

# config files
if [ $retc -eq 0 ]; then
   if [ "$debug" == "yes" ] ; then read -p "Press any key ..." ; fi
   logmsg "INFO   :  Create temp sys dir"
   OUTPUT=$(2>&1 mkdir -v $syspath)
   if [ $? -ne 0 ]; then
      logmsg "ERROR  : cannot create dir [$OUTPUT] - abort"
      retc=89
   fi
fi


if [ $retc -eq 0 ]; then
   if [ "$debug" == "yes" ] ; then read -p "Press any key ..." ; fi
   logmsg "INFO   :  mount fsi server pxe sys"
   OUTPUT=$(2>&1 mount -t nfs $fsisrv":"$mountsys $syspath)
   if [ $? -ne 0 ]; then
      logmsg "ERROR  : cannot mount fsisrv [$OUTPUT] - abort"
      retc=99
   else
      logmsg "INFO   : mount ok"
   fi
fi


job=(
   $xencfg.conf
   $xencfg.ext
   $xencfg.pool
   $xencfg.sh
)

if [ $retc -eq 0 ]; then
   logmsg "INFO   :  get config files"
   for ((i=0; i<${#job[*]}; i++)); do
      if [ "$debug" == "yes" ] ; then logmsg "DEBUG     job: ${job[$i]}" ; fi
      if [ -f ${syspath}/$mac/${job[$i]} ]; then
         logmsg "INFO   :    found ${job[$i]} on nfs and copy"
         OUTPUT=$(cp -f ${syspath}/$mac/${job[$i]} $rootdir$fsidir/${job[$i]})
         retc=$?
         if [ $retc -ne 0 ]; then
            logmsg "ERROR  : cannot copy ${job[$i]} file [$OUTPUT] - abort"
            retc=77
         fi
      else
         logmsg "INFO   :  not find on nfs, try http://$fsisrv/pxe/sys/$mac/${job[$i]}"
         OUTPUT=$(2>&1 wget -P $rootdir$fsidir/ http://$fsisrv/pxe/sys/$mac/${job[$i]})
         if [ $? -ne 0 ] ; then
            if [ "${job[$i]}" == "$xencfg.pool" ] || [ "${job[$i]}" == "$xencfg.sh" ] ; then
               logmsg "WARN   :  cannot get optional conf script ${job[$i]} - maybe not exist, ignore warning"
               retc=0
            else
               logmsg "ERROR  : cannot get conf script [$OUTPUT] - abort"
               retc=98
            fi
         else
            if [ "$debug" == "yes" ] ; then logmsg "DEBUG     ok " ; fi
         fi
      fi
   done
fi

if [ $retc -eq 0 ]; then
   if [ "$debug" == "yes" ] ; then read -p "Press any key ..." ; fi
   logmsg "INFO   :  chmod config script"
   OUTPUT=$(2>&1 chmod 0777 $rootdir$fsidir/$xencfg.conf)
   if [ $? -ne 0 ]; then
      logmsg "ERROR  : cannot chmod conf script $OUTPUT - abort"
      retc=1
   fi
fi

if [ $retc -eq 0 ]; then
   logmsg "INFO   :  write xensource [$xensource] in [$rootdir$fsidir/$xencfg.conf]"
   echo >>$rootdir$fsidir/$xencfg.conf
   echo xensource=$xensource >>$rootdir$fsidir/$xencfg.conf
fi


if [ $retc -eq 0 ]; then
   if [ "$debug" == "yes" ] ; then read -p "Press any key ..." ; fi
   logmsg "INFO   :  create fsi deploy server conf file"
   OUTPUT=$(2>&1 echo $fsisrv >$visrvfile)
   if [ $? -ne 0 ]; then
      logmsg "ERROR  : cannot create fsisrv file $OUTPUT - abort"
      retc=1
   fi
fi


if [ $retc -eq 0 ]; then
   if [ "$debug" == "yes" ] ; then read -p "Press any key ..." ; fi
   logmsg "INFO   :  reate fsi deploy server temp mount file"
   OUTPUT=$(2>&1 echo $mountp >$vimountfile)
   if [ $? -ne 0 ]; then
      logmsg "ERROR  : cannot create fsisrv mount file $OUTPUT - abort"
      retc=2
   fi
fi

if [ $retc -eq 0 ]; then
   logmsg "INFO   :  Create new log.cfg"
    cat >>$rootdir$fsidir/log.cfg <<"EOF3"
# Version 1.00
log4perl.category = TRACE, Logfile, Screen
log4perl.appender.Logfile = Log::Log4perl::Appender::File
log4perl.appender.Logfile.filename = sub { return get_log_fn(); }
log4perl.appender.Logfile.mode = append
log4perl.appender.Logfile.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Logfile.layout.ConversionPattern = %d{yyyy.MM.dd-HH:mm:ss,SSS} : %-6P - %-30F{1} %-6p : %m %n
log4perl.appender.Screen        = Log::Log4perl::Appender::ScreenColoredLevels
log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern = %d{HH:mm:ss} %-6p : %m %n
log4perl.appender.Screen.Threshold = INFO
EOF3
   
fi

if [ $retc -eq 0 ]; then
   logmsg "INFO   :  Create new rc.local to call customize script after reboot"
    cat >>$rootdir/etc/rc.local <<"EOF2"

logfile=/var/fsi/fsixeninst.log
function logmsg() {
   local timestamp=$(date +%H:%M:%S)
   local datetimestamp=$(date +%Y.%m.%d)"-"${timestamp}
   local pidnr=$$
   local progname=${0##*/}
   tput setaf 2
   echo $timestamp "$1"
   tput sgr0
   printf "%-19s : %-6d - %-30s %s\n" $datetimestamp,000 $pidnr $progname "$1" >>$logfile
}
logmsg "INFO   :  - - - - - - - - - - - - - - - - - - - - - - - - - - -"
logmsg "INFO   :  Start post install script on ${HOSTNAME%%.*} Version $version"
logmsg "INFO   :  end rc.local - start customize installation script"
/var/fsi/customize.sh
sleep 100
EOF2
   logmsg "INFO   :  Create stage file"
   logmsg "INFO   :  set -x to file"
   out=$(2>&1 chmod +x $rootdir/etc/rc.d/rc.local)
   if [ $? -ne 0 ]; then
      logmsg "ERROR  : cannot set execute flag to rc.local"
      logmsg "[$out]"
      retc=3
   fi
   echo 2 >$stagefile
fi

if [ $retc -eq 0 ]; then
   if [ "$xenmain" == "6" ] ; then
      if [ "$debug" == "yes" ] ; then read -p "Press any key (6)..." ; fi
      logmsg "INFO   :  Create extlinux.conf without quiet .."
      sed -e s/quiet//g -e s/splash//g $rootdir/boot/extlinux.conf >$rootdir/boot/extlinux.new
      logmsg "INFO   :  rename org file"
      rename /$rootdir/boot/extlinux.conf $rootdir/boot/extlinux.org
      logmsg "INFO   :  copy new file"
      cp -f $rootdir/boot/extlinux.new $rootdir/boot/extlinux.conf
      elif  [ "$xenmain" == "7" ]; then
      if [ "$debug" == "yes" ] ; then read -p "Press any key ..." ; fi
      logmsg "INFO   :  Create grub.conf without quiet (7)..."
      sed -e s/quiet//g -e s/splash//g $rootdir/boot/grub/grub.conf >$rootdir/boot/grub/grub.new
      logmsg "INFO   :  rename org file"
      rename $rootdir/boot/grub/grub.conf $rootdir/boot/grub/grub.org
      logmsg "INFO   :  copy new file"
      cp -f $rootdir/boot/grub/grub.new $rootdir/boot/grub/grub.conf
   fi
fi

logmsg "INFO   : End post xen server installation - reboot"




