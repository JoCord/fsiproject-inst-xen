#!/bin/sh
#
#   sub-04_cert-default.sh - cert default install
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
macd="none"

ver="1.0.8 - 14.03.2017"
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
syspath="/mnt/sys"
mountsys="/opt/fsi/pxe/sys"

infmsg "$ls default cert Installation v. $ver"

if [ "$macd" = "none" ] ; then
    errmsg "no mac found - abort"
    retc=98
fi

if [ $retc -eq 0 ]; then
   infmsg "$ls  get host certificate"
   debmsg "$ls    fsisrv: $fsisrv"
   debmsg "$ls    mac: $macd"
   
   if [ $retc -eq 0 ]; then
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
   
   
   if [ -f ${syspath}/$macd/cert/$xencfg.pem ]; then
      tracemsg "$ls  found ${syspath}/$macd/cert/$xencfg.pem on nfs and copy"
      OUTPUT=$(cp -f ${syspath}/$macd/cert/$xencfg.pem /etc/xensource/xapi-ssl.pem-new)
      retc=$?
      if [ $retc -ne 0 ]; then
         errmsg "cannot copy ${syspath}/$macd/cert/$xencfg.pem file [$OUTPUT] - ignore"
         retc=0
      else
         infmsg "$ls  get new pem over nfs = ok"
      fi
   else
      tracemsg "$ls  not found on nfs, try http"
      OUTPUT=$(2>&1 wget http://$fsisrv/pxe/sys/$macd/cert/$xencfg.pem --no-check-certificate -O /etc/xensource/xapi-ssl.pem-new)
      if [ $? -ne 0 ]; then
         warnmsg "$ls  cannot get cert - ignore cert installation"
         retc=0
         if [ -f /etc/xensource/xapi-ssl.pem-new ]; then   
            infmsg "$ls  found /etc/xensource/xapi-ssl.pem-new but empty - delete file"
            OUTPUT=$(2>&1 rm /etc/xensource/xapi-ssl.pem-new)
            if [ $? -ne 0 ]; then
               errmsg "cannot delete file"
               retc=99
            else
               infmsg "$ls  ok"
            fi
         fi
            
      else
         infmsg "$ls  get new pem over http = ok"
      fi
   fi
   
   if [ -f /etc/xensource/xapi-ssl.pem-new ]; then   
      infmsg "$ls  got new ssl pem, activate new"
      if [ $retc -eq 0 ]; then
         infmsg "$ls  backup org cert"
         OUTPUT=$(2>&1 rename /etc/xensource/xapi-ssl.pem /etc/xensource/xapi-ssl.pem.org)
         if [ $? -ne 0 ]; then
            errmsg "cannot rename file"
            retc=99
         else
            infmsg "$ls  ok"
         fi
      fi
      
      if [ $retc -eq 0 ]; then
         infmsg "$ls  rename new cert"
         OUTPUT=$(2>&1 rename /etc/xensource/xapi-ssl.pem-new /etc/xensource/xapi-ssl.pem)
         if [ $? -ne 0 ]; then
            errmsg "cannot rename file"
            retc=99
         else
            infmsg "$ls  ok"
         fi
      fi
      
      if [ $retc -eq 0 ] && [ -e /etc/xensource/xapi-ssl.pem ]; then
         infmsg "$ls  chmod certificate"
         OUTPUT=$(2>&1 chmod 400 /etc/xensource/xapi-ssl.pem)
         if [ $? -ne 0 ]; then
            errmsg "cannot chmod pem file - abort"
            retc=99
         else
            infmsg "$ls  ok"
         fi
      fi
      
      if [ $retc -eq 0 ]; then
         infmsg "$ls  restart ssl service"
         OUTPUT=$(2>&1 service xapissl restart)
         if [ $? -ne 0 ]; then
            errmsg "cannot stop ntpd dameon"
            retc=99
         else
            infmsg "$ls  xapissl restarted"
         fi
      fi
   fi
   
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
   
fi



infmsg "$ls Install cert end rc=$retc"
exit $retc     
