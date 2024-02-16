#!/bin/bash
#
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
################
#    CONFIG    #
################
#ENCLOSURE INFO, HORIZONTAL EACH ELEMENT REPRESENTS A LINE OF BAYS
#FORMAT (CTL#):(SLOT#) Numbers as reported by sas2ircu
# CUSTOMIZE THIS OR CREATE YOUR OWN CONFIG IN /etc/<script-name>.conf TO FIT YOUR CHASSIS!
BAYLINES=( #"BAYS" (0|1):[0-3] are not connected to the backplane
   "0:7 0:6 0:5 0:4" #CTL1
   "1:7 1:6 1:5 1:4" #CTL2
   "0:11 0:10 0:9 0:8" #$CTL1
   "1:11 1:10 1:9 1:8" #$CTL2
   "0:15 0:14 0:13 0:12" #$CTL1
   "1:15 1:14 1:13 1:12" #$CTL2
          )
#PRINTF WIDTH PER SLOT
wmax=19
if [ -f "/etc/$ME.conf" ]
then source /etc/$ME.conf
fi

USAGE="$ME [-z|-h]
OPTIONS:
        -z|--zfs  ... include zfs status info
        -h|--help ... print this text

CURRENT BAY CONFIG:
ENCLOSURE INFO, HORIZONTAL EACH ELEMENT REPRESENTS A LINE OF BAYS
FORMAT (CTL#):(SLOT#)
CONFIG: /etc/$ME.conf
$(for line in "${BAYLINES[@]}"
do echo "---------------"
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
bay=1
for line in "${BAYLINES[@]}"
do declare -A BAY MBS MDL SER WWN DEV ZFS
   for slot in $line
   do #dev=$(readlink -e /dev/disk/by-id/wwn-0x$(awk -F: '{print $4}'))
      MBS[$slot]="$(awk -F: '{print $1}' <<< "${CONNS[$slot]}"|sed -r 's#/.*# MB#g')"
      MDL[$slot]="$(awk -F: '{print $2}' <<< "${CONNS[$slot]}")"
      SER[$slot]="$(awk -F: '{print $3}' <<< "${CONNS[$slot]}")"
      WWN[$slot]="$(awk -F: '{print $4}' <<< "${CONNS[$slot]}")"
      DEV[$slot]="$(readlink -e /dev/disk/by-id/wwn-0x$(awk -F: '{print $4}' <<< "${CONNS[$slot]}"))"
      BAY[$slot]="$bay"
      if [ ! -z "$ZS" ]
      then ZFS[$slot]="$(egrep "^$(basename ${DEV[$slot]} 2>/dev/null) " <<< "$ZS" |sed -r "s#$(basename ${DEV[$slot]} 2>/dev/null) ##g")"
      fi
      bay=$((bay+1))
   done
done

#########################
#    OUPUT FUNCTIONS    #
#########################
#OUTPUT FUNCTIONS TAKE SLOT NUMBERS (from sas2ircu output)
#TO FILL HORIZONTAL LINES WITH INFORMATION
head_line(){
  for slot in $@
  do printf "%-${wmax}s" "| BAY ${BAY[$slot]}: ${DEV[$slot]}"
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
  do printf "%-${wmax}s" "| ${ZFS[$slot]}"
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
  do printf "%-${wmax}s" "| ${WWN[$slot]}"
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
  do printf "%-${wmax}s" "| ${MBS[$slot]}"
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
  do printf "%-${wmax}s" "| ${MDL[$slot]}"
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
  do printf "%-${wmax}s" "| ${SER[$slot]}"
  done
}
sep_fill(){ #MAKE SEPARATOR FILLER
  cdown=$((wmax-1))
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
do head_line $line
   echo '|'
   if [ ! -z "$ZS" ]
   then zfs_line $line && echo '|'
   fi
   mdl_line $line && echo '|'
   size_line $line && echo '|'
   ser_line $line && echo '|'
   wwn_line $line && echo '|'
   sep_line
done
