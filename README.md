# mybays.sh
```
LSI Controllers configurable visual bay representation with ZFS integration

Currently External shelves are not supported, since I do not have any to test with.
It should work with any number of lsi HBAs connected in a single chassis.
If sas2ircu list/display output is provided shelf support may be possible with reasonable effort.

#----------------------------------------------------------------------#
HELP OUTPUT, INCLUDING CURRENT CONFIGURATION
root@server:~# mybays.sh -h
mybays.sh [-z|-h]
OPTIONS:
        -z|--zfs  ... include zfs status info
        -h|--help ... print this text

CURRENT BAY CONFIG:
ENCLOSURE INFO, HORIZONTAL EACH ELEMENT REPRESENTS A LINE OF BAYS
FORMAT (CTL#):(SLOT#)
CONFIG: /etc/mybays.sh.conf
---------------
0:7|0:6|0:5|0:4|
---------------
1:7|1:6|1:5|1:4|
---------------
0:11|0:10|0:9|0:8|
---------------
1:11|1:10|1:9|1:8|
---------------
0:15|0:14|0:13|0:12|
---------------
1:15|1:14|1:13|1:12|

#----------------------------------------------------------------------#
THE CONFIG FILE
root@server:~# cat /etc/mybays.sh.conf 
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

#----------------------------------------------------------------------#
EXAMPLE OUTPUT WITH ZFS INFO AND SOME UNPOPULATED BAYS, ON A 24 BAY CHASSIS:
(without -z the "<status> <read-err> <write-err> <cksum-err>" is omitted)
root@server:~# mybays.sh -z
+------------------+------------------+------------------+------------------+
| BAY 1: /dev/sde  | BAY 2: /dev/sdc  | BAY 3: /dev/sda  | BAY 4: /dev/sdb  |
| ONLINE 0 0 0     | ONLINE 0 0 0     | ONLINE 0 0 0     | ONLINE 0 0 0     |
| WDCWD60EFAX-68S  | WDCWD60EFAX-68S  | WDCWD60EFAX-68S  | WDCWD60EFAX-68S  |
| 5723166 MB       | 5723166 MB       | 5723166 MB       | 5723166 MB       |
| WDWX21D59F8X8N   | WDWX11D59DEVKY   | WDWX21D59F8NF1   | WDWX21D19AYN04   |
| 50014ee266ac7af3 | 50014ee266aca62b | 50014ee2115735ea | 50014ee2bbc67d66 |
+------------------+------------------+------------------+------------------+
| BAY 5: /dev/sdi  | BAY 6: /dev/sdh  | BAY 7: /dev/sdj  | BAY 8: /dev/sdm  |
| ONLINE 0 0 0     | ONLINE 0 0 0     | ONLINE 0 0 0     | ONLINE 0 0 0     |
| WDCWD60EFAX-68S  | WDCWD60EFRX-68L  | WDCWD60EFRX-68L  | WDCWD60EFRX-68L  |
| 5723166 MB       | 5723166 MB       | 5723166 MB       | 5723166 MB       |
| WDWX11D39LPDHH   | WDWX61DC896645   | WDWX42D6094299   | WDWX11DA8JC384   |
| 50014ee266ac6ce2 | 50014ee26640e25d | 50014ee212d17aa4 | 50014ee265fcef91 |
+------------------+------------------+------------------+------------------+
| BAY 9: /dev/sdd  | BAY 10: /dev/sdf | BAY 11: /dev/sdg | BAY 12: /dev/sdl |
| ONLINE 0 0 0     | ONLINE 0 0 0     |                  | ONLINE 0 0 0     |
| WDCWD60EFRX-68L  | WDCWD60EFRX-68M  | WDCWD60EFRX-68L  | WDCWD60EFRX-68M  |
| 5723166 MB       | 5723166 MB       | 5723166 MB       | 5723166 MB       |
| WDWX71DC8PTYDA   | WDWX31D55A458A   | WDWX42D60940X2   | WDWX51DC45ZPEF   |
| 50014ee26640e464 | 50014ee20c452454 | 50014ee26826bc4f | 50014ee20b8e4fde |
+------------------+------------------+------------------+------------------+
| BAY 13: /dev/sdn | BAY 14: /dev/sdp | BAY 15: /dev/sdo | BAY 16: /dev/sdq |
| ONLINE 0 0 0     | ONLINE 0 0 0     | ONLINE 0 0 0     | ONLINE 0 0 0     |
| WDCWD60EFRX-68M  | WDCWD60EFRX-68M  | WDCWD60EFRX-68M  | WDCWD60EFZX-68B  |
| 5723166 MB       | 5723166 MB       | 5723166 MB       | 5723166 MB       |
| WDWXK1H645STD6   | WDWX11DC4FKEUY   | WDWX21D7453LPN   | WDC8143B6G       |
| 50014ee2b59ad602 | 50014ee260e50d11 | 50014ee20af00f8f | 50014ee2695badf8 |
+------------------+------------------+------------------+------------------+
| BAY 17:          | BAY 18:          | BAY 19:          | BAY 20:          |
+------------------+------------------+------------------+------------------+
| BAY 21:          | BAY 22:          | BAY 23:          | BAY 24: /dev/sdk |
|                  |                  |                  | ONLINE 0 0 0     |
|                  |                  |                  | SamsungSSD850    |
|                  |                  |                  | 244198 MB        |
|                  |                  |                  | S39KNX0HA00082N  |
|                  |                  |                  | 5002538d414d062a |
+------------------+------------------+------------------+------------------+
```
