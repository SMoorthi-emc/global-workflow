#!/bin/sh
set -x

echo "this job submits cpl_setup.sh"

CWD=$(pwd)

ROCODIR=$CWD
ACCOUNT=fv3-cpu

FHMIN=${1:-$FHMIN}
WARM_START=${2:-$WARM_START}
CDATE=${3:-${CDATE:-2018090100}}

if [ $(echo $CWD | cut -c1-8) = "/scratch" ] ; then
 NOSCRUB=/scratch1/NCEPDEV/global
 export DATA=/scratch1/NCEPDEV/stmp2/Shrinivas.Moorthi/sub
 SUBCMD=/scratch1/NCEPDEV/global/Shrinivas.Moorthi/save/gc_wrkflo_Aug11/global-workflow/ush/rocoto/sub_hera
 ROTDIR=${ROTDIR:-/scratch1/NCEPDEV/stmp4/Shrinivas.Moorthi/CFV3/2018090100/c384_phyaa}
elif [ $(echo $CWD | cut -c1-11) = "/gpfs/dell2" ] ; then
 NOSCRUB=/gpfs/dell2/emc/modeling/noscrub
elif [ $(echo $CWD | cut -c1-9) = "/gpfs/hps" ] ; then
 NOSCRUB=/gpfs/hps3/emc/modeling/noscrub
fi

mkdir -p $DATA

#$SUBCMD -e FHMIN=$FHMIN,WARM_START=$WARM_START,ROCODIR=$ROCODIR -a $ACCOUNT -q debug -p 1/1/N -r 3072/1/1 -t 00:05:00 -j testjob -o $CWD/test_log $ROCODIR/test.sh

$SUBCMD -e FHMIN=$FHMIN,WARM_START=$WARM_START,ROCODIR=$ROCODIR -a $ACCOUNT -q debug -p 1/1/N -r 3072/1/1 -t 00:05:00 -j fv3gfs -o $ROTDIR/logs/$CDATE/gfsfcst_${FHMIN}_log $ROCODIR/cpl_setup.sh


