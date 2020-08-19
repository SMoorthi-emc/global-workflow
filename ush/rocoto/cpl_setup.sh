#!/bin/sh
set -x

echo "Load modules first"
#source /usr/Modules/3.2.10/init/sh
. $MODULESHOME/init/sh 2>/dev/null
#module load rocoto
#module load rocoto/20180420-master
module load rocoto/1.3.1
module load hpss

CWD=$(pwd)
# $IDATE is the initial start date of your run (first cycle CDATE, YYYYMMDDCC)
#IDATE=$1
IDATE=2016010100
IDATE=2018010100
#IDATE=2018090100
 IDATE=2018090100
#IDATE=2011100100
#IDATE=2018011500
 IDATE=2018031500
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
 expt=_phybj
#expt=_phyai    # cmeps run
#expt=_phyal    # 9 month run
#expt=_phyad
#expt=_phyg
#expt=_phyf
expt=${expt:-''}
PSLOT=c${RES}$expt

#FROM_HPSS=/scratch4/NCEPDEV/nems/noscrub/Bin.Li/FROM_HPSS
#FROM_HPSS=/global/noscrub/Jiande.Wang/WF3/FROM_HPSS
#FROM_HPSS=/gpfs/dell2/emc/modeling/noscrub/Shrinivas.Moorthi/FROM_HPSS

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

# ./setup_expt_fcstonly.py --pslot $PSLOT --configdir $CONFIGDIR --idate $IDATE --edate $EDATE --res $RES --gfs_cyc $GFS_CYC --comrot $COMROT --expdir $EXPDIR

# $COMROT is the path to your experiment output directory. DO NOT include PSLOT folder at end of path, it’ll be built for you.
#COMROT=/scratch4/NCEPDEV/nems/noscrub/Patrick.Tripp/COMFV3
#COMROT=/scratch4/NCEPDEV/nems/noscrub/Bin.Li/benchmark/COMFV3
#COMROT=/scratch4/NCEPDEV/nems/noscrub/${USER}/benchmark/${YMD}/COMFV3
#COMROT=/gpfs/dell2/ptmp/$LOGNAME/CFV3/$IDATE
#mkdir -p $COMROT

# $CONFIGDIR is the path to the /config folder under the copy of the system you're using (i.e. ../parm/config/)
#CONFIGDIR=/scratch4/NCEPDEV/nems/noscrub/Patrick.Tripp/new.fv3gfs/parm/config
#CONFIGDIR=/scratch4/NCEPDEV/stmp4/Bin.Li/fv3gfs3_benchmark/parm/config
#CONFIGDIR=/gpfs/dell2/emc/modeling/noscrub/Shrinivas.Moorthi/cfv3_wrkflo/fv3gfs_benchmark/parm/config
CONFIGDIR=${CONFIGDIR:-../../parm/config}

# do not export ICSDIR, causes error in py script
#BL2018
#ICSDIR=$COMROT/FV3ICS
#
#FROM_HPSS=/scratch4/NCEPDEV/nems/noscrub/Bin.Li/FROM_HPSS
#FV3DATA=$FROM_HPSS/2016040100/gfs/C384/INPUT
#ICSDIR=$FV3DATA
#ICE_DIR=$FROM_HPSS/2016040100/cice5_cfsv2
#OCN_DIR=$FROM_HPSS/2016040100/mom6_cfsv2

# Link the existing FV3ICS folder to here, I prefer this directory to be in main directory, but changing in script can cause issues
#mkdir -p $COMROT
cd $COMROT
mkdir -p FV3ICS
#ln -s ../FV3ICS .
#ln -s $FROM_HPSS/* ../FV3ICS
#ln -fs $FROM_HPSS/* ../FV3ICS
#ln -fs $FROM_HPSS/$IDATE ../FV3ICS/$IDATE
 ln -fs $FROM_HPSS/$IDATE FV3ICS/

cd $CWD

# $GFS_CYC is the forecast frequency (0 = none, 1 = 00z only [default], 2 = 00z & 12z, 4 = all cycles)
GFS_CYC=1

# $EXPDIR is the path to your experiment directory where your configs will be placed and where you will find your workflow monitoring files (i.e. rocoto database and xml file). DO NOT include PSLOT folder at end of path, it will be built for you.

#EXPDIR=/scratch4/NCEPDEV/nems/noscrub/Patrick.Tripp/EXPFV3
#EXPDIR=/scratch4/NCEPDEV/nems/noscrub/${USER}/benchmark/${YMD}/EXPFV3
#EXPDIR=/gpfs/dell2/emc/modeling/noscrub/$LOGNAME/CFV3/$IDATE/EXPFV3
#mkdir -p $EXPDIR

./setup_expt_fcstonly.py --pslot $PSLOT --configdir $CONFIGDIR --idate $IDATE --edate $EDATE --res $RES --gfs_cyc $GFS_CYC --comrot $COMROT --expdir $EXPDIR

# Edit base.config
# Change noscrub dirs from global to climate
# Change account to CFS-T20

# Copy ICs : can put in a loop if running multiple cycles

#YMD=`echo $IDATE | cut -c1-8`
#HH=`echo $IDATE | cut -c9-10`
mkdir -p $COMROT/$PSLOT/gfs.$YMD/$HH/INPUT
cd $COMROT/$PSLOT/gfs.$YMD/$HH/INPUT

# Copy the ICs if they exist, otherwise the workflow will generate them from EMC_ugcs ICs
#BL2018
#if [ -d $ICSDIR/$IDATE/gfs/C$RES/INPUT ] ; then
#  cp -p $ICSDIR/$IDATE/gfs/C$RES/INPUT/* .

#BL2018
if [ -d $FV3DATA ] ; then
#  cp -p $FV3DATA/* .
  ln -s $FV3DATA/* .
fi

# Come back to this folder
cd $CWD

#exit
# Setup workflow
./setup_workflow_fcstonly.py --expdir $EXPDIR/$PSLOT

#exit
# Copy rocoto_viewer.py to EXPDIR
 cp rocoto_viewer.py $EXPDIR/$PSLOT
#
#exit
 cd $EXPDIR/$PSLOT
#module load rocoto/1.2.4
 rocotorun -d $PSLOT.db -w $PSLOT.xml
#rocotorun -v 10 -d $PSLOT.db -w $PSLOT.xml
