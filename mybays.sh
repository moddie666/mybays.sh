#!/bin/bash
#
# https://github.com/moddie666/mybays.sh
#

ME=$(basename $0)
DEPS="sas2ircu"
for d in $DEPS
do if [ "x$(which $d)" = "x" ]
   then missing+=" $d"
   fi
done
if [ "x$missing" != "x" ]
then echo "Missing dependency:$missing!"
     exit 1
fi
#--- COLORS ---#
nc=$(tput sgr 0)
rd=$(tput setaf 9)
gr=$(tput setaf 10)
yl=$(tput setaf 11)
cy=$(tput setaf 14)

################
#    CONFIG    #
################
#
# ENCLOSURE INFO, HORIZONTAL EACH ELEMENT REPRESENTS A LINE OF BAYS
# FORMAT (BAY_DEF):(CTL#):(SLOT#) 
# CTL/SLOT# ... Numbers as reported by sas2ircu
# BAY_DEF   ... Your custom bay definition (i.e. numbering, any chars except ":" allowed.
#               Just take into account wmax per bay.
# NOTE: Using ":" in BAY_DEF WILL BREAK output.
# CUSTOMIZE THIS OR CREATE YOUR OWN CONFIG IN /etc/<script-name>.conf TO FIT YOUR CHASSIS!
#
BAYLINES=( #"BAYS" (0|1):[0-3] are not connected to the backplane
   "1:0:7 2:0:6 3:0:5 4:0:4" #CTL1
   "5:1:7 6:1:6 7:1:5 8:1:4" #CTL2
   "9:0:11 10:0:10 11:0:9 12:0:8" #$CTL1
   "13:1:11 14:1:10 15:1:9 16:1:8" #$CTL2
   "17:0:15 18:0:14 19:0:13 20:0:12" #$CTL1
   "21:1:15 22:1:14 23:1:13 24:1:12" #$CTL2
          )
#PRINTF WIDTH PER SLOT
wmax=18

#INFO ITEMS PRINTED FOR EACH BAY
LINE_ITEMS="mdl_line size_line ser_line wwn_line"
# mdl_line  ... model string
# size_line ... size in MB
# ser_line  ... serial 
# wwn_line  ... wwn

#PRINT ZFS LINE BY DEFAULT? (on/off)
ZFS_DEFAULT=off

if [ -f "/etc/$ME.conf" ]
then source /etc/$ME.conf
     CF="CONFIG in /etc/$ME.conf"
else CF="CONFIG in $ME"
fi

USAGE="$ME [-z|-h]
OPTIONS:
        -z|--zfs  ... include zfs status info
        -h|--help ... print this text

CURRENT BAY CONFIG:
ENCLOSURE INFO, HORIZONTAL EACH ELEMENT REPRESENTS A LINE OF BAYS
FORMAT (CTL#):(SLOT#)
$CF
$(for line in "${BAYLINES[@]}"
do echo "---------------------"
   echo -n '|'
   for i in $line
   do echo -n "$i|"
   done
   echo
done)"

#################
#    OPTIONS    #
#################
while [ ! -z $1 ]
do case $1 in
        -z|--zfs) ZS=$(zpool status -L | awk '{print $1, $2, $3, $4, $5}'| sed -n '/NAME STATE READ WRITE CKSUM/,$p')
                  shift;;
       -h|--help) echo "$USAGE"
                  exit 0;;
               *) echo "unrecognized option $1"
                  EXIT=1
                  shift;;
   esac
done
if [ "$ZFS_DEFAULT" = "on" ] && [ "x$ZS" = "x" ]
then ZS=$(zpool status -L | awk '{print $1, $2, $3, $4, $5}'| sed -n '/NAME STATE READ WRITE CKSUM/,$p')
fi
if [ "$EXIT" = "1" ]
then exit $EXIT
fi

#####################
#    GATHER DATA    #
#####################
1>&2 echo -en "Emumerating Controllers\r"
CTL=$(sas2ircu list | egrep -o '^\s+[0-9]+' | awk '{print $1}')

1>&2 echo -en "Getting Disk Info      \r"
for c in $CTL
do CTLS[$c]=$(sas2ircu $c display | egrep '^  Serial No|^  Slot #|^  Model Number|^  GUID|^\s?$|^  Size ')
done

########################
#    TRANSFORM DATA    #
########################
listconns(){ #list disk info for connected lsi hba slots, output as array for later evaluation
for k in ${!CTLS[@]}
do #echo -e "\n#--- $k ---#"
   ctr=0
   for i in $(echo "${CTLS[$k]}" | sed -r 's# ##g' | awk -F: '{print $2}')
   do echo "${k}:${i}"
   done | while read -r line
          do if egrep '^[0-9]+:[0-9]+$' <<< "$line" &>/dev/null
             then echo -en "\"\nCONNS[$line]=\""
             else echo -n "$line" | sed -r 's#^[0-9]+:##g;s#$#:#g'
             fi
          done | sed -r 's#^"$##g;s#:"$#"#g;s#:$##g'
echo '"'
done
}

declare -A CONNS
eval "$(listconns)"
1>&2 echo -en "Formatting Data       \r"
#bay=1
for line in "${BAYLINES[@]}"
do declare -A BAY MBS MDL SER WWN DEV ZFS
   for def in $line
   do slot="$(awk -F: '{print $2":"$3}' <<< "$def")" # EXTRACT sas2ircu SLOT DEFINITION FROM CONFIG
      BAY[$slot]="$(awk -F: '{print $1}' <<< "$def")"
      MBS[$slot]="$(awk -F: '{print $1}' <<< "${CONNS[$slot]}"|sed -r 's#/.*# MB#g')"
      MDL[$slot]="$(awk -F: '{print $2}' <<< "${CONNS[$slot]}")"
      SER[$slot]="$(awk -F: '{print $3}' <<< "${CONNS[$slot]}")"
      WWN[$slot]="$(awk -F: '{print $4}' <<< "${CONNS[$slot]}")"
      DEV[$slot]="$(readlink -e /dev/disk/by-id/wwn-0x$(awk -F: '{print $4}' <<< "${CONNS[$slot]}"))"
      if [ ! -z "$ZS" ]
      then ZFS[$slot]="$(egrep "^$(basename ${DEV[$slot]} 2>/dev/null) " <<< "$ZS" |sed -r "s#$(basename ${DEV[$slot]} 2>/dev/null) ##g")"
      fi
#      bay=$((bay+1))
   done
done

#########################
#    OUPUT FUNCTIONS    #
#########################
#OUTPUT FUNCTIONS TAKE SLOT NUMBERS (from sas2ircu output)
#TO FILL HORIZONTAL LINES WITH INFORMATION
head_line(){
  for slot in $@
  do printf "|%-${wmax}s" " BAY ${BAY[$slot]}: ${DEV[$slot]}"
  done
}
zfs_line(){
  unset hasdata
  #FIRST CHECK IF THERE IS DATA ON THE LINE  
  for slot in $@
  do if [ ! -z "${ZFS[$slot]}" ]
     then hasdata=yes
     fi
  done
  #RETURN IF NO DATA
  if [ "$hasdata" != "yes" ]
  then return 1
  fi
  #OTHERWISE PRINT LINE
  for slot in $@
  do if egrep "^ONLINE 0 0 0$" <<< "${ZFS[$slot]}" &>/dev/null
     then printf "|$gr%-${wmax}s$nc" " ${ZFS[$slot]}"
     elif [ "x${ZFS[$slot]}" = "x" ] && [ "x${DEV[$slot]}" != "x" ]
     then printf "|$cy%-${wmax}s$nc" " not in any pool"
     else printf "|$yl%-${wmax}s$nc" " ${ZFS[$slot]}"
     fi
  done
}
wwn_line(){
  unset hasdata
  for slot in $@
  do if [ ! -z "${WWN[$slot]}" ] 
     then hasdata=yes
     fi
  done
  if [ "$hasdata" != "yes" ]
  then return 1
  fi
  for slot in $@
  do printf "|%-${wmax}s" " ${WWN[$slot]}"
  done
}
size_line(){
  unset hasdata
  for slot in $@
  do if [ ! -z "${MBS[$slot]}" ]
     then hasdata=yes
     fi
  done
  if [ "$hasdata" != "yes" ]
  then return 1
  fi
  for slot in $@
  do printf "|%-${wmax}s" " ${MBS[$slot]}"
  done
}
mdl_line(){
  unset hasdata
  for slot in $@
  do if [ ! -z "${MDL[$slot]}" ]
     then hasdata=yes
     fi
  done
  if [ "$hasdata" != "yes" ]
  then return 1
  fi
  for slot in $@
  do printf "|%-${wmax}s" " ${MDL[$slot]}"
  done
}
ser_line(){
  unset hasdata
  for slot in $@
  do if [ ! -z "${SER[$slot]}" ]
     then hasdata=yes
     fi
  done
  if [ "$hasdata" != "yes" ]
  then return 1
  fi
  for slot in $@
  do printf "|%-${wmax}s" " ${SER[$slot]}"
  done
}
sep_fill(){ #MAKE SEPARATOR FILLER
  cdown=$wmax
  while [ $cdown -gt 0 ]
  do echo -n '-'
     cdown=$((cdown-1))
  done
}
sep_line(){ #SEPERATOR LINE GENERATION WITH "+" AT EACH END
  smax=$(sep_fill)
  sep="+$smax"
  for b in ${BAYLINES[0]}
  do printf "%-${wmax}s" "$sep"
  done
  echo +
}

##########################
#    DRAW OUTPUT GRID    #
##########################
sep_line
for line in "${BAYLINES[@]}"
do slots=$(sed -r 's#[^ ]+:([0-9]+:[0-9]+)#\1#g' <<< "$line") #CONVERT FROM BAY:CTL:SLOT to CTL:SLOT
   head_line $slots
   echo '|'
   if [ ! -z "$ZS" ]
   then zfs_line $slots && echo '|'
   fi
   for info in $LINE_ITEMS
   do $info $slots && echo '|'
   done
   sep_line
done
