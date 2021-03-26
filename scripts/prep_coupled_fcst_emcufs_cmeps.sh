#!/bin/ksh
set -xa

if [ $# -ne 1 ] ; then
  echo "Usage: $0 [ cold | warm | restart ]"
  exit -1
fi

inistep=$1   # cold warm restart

NCP=${NCP:-"/bin/cp "}
NLN=${NLN:-"/bin/ln -sf"}

# Directories
# -----------
DATA=${DATA:-$pwd/fv3tmp$$}    # temporary running directory
ROTDIR=${ROTDIR:-$pwd}         # rotating archive directory

if [ ! -d $ROTDIR ] ; then mkdir -p $ROTDIR ; fi
if [ ! -d $DATA ]   ; then mkdir -p $DATA   ; fi
mkdir -p $DATA/INPUT
mkdir -p $DATA/restart     $DATA/OUTPUT
mkdir -p $DATA/MOM6_OUTPUT $DATA/MOM6_RESTART
cd $DATA || exit 8

export NCP=${NCP:-"/bin/cp -p"}
PDY=$(echo $CDATE | cut -c1-8)
cyc=$(echo $CDATE | cut -c9-10)
MED_RESTDIR=${MED_RESTDIR:-$ROTDIR/${CDUMP}.$PDY/$cyc/MED_RESTDIR}
OCN_RESTDIR=${OCN_RESTDIR:-$ROTDIR/${CDUMP}.$PDY/$cyc/OCN_RESTDIR}
ICE_RESTDIR=${ICE_RESTDIR:-$ROTDIR/${CDUMP}.$PDY/$cyc/ICE_RESTDIR}
mkdir -p $MED_RESTDIR
mkdir -p $OCN_RESTDIR
mkdir -p $ICE_RESTDIR

if [ $CPLDWAV = YES ] ; then
 WW3_RESTDIR=${WW3_RESTDIR:-$ROTDIR/${CDUMP}.$PDY/$cyc/WW3_RESTDIR}
 mkdir -p $WW3_RESTDIR
fi

if [[ $inistep = cold ]] ; then
  export start_type=startup
  export case_name=$MED_RESTDIR/ufs.med.cold
  export history_n=1
  export mediator_read_restart=.false.
else
  export start_type=continue
  export case_name=$MED_RESTDIR/ufs.med
  export history_n=0
  export mediator_read_restart=.true.
  if [ $USE_COLDSTART = .false. -a $FHMIN -eq 0 ] ; then
    export start_type=startup
    export mediator_read_restart=.false.
< fi
fi

if [ $inistep = warm -a $USE_COLDSTART = .true. ] ; then # using restart file for the cmeps mediator
  SDATE=$($NDATE +1 $CDATE)
  PDYS=$(echo $SDATE | cut -c1-8)
  yyyy=$(echo $SDATE | cut -c1-4)
    mm=$(echo $SDATE | cut -c5-6)
    dd=$(echo $SDATE | cut -c7-8)
  secs=$(($(echo $SDATE | cut -c9-10)*3600))
    RFILE=${case_name}.cold.cpl.r.${yyyy}-${mm}-${dd}-$(printf %05i $secs).nc
    echo "$RFILE" > $DATA/rpointer.cpl
#   echo "$MED_RESTDIR/$RFILE" > $DATA/rpointer.cpl
  export USE_COLDSTART=.false.

elif [ $inistep = restart ] ; then # using restart files for MOM6 and CICE here, FV3 will set in exglobal script
                                 # ---------------------------------------------------------------------------
  export warm_start=.true.

  SDATE=$($NDATE +$FHMIN $CDATE)
  PDYS=$(echo $SDATE | cut -c1-8)
  yyyy=$(echo $SDATE | cut -c1-4)
    mm=$(echo $SDATE | cut -c5-6)
    dd=$(echo $SDATE | cut -c7-8)
  cycs=$(echo $SDATE | cut -c9-10)
  secs=$(($(echo $SDATE | cut -c9-10)*3600))

# for mediator
# ------------
    RFILE=${case_name}.cpl.r.${yyyy}-${mm}-${dd}-$(printf %05i $secs).nc

    echo "$RFILE" > $DATA/rpointer.cpl
#   echo "$MED_RESTDIR/$RFILE" > $DATA/rpointer.cpl

# for Ocean (MOM6)
# ----------------
  cd INPUT
  USE_LAST_RESTART=${USE_LAST_RESTART:-NO}
  if [ -s $OCN_RESTDIR ] ; then
#   ocnf=$OCN_RESTDIR/ocn.mom6.r.${yyyy}-${mm}-${dd}-${cycs}
    ocnf=$OCN_RESTDIR/${Restart_Prefix}.${yyyy}-${mm}-${dd}-${cycs}
    nfiles=$(ls -1 $ocnf*.nc | wc -l)
    if [ $nfiles -gt 0 -a $USE_LAST_RESTART = NO ] ; then
      $NCP ${ocnf}-00-00.nc   MOM.res.nc
      $NCP ${ocnf}-00-00_1.nc MOM.res_1.nc
      $NCP ${ocnf}-00-00_2.nc MOM.res_2.nc
      $NCP ${ocnf}-00-00_3.nc MOM.res_3.nc
    else
#  First copy the last restart files for future use
#  ------------------------------------------------
      $NCP $OCN_RESTDIR/MOM.res.nc   ${ocnf}-00-00.nc
      $NCP $OCN_RESTDIR/MOM.res_1.nc ${ocnf}-00-00_1.nc
      $NCP $OCN_RESTDIR/MOM.res_2.nc ${ocnf}-00-00_2.nc
      $NCP $OCN_RESTDIR/MOM.res_3.nc ${ocnf}-00-00_3.nc
#  Now copy the restart files to INPUT directory under RUNDIR
#  ----------------------------------------------------------
      $NCP $OCN_RESTDIR/MOM.res*.nc .
    fi
    export input_filename="'r'"
  fi

# for Ice (CICE5/6)
# -----------------
  cd $DATA
  if [ -s $ICE_RESTDIR ] ; then
    secs=$((cycs*3600))
    secs=$(printf %05i $secs)
    rm $ICE_RESTDIR/ice.restart_file
    echo "$ICE_RESTDIR/iced.${yyyy}-${mm}-${dd}-$secs.nc" > $ICE_RESTDIR/ice.restart_file
    cat $ICE_RESTDIR/ice.restart_file
    export runtype='continue'
    export pointer_file=ice.restart_file
    $NLN $ICE_RESTDIR/ice.restart_file ice.restart_file
    export tr_pond_lvl=.true.
    export restart_pond_lvl=.true.
    export use_restart_time=.true.
  fi

  if [ $CPLDWAV = YES ] ; then
# for Wave (WW3)
# --------------
    cd $DATA
    WW3_RESTDIR=${WW3_RESTDIR:-$ROTDIR/WW3_RESTDIR}
    if [ -s $WW3_RESTDIR ] ; then
      eval $NCP $WW3_RESTDIR/${yyyy}${mm}${dd}.${cycs}0000.restart.$ww3_grid restart.$ww3_grid
    fi
  fi

  cd $DATA
else
  ICSDIR=${ICSDIR:-$pwd}         # cold start initial conditions
  IC_FROM=${IC_FROM:-bench1}

  if [ $IC_FROM = bench1 ] ; then
# Copy CICE5 IC - pre-generated from CFSv2
# ----------------------------------------
   $NCP $ICSDIR/$CDATE/cice5_model_0.25.res_$CDATE.nc ./cice5_model.res_$CDATE.nc
   export prepend_date=.true.
   export input_filename="'n'"
   export USE_IDEAL_AGE_TRACER=${USE_IDEAL_AGE_TRACER:-True}
   $NCP $ICSDIR/$CDATE/MOM6_IC_TS_2* INPUT/MOM6_IC_TS.nc

  elif [ $IC_FROM = bench2 ] ; then
   if [ ${CPC_ICE:-NO} = YES ] ; then
     $NCP $ICSDIR/$CDATE/cpc_with_sw/cice5_model_0.25.res_$CDATE.nc ./cice5_model.res_$CDATE.nc
   else
     $NCP $ICSDIR/$CDATE/mom6_da/cice5_model_0.25.res_$CDATE.nc ./cice5_model.res_$CDATE.nc
   fi
   export prepend_date=.false.
#  export prepend_date=.true.
   export input_filename="'r'"
   export USE_IDEAL_AGE_TRACER=${USE_IDEAL_AGE_TRACER:-False}
   $NCP $ICSDIR/$CDATE/mom6_da/MOM*nc INPUT/.
  else
   echo "Currently initial conditions not available"
   exit 777
  fi
  if [ $CPLDWAV = YES -a $USE_WAVES = True ] ; then
    yyyymmdd=$(echo $CDATE | cut -c1-8)
    $NCP $ICSDIR/$CDATE/$yyyymmdd.000000.restart.$ww3_grid restart.$ww3_grid
  fi
fi
RESTART_CHECKSUMS_REQUIRED=${RESTART_CHECKSUMS_REQUIRED:-False}

# Copy CICE5 fixed files, and namelists
# -------------------------------------
$NCP $FIXcice/kmtu_cice_NEMS_mx025.nc .
$NCP $FIXcice/grid_cice_NEMS_mx025.nc .

cd INPUT

#if [ $IC_FROM = bench1 ] ; then   # Copy MOM6 ICs (from CFSv2 file)
# $NCP $ICSDIR/$CDATE/MOM6_IC_TS_2* MOM6_IC_TS.nc
#elif [ $IC_FROM = bench2 ] ; then
# $NCP $ICSDIR/$CDATE/mom6_da/MOM*nc .
#fi

# Copy MOM6 ICs (from HYCOM file)
#$NCP $ICSDIR/$CDATE/mom6_hycom/* MOM6_IC_TS.nc

# Copy MOM6 fixed files
# ---------------------
$NCP $FIXmom/INPUT/* .

#JW use updated MOM_input (WIND_STAGGER=A, no more MIN_Z_DIAG_INTERVAL and Z_OUTPUT_GRID_FILE)
#cp -p $FIXmom/INPUT/MOM_input_update MOM_input
export WIND_STAGGER="A"              # default = "C"
                                     # A case-insensitive character string to indicate the
                                     # staggering of the input wind stress field.  Valid
                                     # values are 'A', 'B', or 'C'.

# Copy grid_spec and mosaic files
# -------------------------------
$NCP $FIXgrid/$CASE/* .


cd $DATA
 
# Setup namelists
# ---------------

export DELTIM=${DELTIM:-450}
export OCNTIM=${OCNTIM:-900}
export ICETIM=${ICETIM:-$DELTIM}
export DT_THERM=${DT_THERM:-$((OCNTIM*2))}

export CPL_SLOW=${CPL_SLOW:-$DT_THERM}
export CPL_FAST=${CPL_FAST:-$ICETIM}

# Setup nems.configure
DumpFields_MED=${DumpFields_MED:-false}
DumpFields_ATM=${DumpFields_ATM:-false}
DumpFields_OCN=${DumpFields_OCN:-false}
DumpFields_ICE=${DumpFields_ICE:-false}
OverwriteSlice_MED=${OverwriteSlice_MED:-$DumpFields_MED}
OverwriteSlice_OCN=${OverwriteSlice_OCN:-$DumpFields_OCN}
OverwriteSlice_ICE=${OverwriteSlice_ICE:-$DumpFields_ICE}
Restart_Prefix=${Restart_Prefix:-'ocn.mom6.r'}

if [ $inistep = cold ] ; then
  coldstart=true     # this is the correct setting
  ice_restart=.false.
  export WRITE_DOPOST_CPLD=.false.
  if [ $DONST = YES ] ; then export nstf_name=2,1,1,0,5 ; fi
  export diag_table_cpl=diag_table_cpl
elif [ $inistep = warm ] ; then
  restart_interval=${restart_interval:-1296000}    # Interval in seconds to write restarts
  coldstart=false
  ice_restart=.false.
  export WRITE_DOPOST_CPLD=$WRITE_DOPOST
  if [ $DONST = YES ] ; then export nstf_name=2,1,1,0,5 ; fi
  if [ ${OCN_AVG:-NO} = YES ] ; then
    export diag_table_cpld=diag_table_cpl_hourly_mean
  else
    export diag_table_cpld=diag_table_cpl_hourly_inst
  fi
  export generate_landmask=false
else
  restart_interval=${restart_interval:-1296000}    # Interval in seconds to write restarts
  coldstart=false
  ice_restart=.true.
  export WRITE_DOPOST_CPLD=$WRITE_DOPOST
  if [ $DONST = YES ] ; then export nstf_name=2,0,1,0,5 ; fi
  if [ ${OCN_AVG:-NO} = YES ] ; then
    export diag_table_cpld=diag_table_cpl_hourly_mean
  else
    export diag_table_cpld=diag_table_cpl_hourly_inst
  fi
  export generate_landmask=false
fi
restart_ext=.true.
restart_interval=${restart_interval:-86400}    # Interval in seconds to write restarts

# Clean up un-needed files after cold start
# -----------------------------------------
if [[ $inistep = warm ]] ; then
  rm -f init_field*.nc
  rm -f field_med_*.nc
  rm -f array_med_*.nc
  rm -f atmos_*.tile*.nc
fi

export  MED_petlist_bounds=${MED_petlist_bounds:-'0 311'}    # default here is for C384 on dell
export  ATM_petlist_bounds=${ATM_petlist_bounds:-'0 311'}    #6*8*6+wrtgrps(24)
export  OCN_petlist_bounds=${OCN_petlist_bounds:-'312 451'}  #140
export  ICE_petlist_bounds=${ICE_petlist_bounds:-'452 475'}  #24

export CPLDFV3_MOM6_CICE=${CPLDFV3_MOM6_CICE:-YES}
export CPLDWAV=${CPLDWAV:-NO}

export ATM_model=${ATM_model:-fv3}
if [ $CPLDFV3_MOM6_CICE = YES ] ; then
#export MED_model=${MED_model:-cmeps}
 export MED_model=nems
 export OCN_model=${OCN_model:-mom6}
 export ICE_model=${ICE_model:-cice}
 if [ $CPLDWAV = NO ] ; then
  export EARTH_component_list=${EARTH_component_list:-'MED ATM OCN ICE'}
 else
  export EARTH_component_list=${EARTH_component_list:-'MED ATM OCN ICE WAV'}
  export WAV_model=${WAV_model:-ww3}
 fi
elif [ $CPLDWAV = YES ] ; then
  export EARTH_component_list=${EARTH_component_list:-'ATM WAV'}
  export WAV_model=${WAV_model:-ww3}
fi
export MED_model=${MED_model:-none}
export OCN_model=${OCN_model:-none}
export ICE_model=${ICE_model:-none}
export WAV_model=${WAV_model:-none}

# restart_dir = $MED_RESTDIR/

cat > nems.configure <<eof
#############################################
####  NEMS Run-Time Configuration File  #####
#############################################

# EARTH #
EARTH_component_list: $EARTH_component_list
EARTH_attributes::
  Verbosity = ${Verbosity:-0}
::

eof
if [ $MED_model != none ] ; then
cat >>nems.configure <<eof
# MED #
MED_model:                      $MED_model
MED_petlist_bounds:             $MED_petlist_bounds
::

eof
fi

cat >>nems.configure <<eof
# ATM #
ATM_model:                      $ATM_model
ATM_petlist_bounds:             $ATM_petlist_bounds
ATM_attributes::
  Verbosity = ${Verbosity:-0}
  DumpFields    = ${DumpFields_ATM:-false}
  ProfileMemory = ${ProfileMemory:-False}
  OverwriteSlice = ${OverwriteSlice_ATM:-true}
::

eof

if [ $OCN_model != none ] ; then
cat >>nems.configure <<eof
# OCN #
OCN_model:                      $OCN_model
OCN_petlist_bounds:             $OCN_petlist_bounds
OCN_attributes::
  Verbosity = ${Verbosity:-0}
  DumpFields       = ${DumpFields_OCN:-false}
  OverwriteSlice   = ${OverwriteSlice_OCN:-true}
  restart_interval = $restart_interval
  restart_option = 'nseconds'
  restart_n = $restart_interval
  Restart_Prefix = $Restart_Prefix
  ProfileMemory = ${ProfileMemory:-False}
::

eof
fi

if [ $ICE_model != none ] ; then
cat >>nems.configure <<eof
# ICE #
ICE_model:                      $ICE_model
ICE_petlist_bounds:             $ICE_petlist_bounds
ICE_attributes::
  Verbosity = ${Verbosity:-0}
  DumpFields     = ${DumpFields_ICE:-false}
  OverwriteSlice = ${OverwriteSlice_ICE:-true}
  ProfileMemory = ${ProfileMemory:-False}
::
eof
fi

if [ $WAV_model != none ] ; then
cat >>nems.configure <<eof
# WAV #
  WAV_model:                    ${WAV_model:-ww3}
  WAV_petlist_bounds:           $WAV_petlist_bounds
  WAV_attributes::
  Verbosity = ${Verbosity:-0}
  OverwriteSlice = ${OverwriteSlice_WAV:-False}
::
eof
fi

#------------------------------
#     MED MedPhase_fast_after
#     MED MedPhase_atm_ocn_flux # use this or above to compute fluxes in the mediator
#------------------------------

# Add the runsequence
if [ $CPLDFV3_MOM6_CICE = YES ] ; then
 if [ $CPLDWAV = NO ] ; then
  if [[ $inistep = cold ]] ; then

cat >> nems.configure <<eof
# CMEPS Coldstart Run Sequence #
runSeq::
  @$CPL_SLOW
    @$CPL_FAST
      MED med_phases_prep_atm
      MED -> ATM :remapMethod=redist
      ATM
      ATM -> MED :remapMethod=redist
      MED med_phases_prep_ice
      MED -> ICE :remapMethod=redist
      ICE
      ICE -> MED :remapMethod=redist
      MED med_fraction_set
      MED med_phases_prep_ocn_map
      MED med_phases_prep_ocn_merge
      MED med_phases_prep_ocn_accum_fast
    @
    MED med_phases_restart_write
    MED med_phases_prep_ocn_accum_avg
    MED -> OCN :remapMethod=redist
    OCN
    OCN -> MED :remapMethod=redist
  @
::
eof

  else   # NOT a coldstart

cat >> nems.configure <<eof
# Forecast Run Sequence #
runSeq::
  @$CPL_SLOW
    MED med_phases_prep_ocn_accum_avg
    MED -> OCN :remapMethod=redist
    OCN
    @$CPL_FAST
      MED med_phases_prep_atm
      MED med_phases_prep_ice
      MED -> ATM :remapMethod=redist
      MED -> ICE :remapMethod=redist
      ATM
      ICE
      ATM -> MED :remapMethod=redist
      ICE -> MED :remapMethod=redist
      MED med_fraction_set
      MED med_phases_prep_ocn_map
      MED med_phases_prep_ocn_merge
      MED med_phases_prep_ocn_accum_fast
      MED med_phases_profile
    @
    OCN -> MED :remapMethod=redist
    MED med_phases_restart_write
  @
::
eof
  fi  # nems.configure
 else                            # include wave model
                                 # ------------------
   if [ $USE_WAVES = True ] ; then
     if [[ $inistep = cold ]] ; then

cat >> nems.configure <<eof
# Coldstart Run Sequence #
runSeq::
  @$CPL_SLOW
    OCN -> WAV
    WAV -> OCN :srcMaskValues=1
    @$CPL_FAST
      MED med_phases_prep_atm
      MED -> ATM :remapMethod=redist
      WAV -> ATM :srcMaskValues=1
      ATM
      ATM -> WAV
      ATM -> MED :remapMethod=redist
      MED med_phases_prep_ice
      MED -> ICE :remapMethod=redist
      ICE
      ICE -> WAV
      WAV
      ICE -> MED :remapMethod=redist
      MED med_fraction_set
      MED med_phases_prep_ocn_map
      MED med_phases_prep_ocn_merge
      MED med_phases_prep_ocn_accum_fast
    @
    MED med_phases_restart_write
    MED med_phases_prep_ocn_accum_avg
    MED -> OCN :remapMethod=redist
    OCN
    OCN -> MED :remapMethod=redist
  @
::
eof

     else   # NOT a coldstart

cat >> nems.configure <<eof
# Forecast Run Sequence #
runSeq::
  @$CPL_SLOW
    MED med_phases_prep_ocn_accum_avg
    MED -> OCN :remapMethod=redist
    OCN -> WAV
    WAV -> OCN :srcMaskValues=1
    OCN
    @$CPL_FAST
      MED med_phases_prep_atm
      MED med_phases_prep_ice
      MED -> ATM :remapMethod=redist
      MED -> ICE :remapMethod=redist
      WAV -> ATM :srcMaskValues=1
      ATM -> WAV
      ICE -> WAV
      ATM
      ICE
      WAV
      ATM -> MED :remapMethod=redist
      ICE -> MED :remapMethod=redist
      MED med_fraction_set
      MED med_phases_prep_ocn_map
      MED med_phases_prep_ocn_merge
      MED med_phases_prep_ocn_accum_fast
      MED med_phases_profile
    @
    OCN -> MED :remapMethod=redist
    MED med_phases_restart_write
  @
::
eof
     fi
   else
     if [[ $inistep = cold ]] ; then

cat >> nems.configure <<eof
# Coldstart Run Sequence #
runSeq::
  @$CPL_SLOW
    @$CPL_FAST
      MED med_phases_prep_atm
      MED -> ATM :remapMethod=redist
      ATM -> WAV
      WAV -> ATM :srcMaskValues=1
      WAV
      ATM
      ATM -> MED :remapMethod=redist
      MED med_phases_prep_ice
      MED -> ICE :remapMethod=redist
      ICE
      ICE -> MED :remapMethod=redist
      MED med_fraction_set
      MED med_phases_prep_ocn_map
      MED med_phases_prep_ocn_merge
      MED med_phases_prep_ocn_accum_fast
    @
    MED med_phases_restart_write
    MED med_phases_prep_ocn_accum_avg
    MED -> OCN :remapMethod=redist
    OCN
    OCN -> MED :remapMethod=redist
  @
::
eof

     else   # NOT a coldstart

cat >> nems.configure <<eof
# Forecast Run Sequence #
runSeq::
  @$CPL_SLOW
    MED med_phases_prep_ocn_accum_avg
    MED -> OCN :remapMethod=redist
    OCN
    @$CPL_FAST
      MED med_phases_prep_atm
      MED med_phases_prep_ice
      MED -> ATM :remapMethod=redist
      MED -> ICE :remapMethod=redist
      ATM -> WAV
      WAV -> ATM :srcMaskValues=1
      WAV
      ATM
      ICE
      ATM -> MED :remapMethod=redist
      ICE -> MED :remapMethod=redist
      MED med_fraction_set
      MED med_phases_prep_ocn_map
      MED med_phases_prep_ocn_merge
      MED med_phases_prep_ocn_accum_fast
      MED med_phases_profile
    @
    OCN -> MED :remapMethod=redist
    MED med_phases_restart_write
  @
::
eof
     fi
   fi # USE_WAVES
 fi   # nems.configure
fi


if [ $inistep = warm -o $inistep = restart ] ; then
  restart_hr=$((restart_interval/3600))
fi

# CMEPS variables
export frac_grid=${frac_grid:-.false.}
if [ $frac_grid = .true. ] ; then export coupling_mode="nems_frac" ; fi

cat >> nems.configure <<eof
DRIVER_attributes::
      mediator_read_restart = ${mediator_read_restart:-.true.}
::
MED_attributes::
      ATM_model = $ATM_model
      ICE_model = $ICE_model
      OCN_model = $OCN_model
      history_n = ${history_n:-1}
      history_option = nhours
      history_ymd = -999
      coupling_mode = ${coupling_mode:-nems_orig}
::
ALLCOMP_attributes::
      ScalarFieldCount = 2
      ScalarFieldIdxGridNX = 1
      ScalarFieldIdxGridNY = 2
      ScalarFieldName = cpl_scalars
      start_type = ${start_type:-startup}
      case_name = ${case_name:-$MED_RESTDIR/ufs.s2s.cold}
      restart_n = ${restart_hr:-1}
      restart_option = nhours
      restart_ymd = -999
      dbug_flag   = ${cap_dbug_flag:-1}
      use_coldstart = ${USE_COLDSTART:-.false.}
::
eof

#     restart_n = ${restart_interval:-1}
#export histfreq_n=$FHOUT

# Create ice_in file

#if [ $inistep = restart ] ; then
# restim=.true.
#else
# restim=.false.
#fi

iceic=${iceic:-cice5_model.res_$CDATE.nc}
year=$(echo $CDATE|cut -c 1-4)
stepsperhr=$((3600/$ICETIM))
nhours=$($NHOUR $CDATE ${year}010100)
steps=$((nhours*stepsperhr))
npt=$((FHMAX*$stepsperhr))      # Need this in order for dump_last to work

if [ $NSOUT -gt 0 ] ; then      # this should output every timestep from the ice model
 histfreq="'1','x','x','x','x'"
 histfreq_n=1,1,1,1,1
 hist_avg=.false.
 export mdhxx='1xxxx'
fi

histfreq=${histfreq:-"'m','d','h','x','x'"}
histfreq_n=${histfreq_n:-0,0,$FHOUT,1,1}
export mdhxx=${mdhxx:-"'mdhxx'"}
export xxxxx=${xxxxx:-"'xxxxx'"}

restart_interval=${restart_interval:-1296000}    # restart write interval in seconds, default 15 days
dumpfreq="'s'"
dumpfreq_n=$restart_interval                     # restart write interval in seconds

restart_dir=${restart_dir:-\'$ICE_RESTDIR/\'}
history_dir=${history_dir:-\'$ICE_OUTDIR/\'}

ktherm=${ktherm:-1}
if [ $ktherm -eq 1 ] ; then export conduc=MU17 ; fi

# , restart_dir    = ${restart_dir:-'./restart/'}
# , pointer_file   = ${pointer_file:-'./restart/ice.restart_file'}
# , history_dir    = ${history_dir:-'./history/'}
# , incond_dir     = './history/'

cat > ice_in <<eof  
&setup_nml
    days_per_year  = 365
  , use_leap_years = .true.
  , year_init      = $year
  , istep0         = $steps
  , dt             = $ICETIM
  , npt            = $npt
  , ndtd           = 1
  , runtype        = ${runtype:-'initial'}
  , runid          = ${runid:-'unknown'}
  , ice_ic         = ${iceic:-'$iceic'}
  , pointer_file   = ${pointer_file:-'ice.restart_file'}
  , restart        = ${ice_restart:-.false.}
  , restart_ext    = ${restart_ext:-.true.}
  , use_restart_time = ${use_restart_time:-.false.}
  , restart_format = ${restart_format:-'nc'}
  , lcdf64         = .false.
  , restart_file   = ${restart_file:-'iced'}
  , restart_dir    = ${restart_dir:-'./restart/'}
  , dumpfreq       = ${dumpfreq:-'d'}
  , dumpfreq_n     = ${dumpfreq_n:- 45}
  , dump_last      = .false.  
  , diagfreq       = ${diagfreq:-6}
  , diag_type      = 'file'
  , diag_file      = ${diag_file:-'ice_diag.d'}
  , print_global   = .true.
  , print_points   = .true.
  , latpnt(1)      =  90.
  , lonpnt(1)      =   0.
  , latpnt(2)      = -65.
  , lonpnt(2)      = -45.
  , dbug           = .false.
  , histfreq       = ${histfreq:-"'m','d','h','x','x'"}
  , histfreq_n     = ${histfreq_n:-0,0,6,1,1}
  , hist_avg       = ${hist_avg:-.true.}
  , history_file   = ${history_file:-'iceh'}
  , history_dir    = ${history_dir:-'./history/'}
  , write_ic       = .true.
  , incond_dir     = ${incond_dir:-$history_dir}
  , incond_file    = 'iceh_ic'
/

&grid_nml
    grid_format  = 'nc'
  , grid_type    = 'displaced_pole'
  , grid_file    = 'grid_cice_NEMS_mx025.nc'
  , kmt_file     = 'kmtu_cice_NEMS_mx025.nc'
  , kcatbound    = 0
/

&domain_nml
    nprocs            = ${npe_ice:-24} 
  , processor_shape   = 'slenderX2'
  , distribution_type = 'cartesian'
  , distribution_wght = 'latitude'
  , ew_boundary_type  = 'cyclic'
  , ns_boundary_type  = 'tripole'
  , maskhalo_dyn      = .false.
  , maskhalo_remap    = .false.
  , maskhalo_bound    = .false.
/

&tracer_nml
    tr_iage           = .true.
  , restart_age       = .false.
  , tr_FY             = .true.
  , restart_FY        = .false.
  , tr_lvl            = .true.
  , restart_lvl       = .false.
  , tr_pond_cesm      = .false.
  , restart_pond_cesm = .false.
  , tr_pond_topo      = .false.
  , restart_pond_topo = .false.
  , tr_pond_lvl       = ${tr_pond_lvl:-.true.}
  , restart_pond_lvl  = ${restart_pond_lvl:-.false.}
  , tr_aero           = .false.
  , restart_aero      = .false.
/

&thermo_nml
    kitd              = 1
  , ktherm            = ${ktherm:-1}
  , conduct           = ${conduct:-'bubbly'}
  , a_rapid_mode      =  0.5e-3
  , Rac_rapid_mode    =    10.0
  , aspect_rapid_mode =     1.0
  , dSdt_slow_mode    = -5.0e-8
  , phi_c_slow_mode   =    0.05
  , phi_i_mushy       =    0.85
/

&dynamics_nml
    kdyn            = 1
  , ndte            = 120
  , revised_evp     = .false.
  , advection       = 'remap'
  , kstrength       = 1
  , krdg_partic     = 1
  , krdg_redist     = 1
  , mu_rdg          = 3
/

&shortwave_nml
    shortwave       = 'dEdd'
  , albedo_type     = 'default'
  , albicev         = 0.78
  , albicei         = 0.36
  , albsnowv        = 0.98
  , albsnowi        = 0.70 
  , ahmax           = 0.3
  , R_ice           = 0.
  , R_pnd           = 0.
  , R_snw           = 1.5
  , dT_mlt          = 1.5
  , rsnw_mlt        = 1500.
/

&ponds_nml
    hp1             = 0.01
  , hs0             = 0.
  , hs1             = 0.03
  , dpscale         = 1.0e-3
  , frzpnd          = 'hlid'
  , snowinfil       = .true.
  , rfracmin        = 0.15
  , rfracmax        = 1.
  , pndaspect       = 0.8
/

&zbgc_nml
    tr_brine        = .false.
  , restart_hbrine  = .false.
  , skl_bgc         = .false.
  , bgc_flux_type   = 'Jin2006'
  , restart_bgc     = .false.
  , restore_bgc     = .false.
  , bgc_data_dir    = 'unknown_bgc_data_dir'
  , sil_data_type   = 'default'
  , nit_data_type   = 'default'
  , tr_bgc_C_sk     = .false.
  , tr_bgc_chl_sk   = .false.
  , tr_bgc_Am_sk    = .false.
  , tr_bgc_Sil_sk   = .false.
  , tr_bgc_DMSPp_sk = .false.
  , tr_bgc_DMSPd_sk = .false.
  , tr_bgc_DMS_sk   = .false.
  , phi_snow        = 0.5
/

&forcing_nml
    formdrag        = .false.
  , atmbndy         = 'default'
  , fyear_init      = 1997
  , ycycle          = 1
  , atm_data_format = 'bin'
  , atm_data_type   = 'none'
  , atm_data_dir    = ${atm_data_dir:-$ROTDIR/lanl_cice_data}
  , calc_strair     = .true.
  , calc_Tsfc       = .true.
  , precip_units    = 'mm_per_month'
  , ustar_min       = 0.0005
  , update_ocn_f    = .false.
  , oceanmixed_ice  = .false.
  , ocn_data_format = 'bin'
  , sss_data_type   = 'default'
  , sst_data_type   = 'default'
  , ocn_data_dir    = 'unknown_ocn_data_dir'
  , oceanmixed_file = 'unknown_oceanmixed_file'
  , restore_sst     = .false.
  , trestore        =  90
  , restore_ice     = .false.
/

&icefields_nml
    f_tmask         = .true.
  , f_tarea         = .true.
  , f_uarea         = .true.
  , f_dxt           = .false.
  , f_dyt           = .false.
  , f_dxu           = .false.
  , f_dyu           = .false.
  , f_HTN           = .false.
  , f_HTE           = .false.
  , f_ANGLE         = .true.
  , f_ANGLET        = .true.
  , f_NCAT          = .true.
  , f_VGRDi         = .false.
  , f_VGRDs         = .false.
  , f_VGRDb         = .false.
  , f_bounds        = .false.
  , f_aice          = $mdhxx 
  , f_hi            = $mdhxx
  , f_hs            = $mdhxx 
  , f_Tsfc          = $mdhxx 
  , f_sice          = $mdhxx 
  , f_uvel          = $mdhxx 
  , f_vvel          = $mdhxx 
  , f_fswdn         = $mdhxx 
  , f_flwdn         = $mdhxx
  , f_snow          = $mdhxx 
  , f_snow_ai       = $xxxxx 
  , f_rain          = $mdhxx 
  , f_rain_ai       = $xxxxx 
  , f_sst           = $mdhxx 
  , f_sss           = $mdhxx 
  , f_uocn          = $mdhxx 
  , f_vocn          = $mdhxx 
  , f_frzmlt        = $mdhxx
  , f_fswfac        = $mdhxx
  , f_fswabs        = $mdhxx 
  , f_fswabs_ai     = $xxxxx 
  , f_albsni        = $mdhxx 
  , f_alvdr         = $mdhxx
  , f_alidr         = $mdhxx
  , f_albice        = $mdhxx
  , f_albsno        = $mdhxx
  , f_albpnd        = $mdhxx
  , f_coszen        = $mdhxx
  , f_flat          = $mdhxx 
  , f_flat_ai       = $xxxxx 
  , f_fsens         = $mdhxx 
  , f_fsens_ai      = $xxxxx 
  , f_flwup         = $mdhxx 
  , f_flwup_ai      = $xxxxx 
  , f_evap          = $mdhxx 
  , f_evap_ai       = $xxxxx 
  , f_Tair          = $mdhxx 
  , f_Tref          = $mdhxx 
  , f_Qref          = $mdhxx
  , f_congel        = $mdhxx 
  , f_frazil        = $mdhxx 
  , f_snoice        = $mdhxx 
  , f_dsnow         = $mdhxx 
  , f_melts         = $mdhxx
  , f_meltt         = $mdhxx
  , f_meltb         = $mdhxx
  , f_meltl         = $mdhxx
  , f_fresh         = $mdhxx
  , f_fresh_ai      = $xxxxx
  , f_fsalt         = $mdhxx
  , f_fsalt_ai      = $xxxxx
  , f_fhocn         = $mdhxx 
  , f_fhocn_ai      = $xxxxx 
  , f_fswthru       = $mdhxx 
  , f_fswthru_ai    = $xxxxx 
  , f_fsurf_ai      = $xxxxx
  , f_fcondtop_ai   = $xxxxx
  , f_fmeltt_ai     = $xxxxx 
  , f_strairx       = $mdhxx 
  , f_strairy       = $mdhxx 
  , f_strtltx       = $mdhxx 
  , f_strtlty       = $mdhxx 
  , f_strcorx       = $mdhxx 
  , f_strcory       = $mdhxx 
  , f_strocnx       = $mdhxx 
  , f_strocny       = $mdhxx 
  , f_strintx       = $mdhxx 
  , f_strinty       = $mdhxx
  , f_strength      = $mdhxx
  , f_divu          = $mdhxx
  , f_shear         = $mdhxx
  , f_sig1          = 'x' 
  , f_sig2          = 'x' 
  , f_dvidtt        = $mdhxx 
  , f_dvidtd        = $mdhxx 
  , f_daidtt        = $mdhxx
  , f_daidtd        = $mdhxx 
  , f_mlt_onset     = $mdhxx
  , f_frz_onset     = $mdhxx
  , f_hisnap        = $mdhxx
  , f_aisnap        = $mdhxx
  , f_trsig         = $mdhxx
  , f_icepresent    = $mdhxx
  , f_iage          = $mdhxx
  , f_FY            = $mdhxx
  , f_aicen         = $xxxxx
  , f_vicen         = $xxxxx
  , f_Tinz          = 'x'
  , f_Sinz          = 'x'
  , f_Tsnz          = 'x'
  , f_fsurfn_ai     = $xxxxx
  , f_fcondtopn_ai  = $xxxxx
  , f_fmelttn_ai    = $xxxxx
  , f_flatn_ai      = $xxxxx
  , f_s11           = $mdhxx
  , f_s12           = $mdhxx
  , f_s22           = $mdhxx
  , f_yieldstress11 = $mdhxx
  , f_yieldstress12 = $mdhxx
  , f_yieldstress22 = $mdhxx
/

&icefields_mechred_nml
    f_alvl         = $mdhxx
  , f_vlvl         = $mdhxx
  , f_ardg         = $mdhxx
  , f_vrdg         = $mdhxx
  , f_dardg1dt     = 'x'
  , f_dardg2dt     = 'x'
  , f_dvirdgdt     = 'x'
  , f_opening      = $mdhxx
  , f_ardgn        = $xxxxx
  , f_vrdgn        = $xxxxx
  , f_dardg1ndt    = 'x'
  , f_dardg2ndt    = 'x'
  , f_dvirdgndt    = 'x'
  , f_krdgn        = 'x'
  , f_aparticn     = 'x'
  , f_aredistn     = 'x'
  , f_vredistn     = 'x'
  , f_araftn       = 'x'
  , f_vraftn       = 'x'
/

&icefields_pond_nml
    f_apondn       = $xxxxx
  , f_apeffn       = $xxxxx
  , f_hpondn       = $xxxxx
  , f_apond        = $mdhxx
  , f_hpond        = $mdhxx
  , f_ipond        = $mdhxx
  , f_apeff        = $mdhxx
  , f_apond_ai     = $xxxxx
  , f_hpond_ai     = $xxxxx
  , f_ipond_ai     = $xxxxx
  , f_apeff_ai     = $xxxxx
/

&icefields_bgc_nml
    f_faero_atm    = 'x'
  , f_faero_ocn    = 'x'
  , f_aero         = 'x'
  , f_fNO          = 'x'
  , f_fNO_ai       = 'x'
  , f_fNH          = 'x'
  , f_fNH_ai       = 'x'
  , f_fN           = 'x'
  , f_fN_ai        = 'x'
  , f_fSil         = 'x'
  , f_fSil_ai      = 'x'
  , f_bgc_N_sk     = 'x'
  , f_bgc_C_sk     = 'x'
  , f_bgc_chl_sk   = 'x'
  , f_bgc_Nit_sk   = 'x'
  , f_bgc_Am_sk    = 'x'
  , f_bgc_Sil_sk   = 'x'
  , f_bgc_DMSPp_sk = 'x'
  , f_bgc_DMSPd_sk = 'x'
  , f_bgc_DMS_sk   = 'x'
  , f_bgc_Nit_ml   = 'x'
  , f_bgc_Am_ml    = 'x'
  , f_bgc_Sil_ml   = 'x'  
  , f_bgc_DMSP_ml  = 'x'
  , f_bTin         = 'x'
  , f_bphi         = 'x'
  , f_fbri         = 'x'
  , f_hbri         = 'x'
  , f_grownet      = 'x'
  , f_PPnet        = 'x'
/

&icefields_drag_nml
    f_drag         = $mdhxx
  , f_Cdn_atm      = $mdhxx
  , f_Cdn_ocn      = $mdhxx
/
eof

echo $(pwd)
cd $DATA
cat > med_modelio.nml <<eof  
&pio_inparm
  pio_netcdf_format = "64bit_offset"
  pio_numiotasks = -99
  pio_rearranger = 1
  pio_root = 1
  pio_stride = 36
  pio_typename = ${NETCDF_TYPE:-"netcdf"}
/
eof

echo $(pwd)
ls -ltr med_mo*

# Enables linking files for the warm and restart steps
# ----------------------------------------------------
export LINK_MED_RST_FILES=${LINK_MED_RST_FILES:-YES}
if [ $inistep = warm -o $inistep = restart ] ; then
 export LINK_OCN_FILES=${LINK_OCN_FILES:-YES}
 export LINK_MED_RST_FILES=${LINK_MED_RST_FILES:-YES}
 export LINK_WW3_RST_FILES=${LINK_WW3_RST_FILES:-YES}
fi

# Optionally link ocean history files to OCN_OUTDIR directory
#-----------------------------------------------------------
if [ ${LINK_OCN_FILES:-NO} = YES ] ; then
  export FHOUT_O=${FHOUT_O:-6}
  export FHMIN=$((FHMIN+0))
  if [ ${OCN_AVG:-NO} = YES ] ; then
    fhr=$((10#$FHMIN+10#$FHOUT_O/2))
    min=$((FHOUT*30-(FHOUT/2)*60))
  else
    fhr=$((10#$FHMIN+10#$FHOUT_O))
    min=0
  fi
  while [ $fhr -le $FHMAX ] ; do
    XDATE=$($NDATE +$fhr $CDATE)
    PDYX=$(echo $XDATE | cut -c1-8)
    yyyy=$(echo $XDATE | cut -c1-4)
      mm=$(echo $XDATE | cut -c5-6)
      dd=$(echo $XDATE | cut -c7-8)
    cycx=$(echo $XDATE | cut -c9-10)
    for file in ocn SST ; do
      if [ $min -gt 0 ] ; then
        file_name=${file}_${yyyy}_${mm}_${dd}_${cycx}_${min}.nc
      else
        file_name=${file}_${yyyy}_${mm}_${dd}_${cycx}.nc
      fi
      eval $NLN $OCN_OUTDIR/$file_name $file_name
    done
    fhr=$((fhr+FHOUT_O))
  done
fi
if [ ${LINK_MED_RST_FILES:-NO} = YES ] ; then
# restart_hr=$((restart_interval/3600))
  if [ $inistep = cold ] ; then restart_hr=1 ; fi
  export FHMIN=$((FHMIN+0))
  fhr=$((10#$FHMIN+10#$restart_hr))
  if [ $fhr -gt $FHMAX ] ; then export fhr=$FHMAX ; fi
  while [ $fhr -le $FHMAX ] ; do
    XDATE=$($NDATE +$fhr $CDATE)
    XYEAR=$(echo $XDATE | cut -c1-4)
    XMON=$(echo $XDATE | cut -c5-6)
    XDAY=$(echo $XDATE | cut -c7-8)
    XSEC=$(($(echo $XDATE | cut -c9-10)*3600)) 
    RFILE=${case_name}.cpl.r.${XYEAR}-${XMON}-${XDAY}-$(printf %05i $XSEC).nc

 #  eval $NLN $MED_RESTDIR/$RFILE $RFILE

    fhr=$((fhr+restart_hr))
  done
fi

# for Wave (WW3)    (to be done)
if [ $CPLDWAV = YES ] ; then
 if [ ${LINK_WW3_RST_FILES:-NO} = YES ] ; then
# restart_hr=$((restart_interval/3600))
  export FHMIN=$((FHMIN+0))
  fhr=$((10#$FHMIN+10#$restart_hr))
  while [ $fhr -le $FHMAX ] ; do
    XDATE=$($NDATE +$fhr $CDATE)
    PDYX=$(echo $XDATE | cut -c1-8)
    cycx=$(echo $XDATE | cut -c9-10)
    eval $NLN $WW3_RESTDIR/${PDYX}.${cycx}0000.restart.$ww3_grid ${PDYX}.${cycx}0000.restart.$ww3_grid
    fhr=$((fhr+restart_hr))
  done
 fi
fi


#CMEPS_DIR=${CMEPS_DIR:-$appdir/CMEPS}
#$NLN $CMEPS_DIR/mediator/fd_nems.yaml fd_nems.yaml
#$NLN $CMEPS_DIR/../parm/pio_in        pio_in

