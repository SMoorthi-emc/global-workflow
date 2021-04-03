#!/bin/ksh -x

###############################################################
## Abstract:
## Create FV3 initial conditions from GFS intitial conditions
## RUN_ENVIR : runtime environment (emc | nco)
## HOMEgfs   : /full/path/to/workflow
## EXPDIR : /full/path/to/config/files
## CDATE  : current date (YYYYMMDDHH)
## CDUMP  : cycle name (gdas / gfs)
## PDY    : current date (YYYYMMDD)
## cyc    : current cycle (HH)
###############################################################

###############################################################
# Source FV3GFS workflow modules
. $HOMEgfs/ush/load_fv3gfs_modules.sh
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Source relevant configs
configs="base fv3ic"
for config in $configs; do
    . $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done

###############################################################
# Source machine runtime environment
. $BASE_ENV/${machine}.env fv3ic
status=$?
[[ $status -ne 0 ]] && exit $status

# Set component
export COMPONENT=${COMPONENT:-atmos}

# Temporary runtime directory
export DATA="$RUNDIR/$CDATE/$CDUMP/fv3ic$$"
[[ -d $DATA ]] && rm -rf $DATA

#<<<<<<< HEAD
# Input GFS initial condition files
if [ $cpl = ".true." ] ; then

  # If running a coupled forecast, the first step of IC prep is done with the EMC_ugcs workflow.
  # Eventually a separate workflow task can be generated to do this
  # The output of the EMC_ugcs prepareics task become inputs to the next step and need to be here:
  # UGCSICSDIR is specified in config.base
  export INIDIR="$UGCSICSDIR/t574"
  export ATMANL="$UGCSICSDIR/t574/gfsanl.$CDATE"
  export SFCANL="$UGCSICSDIR/t574/sfnanl.$CDATE"

  # Copy the CICE5 and MOM6 ICs from UGCSICSDIR

  mkdir -p $ICSDIR/$CDATE/cice5_cfsv2 
  $NCP $UGCSICSDIR/cice5_model_0.25.res_$CDATE.nc $ICSDIR/$CDATE/cice5_cfsv2
  status=$?
  [[ $status -ne 0 ]] && exit $status

  mkdir -p $ICSDIR/$CDATE/mom6_cfsv2
  cd $ICSDIR/$CDATE/mom6_cfsv2
  tar -xvf $UGCSICSDIR/MOM6_restart_2016100100.tar MOM6_IC_TS.nc
  status=$?
  [[ $status -ne 0 ]] && exit $status

else

  export INIDIR="$ICSDIR/$CDATE/$CDUMP"
  export ATMANL="$ICSDIR/$CDATE/$CDUMP/siganl.${CDUMP}.$CDATE"
  export SFCANL="$ICSDIR/$CDATE/$CDUMP/sfcanl.${CDUMP}.$CDATE"
  if [ -f $ICSDIR/$CDATE/$CDUMP/nstanl.${CDUMP}.$CDATE ]; then
    export NSTANL="$ICSDIR/$CDATE/$CDUMP/nstanl.${CDUMP}.$CDATE"
  fi
fi
#=======
# Input GFS initial condition directory
#export INIDIR="$ICSDIR/$CDATE/$CDUMP/$CDUMP.$PDY/$cyc"
#>>>>>>> upstream/develop

# Output FV3 initial condition directory
export OUTDIR="$ICSDIR/$CDATE/$CDUMP/$CASE/INPUT"

export OMP_NUM_THREADS_CH=$NTHREADS_CHGRES
export APRUNC=$APRUN_CHGRES

# Call global_chgres_driver.sh
$HOMEgfs/ush/global_chgres_driver.sh
status=$?
if [ $status -ne 0 ]; then
    echo "global_chgres_driver.sh returned with a non-zero exit code, ABORT!"
    exit $status
fi

# Stage the FV3 initial conditions to ROTDIR
COMOUT="$ROTDIR/$CDUMP.$PDY/$cyc/$COMPONENT"
[[ ! -d $COMOUT ]] && mkdir -p $COMOUT
cd $COMOUT || exit 99
rm -rf INPUT
#PT since INPUT directory is also used by MOM6 ICs, do not link, copy instead
#$NLN $OUTDIR .
mkdir INPUT
cd INPUT
$NCP $OUTDIR/* .

###############################################################
# Exit cleanly
exit 0
