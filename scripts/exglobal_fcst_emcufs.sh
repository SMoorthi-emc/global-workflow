#!/bin/ksh
################################################################################
# UNIX Script Documentation Block
# Script name:         exglobal_fcst_fv3gfs.sh.ecf
# Script description:  Runs a global FV3GFS model forecast
#
# Author:   Fanglin Yang       Org: NCEP/EMC       Date: 2016-11-15
# Abstract: This script runs a single GFS forecast with FV3 dynamical core.  
#           This script is created based on a C-shell script that GFDL wrote 
#           for the NGGPS Phase-II Dycore Comparison Project. 
#
# Script history log:
# 2016-11-15  Fanglin Yang
# 2017-01-10  S Moorthi - some cleanup and generalization
# 2017-02-01  S Moorthi - updated for NEMS/FV3 using Jun Wangs script
# 2017-03-20  S Moorthi - updated for NEMS/FV3 for IPD4
# 2017-07-14  S Moorthi - updated for write grid component
# 2017-12-20  S Moorthi - added links to atm and sfc nemsio files
# 2019-01-31  S Moorthi - merged with "exglobal_fcst_nemsfv3gfs.sh" from
#                         coupled fv3gfs_benchmark workflow.
# 2019-03-05  Rahul Mahajan  Implemented IAU
# 2019-03-21  Fanglin Yang   Add restart capability for running gfs fcst from a break point.
# 2019-05-15  S Moorthi - Adding UGW namelist parameters 
# 2019-11-07  S Moorthi - updating to run multiple coupled apps (FV3, MOM6, CICE, WW3)
#
# Attributes:
#   Language: Portable Operating System Interface (POSIX) Shell
#   Machine: WCOSS-CARY, WCOSS-DEll-P3, HERA, GAEA           
################################################################################

#  Set environment.
#------------------
export VERBOSE=${VERBOSE:-YES}
if [[ $VERBOSE = YES ]] ; then
  echo $(date) EXECUTING $0 $* >&2
  set -x
fi

export machine=${machine:-WCOSS_DELL_P3}
export machine=$(echo $machine|tr '[a-z]' '[A-Z]')
export FCST_LAUNCHER=${FCST_LAUNCHER:-${APRUN_FV3:-${APRUN_FCST:-${APRUN:-""}}}}
export APRUNB=${APRUNB:-NONE}
export APRUNE=${APRUNE:-NONE}
export APRUNW=${APRUNW:-NONE}
#export I_MPI_DEBUG=${I_MPI_DEBUG:-0}
#export I_MPI_DEBUG_OUTPUT=${I_MPI_DEBUG_OUTPUT:-''}

export print_esmf=${print_esmf:-.false.} # print each PET output to file
export ESMF_RUNTIME_PROFILE=${ESMF_RUNTIME_PROFILE:-ON}
export ESMF_RUNTIME_PROFILE_OUTPUT=${ESMF_RUNTIME_PROFILE_OUTPUT:-SUMMARY}
export ESMF_RUNTIME_COMPLIANCECHECK=${ESMF_RUNTIME_COMPLIANCECHECK:-'OFF:depth=4'}

export cplflx=${cplflx:-${CPLFLX:-.false.}}
export cpl=${cpl:-${CPL:-.false.}}
export mediator=${mediator:-cmeps}

# experiment name, horizontal and vertical resolutions
#-----------------------------------------------------
export CASE=${CASE:-C768}
export LEVS=${LEVS:-127}
export res=$(echo $CASE |cut -c 2-5)
export DELTIM=${DELTIM:-225}
export layout_x=${layout_x:-8}
export layout_y=${layout_y:-$((layout_x*2))}

# Cycling and forecast hour specific parameters
#----------------------------------------------
export CDATE=${CDATE:-2019010100}      # current forecast date
export CDUMP=${CDUMP:-gdas}
export FHMAX=${FHMAX:-240}             # max hours to forecast
export FHOUT=${FHOUT:-6.0}             # output interval
export FHZER=${FHZER:-$FHOUT}          # interval over which to reset accumulating arrays
export FHMAX_HF=${FHMAX_HF:-0}         # max hour for high frquency output
export FHOUT_HF=${FHOUT_HF:-1}         # output interval for high frequency output
export FHMIN=${FHMIN:-0}               # starting hour
export FHROT=${FHROT:-$FHMIN}
export FHCYC=${FHCYC:-0.0}             # interval to update boundary conditions
export NSOUT=${NSOUT:-${nsout:--1}}
if [ $FHMAX_HF -gt 0 -a $FHOUT_HF -gt 0 ] ; then
 export fdiag=${fdiag:-$FHOUT_HF}
else
 export fdiag=${fdiag:-$FHOUT}
fi
WRITE_DOPOST=${WRITE_DOPOST_CPLD:-${WRITE_DOPOST:-.false.}}

PDY=$(echo $CDATE | cut -c1-8)
cyc=$(echo $CDATE | cut -c9-10)

# Directories
#------------

pwd=$(pwd)
export NWPROD=${NWPROD:-${NWROOT:-$pwd}}
export HOMEgfs=${HOMEgfs:-$NWPROD}
export FIX_DIR=${FIX_DIR:-$HOMEgfs/fix}
export FIX_AM=${FIX_AM:-$FIX_DIR/fix_am}
export FIX_FV3=${FIX_FV3:-${FIXfv3:-$FIX_DIR/fix_fv3_gmted2010}}

DATA=${DATA:-$pwd/ufstmp$$}    # temporary running directory
ROTDIR=${ROTDIR:-$pwd}         # rotating archive directory
ICSDIR=${ICSDIR:-$pwd}         # cold start initial conditions
DMPDIR=${DMPDIR:-$pwd}         # global dumps for seaice, snow and sst analysis

if [ $machine = HERA ] ; then
# export MPICH_FAST_MEMCPY=${MPICH_FAST_MEMCPY:-ENABLE}
# export MPI_BUFS_PER_PROC=${MPI_BUFS_PER_PROC:-2048}
# export MPI_BUFS_PER_HOST=${MPI_BUFS_PER_HOST:-2048}
  export MKL_NUM_THREADS=${MKL_NUM_THREADS:-0}

  . $MODULESHOME/init/sh 2>/dev/null
  module list

  NS_GLOPARA=${NS_GLOPARA:-/scratch1/NCEPDEV/global/glopara}
  export FIX_DIR=${FIX_DIR:-$NS_GLOPARA/fix}
elif [ $machine = GAEA ] ; then
  export gaea_c=${gaea_c:-c3}
# . $MODULESHOME/init/sh 2>/dev/null
# . /opt/modules/3.2.6.7/init/ksh 2>/dev/null
  if [ $gaea_c = c3 ] ; then
  . /opt/modules/3.2.10.3/init/sh 2>/dev/null # for c3
  else
  . /opt/modules/3.2.10.5/init/sh 2>/dev/null # for c4
  fi

  export PRGENV=${PRGENV:-intel}
  export HUGEPAGES=${HUGEPAGES:-hugepages2M}

  module unload prod_util iobuf PrgEnv-$PRGENV craype-$HUGEPAGES 2>/dev/null
  module   load prod_util iobuf PrgEnv-$PRGENV craype-$HUGEPAGES 2>/dev/null

# export IOBUF_PARAMS=${IOBUF_PARAMS:-'*:size=8M'}

  export IOBUF_PARAMS=${IOBUF_PARAMS:-'*:size=8M:verbose'}
  export MPICH_GNI_COLL_OPT_OFF=${MPICH_GNI_COLL_OPT_OFF:-MPI_Alltoallv}

  NS_GLOPARA=${NS_GLOPARA:-/gpfs/hps/emc/global/noscrub/emc.glopara}
  export FIX_DIR=${FIX_DIR:-$NS_GLOPARA/fix}}
  export MPICH_FAST_MEMCPY=${MPICH_FAST_MEMCPY:-ENABLE}
  export MPICH_MAX_SHORT_MSG_SIZE=${MPICH_MAX_SHORT_MSG_SIZE:-4096}
  export MPICH_UNEX_BUFFER_SIZE=${MPICH_UNEX_BUFFER_SIZE:-1024000000}
  export MPICH_PTL_UNEX_EVENTS=${MPICH_PTL_UNEX_EVENTS:-400000}
  export MPICH_PTL_OTHER_EVENTS=${MPICH_PTL_OTHER_EVENTS:-100000}
  export MPMD_PROC=${MPMD_PROC:-NO}
  export MKL_NUM_THREADS=${MKL_NUM_THREADS:-1}

elif [ $machine = WCOSS_C -a  ${LOADIOBUF:-YES} = YES ] ; then
  . $MODULESHOME/init/sh 2>/dev/null
  export PRGENV=${PRGENV:-intel}
  export HUGEPAGES=${HUGEPAGES:-hugepages2M}

  module unload prod_util iobuf PrgEnv-$PRGENV craype-$HUGEPAGES 2>/dev/null
  module   load prod_util iobuf PrgEnv-$PRGENV craype-$HUGEPAGES 2>/dev/null

# export IOBUF_PARAMS=${IOBUF_PARAMS:-'*:size=8M'}
  export WRTIOBUF=${WRTIOBUF:-"4M"}
  export NC_BLKSZ=${NC_BLKSZ:-"4M"}
  export IOBUF_PARAMS="*nemsio:verbose:size=${WRTIOBUF},*:verbose:size=${NC_BLKSZ}"

  export MPICH_GNI_COLL_OPT_OFF=${MPICH_GNI_COLL_OPT_OFF:-MPI_Alltoallv}

  NS_GLOPARA=${NS_GLOPARA:-/gpfs/hps3/emc/global/noscrub/emc.glopara}
  export FIX_DIR=${FIX_DIR:-$NS_GLOPARA/svn/fv3gfs/fix}

  export MKL_CBWR=${MKL_CBWR:-AVX}          # Needed for bit reproducibility with mkl
  export MKL_NUM_THREADS=${MKL_NUM_THREADS:-1}

elif [ $machine = WCOSS_DELL_P3 ] ; then
  ulimit -s unlimited
  export SAVE_ALL_TASKS=${SAVE_ALL_TASKS:-no}
  export PROFILE_BY_CALL_SITE=${PROFILE_BY_CALL_SITE:-no}

  . ${MODULESHOME:-/usrx/local/prod/lmod/lmod}/init/sh  2>> /dev/null

  export MKL_CBWR=${MKL_CBWR:-AVX}          # Needed for bit reproducibility with mkl
  export MKL_NUM_THREADS=${MKL_NUM_THREADS:-1}
  export MP_EAGER_LIMIT=${MP_EAGER_LIMIT:-64K}
  export FORT_BUFFERED=${FORT_BUFFERED:-true}
  export MP_EUIDEVICE=${MP_EUIDEVICE:-min}
  export MP_EUILIB=${MP_EUILIB:-us}
# export MP_TASK_AFFINITY=${MP_TASK_AFFINITY:-"cpu:$NTHREADS"}
  export MPICH_ALLTOALL_THROTTLE=${MPICH_ALLTOALL_THROTTLE:-0}
  export MP_SINGLE_THREAD=${MP_SINGLE_THREAD:-yes}
  export VPROF_PROFILE=${VPROF_PROFILE:-no}
  export MP_COREFILE_FORMAT=${MP_COREFILE_FORMAT:-lite}
  export KMP_AFFINITY=${KMP_AFFINITY:-disabled}

  module list
fi

export FIX_AER=${FIX_AER:-$FIX_DIR/fix_aer}
export FIX_CCN=${FIX_CCN:-$FIX_DIR/fix_ccn}
export FIX_LUT=${FIX_LUT:-$FIX_DIR/fix_lut}
export CO2DIR=${CO2DIR:-$FIX_AM/fix_co2_proj}
export PARM_DIR=${PARM_DIR:-$HOMEgfs/parm/parm_fv3diag}
export PARM_POST=${PARM_POST:-$POSTDIR/parm}

if [ $CDUMP = gfs ] ; then
  export adjust_dry_mass=.false.
else
  export adjust_dry_mass=${adjust_dry_mass:-.true.}
fi

# Utilities
#NCP=${NCP:-"/bin/cp -p"}
NCP=${NCP:-"/bin/cp "}
NLN=${NLN:-"/bin/ln -sf"}
NMV=${NMV:-"/bin/mv"}
SEND=${SEND:-YES}   #move final result to rotating directory
KEEPDATA=${KEEPDATA:-NO}
ERRSCRIPT=${ERRSCRIPT:-'eval [[ $err = 0 ]]'}
NDATE=${NDATE:-$NWPROD/util/exec/ndate}
NHOUR=${NHOUR:-$NWPROD/util/exec/nhour}

# Other options
# -------------
MEMBER=${MEMBER:--1}               # -1: control, 0: ensemble mean, >0: ensemble member $MEMBER
ENS_NUM=${ENS_NUM:-1}              # Single executable runs multiple members (e.g. GEFS)
PREFIX_ATMINC=${PREFIX_ATMINC:-""} # allow ensemble to use recentered increment

# IAU options
# -----------
DOIAU=${DOIAU:-NO}
IAUFHRS=${IAUFHRS:-0}
IAU_DELTHRS=${IAU_DELTHRS:-0}
IAU_OFFSET=${IAU_OFFSET:-0}

# options to use quilting in UFS
#-------------------------------
export QUILTING=${QUILTING:-.true.}
export WRITE_GROUP=${WRITE_GROUP:-1}
export WRTTASK_PER_GROUP=${WRTTASK_PER_GROUP:-6}
export NUM_FILES=${NUM_FILES:-2}
export FILENAME_BASE=${FILENAME_BASE:-'atm sfc'}
export OUTPUT_GRID=${OUTPUT_GRID:-gaussian_grid}
export OUTPUT_FILE=${OUTPUT_FILE:-nemsio}
export WRITE_NEMSIOFLIP=${WRITE_NEMSIOFLIP:-.true.}
export WRITE_FSYNCFLAG=${WRITE_FSYNCFLAG:-.true.}


#-------------------------------------------------------
#-------------------------------------------------------
export TYPE=${TYPE:-nh}                  # choices:  nh, hydro
export MONO=${MONO:-non-mono}            # choices:  mono, non-mono

export FCSTEXECDIR=${FCSTEXECDIR:-$HOMEgfs/sorc/fv3gfs.fd/NEMS/exe}
export FCSTEXEC=${FCSTEXEC:-NEMS.x}
$NCP  $FCSTEXECDIR/$FCSTEXEC $DATA/.                                                   

export HYPT=${HYPT:-off}             # choices:  on, off  (controls hyperthreading)
if [ $HYPT = on ] ; then
   export hyperthread=.true.
   export j_opt="-j 2"
else
   export hyperthread=.false.
   export j_opt="-j 1"
fi
#export nthreads=${nth_f:-2}
export nthreads=${NTHREADS_FV3:-${NTHREADS_FCST:-${nth_f:-1}}}
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-$nthreads}
export cores_per_node=${cores_per_node:-${npe_node_f:-28}}
ntiles=${ntiles:-6}
#
export WRITE_GROUP=${WRITE_GROUP:-0}
export WRTTASK_PER_GROUP=${WRTTASK_PER_GROUP:-0}
export tasks=${npe_fv3:-${npe_fcst:-$((ntiles*layout_x*layout_y+WRITE_GROUP*WRTTASK_PER_GROUP))}}


#-------------------------------------------------------
if [ ! -s $ROTDIR ] ; then mkdir -p $ROTDIR ; fi
if [ ! -s $DATA ]   ; then mkdir -p $DATA   ; fi
cd $DATA || exit 8

mkdir -p $DATA/INPUT
restart_interval_atm=${restart_interval_atm:-0}
restart_interval=$(echo $restart_interval_atm |cut -d " " -f 1)
if [ $CDUMP = gfs -a $restart_interval -gt 0 ] ; then
  ATM_RESTDIR=${ATM_RESTDIR:-$ROTDIR/${CDUMP}.$PDY/$cyc/ATM_RESTART}
  if [ ! -d $ATM_RESTDIR ] ; then mkdir -p $ATM_RESTDIR ; fi
  $NLN $ATM_RESTDIR $DATA/RESTART
  rm $DATA/RESTART/ATM_RESTART
  export LINK_RESTDIR=YES
else
  mkdir -p $DATA/RESTART
  export LINK_RESTDIR=NO
fi

#--------------------------------------------------------------------
# determine if restart IC exists to continue from a previous forecast
#--------------------------------------------------------------------
RERUN_FCST=${RERUN_FCST:-NO}
RUNCONTINUE=NO
filecount=$(find $ATM_RESTDIR -type f | wc -l)
if [ $CDUMP = gfs -a $restart_interval -gt 0 -a $FHMAX -gt $restart_interval -a $filecount -gt 10 ] ; then
  if [ $FHMIN -gt 0  -a $FHMIN -lt $FHMAX ] ; then
    CDATE_RST=$($NDATE $FHMIN $CDATE)
    RUNCONTINUE=YES
  elif [ $FHMIN -ge $FHMAX  -a $RERUN_FCST = NO ] ; then
    echo 'FHMIN ' $FHMIN ' >= FHMAX ' $FHMAX
    exit
  elif [ ${RERUN_FCST:-NO} = NO ]  ; then
    reverse=$(echo "${restart_interval_atm[@]} " | tac -s ' ')
    for xfh in $reverse ; do
      if [ $xfh -eq $restart_interval ] ; then
        CDATE_RST=$CDATE
        SDATE=$($NDATE +$FHMAX $CDATE)
        EDATE=$($NDATE +$restart_interval $CDATE)
        while [ $SDATE -gt $EDATE ] ; do
          PDYS=$(echo $SDATE | cut -c1-8)
          cycs=$(echo $SDATE | cut -c9-10)
          flag1=$ATM_RESTDIR/${PDYS}.${cycs}0000.coupler.res
          flag2=$ATM_RESTDIR/coupler.res
          if [ -s $flag1 ] ; then
            mv $flag1 ${flag1}.old
            if [ -s $flag2 ] ; then mv $flag2 ${flag2}.old ; fi
            RUNCONTINUE=YES
            CDATE_RST=$($NDATE -$restart_interval $SDATE)
            break
          fi
          SDATE=$($NDATE -$restart_interval $SDATE)
        done
        FHMIN=$($NHOUR $CDATE_RST $CDATE)
        FHROT=$FHMIN
      else
        yfh=$((xfh-(IAU_OFFSET/2)))
        SDATE=$($NDATE +$yfh $CDATE)
        PDYS=$(echo $SDATE | cut -c1-8)
        cycs=$(echo $SDATE | cut -c9-10)
        flag1=$ATM_RESTDIR/${PDYS}.${cycs}0000.coupler.res
        flag2=$ATM_RESTDIR/coupler.res
        if [ -s $flag1 ]; then
            CDATE_RST=$SDATE
            [[ $RUNCONTINUE = YES ]] && break
            mv $flag1 ${flag1}.old
            if [ -s $flag2 ]; then mv $flag2 ${flag2}.old ;fi
            RUNCONTINUE=YES
            [[ $xfh = $restart_interval ]] && RUNCONTINUE=NO
        fi
      fi
    done
  fi
fi

rCDUMP=${rCDUMP:-$CDUMP}

# member directory
# ----------------
if [ $MEMBER -lt 0 ] ; then
  prefix=$CDUMP
  rprefix=$rCDUMP
  memchar=""
else
  prefix=enkf.$CDUMP
  rprefix=enkf.$rCDUMP
  memchar=/mem$(printf %03i $MEMBER)
fi
memdir=$ROTDIR/${prefix}.$PDY/${cyc}$memchar
if [ ! -d $memdir ] ; then mkdir -p $memdir ; fi

assim_freq=${assim_freq:-6}
GDATE=$($NDATE -$assim_freq $CDATE)
gPDY=$(echo $GDATE | cut -c1-8)
gcyc=$(echo $GDATE | cut -c9-10)
gmemdir=$ROTDIR/${rprefix}.$gPDY/${gcyc}$memchar
sCDATE=$($NDATE -3 $CDATE)

export DOIAU=${DOIAU:-NO}
if [[ $DOIAU = YES ]] ; then
  sCDATE=$($NDATE -3 $CDATE)
  sPDY=$(echo $sCDATE | cut -c1-8)
  scyc=$(echo $sCDATE | cut -c9-10)
  tPDY=$gPDY
  tcyc=$gcyc
  fhrot=${IAU_FHROT:--3}
else
  sCDATE=$CDATE
  sPDY=$PDY
  scyc=$cyc
  tPDY=$sPDY
  tcyc=$cyc
fi

#-------------------
# initial conditions
# ------------------
export warm_start=${warm_start:-.false.}
read_increment=${read_increment:-.false.}

# Determine if this is a warm start or cold start
if [ -f $gmemdir/RESTART/${PDY}.${cyc}0000.coupler.res ] ; then
  export warm_start=.true.
fi

# turn IAU off for cold start
# ---------------------------
DOIAU_coldstart=${DOIAU_coldstart:-NO}
if [ $DOIAU = YES -a $warm_start = .false. ] || [ $DOIAU_coldstart = YES -a $warm_start = .true. ] ; then
  export DOIAU=NO
  echo "turning off IAU since warm_start = $warm_start"
  DOIAU_coldstart=YES
  IAU_OFFSET=0
  sCDATE=$CDATE
  sPDY=$PDY
  scyc=$cyc
  tPDY=$sPDY
  tcyc=$cyc
fi

if [ $warm_start = .true. -o $RUNCONTINUE = YES ] ; then

  nggps_ic=.false.
  ncep_ic=.false.
  external_ic=.false.
# external_eta=.false.
  mountain=.true.
  export na_init=0
  export make_nh=.false.           # restarts already contains non-hydrostatic state

  if [ $RUNCONTINUE = NO ] ; then
  # Link all (except sfc_data) restart files from $gmemdir
    if [ -f $gmemdir/RESTART/${PDY}.${cyc}0000.coupler.res ] ; then
      for file in $gmemdir/RESTART/${PDY}.${cyc}0000.*.nc* ; do
        file2=$(echo $(basename $file))
        file2=$(echo $file2 | cut -d. -f3-) # remove the date from file
        fsuf=$(echo $file2 | cut -d. -f1)
        if [ $fsuf != sfc_data ] ; then
          $NLN $file $DATA/INPUT/$file2
       fi
      done

  # Link sfcanl_data restart files from $memdir
      for file in $memdir/RESTART/${PDY}.${cyc}0000.*.nc* ; do
        file2=$(echo $(basename $file))
        file2=$(echo $file2 | cut -d. -f3-) # remove the date from file
        fsufanl=$(echo $file2 | cut -d. -f1)
        if [ $fsufanl = sfcanl_data ] ; then
          file2=$(echo $file2 | sed -e "s/sfcanl_data/sfc_data/g")
          $NLN $file $DATA/INPUT/$file2
        fi
      done
    fi

  # Need a coupler.res when doing IAU
    if [ $DOIAU = YES ] ; then
      rm -f $DATA/INPUT/coupler.res
      cat >> $DATA/INPUT/coupler.res << EOF
       2        (Calendar: no_calendar=0, thirty_day_months=1, julian=2, gregorian=3, noleap=4)
    ${gPDY:0:4}  ${gPDY:4:2}  ${gPDY:6:2}  ${gcyc}     0     0        Model start time:   year, month, day, hour, minute, second
    ${sPDY:0:4}  ${sPDY:4:2}  ${sPDY:6:2}  ${scyc}     0     0        Current model time: year, month, day, hour, minute, second
EOF

  # Link increments
      for i in $(echo $IAUFHRS | sed "s/,/ /g" | rev); do
        incfhr=$(printf %03i $i)
        if [ $incfhr = "006" ] ; then
          increment_file=$memdir/${CDUMP}.t${cyc}z.${PREFIX_ATMINC}atminc.nc
        else
          increment_file=$memdir/${CDUMP}.t${cyc}z.${PREFIX_ATMINC}atmi${incfhr}.nc
        fi
        if [ ! -f $increment_file ] ; then
          echo "ERROR: DOIAU = $DOIAU, but missing increment file for fhr $incfhr at $increment_file"
          echo "Abort!"
          exit 1
        fi
        $NLN $increment_file $DATA/INPUT/fv_increment$i.nc
        IAU_INC_FILES="'fv_increment$i.nc',$IAU_INC_FILES"
      done
      read_increment=.false.
      res_latlon_dynamics=""
    else
      increment_file=$memdir/${CDUMP}.t${cyc}z.atminc.nc
      if [ -f $increment_file ] ; then
        $NLN $increment_file $DATA/INPUT/fv_increment.nc
        read_increment=.true.               # add increment on the fly to the restarts
        res_latlon_dynamics="fv_increment.nc"
      else
        read_increment=.false.
        res_latlon_dynamics=""
      fi
  # Handle coupler.res file for DA cycling
      if [ ${USE_COUPLER_RES:-NO} = YES ] ; then
    # In DA, this is not really a "true restart",
    # and the model start time is the analysis time
    # The alternative is to replace
    # model start time with current model time in coupler.res
        file=$gmemdir/RESTART/${PDY}.${cyc}0000.coupler.res
        file2=$(echo $(basename $file))
        file2=$(echo $file2 | cut -d. -f3-) # remove the date from file
       $NLN $file $DATA/INPUT/$file2
      fi

    fi
#---------------------------------------------------
  else     # RUNCONTINUE = YES
    if [ $FHMIN -gt 0 ] ; then
      export warm_start=.true.
      PDYT=$(echo $CDATE_RST | cut -c1-8)
      cyct=$(echo $CDATE_RST | cut -c9-10)
      for file in $ATM_RESTDIR/${PDYT}.${cyct}0000.* ; do
        file2=$(echo $(basename $file))
        if [ -f $ATM_RESTDIR/$file2 ] ; then
          file3=$(echo $file2 | cut -d. -f3-)
          $NLN $file $DATA/INPUT/$file3
        elif [ -f $ATM_RESTDIR/$file3 ] ; then
          $NLN $ATM_RESTDIR/$file3 $DATA/INPUT/$file3
        fi
      done
    fi
  fi
  export fhouri=0.0
  export fac_n_spl=1

#---------------------------------------------------
else ## cold start

  if [ -s $memdir/INPUT ] ; then
   for file in $memdir/INPUT/*.nc ; do
     file2=$(echo $(basename $file))
     fsuf=$(echo $file2 | cut -c1-3)
     if [ $fsuf = gfs -o $fsuf = sfc ] ; then
       $NLN $file $DATA/INPUT/$file2
     fi
   done
   export na_init=${na_init:-1}
  fi

#---------------------------------------------------
fi
#---------------------------------------------------
nfiles=$(ls -1 $DATA/INPUT/* | wc -l)
if [ $nfiles -le 0 ] ; then
  if [ -d $ICSDIR/${CASE}_$CDATE -a $cpl = .false. ] ; then
     cd $ICSDIR/${CASE}_$CDATE
     $NCP * $DATA/INPUT/.
  fi
  nfiles=$(ls -1 $DATA/INPUT/* | wc -l)

  if [ $nfiles -le 0 ] ; then
    echo "Initial conditions must exist in $DATA/INPUT, ABORT!"
    msg=”"Initial conditions must exist in $DATA/INPUT, ABORT!"
    postmsg "$jlogfile" "$msg"
    exit 1
  fi
fi

# If doing IAU, change forecast hours
if [[ $DOIAU = YES ]] ; then
  FHMAX=$((10#FHMAX+6))
  if [ $FHMAX_HF -gt 0 ] ; then
     FHMAX_HF=$((10#FHMAX_HF+6))
  fi
fi

#------------------------
# Grid and orography data
#------------------------
if [ ${use_lake_oro:-NO} = NO ] ; then
 ORO_DIR=$FIX_FV3
else
 ORO_DIR=${FIX_LAKE_ORO:-$FIX_FV3}
fi

for n in $(seq 1 $ntiles) ; do
 $NCP $FIX_FV3/$CASE/${CASE}_grid.tile${n}.nc     $DATA/INPUT/${CASE}_grid.tile${n}.nc
 $NCP $ORO_DIR/$CASE/${CASE}_oro_data.tile${n}.nc $DATA/INPUT/oro_data.tile${n}.nc
done

# Coupled model uses a different grid_spec that includes MOM6 and FV3
if [ $cplflx = .false. ] ; then
  $NCP $FIX_FV3/$CASE/${CASE}_mosaic.nc  $DATA/INPUT/grid_spec.nc
fi

# GFS standard input data
export IALB=${IALB:-1}
export IEMS=${IEMS:-1}
export ISOL=${ISOL:-2}
export IAER=${IAER:-111}
export ICO2=${ICO2:-2}

O3FORC=${O3FORC:-ozprdlos_2015_new_sbuvO3_tclm15_nuchem.f77}
$NCP $FIX_AM/${O3FORC:-global_o3prdlos.f77}    $DATA/global_o3prdlos.f77
$NCP $FIX_AM/${H2OFORC:-global_h2o_pltc.f77}   $DATA/global_h2oprdlos.f77
$NCP $FIX_AM/global_solarconstant_noaa_an.txt  $DATA/solarconstant_noaa_an.txt
$NCP $FIX_AM/global_sfc_emissivity_idx.txt     $DATA/sfc_emissivity_idx.txt

export iccn=${iccn:-0}

## ccn/in climo
#--------------
if [ $iccn -eq 1 ] ; then
 $NLN $FIX_CCN/cam5_4_143_NAAI_monclimo2.nc  $DATA/cam5_4_143_NAAI_monclimo2.nc
 $NLN $FIX_CCN/cam5_4_143_NPCCN_monclimo2.nc $DATA/cam5_4_143_NPCCN_monclimo2.nc
fi

## merra2 aerosol climo
#----------------------
#export aero_in=${aero_in:-.false.}

export iaer_clm=${iaer_clm:-.false.}
if [ $iaerclm = .true. ] ; then
 export MERRA_AER=${MERRA_AER:-merra2C.aerclim.2003-2014}   # default low resolution
 for n in 01 02 03 04 05 06 07 08 09 10 11 12 ; do
   $NLN $FIX_AER/$MERRA_AER.m${n}.nc  $DATA/aeroclim.m${n}.nc
 done
fi

## ccn/in climo
#--------------
if [ $iccn -gt 1 -a $iaerclm = .true. ] ; then

 $NLN $FIX_LUT/optics_BC.v1_3.dat  $DATA/optics_BC.dat
 $NLN $FIX_LUT/optics_OC.v1_3.dat  $DATA/optics_OC.dat
 $NLN $FIX_LUT/optics_DU.v15_3.dat $DATA/optics_DU.dat
 $NLN $FIX_LUT/optics_SS.v3_3.dat  $DATA/optics_SS.dat
 $NLN $FIX_LUT/optics_SU.v1_3.dat  $DATA/optics_SU.dat
fi

$NCP $FIX_AM/global_co2historicaldata_glob.txt $DATA/co2historicaldata_glob.txt
$NCP $FIX_AM/co2monthlycyc.txt                 $DATA/co2monthlycyc.txt
if [ $ICO2 -gt 0 ] ; then
 for file in $(ls $CO2DIR/global_co2historicaldata*) ; do
   $NCP $file $DATA/$(echo $(basename $file) |sed -e "s/global_//g")
 done
fi

$NCP $FIX_AM/global_climaeropac_global.txt     $DATA/aerosol.dat
if [ $IAER -gt 0 ] ; then
 for file in $(ls $FIX_AM/global_volcanic_aerosols*) ; do
   $NCP $file $DATA/$(echo $(basename $file) |sed -e "s/global_//g")
 done
fi

# inline post fix files
# ---------------------
if [ $WRITE_DOPOST = .true. ] ; then
cat > $DATA/itag << EOF
 &NAMPGB
 $POSTGPVARS
/
EOF
cat itag
  export PostFlatFile00=${PostFlatFile00:-postxconfig-NT-GFS-F00-TWO.txt}
  export PostFlatFile=${PostFlatFile:-postxconfig-NT-GFS-TWO.txt}
# $NLN $PARM_POST/post_tag_gfs${LEVS}             $DATA/itag
# $NLN $PARM_POST/postxconfig-NT-GFS-TWO.txt      $DATA/postxconfig-NT.txt
# $NLN $PARM_POST/postxconfig-NT-GFS-F00-TWO.txt  $DATA/postxconfig-NT_FH00.txt

  $NLN $PARM_POST/$PostFlatFile00                 $DATA/postxconfig-NT_FH00.txt
  $NLN $PARM_POST/$PostFlatFile                   $DATA/postxconfig-NT.txt
  $NLN $PARM_POST/params_grib2_tbl_new            $DATA/params_grib2_tbl_new
# $NLN $LONSPERLAT                                $DATA/lonsperlat.dat
  $NLN $SIGLEVEL                                  $DATA/hyblev_file
fi

######################  mediator ########################################
if [ $mediator = cmeps ] ; then
  CMEPS_DIR=${CMEPS_DIR:-$appdir/CMEPS}
  $NLN $CMEPS_DIR/mediator/fd_nems.yaml fd_nems.yaml
  $NLN $CMEPS_DIR/../parm/pio_in        pio_in
fi

######################  CCPP ########################################
CCPPDIR=${CCPPDIR:-none}
if [ $CCPPDIR != none ] ; then
 $NCP $CCPPDIR/suites/suite_$CCPP_SUITE.xml $DATA/ccpp_suite.xml
fi
######################  WW3 #########################################
#
#           May need to update here to be compatible with GFSv16
#           ----------------------------------------------------
#####################################################################
export cplwav=${cplwav:-${CPLWAV:-.false.}}
if [ $cplwav = .true. ] ; then
 export ww3_grid=${ww3_grid:-'glo_30m'}
 FIX_WW3=${FIX_WW3:-/gpfs/dell2/emc/modeling/noscrub/Shrinivas.Moorthi/WW3_input_data}
 $NCP $FIX_WW3/mod* $DATA/
 mv $DATA/mod_def.points_$ww3_grid $DATA/mod_def.points
 ymd=$(echo $CDATE |cut -c 1-8)
 export ww3_coupling_interval_sec=${ww3_coupling_interval_sec:-$DELTIM}
#$NCP $FIX_WW3/ww3_multi.inp_$ymd $DATA/ww3_multi.inp
 secout=$((FHOUT*3600))
 rsecs=$((restart_interval*3600))
 $NCP $FIX_WW3/ww3_multi.inp_template                  $DATA/ww3_multi.inp0
 sed -e "s/glo_30m/$ww3_grid/g" $DATA/ww3_multi.inp0 > $DATA/ww3_multi.inp1
 sed -e "s/1800/$secout/g"      $DATA/ww3_multi.inp1 > $DATA/ww3_multi.inp2
 sed -e "s/20000000/$ymd/g"     $DATA/ww3_multi.inp2 > $DATA/ww3_multi.inp0
 sed -e "s/RSTSEC/$rsecs/g"     $DATA/ww3_multi.inp0 > $DATA/ww3_multi.inp
 rm $DATA/ww3_multi.inp0        $DATA/ww3_multi.inp1   $DATA/ww3_multi.inp2
fi

# spectral truncation and regular grid resolution based on FV3 resolution
# -----------------------------------------------------------------------
JCAP_CASE=$((2*res-2))
LONB_CASE=$((4*res))
LATB_CASE=$((2*res))

JCAP=${JCAP:-$JCAP_CASE}
LONB=${LONB:-$LONB_CASE}
LATB=${LATB:-$LATB_CASE}

LONB_IMO=${LONB_IMO:-$LONB_CASE}
LATB_JMO=${LATB_JMO:-$LATB_CASE}

# Fix files
FNGLAC=${FNGLAC:-"$FIX_AM/global_glacier.2x2.grb"}
FNMXIC=${FNMXIC:-"$FIX_AM/global_maxice.2x2.grb"}
FNTSFC=${FNTSFC:-"$FIX_AM/RTGSST.1982.2012.monthly.clim.grb"}
FNSNOC=${FNSNOC:-"$FIX_AM/global_snoclim.1.875.grb"}
FNZORC=${FNZORC:-"igbp"}
FNALBC2=${FNALBC2:-"$FIX_AM/global_albedo4.1x1.grb"}
FNAISC=${FNAISC:-"$FIX_AM/CFSR.SEAICE.1982.2012.monthly.clim.grb"}
FNTG3C=${FNTG3C:-"$FIX_AM/global_tg3clim.2.6x1.5.grb"}
FNVEGC=${FNVEGC:-"$FIX_AM/global_vegfrac.0.144.decpercent.grb"}
FNMSKH=${FNMSKH:-"$FIX_AM/global_slmask.t1534.3072.1536.grb"}
FNVMNC=${FNVMNC:-"$FIX_AM/global_shdmin.0.144x0.144.grb"}
FNVMXC=${FNVMXC:-"$FIX_AM/global_shdmax.0.144x0.144.grb"}
FNSLPC=${FNSLPC:-"$FIX_AM/global_slope.1x1.grb"}
FNALBC=${FNALBC:-"$FIX_AM/global_snowfree_albedo.bosu.t$JCAP.$LONB.$LATB.rg.grb"}
FNVETC=${FNVETC:-"$FIX_AM/global_vegtype.igbp.t$JCAP.$LONB.$LATB.rg.grb"}
FNSOTC=${FNSOTC:-"$FIX_AM/global_soiltype.statsgo.t$JCAP.$LONB.$LATB.rg.grb"}
FNABSC=${FNABSC:-"$FIX_AM/global_mxsnoalb.uariz.t$JCAP.$LONB.$LATB.rg.grb"}
FNSMCC=${FNSMCC:-"$FIX_AM/global_soilmgldas.statsgo.t$JCAP.$LONB.$LATB.grb"}

# If the appropriate resolution fix file is not present, use the highest resolution available (T1534)
[[ ! -f $FNALBC ]] && FNALBC="$FIX_AM/global_snowfree_albedo.bosu.t1534.3072.1536.rg.grb"
[[ ! -f $FNVETC ]] && FNVETC="$FIX_AM/global_vegtype.igbp.t1534.3072.1536.rg.grb"
[[ ! -f $FNSOTC ]] && FNSOTC="$FIX_AM/global_soiltype.statsgo.t1534.3072.1536.rg.grb"
[[ ! -f $FNABSC ]] && FNABSC="$FIX_AM/global_mxsnoalb.uariz.t1534.3072.1536.rg.grb"
[[ ! -f $FNSMCC ]] && FNSMCC="$FIX_AM/global_soilmgldas.statsgo.t1534.3072.1536.grb"


# NSST Options
# nstf_name contains the NSST related parameters
# nstf_name(1) : 0 = NSSTM off, 1 = NSSTM on but uncoupled, 2 = NSSTM on and coupled
# nstf_name(2) : 0 = NSSTM spin up off, 1 = NSSTM spin up on,
# nstf_name(3) : 0 = NSSTM analysis off, 1 = NSST analysis on
# nstf_name(4) : zsea1 in mm
# nstf_name(5) : zsea2 in mm
# nst_anl      : .true. or .false., NSST analysis over lake

NST_MODEL=${NST_MODEL:-0}
NST_SPINUP=${NST_SPINUP:-0}
NST_RESV=${NST_RESV-0}
ZSEA1=${ZSEA1:-0}
ZSEA2=${ZSEA2:-0}
nstf_name=${nstf_name:-"$NST_MODEL,$NST_SPINUP,$NST_RESV,$ZSEA1,$ZSEA2"}
nst_anl=${nst_anl:-.false.}

#
# export the pre-conditioning of the solution (na_init)
# =0 implies no pre-conditioning
# >0 means new adiabatic pre-conditioning
# <0 means older adiabatic pre-conditioning

cd $DATA

#------------------------------------------------------------------
#------------------------------------------------------------------
# changeable parameters
# dycore definitions
#res=$(echo $CASE |cut -c 2-5)
 resp=$((res+1))
 export npx=$resp
 export npy=$resp
 export npz=$((LEVS-1))
 export LEVR=${LEVR:-$npz}

 export layout_x=${layout_x:-8}  
 export layout_y=${layout_y:-16}  
 export io_layout_x=${io_layout_x:-$((layout_x/4))}
 export io_layout_y=${io_layout_y:-$((layout_y/4))}
 export nthreads=${nthreads:-4}
 export ncols=$(((npx-1)*(npy-1)*3/2))

# blocking factor used for threading and general physics performance
#   export nxblocks=3; export nyblocks=48
#   export nyblocks=$(((npy-1)/layout_y))
#   export nxblocks=$(((npx-1)/layout_x/32))
#   if [ $nxblocks -le 0 ] ; then export nxblocks=1 ; fi
 export nxblocks=1 ; export nyblocks=1

# run length
 export months=${months:-0}
 export days=${days:-$((FHMAX/24))}
 export hours=${hours:-$((FHMAX-24*(FHMAX/24)))}

# variables for controlling initialization of NCEP/NGGPS ICs
 export filtered_terrain=${filtered_terrain:-.true.}
#export ncep_plevels=${ncep_plevels:-.true.}
 export gfs_dwinds=${gfs_dwinds:-.true.}

# setup fdiag if not setup already
 fd1=$(echo $fdiag | cut -d, -f 1,1)
 if [ $fd1 = none ] ; then
   export NFCST=${NFCST:-$((FHMAX/FHOUT+1))} ;#number of forecatsts included in netCDF file
#  fdiag=$( for (( num=2; num<=$NFCST; num++ )); do printf "%d," $(((num-1)*FHOUT)); done )
   fh00=${fh00:-0}
#  fdiag=${fh00},$fdiag
   if [ $fh00 -ge 0 ] ; then
    fdiag=${fh00}
   else
    fdiag=xxx
   fi
   num=2
   while [ $num -le $NFCST ] ; do
    xx=$(((num-1)*FHOUT))
    if [ $fdiag = xxx ] ; then
     fdiag=${xx}.
    else
     fdiag=${fdiag},${xx}.
    fi
    num=$((num+1))
   done
 elif [ $fd1 -eq $FHOUT ] ; then
   fdiag=$((FHMIN+FHOUT))
 fi
 export fhzer=${FHZER:-6.0}
 export fhcyc=${FHCYC:-0.0}

# determines whether FV3 or GFS physics calculate geopotential
 export gfs_phil=${gfs_phil:-.false.}

# determine whether ozone production occurs in GFS physics
 export ozcalc=${ozcalc:-.true.}

# export various debug options
 export no_dycore=${no_dycore:-.false.}
 export dycore_only=${adiabatic:-${dycore_only:-.false.}}
 export print_freq=${print_freq:-6}

 if [ $TYPE = nh ] ; then              # non-hydrostatic options
   export make_nh=${make_nh:-.true.}
   export hydrostatic=.false.
   export phys_hydrostatic=.false.     # can be tested
   export use_hydro_pressure=.false.   # can be tested
   export consv_te="1.0"
   export MONO=non-mono
 else                                  # hydrostatic options
   export make_nh=${make_nh:-.false.}
   export hydrostatic=.true.
   export phys_hydrostatic=.false.     # will be ignored in hydro mode
   export use_hydro_pressure=.true.    # have to be .T. in hydro mode
   export consv_te="0."
   export MONO=${MONO:-mono}
 fi
                                       # time step parameters in FV3
 export k_split=${k_split:-2}
 export n_split=${n_split:-6}

 if [ $MONO = mono -o  $MONO = monotonic ] ;  then # monotonic options
   export d_con=0.0
   export do_vort_damp=.false.
   export vtdm4=0.0
   export hord_mt=10
   export hord_vt=10
   export hord_tm=10
   export hord_dp=-10
 else                                              # non-monotonic options
   export d_con=1.0
   export do_vort_damp=.true.
   if [ $TYPE == nh ] ; then                       # non-hydrostatic
     export hord_mt=${hord_mt:-5}
     export hord_vt=${hord_vt:-5}
     export hord_tm=${hord_tm:-5}
     export hord_dp=${hord_dp:--5}
     export vtdm4=${vtdm4:-0.06}
   else                                            # hydrostatic
     export hord_mt=10
     export hord_vt=10
     export hord_tm=10
     export hord_dp=-10
     export vtdm4=0.05
   fi
 fi

 export fv_core_nml=${fv_core_nml:-""}
#   if [ $vtdm4 -lt 0.02 ] ; then export d_con=0.0 ; fi

#   clock_grain=${clock_grain:-ROUTINE}
#   clock_grain=${clock_grain:-LOOP}

# Stochastic Physics Options
if [ ${SET_STP_SEED:-YES} = YES ] ; then
  ISEED_SKEB=$((CDATE*1000 + MEMBER*10 + 1))
  ISEED_SHUM=$((CDATE*1000 + MEMBER*10 + 2))
  ISEED_SPPT=$((CDATE*1000 + MEMBER*10 + 3))
else
  ISEED=${ISEED:-0}
fi
DO_SKEB=${DO_SKEB:-NO}
DO_SPPT=${DO_SPPT:-NO}
DO_SHUM=${DO_SHUM:-NO}
JCAP_STP=${JCAP_STP:-$JCAP_CASE}
LONB_STP=${LONB_STP:-$LONB_CASE}
LATB_STP=${LATB_STP:-$LATB_CASE}

if [ $DO_SKEB = YES ] ; then do_skeb=.true. ; fi
if [ $DO_SHUM = YES ] ; then do_shum=.true. ; fi
if [ $DO_SPPT = YES ] ; then do_sppt=.true. ; fi

# build the date for curr_date and diag_table from NAME
#SYEAR=$(echo  $CDATE | cut -c1-4)
#SMONTH=$(echo $CDATE | cut -c5-6)
#SDAY=$(echo   $CDATE | cut -c7-8)
#SHOUR=$cyc
#SHOUR=$(echo  $CDATE | cut -c9-10)
#curr_date="${SYEAR},${SMONTH},${SDAY},${SHOUR},0,0"

rsecs=$((restart_interval*3600))
restart_secs=${rsecs:-0}
ymd=$(echo $CDATE |cut -c 1-8)
NAME="NEMSFV3 Run - ${ymd}.${h}Z"

# build the diag_table with the experiment name and date stamp
#------------------------------------------------------------
if [ $DOIAU = YES ] ; then
  SYEAR=${gPDY:0:4} ; SMONTH=${gPDY:4:2} ; SDAY=${gPDY:6:2} ; SHOUR=${gcyc}
else
  SYEAR=${sPDY:0:4} ; SMONTH=${sPDY:4:2} ; SDAY=${sPDY:6:2} ; SHOUR=${scyc}
fi

cat > diag_table << EOF
FV3 Forecast
$SYEAR $SMONTH $SDAY $SHOUR 0 0
EOF

if [ $cpl = .true. ] ; then
 diag_table_cpld=${diag_table_cpld:-diag_table_cpl}
 cat $PARM_DIR/$diag_table_cpld                      >> diag_table
fi
cat $PARM_DIR/diag_table${FVER_diag:-""}${FVRS:-""} >> diag_table
if [ $REMAP_GRID = gaussian ] ; then
 cat $PARM_DIR/diag_table_fv3_2dvars                >> diag_table
fi

# copy over the other tables and executable
$NCP $PARM_DIR/data_table                        data_table
$NCP $PARM_DIR/field_table${FVER:-""}${FVRS:-''} field_table
export ntrac=$(grep TRACER field_table | wc -l)
ncom=$(grep '#' field_table | grep TRACER | wc -l)
export ntrac=$((ntrac-ncom))

# Some microphysics related parameters
export ncld=${ncld:-1}
export nwat=$((ncld+1))
export fprcp=${fprcp:-0}   # for MG with prognostic rain and snow
if [ $ncld -eq 2 ] ; then
 if [ $imp_physics -eq 6 -o $imp_physics -eq 8 ] ; then
  export nwat=$((nwat+3))
 elif [ $imp_physics -eq 10 ] ; then
  if [ $fprcp -gt 0 -o $fprcp -lt 0 ] ; then
   export nwat=$((nwat+2))
  fi
  if [ $fprcp -eq 2 ] ; then
   export mg_do_graupel=${mg_do_graupel:-.false.}
   export mg_do_hail=${mg_do_hail:-.false.}
   if [ $mg_do_graupel = .true. -o $mg_do_hail = .true. ] ; then
     export nwat=$((nwat+1))
   fi
  fi
 fi
fi
if [ $ncld -eq 5 -a $imp_physics -eq 11 ] ; then    # for GFDL Microphysics
 do_sat_adj=${do_sat_adj:-.true.}
fi


# coupled has the nems.configure generated by prep script
# Here generate one for the uncoupled application

if [ $cpl = .false. ] ; then
#set nems configure file
  rm -f nems.configure
  cat > nems.configure << EOF
 EARTH_component_list: ATM
 ATM_model:            ${ATM_model:-fv3}
 runSeq::
   ATM
 ::
EOF

elif [ $cplwav = .true. -a ! -f nems.configure ] ; then

###############################################################
# create nems.configure for atm-wave coupled model

  cat << EOF > nems.configure
# EARTH #
  EARTH_component_list: ATM WAV
  EARTH_attributes::
  Verbosity = 0
::

# ATM #
  ATM_model:                      ${ATM_model:-fv3}
  ATM_petlist_bounds:             $ATM_petlist_bounds
  ATM_attributes::
  Verbosity = 0
  DumpFields = false
::

# WAV #
  WAV_model:                      ${WAV_model:-ww3}
  WAV_petlist_bounds:             $WAV_petlist_bounds
  WAV_attributes::
  Verbosity = 0
::

# Run Sequence #
runSeq::
  @$ww3_coupling_interval_sec
    ATM -> WAV
    ATM -> WAV :SrcTermProcessing=0:TermOrder=SrcSeq
    WAV
    ATM
  @
::
EOF

###############################################################

fi

rm -f model_configure
cat > model_configure << EOF
print_esmf:                 ${print_esmf:-.false.}
total_member:               $ENS_NUM
PE_MEMBER01:                $tasks
start_year:                 ${tPDY:0:4}
start_month:                ${tPDY:4:2}
start_day:                  ${tPDY:6:2}
start_hour:                 $tcyc
start_minute:               0
start_second:               0
nhours_fcst:                $FHMAX
RUN_CONTINUE:               ${RUN_CONTINUE:-.false.}
ENS_SPS:                    ${ENS_SPS:-.false.}

dt_atmos:                   $DELTIM
calendar:                   ${calendar:-julian}
cpl:                        ${cpl:-${CPL:-.false.}}
memuse_verbose:             ${memuse_verbose:-.false.}
atmos_nthreads:             $nthreads
use_hyper_thread:           ${hyperthread:-.false.}
ncores_per_node:            ${cores_per_node:-28}
restart_interval:           ${restart_interval_atm:-0}
atm_coupling_interval_sec:  ${CPL_FAST:-$DELTIM}

quilting:                   ${QUILTING:-.true.}
write_groups:               ${WRITE_GROUP:-1}
write_tasks_per_group:      ${WRTTASK_PER_GROUP:-28}
output_history:             ${OUTPUT_HISTORY:-.true.}
write_dopost:               ${WRITE_DOPOST:-.false.}
num_files:                  ${NUM_FILES:-2}
filename_base:              ${FILENAME_BASE:-'atm sfc'}
output_grid:                ${OUTPUT_GRID:-cubed_sphere_grid}
output_file:                ${OUTPUT_FILE:-netcdf}
write_nemsioflip:           ${WRITE_NEMSIOFLIP:-.true.}
write_fsyncflag:            $WRITE_FSYNCFLAG
imo:                        ${imo:-${LONB_IMO:-384}}
jmo:                        ${jmo:-${LATB_JMO:-190}}
nsoil:                      ${lsoil:-${LSOIL:-4}}
ncld:                       ${ncld:-1}
ntrac:                      ${ntrac:-3}

nfhout:                     $FHOUT
nfhmax_hf:                  $FHMAX_HF
nfhout_hf:                  $FHOUT_HF
nsout:                      ${nsout:-${NSOUT:-0}}
fhrot:                      ${fhrot:-${FHROT:-0}}
iau_offset:                 ${IAU_OFFSET:-0}

output_1st_tstep_rst:       ${output_1st_tstep_rst:-.false.}

EOF
if [ $OUTPUT_FILE = netcdf ] ; then
cat >> model_configure << EOF
 ichunk2d:                ${ichunk2d:-0}
 jchunk2d:                ${jchunk2d:-0}
 ichunk3d:                ${ichunk3d:-0}
 jchunk3d:                ${jchunk3d:-0}
 kchunk3d:                ${kchunk3d:-0}
 ideflate:                ${ideflate:-1}
 nbits:                   ${nbits:-14}
EOF
fi

#&coupler_nml
#      months   = $months
#      days     = $days
#      hours    = $hours
#      dt_atmos = $DELTIM
#      dt_ocean = $DELTIM
#      current_date =  $curr_date
#      calendar     = 'julian'
#      memuse_verbose   = .false.
#      atmos_nthreads   = $nthreads
#      use_hyper_thread = $hyperthread
#      ncores_per_node  = $cores_per_node
#/
#
#&nggps_diag_nml
#      fdiag   = $fdiag
#      fhmax   = $FHMAX
#      fhmaxhf = $FHMAX_HF
#      fhout   = $FHOUT
#      fhouthf = $FHOUT_HF
#
#
#
#    fhouthf      = $FHOUT_HF
#    fhmaxhf      = $FHMAX_HF
#    fhout        = $FHOUT

cat > input.nml << EOF
 &amip_interp_nml
     interp_oi_sst = .true.
     use_ncep_sst  = .true.
     use_ncep_ice  = .false.
     no_anom_sst   = .false.
     data_set      = 'reynolds_oi',
     date_out_of_range = 'climo',
     $amip_interp_nml
/

 &atmos_model_nml
     blocksize    = ${blocksize:-32}
     chksum_debug = ${chksum_debug:-.false.}
     dycore_only  = ${dycore_only:-.false.}
     fdiag        = $fdiag
     fhmax        = $FHMAX
     fhout        = $FHOUT
     fhmaxhf      = $FHMAX_HF
     fhouthf      = $FHOUT_HF
     $atmos_model_nml
/

 &diag_manager_nml
     max_output_fields = ${max_output_fields:-400}
     prepend_date = ${prepend_date:-.true.}
     $diag_manager_nml
/

 &fms_io_nml
     checksum_required = .false.
     max_files_r = 100,
     max_files_w = 100,
     $fms_io_nml
/

 &fms_nml
     clock_grain = 'ROUTINE',
     domains_stack_size = ${domains_stack_size:-3072000},
     print_memory_usage = ${print_memory_usage:-.false.}
     $fms_nml
/

 &fv_core_nml
       layout      = $layout_x,$layout_y
       io_layout   = $io_layout_x,$io_layout_y
       npx         = $npx
       npy         = $npy
       ntiles      = $ntiles
       npz         = $npz
       grid_type   = -1
       make_nh     = $make_nh
       fv_debug    = ${fv_debug:-.false.}
       range_warn  = ${range_warn:-.false.}
       reset_eta   = ${reset_eta:-.false.}
       n_sponge    = ${n_sponge:-$(((npz+1)/6))}
       nudge_qv    = ${nudge_qv:-.true.}
       nudge_dz    = ${nudge_dz:-.false.}
       tau         = ${tau:-10.0}
       rf_cutoff   = ${rf_cutoff:-7.5e2}
       d2_bg_k1    = ${d2_bg_k1:-0.16}
       d2_bg_k2    = ${d2_bg_k2:-0.02}
       kord_tm     = ${kord_tm:--9}
       kord_mt     = ${kord_mt:-9}
       kord_wz     = ${kord_wz:-9}
       kord_tr     = ${kord_tr:-9}
       hydrostatic = ${hydrostatic:-.false.}
       phys_hydrostatic   = ${phys_hydrostatic:-.false.}
       use_hydro_pressure = ${use_hydro_pressure:-.false.}
       beta      = ${beta:-0.0}
       a_imp     = ${a_imp:-1.0}
       p_fac     = ${p_fac:-0.1}
       k_split   = ${k_split:-1}
       n_split   = ${n_split:-6}
       nwat      = ${nwat:-2}
       na_init   = ${na_init:-1}
       d_ext     = ${d_ext:-0.0}
       dnats     = ${dnats:-0}
       fv_sg_adj = ${fv_sg_adj:-450}
       d2_bg     = ${d2_bg:-0.0}
       nord      = ${nord:-2}
       nord_tr   = ${nord_tr:-$nord}
       dddmp     = ${dddmp:-0.2}
       d4_bg     = ${d4_bg:-0.15}
       vtdm4     = ${vtdm4:-0.05}
       trdm2     = ${trdm2:-0.0}
       delt_max  = ${delt_max:-0.002}
       ke_bg     = 0.
       do_vort_damp        = ${do_vort_damp:-.true.}
       external_ic         = ${external_ic:-.true.}
       external_eta        = ${external_eta:-.true.}
       gfs_phil            = ${gfs_phil:-.false.}
       nggps_ic            = ${nggps_ic:-.true.}
       mountain            = ${mountain:-.false.}
       ncep_ic             = ${ncep_ic:-.false.}
       d_con               = ${d_con:-1.0}
       hord_mt             = ${hord_mt:-5}
       hord_vt             = ${hord_vt:-5}
       hord_tm             = ${hord_tm:-5}
       hord_dp             = ${hord_dp:--5}
       hord_tr             = ${hord_tr:--8}
       adjust_dry_mass     = ${adjust_dry_mass:-.false.}
       dry_mass            = ${dry_mass:-98320.0}
       consv_te            = ${consv_te:-0.0}
       consv_am            = ${consv_am:-.false.}
       do_sat_adj          = ${do_sat_adj:-.false.}
       fill                = ${fill:-.true.}
       dwind_2d            = ${dwind_2d:-.false.}
       print_freq          = ${print_freq:-6}
       warm_start          = ${warm_start:-.false.}

       no_dycore           = ${no_dycore:-.false.}
       z_tracer            = .true.

       agrid_vel_rst       = ${agrid_vel_rst:-.true.}
       read_increment      = ${read_increment:-.false.}
       res_latlon_dynamics = ${res_latlon_dynamics:-'""'}

       fhouri              = ${fhouri:-0.0}
       fac_n_spl           = ${fac_n_spl:-1.0}
       $fv_core_nml
/

 &external_ic_nml 
       filtered_terrain = ${filtered_terrain:-.true.}
       levp             = $LEVS
       gfs_dwinds       = $gfs_dwinds
       checker_tr       = ${checker_tr:-.false.}
       nt_checker       = 0
       $external_ic_nml
/

 &gfs_physics_nml
       fhzero         = ${fhzero:-${fhzer:-6.}}
       ldiag3d        = ${ldiag3d:-.false.}
       ldiag_ugwp     = ${ldiag_ugwp:-.false.}
       do_ugwp        = ${do_ugwp:-.true.}
       do_tofd        = ${do_tofd:-.true.}
       fhcyc          = ${fhcyc:-24.}
       use_ufo        = ${use_ufo:-.true.}
       pre_rad        = ${pre_rad:-.false.}
       crtrh          = ${crtrh:-"0.90,0.90,0.90"}
       ncld           = ${ncld:-1}
       imp_physics    = ${imp_physics:-99}
       levr           = ${levr:-${LEVR:-$npz}}
       fhswr          = ${fhswr:-3600.}
       fhlwr          = ${fhlwr:-3600.}
       ialb           = ${IALB:-1}
       iems           = ${iems:-1}
       iaer           = ${iaer:-${IAER:-111}}
       iaerclm        = ${iaerclm:-.false.}
       icliq_sw       = ${icliq_sw:-2}
       iovr_lw        = ${iovr_lw:-3}
       iovr_sw        = ${iovr_sw:-3}
       ico2           = ${ico2:-2}
       isubc_sw       = ${isubc_sw:-2}
       isubc_lw       = ${isubc_lw:-2}
       isol           = ${isol:-2}
       lwhtr          = ${lwhtr:-.true.}
       swhtr          = ${swhtr:-.true.}
       cnvgwd         = ${cnvgwd:-.true.}
       shal_cnv       = ${shal_cnv:-.true.}
       cal_pre        = ${cal_pre:-.true.}
       redrag         = ${redrag:-.true.}
       dspheat        = ${dspheat:-.true.}
       hybedmf        = ${hybedmf:-.false.}
       satmedmf       = ${satmedmf:-.true.}
       isatmedmf      = ${isatmedmf:-1}
       random_clds    = ${random_clds:-.true.}
       trans_trac     = ${trans_trac:-.true.}
       cnvcld         = ${cnvcld:-.true.}
       imfshalcnv     = ${imfshalcnv:-2}
       imfdeepcnv     = ${imfdeepcnv:-2}
       cdmbgwd        = ${cdmbgwd:-3.5, 0.25}
       sup            = ${sup:-1.0}
       prslrd0        = ${prslrd0:-0.0}
       ral_ts         = ${ral_ts:-0.0}
       ivegsrc        = ${ivegsrc:-1}
       isot           = ${isot:-1}
       lsoil          = ${lsoil:-${LSOIL:-4}}
       lsm            = ${lsm:-${LSM:-1}}
       debug          = ${debug:-.false.}

       ras            = ${ras:-.false.}
       cscnv          = ${cscnv:-.false.}
       do_shoc        = ${do_shoc:-.false.}
       shoc_parm      = ${shoc_parm:-7000.0,1.0,4.2857143,0.7,-999.0}
       do_aw          = ${do_aw:-.false.}
       shoc_cld       = ${shoc_cld:-.false.}
       h2o_phys       = ${h2o_phys:-.false.}
       shcnvcw        = ${shcnvcw:-.false.}
       xkzm_h         = ${xkzm_h:-1.0}
       xkzm_m         = ${xkzm_m:-1.0}
       xkzm_s         = ${xkzm_s:-1.0}
       nstf_name      = ${nstf_name:-"0, 0, 1, 0, 5"}
       nst_anl        = ${nst_anl:-${NST_ANL:-.false.}}
       psautco        = ${psautco:-"6.0d-4,3.0d-4"}
       prautco        = ${prautco:-"6.0d-4,3.0d-4"}
       wminco         = ${wminco:-"1.0d-5,1.0d-6"}
       psauras        = ${psauras:-"1.0d-3,1.0d-3"}
       prauras        = ${prauras:-"1.0d-3,2.0d-3"}
       wminras        = ${wminras:-"1.0d-5,1.0d-5"}
       evpco          = ${evpco:-2.0d-5}
       pdfcld         = ${pdfcld:-.false.}
       ccwf           = ${ccwf:-"1.0, 1.0"}
       dlqf           = ${dlqf:-"0.25, 0.05"}
       mg_dcs         = ${mg_dcs:-100.0}
       mg_ts_auto_ice = ${mg_ts_auto_ice:-"180.0,180.0"}
       mg_qcvar       = ${mg_qcvar:-1.0}
       mg_qcmin       = ${mg_qcmin:-"1.0e-8,1.0e-7"}
       mg_alf         = ${mg_alf:-1.0}
       fprcp          = ${fprcp:-0}
       pdfflag        = ${pdfflag:-4}
       iccn           = ${iccn:-0}
       mg_do_graupel  = ${mg_do_graupel:-.false.}
       mg_do_hail     = ${mg_do_hail:-.false.}
       do_sb_physics  = ${do_sb_physics:-.true.}
       mg_do_ice_gmao = ${mg_do_ice_gmao:-.true.}
       mg_do_liq_liu  = ${mg_do_liq_liu:-.true.}
       cs_parm        = ${cs_parm:-"8.0,4.0,1.0e3,3.5e3,20.0,1.0,-999.,1.,0.,0."}
       ctei_rm        = ${ctei_rm:-"10.0,10.0"}
       max_lon        = ${max_lon:-8000}
       max_lat        = ${max_lat:-4000}
       rhcmax         = ${rhcmax:-0.9999999}
       effr_in        = ${effr_in:-.true.}
       ccnorm         = ${ccnorm:-.true.}

       ltaerosol      = ${ltaerosol:-.false.}
       lradar         = ${lradar:-.false.}

       cplflx         = ${cplflx:-${CPLFLX:-.false.}}
       cplwav         = ${cplwav:-${CPLWAV:-.false.}}
       cplwav2atm     = ${cplwav2atm:-${CPLWAV2ATM:-.false.}}
       cplchm         = ${cplchm:-${CPLCHM:-.false.}}

       iau_delthrs    = ${iau_delthrs:-6}
       iaufhrs        = ${iaufhrs:-30}
       iau_inc_files  = ${iau_inc_files:-''}
       lheatstrg      = ${lheatstrg:-.true.}
       lgfdlmprad     = ${lgfdlmprad:-.true.}

       nca            = ${nca:-1}
       ncells         = ${ncells:-5}
       nfracseed      = ${nfracseed:-0.5}
       nlives         = ${nlives:-30}
       nthresh        = ${nthresh:-0.5}
       nseed          = ${nseed:-100000}
       do_ca          = ${do_ca:-.false.}
       ca_global      = ${ca_global:-.false.}
       ca_sgs         = ${ca_sgs:-.true.}
       ca_smooth      = ${ca_smooth:-.false.}
       nspinup        = ${nspinup:-1000}
       iseed_ca       = ${iseed_ca:-0}

       min_seaice     = ${min_seaice:-1.0e-6}
       min_lakeice    = ${min_lakeice:-0.15}
       frac_grid      = ${frac_grid:-.false.}
       ignore_lake    = ${ignore_lake:-.false.}
       sfc_z0_type    = ${sfc_z0_type:-0}

       do_sppt        = ${do_sppt:-.false.}
       do_shum        = ${do_shum:-.false.}
       do_skeb        = ${do_skeb:-.false.}

EOF
#      isppt_deep     = ${isppt_deep:-.false.}
if [ ${lsm:-${LSM:-1}} -eq 2 ] ; then

# add noahMP related namelist variables
  cat >> input.nml << EOF
       iopt_dveg      = ${opt_dveg:-1}  # 4 -> off (use table lai; use maximum vegetation fraction)
       iopt_crs       = ${opt_btr:- 1}  #canopy stomatal resistance (1-> ball-berry; 2->jarvis)
       iopt_btr       = ${iopt_btr:-1}  #soil moisture factor for stomatal resistance (1-> noah; 2-> clm; 3-> ssib)
       iopt_run       = ${iopt_run:-1}  #runoff and groundwater (1->simgm; 2->simtop; 3->schaake96; 4->bats)
       iopt_sfc       = ${iopt_frz:-1}  #surface layer drag coeff (ch & cm) (1->m-o; 2->chen97)
       iopt_frz       = ${iopt_inf:-1}  #supercooled liquid water (1-> ny06; 2->koren99)
       iopt_inf       = ${iopt_rad:-1}  #frozen soil permeability (1-> ny06; 2->koren99)
       iopt_rad       = ${iopt_alb:-1}  #radiation transfer (1->gap=f(3d,cosz); 2->gap=0; 3->gap=1-fveg)
       iopt_alb       = ${iopt_alb:-2}  #snow surface albedo (1->bats; 2->class)
       iopt_snf       = ${iopt_snf:-4}  #rainfall & snowfall (1-jordan91; 2->bats; 3->noah)
       iopt_tbot      = ${iopt_tbot:-2} #lower boundary of soil temperature (1->zero-flux; 2->noah)
       iopt_stc       = ${iopt_stc:-1}  #snow/soil temperature time scheme (only layer 1)
EOF
fi
if [ $CCPPDIR != none ] ; then
  cat >> input.nml << EOF
       oz_phys      = ${oz_phys:-.false.}
       oz_phys_2015 = ${oz_phys_2015:-.true.}
EOF
fi
# Add namelist for IAU
if [ $DOIAU = YES ] ; then
  cat >> input.nml << EOF
       iaufhrs        = ${IAUFHRS:-0}
       iau_delthrs    = ${IAU_DELTHRS:-0}
       iau_inc_files  = ${IAU_INC_FILES:-""}
EOF
fi
cat >> input.nml << EOF
       $gfs_physics_nml
/

 &gfdl_cloud_microphysics_nml
       sedi_transport = ${sedi_transport:-.true.}
       do_sedi_heat   = ${do_sedi_heat:-.false.}
       rad_snow       = ${rad_snow:-.true.}
       rad_graupel    = ${rad_graupel:-.true.}
       rad_rain       = ${rad_rain:-.true.}
       const_vi       = ${const_vi:-.false.}
       const_vs       = ${const_vs:-.false.}
       const_vg       = ${const_vg:-.false.}
       const_vr       = ${const_vr:-.false.}
       vi_max         = ${vi_max:-1.}
       vs_max         = ${vs_max:-2.}
       vg_max         = ${vg_max:-12.}
       vr_max         = ${vr_max:-12.}
       qi_lim         = ${qi_lim:-1.}
       prog_ccn       = ${prog_ccn:-.false.}
       do_qa          = ${do_qa:-.true.}
       fast_sat_adj   = ${fast_sat_adj:-.true.}
       tau_i2s        = ${tau_i2s:-1000.0}
       tau_l2r        = ${tau_l2r:-900.0}
       tau_l2v        = ${tau_l2v:-225}
       tau_v2l        = ${tau_v2l:-150.}
       tau_g2v        = ${tau_g2v:-900.}
       rthresh        = ${rthresh:-10.e-6}  ! This is a key parameter for cloud water
       dw_land        = ${dw_land:-0.16}
       dw_ocean       = ${dw_ocean:-0.10}
       ql_gen         = ${ql_gen:-1.0e-3}
       ql_mlt         = ${ql_mlt:-1.0e-3}
       qi0_crt        = ${qi0_crt:-8.0E-5}
       qs0_crt        = ${qs0_crt:-1.0e-3}
       c_psaci        = ${c_psaci:-0.05}
       c_pgacs        = ${c_pgacs:-0.01}
       rh_inc         = ${rh_inc:-0.30}
       rh_inr         = ${rh_inr:-0.30}
       rh_ins         = ${rh_ins:-0.30}
       ccn_l          = ${ccn_l:-300.}
       ccn_o          = ${ccn_o:-100.}
       c_paut         = ${c_paut:-0.5}
       c_cracw        = ${c_cracw:-0.8}
       use_ppm        = ${use_ppm:-.false.}
       use_ccn        = ${use_ccn:-.true.}
       mono_prof      = ${mono_prof:-.true.}
       z_slope_liq    = ${z_slope_liq:-.true.}
       z_slope_ice    = ${z_slope_ice:-.true.}
       de_ice         = ${de_ice:-.false.}
       fix_negative   = ${fix_negative:-.true.}
       icloud_f       = ${icloud_f:-1}
       mp_time        = ${mp_time:-150.}
       reiflag        = ${reiflag:-2}
       $gfdl_cloud_microphysics_nml
/

&cires_ugwp_nml
       knob_ugwp_solver  = ${knob_ugwp_solver:-2}
       knob_ugwp_source  = ${knob_ugwp_source:-1,1,0,0}
       knob_ugwp_wvspec  = ${knob_ugwp_wvspec:-1,25,25,25}
       knob_ugwp_azdir   = ${knob_ugwp_azdir:-2,4,4,4}
       knob_ugwp_stoch   = ${knob_ugwp_stoch:-0,0,0,0}
       knob_ugwp_effac   = ${knob_ugwp_effac:-1,1,1,1}
       knob_ugwp_doaxyz  = ${knob_ugwp_doaxyz:-1}
       knob_ugwp_doheat  = ${knob_ugwp_doheat:-1}
       knob_ugwp_dokdis  = ${knob_ugwp_dokdis:-1}
       knob_ugwp_ndx4lh  = ${knob_ugwp_ndx4lh:-1}
       knob_ugwp_version = ${knob_ugwp_version:-0}
       launch_level      = ${launch_level:-54}
/

  &interpolator_nml
       interp_method = 'conserve_great_circle'
       $interpolator_nml
/

&namsfc
       FNGLAC  = "$FNGLAC"
       FNMXIC  = "$FNMXIC"
       FNTSFC  = "$FNTSFC"
       FNSNOC  = "$FNSNOC"
       FNZORC  = "$FNZORC"
       FNALBC  = "$FNALBC"
       FNALBC2 = "$FNALBC2"
       FNAISC  = "$FNAISC"
       FNTG3C  = "$FNTG3C"
       FNVEGC  = "$FNVEGC"
       FNVETC  = "$FNVETC"
       FNSOTC  = "$FNSOTC"
       FNSMCC  = "$FNSMCC"
       FNMSKH  = "$FNMSKH"
       FNTSFA  = "$FNTSFA"
       FNACNA  = "$FNACNA"
       FNSNOA  = "$FNSNOA"
       FNVMNC  = "$FNVMNC"
       FNVMXC  = "$FNVMXC"
       FNSLPC  = "$FNSLPC"
       FNABSC  = "$FNABSC"
       LDEBUG  =.false.
       FSMCL(2) = 99999
       FSMCL(3) = 99999
       FSMCL(4) = 99999
       FTSFS = 90
       FAISS = 99999
       FSNOL = 99999
       FSICL = 99999
       FTSFL = 99999
       FAISL = 99999
       FVETL = 99999
       FSOTL = 99999
       FvmnL = 99999
       FvmxL = 99999
       FSLPL = 99999
       FABSL = 99999
       FSNOS=99999
       FSICS=99999
       $namsfc_nml
/

&fv_grid_nml
       grid_file = 'INPUT/grid_spec.nc'
       $fv_grid_nml
/

EOF
if [ ${compress_restart:-NO} = YES ] ; then
 cat >> input.nml << EOF
&mpp_io_nml
 shuffle=${shuffle:-1}
 deflate_level=${deflate_level:-1}
/
EOF
fi
#      ncep_plevels = ${ncep_plevels:-.false.}
#      ncep_plevels = $ncep_plevels


# Add namelist for stochastic physics options
echo "" >> input.nml
if [ $MEMBER -gt 0 ] ; then

    cat >> input.nml << EOF
&nam_stochy
  ntrunc = $JCAP_STP
  lon_s  = $LONB_STP
  lat_s  = $LATB_STP
EOF

  if [ ${DO_SKEB:-NO} = YES ] ; then
    cat >> input.nml << EOF
  skeb = $SKEB
  iseed_skeb  = ${ISEED_SKEB:-$ISEED}
  skeb_tau    = ${SKEB_TAU:-"-999."}
  skeb_lscale = ${SKEB_LSCALE:-"-999."}
  skebnorm    = ${SKEBNORM:-1}
  skeb_npass  = ${SKEB_nPASS:-30}
  skeb_vdof   = ${SKEB_VDOF:-5}
EOF
  fi

  if [ ${DO_SHUM:-NO} = YES ] ; then
    cat >> input.nml << EOF
  shum = $SHUM
  iseed_shum = ${ISEED_SHUM:-$ISEED}
  shum_tau = ${SHUM_TAU:-"-999."}
  shum_lscale = ${SHUM_LSCALE:-"-999."}
EOF
  fi

  if [ ${DO_SPPT:-NO}  = YES ] ; then
    cat >> input.nml << EOF
  sppt = $SPPT
  iseed_sppt = ${ISEED_SPPT:-$ISEED}
  sppt_tau = ${SPPT_TAU:-"-999."}
  sppt_lscale = ${SPPT_LSCALE:-"-999."}
  sppt_logit = ${SPPT_LOGIT:-.true.}
  sppt_sfclimit = ${SPPT_SFCLIMIT:-.true.}
  use_zmtnblck = ${use_zmtnblck:-.true.}
EOF
  fi

  cat >> input.nml << EOF
  $nam_stochy_nml
/
EOF


    cat >> input.nml << EOF
&nam_sfcperts
  $nam_sfcperts_nml
/
EOF

else

  cat >> input.nml << EOF
&nam_stochy
/
&nam_sfcperts
/
EOF

fi

# restart_output_dir = 'MOM6_RESTART/',

# Update MOM6 namelist file
# -------------------------
if [ $cplflx = .true. ] ; then

  cat >> input.nml << EOF

&MOM_input_nml
  output_directory   = 'MOM6_OUTPUT/',
  input_filename     = ${input_filename:-'n'}
  restart_input_dir  = 'INPUT/',
  restart_output_dir = '${OCN_RESTDIR:-MOM6_RESTART/}'
  parameter_filename = 'INPUT/MOM_input',
                       'INPUT/MOM_override'
/
EOF

#cat >> INPUT/MOM_override << EOF
cat >> INPUT/MOM_override << EOF
 RESTART_CHECKSUMS_REQUIRED=${RESTART_CHECKSUMS_REQUIRED:-False}
 VERBOSITY=${VERBOSITY:-2}

EOF

cat >> INPUT/MOM_input << EOF
  DT                    = $OCNTIM
  DT_THERM              = ${DT_THERM:-$OCNTIM}
  NIGLOBAL              = ${NX_GLB:-1440}
  NJGLOBAL              = ${NY_GLB:-1080}
  USE_IDEAL_AGE_TRACER  = ${USE_IDEAL_AGE_TRACER:-False}
  THERMO_SPANS_COUPLING = ${THERMO_SPANS_COUPLING:-False}
EOF

if [ ${IN_Z_DIAG_INTERVAL:-0} -gt 0 ] ; then
cat >> INPUT/MOM_input << EOF
  IN_Z_DIAG_INTERVAL = $IN_Z_DIAG_INTERVAL
EOF
#else
#cat >> INPUT/MOM_input << EOF
# WIND_STAGGER = $WIND_STAGGER
#EOF
fi
if [ ${Z_OUTPUT_GRID_FILE:-none} != none ] ; then
cat >> INPUT/MOM_input << EOF
  Z_OUTPUT_GRID_FILE = $Z_OUTPUT_GRID_FILE
EOF
fi
if [ ${USE_LA_LI2016:-False} = True ] ; then
cat >> INPUT/MOM_input << EOF
  USE_LA_LI2016 = $USE_LA_LI2016
EOF
fi
if [ ${USE_WAVES:-False} = True ] ; then          # for coupled MOM6 and WW3
cat >> INPUT/MOM_input << EOF
  USE_WAVES = $USE_WAVES
EOF
# WAVE_METHOD=$WAVE_METHOD
# SURFBAND_SOURCE = "COUPLER"               ! default = "EMPTY"
# SURFBAND_WAVENUMBERS = 0.04, 0.11, 0.3305 !   [rad/m] default = 0.12566
# STK_BAND_COUPLER = 3
fi
if [ ${MOM6_RIVER_RUNOF:-False} = True ] ; then          # for coupled MOM6 and WW3
  LIQUID_RUNOFF_FROM_DATA = $MOM6_RIVER_RUNOF
fi

fi                                         # if [ cplflx = .true. ] ; then

#------------------------------------------------------------------
# make symbolic links to write forecast files directly in memdir

cd $DATA

if [ $QUILTING = .true. -a $OUTPUT_GRID = gaussian_grid ] ; then
  if [ $OUTPUT_FILE = nemsio ] ; then
   export output_file=nemsio
  elif [ $OUTPUT_FILE = netcdf ] ; then
   export output_file=nc
  else
   export output_file=$OUTPUT_FILE
  fi

  export FHMIN=$((FHMIN+0))
  fhr=$((10#$FHMIN))
  if [[ $FHMIN -gt 0 ]] ; then
   if [ $FHOUT_HF -ne $FHOUT -a $fhr -lt $FHMAX_HF ] ; then
    fhr=$((10#$FHMIN+10#$FHOUT_HF))
   else
    fhr=$((10#$FHMIN+10#$FHOUT))
   fi
  fi
  while [ $fhr -le $FHMAX ] ; do
    FH3=$(printf %03i $fhr)
    atmo=atmf$FH3.$output_file
    sfco=sfcf$FH3.$output_file
    logo=logf$FH3.$output_file
    prefix="$CDUMP.t${cyc}z."
    rm $memdir/${prefix}$atmo ; $memdir/${prefix}$sfco ; $memdir/${prefix}$logo
    eval $NLN $memdir/${prefix}$atmo ${prefix}$atmo
    eval $NLN $memdir/${prefix}$sfco ${prefix}$sfco
    eval $NLN $memdir/${prefix}$logo logf$FH3
#   eval $NLN $memdir/${prefix}$logo ${prefix}$logo

    if [ $WRITE_DOPOST = .true. ] ; then           # post grib files
      FH2=$(printf %02i $fhr)
      pgbi=GFSPRS.GrbF${FH2}
      flxi=GFSFLX.GrbF${FH2}
      pgbo=$memdir/${CDUMP}.t${cyc}z.master.grb2f${FH3}
      flxo=$memdir/${CDUMP}.t${cyc}z.sfluxgrbf${FH3}.grib2
      eval $NLN $pgbo $pgbi
      eval $NLN $flxo $flxi
    fi
    FHINC=$FHOUT
    if [ $FHMAX_HF -gt 0 -a $FHOUT_HF -gt 0 -a $fhr -lt $FHMAX_HF ] ; then
      FHINC=$FHOUT_HF
    fi
    fhr=$((fhr+FHINC))
  done
else
  for n in $(seq 1 $ntiles) ; do
    eval $NLN $memdir/nggps2d.tile${n}.nc       nggps2d.tile${n}.nc
    eval $NLN $memdir/nggps3d.tile${n}.nc       nggps3d.tile${n}.nc
    eval $NLN $memdir/grid_spec.tile${n}.nc     grid_spec.tile${n}.nc
    eval $NLN $memdir/atmos_static.tile${n}.nc  atmos_static.tile${n}.nc
    eval $NLN $memdir/atmos_4xdaily.tile${n}.nc atmos_4xdaily.tile${n}.nc
  done
fi
#
if [ $cplwav = .true. ] ; then   # link wave history files
 WW3_OUTDIR=${WW3_OUTDIR:-$DATA}
 if [ $WW3_OUTDIR != $DATA ] ; then
  export FHMIN=$((FHMIN+0))
  fhr=$((10#$FHMIN))
  if [[ $FHMIN -gt 0 ]] ; then
   if [ $FHOUT_HF -ne $FHOUT -a $fhr -lt $FHMAX_HF ] ; then
    fhr=$((10#$FHMIN+10#$FHOUT_HF))
   else
    fhr=$((10#$FHMIN+10#$FHOUT))
   fi
  fi
  while [ $fhr -le $FHMAX ] ; do
    RDATE=$($NDATE +$fhr $CDATE)
    rPDY=$(echo $RDATE | cut -c1-8)
    rcyc=$(echo $RDATE | cut -c9-10)
    file=${rPDY}.${rcyc}0000.out_grd.${ww3_grid}
    eval $NLN $WW3_OUTDIR/$file $file
    FHINC=$FHOUT
    if [ $FHMAX_HF -gt 0 -a $FHOUT_HF -gt 0 -a $fhr -lt $FHMAX_HF ] ; then
      FHINC=$FHOUT_HF
    fi
    fhr=$((fhr+FHINC))
  done
 fi
fi
#
# run the executable

##ldd $FCSTEXEC
#echo $APRUN
#$APRUN $FCSTEXEC 1>& 1 2>& 2               

################################################################################
#  Make forecast
if [ "$APRUNW" = NONE ] ; then
 if [ "$APRUNB" = NONE -a "$APRUNE" = NONE ] ; then
   export PGM='$FCST_LAUNCHER $DATA/$(basename $FCSTEXEC)'
 else
  export PGM='$FCST_LAUNCHER $DATA/$(basename $FCSTEXEC) $APRUNB $DATA/$(basename $FCSTEXEC) $APRUNE $DATA/$(basename $FCSTEXEC)'
 fi
else
 if [ "$APRUNB" = NONE -a "$APRUNE" = NONE ] ; then
  export PGM='$FCST_LAUNCHER $DATA/$(basename $FCSTEXEC) $APRUNW $DATA/$(basename $FCSTEXEC)'
 else
  export PGM='$FCST_LAUNCHER $DATA/$(basename $FCSTEXEC) $APRUNB $DATA/$(basename $FCSTEXEC) $APRUNE $DATA/$(basename $FCSTEXEC) $APRUNW $DATA/$(basename $FCSTEXEC)'
 fi
fi
export pgm=$PGM
$LOGSCRIPT
$NCP $FCSTEXEC $DATA
#ldd $DATA/$(basename $FCSTEXEC)

#eval $PGM $REDOUT$PGMOUT $REDERR$PGMERR
eval $PGM 1>& 1 2>& 2


export ERR=$?
export err=$ERR
$ERRSCRIPT||exit 2

#------------------------------------------------------------------
if [ $ERR -eq 0 -a $SEND = YES -a $cpl = .false. -a $LINK_RESTDIR = NO ] ; then 


  # Copy gdas and enkf member restart files
  cd $DATA/RESTART
  mkdir -p $memdir/RESTART

  # Only save restarts at single time in RESTART directory
  # Either at restart_interval or at end of the forecast
  if [ $restart_interval -eq 0 -o $restart_interval -eq $FHMAX ] ; then

    # Add time-stamp to restart files at FHMAX
    RDATE=$($NDATE +$FHMAX $CDATE)
    rPDY=$(echo $RDATE | cut -c1-8)
    rcyc=$(echo $RDATE | cut -c9-10)
    for file in $(ls * | grep -v 0000.) ; do
      $NMV $file ${rPDY}.${rcyc}0000.$file
    done
    if [ $DOIAU = YES ] || [ $DOIAU_coldstart = YES ] ; then
      # if IAU is on, save two consective restarts
      RDATE=$($NDATE +$restart_interval $RDATE)
      rPDY=$(echo $RDATE | cut -c1-8)
      rcyc=$(echo $RDATE | cut -c9-10)
      for file in ${rPDY}.${rcyc}0000.* ; do
         $NCP $file $memdir/RESTART/$file
      done
    fi

  elif [ $CDUMP = gdas ] ; then

    for rst_int in $restart_interval_atm ; do
     if [ $rst_int -ge 0 ] ; then
       RDATE=$($NDATE +$rst_int $CDATE)
       rPDY=$(echo $RDATE | cut -c1-8)
       rcyc=$(echo $RDATE | cut -c9-10)
       for file in $(ls ${rPDY}.${rcyc}0000.*) ; do
         $NCP $file $memdir/RESTART/$file
       done
#-------------------------------------------------------------------------
#      if [ $cplwav = .true. ] ; then
#        WRDIR=$COMOUTWW3/${COMPONENTRSTwave}.${PDY}/${cyc}/restart
#        mkdir -p ${WRDIR}
#        for wavGRD in $waveGRD ; do
#        # Copy wave IC for the next cycle
#          $NCP $DATA/${rPDY}.${rcyc}0000.restart.${wavGRD} ${WRDIR}
#        done
#      fi
#-------------------------------------------------------------------------
     fi
    done
#
    if [ $DOIAU = YES ] || [ $DOIAU_coldstart = YES ] ; then
      # if IAU is on, save restart at start of IAU window
      rst_iau=$(( ${IAU_OFFSET} - (${IAU_DELTHRS}/2) ))
      if [ $rst_iau -lt 0 ] ;then
         rst_iau=$(( (${IAU_DELTHRS}) - ${IAU_OFFSET} ))
      fi
      RDATE=$($NDATE +$rst_iau $CDATE)
      rPDY=$(echo $RDATE | cut -c1-8)
      rcyc=$(echo $RDATE | cut -c9-10)
      for file in $(ls ${rPDY}.${rcyc}0000.*) ; do
         $NCP $file $memdir/RESTART/$file
      done
#-------------------------------------------------------------------------
#     if [ $cplwav = .true. ] ; then
#       WRDIR=$COMOUTWW3/${COMPONENTRSTwave}.${PDY}/${cyc}/restart/
#       mkdir -p ${WRDIR}
#       for wavGRD in $waveGRD ; do
#       # Copy wave IC for the next cycle
#          $NCP $DATA/${rPDY}.${rcyc}0000.restart.${wavGRD} ${WRDIR}
#       done
#     fi
#-------------------------------------------------------------------------
    fi

  fi

fi

if [ ${KEEPREST:-NO} = YES -a $FHMAX -gt ${FHMAX_COLD:-1} ] ; then
 if [ $cplflx = .true. -a $mediator = nems ] ; then
    MED_RESTDIR=${MED_RESTDIR:-$ROTDIR/gfs.$PDY/$cyc/MED_RESTART}
    mkdir -p $MED_RESTDIR
#   $NCP  mediator_*restart*.nc mediator_scalars_restart.txt $MED_RESTDIR/

#   cd $MED_RESTDIR
    RDATE=$($NDATE +$FHMAX $CDATE)
    rPDY=$(echo $RDATE | cut -c1-8)
    rcyc=$(echo $RDATE | cut -c9-10)
    for file in $(ls mediator*) ; do
      $NCP $file $MED_RESTDIR/${rPDY}-${rcyc}0000_$file
    done
 fi
fi
#
#
if [ $CDUMP = gfs ] ; then

   # Add time-stamp to restart files at FHMAX
   cd $ATM_RESTDIR
   RDATE=$($NDATE +$FHMAX $CDATE)
   rPDY=$(echo $RDATE | cut -c1-8)
   rcyc=$(echo $RDATE | cut -c9-10)
   for file in $(ls * | grep -v 0000.) ; do
     $NMV $file ${rPDY}.${rcyc}0000.$file
   done
fi
#

# Clean up before leaving
echo $(pwd)
if [ ${KEEPDATA:-NO} != YES ] ; then rm -rf $DATA ; fi

set +x
if [[ $VERBOSE = YES ]] ; then
   echo $(date) EXITING $0 with return code $err >&2
fi
exit $err


