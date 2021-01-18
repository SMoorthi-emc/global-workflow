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
 IDATE=2013040100
#IDATE=2018011500
#IDATE=2018031500
#IDATE=2019052500    # EC 127 version from FY
 CASE=C384
#IDATE=2017051500
#IDATE=2016110100
#CASE=C768
# $EDATE is the ending date of your run (YYYYMMDDCC) and is the last cycle that will complete
#EDATE=2016010100

EDATE=$IDATE
YMD=$(echo $IDATE | cut -c1-8)
HH=$(echo $IDATE | cut -c9-10)

# $RES is the resolution of the forecast (i.e. 768 for C768)
RES=$(echo $CASE|cut -c 2-)

# $PSLOT is the name of your experiment
 expt=_phyad
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

 export IC_FROM=bench5
export IC_FROM=${IC_FROM:-bench1}
 export LEVS=128
export LEVS=${LEVS:-65}
if [ $IC_FROM = bench5 ] ; then
 frac=fracL$((LEVS-1))
 frac=${frac:-""}
fi

if [ $(echo $CWD | cut -c1-8) = "/scratch" ] ; then
 NOSCRUB=/scratch1/NCEPDEV/global
 FROM_HPSS=$NOSCRUB/$LOGNAME/noscrub/FROM_HPSS
 if [ $IC_FROM = bench5 ] ; then
  FROM_HPSS=/scratch2/NCEPDEV/climate/climpara/S2S/IC/CFSR${frac}
 fi
 COMROT=/scratch1/NCEPDEV/stmp4/$LOGNAME/CFV3/$IDATE
 EXPDIR=$NOSCRUB/$LOGNAME/CFV3/$IDATE/EXPFV3
elif [ $(echo $CWD | cut -c1-11) = "/gpfs/dell2" ] ; then
 NOSCRUB=/gpfs/dell2/emc/modeling/noscrub
 COMROT=/gpfs/dell2/ptmp/$LOGNAME/CFV3/$IDATE
 FROM_HPSS=$NOSCRUB/$LOGNAME/FROM_HPSS
 if [ $IC_FROM = bench5 ] ; then
  FROM_HPSS=/gpfs/dell2/emc/modeling/noscrub/Walter.Kolczynski/global-workflow/IC/CFSR${frac}
 fi
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
  if [ $IC_FROM = bench5 ] ; then
    mkdir -p OCNICS ICEICS WAVICS
    ln -fs $FROM_HPSS/../CPC3Dvar/$IDATE OCNICS/
    ln -fs $FROM_HPSS/../CPC/$IDATE      ICEICS/
    ln -fs $FROM_HPSS/../CFSR/$IDATE     WAVICS/
  fi
fi

cd $CWD

# turn on some options
# --------------------
 export cplflx=.true.                      # turn on cupule model
 export CPLD_APP=YES                       # use coupled app
#export INLINE_POST=NO                     # turn off inline post
 export INLINE_POST=${INLINE_POST:-YES}    # turn on inline post
 export USE_COLDSTART=.false.              # uncomment this line to turn on cold start step
 export frac_grid=.false.
 export frac_grid=${frac_grid:-.true.}
 export OUTPUT_FILE=netcdf                 # to turn on netcdf output (default nemsio)
 export OUTPUT_FILE=${OUTPUT_FILE:-nemsio} # to turn on netcdf output (default nemsio)

 export OCNRES=025

#   comment the following line to turn on wave coupling
#export USE_WAVES=True
 export USE_WAVES=${USE_WAVES:-False}
 if [ $USE_WAVES = True ] ; then
  export cplwav=.true.
  export cplwav2atm=.true.
  export CPLDWAV=YES
 fi

 export cplwav=${cplwav:-.false.}
 export cplwav2atm=${cplwav2atm:-.false.}
 export CPLDWAV=${CPLDWAV:-NO}

#export app=ufs-weather-model_Jan04
 export app=ufs-weather-model_Jan14
 export appdate=Oct10
 export DONST=YES

 export satmedmf=.true.
 export v17sas=NO
 export v17ras=YES
 export v17rasnoshal=NO

 export FH_CHUNK=$((24*45))

#export restart_interval=432000
#export restart_interval=864000
#export restart_interval=1296000
 export restart_interval=864000
 export restart_interval=432000
#export restart_interval=86400
#export restart_interval=43200
#export restart_interval=21600
#export restart_interval=10800

 export FHMAX_GFS_00=2160
#export FHMAX_GFS_00=1920
 export FHMAX_GFS_00=1680
#export FHMAX_GFS_00=1440
#export FHMAX_GFS_00=960
#export FHMAX_GFS_00=720
#export FHMAX_GFS_00=480
#export FHMAX_GFS_00=120
#export FHMAX_GFS_00=48
#export FHMAX_GFS_00=240
#export FHMAX_GFS_00=24

 export FHMAX_GFS_06=0
 export FHMAX_GFS_12=0
 export FHMAX_GFS_18=0

 export NSOUT=0
 export FHOUT_GFS=3
 export FHOUT_GFS=${FHOUT_GFS:-6}      # atmos history output frequency
 export FHOUT_O=${FHOUT_O:-$FHOUT_GFS} # ocean history output frequency
#export OCN_AVG=YES
 export OCN_AVG=${OCN_AVG:-NO}
 export HYPT=on
 export HYPT=${HYPT:-off}
 export FSICS=0

 export envars="LEVS=$LEVS,FHCYC=$FHCYC,IC_FROM=$IC_FROM,IAER=5111,app=$app,appdate=$appdate,cplflx=$cplflx,frac_grid=$frac_grid,INLINE_POST=$INLINE_POST,cplwav=$cplwav,cplwav2atm=$cplwav2atm,CPLDWAV=$CPLDWAV,USE_WAVES=$USE_WAVES,OCNRES=$OCNRES,DONST=$DONST,satmedmf=$satmedmf,v17sas=$v17sas,v17ras=$v17ras,v17rasnoshal=$v17rasnoshal,FH_CHUNK=$FH_CHUNK,restart_interval=$restart_interval,FHMAX_GFS_00=$FHMAX_GFS_00,FHMAX_GFS_06=$FHMAX_GFS_06,FHMAX_GFS_12=$FHMAX_GFS_12,FHMAX_GFS_18=$FHMAX_GFS_18,FHOUT_GFS=$FHOUT_GFS,HYPT=$HYPT,NSOUT=$NSOUT,FHOUT_O=$FHOUT_O,OCN_AVG=$OCN_AVG,USE_COLDSTART=$USE_COLDSTART,FSICS=$FSICS,OUTPUT_FILE=$OUTPUT_FILE"

echo $envars

# $GFS_CYC is the forecast frequency (0 = none, 1 = 00z only [default], 2 = 00z & 12z, 4 = all cycles)
GFS_CYC=1


 ./setup_expt_fcstonly.py --pslot $PSLOT --configdir $CONFIGDIR --idate $IDATE --edate $EDATE --res $RES --gfs_cyc $GFS_CYC --comrot $COMROT --expdir $EXPDIR --warm_start $WARM_START --fhmin $FHMIN --cdump $CDUMP --envars $envars

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
