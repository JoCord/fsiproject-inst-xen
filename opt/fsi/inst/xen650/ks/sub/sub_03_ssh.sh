#!/bin/sh
#
#   sub_03_ssh.sh - ssh server config
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
ver="1.0.10 - 03.03.2017"
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

syspath="/mnt/sys"
mountsys="/opt/fsi/pxe/sys"

infmsg "$ls Configure remote connection v.$ver"
infmsg "$ls  Enable ssh login"
infmsg "$ls  Change Root Login to yes"
cat /etc/ssh/sshd_config |sed "s/PermitRootLogin no/PermitRootLogin yes/g" >/tmp/new-sshd
infmsg "$ls  rename org file"
rename /etc/ssh/sshd_config /etc/ssh/sshd_config.org
infmsg "$ls  copy new file"
cp -f /tmp/new-sshd /etc/ssh/sshd_config
infmsg "$ls  remove temp file"
rm -f /tmp/new-sshd

jobrm=(
   /root/.ssh/known_hosts
   /root/.ssh/authorized_keys
   /etc/ssh/ssh_host_*
)

jobwget1=(
   known_hosts 
   authorized_keys
   id_rsa
   id_rsa.pub
)

jobwget2=(
   ssh_host_dsa_key
   ssh_host_dsa_key.pub
   ssh_host_key 
   ssh_host_key.pub
   ssh_host_rsa_key
   ssh_host_rsa_key.pub
)

jobchmod=(
   /root/.ssh/known_hosts
   /root/.ssh/id_rsa.pub
   /root/.ssh/id_rsa
   /root/.ssh/authorized_keys
   /etc/ssh/ssh_host_key*
   /etc/ssh/ssh_host_dsa*
   /etc/ssh/ssh_host_rsa*
)

infmsg "$ls  remove old files"
for ((i=0; i<${#jobrm[*]}; i++)); do
    tracemsg "$ls   job: ${jobrm[$i]}"
    OUTPUT=$(2>&1 rm -rf ${jobrm[$i]})
    if [ $? -ne 0 ]; then
      errmsg "delete ${jobrm[$i]} [ $OUTPUT ]"
      retc=1
    else
      tracemsg "    ok "
    fi
done

if [ $retc -eq 0 ]; then
   infmsg "$ls  get new files"   
   if [ "$debug" == "yes" ] ; then read -p "Press any key ..." ; fi
   infmsg "$ls   Create temp sys dir"
   OUTPUT=$(2>&1 mkdir -v $syspath)
   if [ $? -ne 0 ]; then
      errmsg "cannot create dir [$OUTPUT] - abort"
      retc=89
   fi
fi


if [ $retc -eq 0 ]; then
   if [ "$debug" == "yes" ] ; then read -p "Press any key ..." ; fi
   infmsg "$ls   mount fsi server pxe sys"
   OUTPUT=$(2>&1 mount -t nfs $fsisrv":"$mountsys $syspath)
   if [ $? -ne 0 ]; then
      errmsg "cannot mount fsisrv [$OUTPUT] - abort"
      retc=99
   else
      infmsg "$ls   mount ok"
   fi
fi


for ((i=0; i<${#jobwget1[*]}; i++)); do
   debmsg "$ls   job: ${jobwget1[$i]}"
   if [ -f ${syspath}/$macd/ssh/${jobwget1[$i]} ]; then
      tracemsg "$ls  found ${jobwget1[$i]} on nfs and copy"
      OUTPUT=$(cp -f ${syspath}/$macd/ssh/${jobwget1[$i]} /root/.ssh/${jobwget1[$i]})
      retc=$?
      if [ $retc -ne 0 ]; then
         logmsg "ERROR  : cannot copy ${jobwget1[$i]} file [$OUTPUT] - abort"
         retc=77
         break
      fi
   else
      tracemsg "$ls   wget -P /root/.ssh http://$fsisrv/pxe/sys/$macd/ssh/${jobwget1[$i]} --no-check-certificate"
      OUTPUT=$(2>&1 wget -P /root/.ssh http://$fsisrv/pxe/sys/$macd/ssh/${jobwget1[$i]} --no-check-certificate)
      if [ $? -ne 0 ]; then
         errmsg "get file ${jobwget1[$i]} [ $OUTPUT ]"
         retc=96
         break
      else
         tracemsg "    ok "
      fi
   fi
done

for ((i=0; i<${#jobwget2[*]}; i++)); do
   debmsg "$ls   job: ${jobwget2[$i]}"
   if [ -f ${syspath}/$macd/ssh/${jobwget2[$i]} ]; then
      tracemsg "$ls  found ${jobwget1[$i]} on nfs and copy"
      OUTPUT=$(cp -f ${syspath}/$macd/ssh/${jobwget2[$i]} /etc/ssh/${jobwget2[$i]})
      retc=$?
      if [ $retc -ne 0 ]; then
         logmsg "ERROR  : cannot copy ${jobwget2[$i]} file [$OUTPUT] - abort"
         retc=77
         break
      fi
   else
      tracemsg "$ls   wget -P /etc/ssh http://$fsisrv/pxe/sys/$macd/ssh/${jobwget2[$i]} --no-check-certificate"
      OUTPUT=$(2>&1 wget -P /etc/ssh http://$fsisrv/pxe/sys/$macd/ssh/${jobwget2[$i]} --no-check-certificate)
      if [ $? -ne 0 ]; then
         errmsg "get file ${jobwget2[$i]} [ $OUTPUT ]"
         retc=97
         break
      else
         tracemsg "    ok "
      fi
   fi
done

if [ $retc -eq 0 ]; then
   if [ "$debug" == "yes" ] ; then read -p "Press any key ..." ; fi
   infmsg "$ls   umount fsi server pxe sys"
   OUTPUT=$(2>&1 umount $syspath)
   if [ $? -ne 0 ]; then
      errmsg "cannot mount fsisrv [$OUTPUT] - abort"
      retc=99
   else
      infmsg "$ls   umount ok"
   fi
fi

if [ $retc -eq 0 ]; then
   if [ "$debug" == "yes" ] ; then read -p "Press any key ..." ; fi
   infmsg "$ls   Remove temp sys dir"
   OUTPUT=$(2>&1 rmdir $syspath)
   if [ $? -ne 0 ]; then
      errmsg "cannot remove dir [$OUTPUT] - abort"
      retc=89
   fi
fi

infmsg "$ls chmod files"
for ((i=0; i<${#jobchmod[*]}; i++)); do
    tracemsg "$ls   job: ${jobchmod[$i]}"
    tracemsg "$ls   chmod 644 ${jobchmod[$i]}"
    OUTPUT=$(2>&1 chmod 600 ${jobchmod[$i]})
    if [ $? -ne 0 ]; then
      errmsg "cannot chmod ${jobchmod[$i]} [ $OUTPUT ]"
      retc=98
      break
    else
      tracemsg "    ok "
    fi
done

infmsg "$ls restart sshd service"
OUTPUT=$(2>&1 service sshd restart)
if [ $? -ne 0 ]; then
   errmsg "cannot restart sshd service $OUTPUT - abort"
   retc=99
else
    infmsg "$ls   sshd restarted"
fi

if [ $retc -eq 0 ]; then
  infmsg "$ls rc=0 means all ok, set to 1 to reboot"
  retc=1
elif [ $retc -eq 1 ]; then
  errmsg "something wrong - 1 means reboot, but error - set to 2"
  retc=2
else
  errmsg "something wrong"
fi

infmsg "$ls End configure remote rc=$retc"
exit $retc
