#!/bin/sh
set -x

echo "Load modules first"
#source /usr/Modules/3.2.10/init/sh
. $MODULESHOME/init/sh 2>/dev/null
#module load rocoto
#module load rocoto/1.3.2
 module load ruby/2.5.1
 module load python/2.7.14
 module load rocoto/1.3.0rc2
module load hpss

CWD=${ROCODIR:-$(pwd)}
# $IDATE is the initial start date of your run (first cycle CDATE, YYYYMMDDCC)
#IDATE=$1
IDATE=2016010100
IDATE=2018010100
#IDATE=2018090100
 IDATE=2018090100
#IDATE=2011100100
#IDATE=2018011500
#IDATE=2018031500
#IDATE=2019052500    # EC 127 version from FY
 CASE=C384
#IDATE=2017051500
#CASE=C768
# $EDATE is the ending date of your run (YYYYMMDDCC) and is the last cycle that will complete
#EDATE=2016010100

EDATE=$IDATE
YMD=$(echo $IDATE | cut -c1-8)
HH=$(echo $IDATE | cut -c9-10)

# $RES is the resolution of the forecast (i.e. 768 for C768)
RES=$(echo $CASE|cut -c 2-)

# $PSLOT is the name of your experiment
 expt=_phyde
#expt=_phyxd
#expt=_phyai    # cmeps run

expt=${expt:-''}
PSLOT=c${RES}$expt
CDUMP=gfs

FHMIN=${1:-$FHMIN}
WARM_START=${2:-$WARM_START}

FHMIN=${FHMIN:-0}
WARM_START=${WARM_START:-.false.}
#FHCYC=0
#FHCYC=3
FHCYC=${FHCYC:-24}


# $COMROT is the path to the experiment output directory. DO NOT include PSLOT folder at end of path, it’ll be built.
# $EXPDIR is the path to the experiment directory where config and workflow monitoring (rocoto database and xml) files are placed. Do not include PSLOT folder at end of path, it will be built.

if [ $(echo $CWD | cut -c1-8) = "/scratch" ] ; then
 NOSCRUB=/scratch1/NCEPDEV/global
 FROM_HPSS=$NOSCRUB/$LOGNAME/noscrub/FROM_HPSS
 COMROT=/scratch1/NCEPDEV/stmp4/$LOGNAME/CFV3/$IDATE
 EXPDIR=$NOSCRUB/$LOGNAME/CFV3/$IDATE/EXPFV3
elif [ $(echo $CWD | cut -c1-11) = "/gpfs/dell2" ] ; then
 NOSCRUB=/gpfs/dell2/emc/modeling/noscrub
 COMROT=/gpfs/dell2/ptmp/$LOGNAME/CFV3/$IDATE
 FROM_HPSS=$NOSCRUB/$LOGNAME/FROM_HPSS
 EXPDIR=$NOSCRUB/$LOGNAME/CFV3/$IDATE/EXPFV3
elif [ $(echo $CWD | cut -c1-9) = "/gpfs/hps" ] ; then
 NOSCRUB=/gpfs/hps3/emc/modeling/noscrub
 FROM_HPSS=/gpfs/dell2/emc/modeling/noscrub/$LOGNAME/FROM_HPSS
 COMROT=/gpfs/dell2/ptmp/$LOGNAME/CFV3/$IDATE
 EXPDIR=$NOSCRUB/$LOGNAME/CFV3/$IDATE/EXPFV3
fi

mkdir -p $COMROT
mkdir -p $EXPDIR

FV3DATA=$FROM_HPSS/$IDATE/gfs/$CASE/INPUT

# $CONFIGDIR is the location of config files (e.g. ../parm/config/)

CONFIGDIR=${CONFIGDIR:-../../parm/config}


# Link the existing FV3ICS directory to the initial condition directory
if [ $FHMIN -eq 0 ] ; then
  cd $COMROT
  mkdir -p FV3ICS
  ln -fs $FROM_HPSS/$IDATE FV3ICS/
fi

cd $CWD

# $GFS_CYC is the forecast frequency (0 = none, 1 = 00z only [default], 2 = 00z & 12z, 4 = all cycles)
GFS_CYC=1

./setup_expt_fcstonly.py --pslot $PSLOT --configdir $CONFIGDIR --idate $IDATE --edate $EDATE --res $RES --gfs_cyc $GFS_CYC --comrot $COMROT --expdir $EXPDIR --fhmin $FHMIN --warm_start $WARM_START --fhcyc $FHCYC --cdump $CDUMP

# Appropriate account e.g. fv3-cpu (hera) GFS-DEV (wcoss)

# Copy ICs : can put in a loop if running multiple cycles

mkdir -p $COMROT/$PSLOT/gfs.$YMD/$HH/INPUT
cd $COMROT/$PSLOT/gfs.$YMD/$HH/INPUT

# link the ICs if they exist, otherwise the workflow will generate them from EMC_ugcs ICs

if [ $FHMIN -eq 0 ] ; then
  if [ -d $FV3DATA ] ; then
    ln -s $FV3DATA/* .
  fi
fi

cd $CWD     # Come back to this folder

#exit           # to test

./setup_workflow_fcstonly.py --expdir $EXPDIR/$PSLOT    # Setup workflow

#exit           # to test
 cp rocoto_viewer.py $EXPDIR/$PSLOT # Copy rocoto_viewer.py to EXPDIR
#
#exit           # to test
 cd $EXPDIR/$PSLOT
 rocotorun -d $PSLOT.db -w $PSLOT.xml
#rocotorun -v 10 -d $PSLOT.db -w $PSLOT.xml    # for verbose of rocotorun
