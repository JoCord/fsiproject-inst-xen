#!/bin/sh
#
#   inst_05_pm.sh - install perl module
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
pm="/tmp/fsipmm.tgz"

ver="1.0.6 - 12.9.2016"
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

if [ -f $fsivars ] ; then
    . $fsivars
else
   errmsg "ERROR cannot load fsi vars $fsivars"
   exit 99
fi

infmsg "$ls Install perl module"

if [ $retc -eq 0 ]; then
    infmsg "$ls   call yum install LibXML"
    OUTPUT=$(2>&1 yum install perl-XML-LibXML -qy)
    if [ $? -ne 0 ]; then
       errmsg "error yum install: $OUTPUT - abort"
       retc=99
    else
       infmsg "$ls   install yum ok"
    fi
fi

if [ $retc -eq 0 ]; then
    infmsg "$ls   call yum install libwww"
    OUTPUT=$(2>&1 yum install perl-libwww-perl -qy)
    if [ $? -ne 0 ]; then
       errmsg "error yum install: $OUTPUT - abort"
       retc=99
    else
       infmsg "$ls   install yum ok"
    fi
fi
    
if [ $retc -eq 0 ]; then
    infmsg "$ls   call yum install crypt"
    OUTPUT=$(2>&1 yum install perl-Crypt-SSLeay -qy)
    if [ $? -ne 0 ]; then
       errmsg "error yum install: $OUTPUT - abort"
       retc=99
    else
       infmsg "$ls   install yum ok"
    fi
fi
    
if [ -f $pm ]; then
   infmsg "$ls  found perl module archiv - unpack it ..."
   OUTPUT=$(2>&1 tar -xzf $pm -C $fsidir)
   if [ $? -ne 0 ]; then
      errmsg "error unpacking perl modules: $OUTPUT - abort"
      retc=99
   else
      infmsg "$ls  install perl modules finished"
   fi
else
   errmsg "cannot find $pm - abort"
   retc=96
fi


infmsg "End bind installation rc=$retc "
exit $retc



