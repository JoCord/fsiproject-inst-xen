#!/bin/sh
#
#   sub-38_pool_join-default.sh - join pool
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
HOSTuuid="none"
pool="none"
poolu="root"
poolpw="none"
poolc="1"
havrun=0                                                                                    # disable ha actions
debug="trace"
waitend=10
waittime=15
waitcount=0

ver="1.0.14 - 9.9.2016"
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

infmsg "$ls   Join pool default v.$ver"

if [ $retc -eq 0 ]; then
    if [ "$Hostuuid" == "none" ] ; then
        errmsg "cannot detect Host uuid"
        retc=40
    fi
fi

if [ $retc -eq 0 ]; then
    if [ "$pool" == "none" ]; then
        errmsg "pool var empty"
        retc=41
    fi
fi

if [ $retc -eq 0 ]; then
    if [ "$poolu" == "none" ]; then
        errmsg "pool user var empty"
        retc=42
    fi
fi

if [ $retc -eq 0 ]; then
    if [ "$poolpw" == "none" ]; then
        errmsg "pool password var empty"
        retc=43
    fi
fi

if [ $retc -eq 0 ]; then
    if [ "$insttyp" == "none" ] ; then
        errmsg "Install typ empty"
        retc=44
    fi
fi

if [ $retc -eq 0 ]; then
    if [ -z $masterip ]; then
        debmsg "$ls master ip not set - try to detect ip ..."
        master=$(2>&1 /usr/bin/fsimaster name)
        retc=$?
        if [ $retc -ne 0 ]; then
           errmsg "cannot detect master - abort"
           retc=66
        else
           debmsg "$ls master: $master"
           if [ -z $dnsdom ]; then
              dnsmaster=$master
           else
              dnsmaster=$master"."$dnsdom
           fi
           masterip=$(2>&1 /usr/bin/fsimaster ip $dnsmaster)
           retc=$?
           if [ $retc -ne 0 ]; then
                errmsg "cannot detect master ip - abort"
                retc=67
           else
                debmsg "$ls master ip: $masterip"
           fi
        fi
    fi                  
fi

if [ $havrun -eq 0 ]; then
    if [ $retc -eq 0 ]; then
        infmsg "$ls   disable ha in pool"
        /usr/bin/fsichha -d -s 2
        if [ $? -ne 0 ]; then
           errmsg "cannot disable ha - abort"
           retc=99
        else
           infmsg "$ls    ha disabled"
        fi   
    fi
else
    infmsg "$ls   ha config disable"
fi

if [ $retc -eq 0 ]; then
    infmsg "$ls   pool tag to member ..."
    OUTPUT=$(2>&1 xe host-param-add uuid=$HOSTuuid param-name=tags param-key=Poolmember)
    if [ $? -ne 0 ]; then
       errmsg "cannot set poolmember flag $OUTPUT - abort"
       retc=99
    else
        infmsg "$ls   member flag ok"
    fi   
fi

if [ $retc -eq 0 ]; then
    infmsg "$ls   try to join pool ..."
    uncryptpw=$(/usr/bin/fsidecrypt$xensource --pw $poolpw --code $poolc)
    debmsg "$ls   join user: $poolu"
    debmsg "$ls   masterip: $masterip"
    OUTPUT=$(2>&1 xe pool-join master-address=$masterip master-username=$poolu master-password=$uncryptpw)
    if [ $? -ne 0 ]; then
       errmsg "cannot join pool [$OUTPUT] - abort"
       retc=99
    else
        infmsg "$ls    join ok - now wait for replication pool db."
        
        echo -n $(date +%H:%M:%S)" INFO   : $ls  Waiting ."
        while [ $waitcount -le $waitend ]; do
           echo -n "."
           sleep $waittime
           waitcount=$((waitcount+1))
        done
        echo " ok"
        
        retc=1 # means reboot server
    fi   
fi

if [ $havrun -eq 0 ] && [ $retc -eq 0 ]; then
    infmsg "$ls    enable ha in pool"
    /usr/bin/fsichha -a -s 2
    retc=$?
    if [ $retc -eq 0 ]; then
       infmsg "$ls    ha enabled"
    elif [ $retc -eq 2 ]; then
       infmsg "$ls    no ha configure"
       retc=0
    elif [ $retc -eq 3 ]; then
       warnmsg "$ls   not enough xenserver in pool"
       retc=0
    else
       infmsg "$ls    error during ha enabling"
    fi   
else
    infmsg "$ls   ha enabled"
fi

if [ $retc -eq 1 ]; then
    infmsg "$ls    pool join ok, need reboot"
elif [ $retc -eq 0 ]; then
    infmsg "$ls    return code 0 means ok, pool join need reboot!"
    retc=1
else
    errmsg "something wrong"
fi

debmsg "$ls End finish join pool routine rc=$retc"
exit $retc



