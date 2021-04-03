#!/bin/ksh -x

###############################################################
## Abstract:
## Get GFS intitial conditions
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
configs="base getic"
for config in $configs; do
    . $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done

###############################################################
# Source machine runtime environment
. $BASE_ENV/${machine}.env getic
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Set script and dependency variables

yyyy=$(echo $CDATE | cut -c1-4)
mm=$(echo $CDATE | cut -c5-6)
dd=$(echo $CDATE | cut -c7-8)
cyc=${cyc:-$(echo $CDATE | cut -c9-10)}

export COMPONENT=${COMPONENT:-atmos}

###############################################################

target_dir=$ICSDIR/$CDATE/$CDUMP
mkdir -p $target_dir
cd $target_dir

# Initialize return code to 0
rc=1

if [ $ics_from = "opsgfs" ]; then

    # Location of production tarballs on HPSS
    hpssdir="/NCEPPROD/hpssprod/runhistory/rh$yyyy/$yyyy$mm/$PDY"

    # Handle nemsio and pre-nemsio GFS filenames
    if [ $CDATE -le "2019061118" ]; then #GFSv14
        # Add CDUMP.PDY/CYC to target_dir
        target_dir=$ICSDIR/$CDATE/$CDUMP/${CDUMP}.$yyyy$mm$dd/$cyc
        mkdir -p $target_dir
        cd $target_dir

        nfanal=4
        fanal[1]="./${CDUMP}.t${cyc}z.atmanl.nemsio"
        fanal[2]="./${CDUMP}.t${cyc}z.sfcanl.nemsio"
        fanal[3]="./${CDUMP}.t${cyc}z.nstanl.nemsio"
        fanal[4]="./${CDUMP}.t${cyc}z.pgrbanl"
        flanal="${fanal[1]} ${fanal[2]} ${fanal[3]} ${fanal[4]}"
        tarpref="gpfs_hps_nco_ops_com"
        if [ $CDUMP = "gdas" ]; then
            tarball="$hpssdir/${tarpref}_gfs_prod_${CDUMP}.${CDATE}.tar"
        elif [ $CDUMP = "gfs" ]; then
            tarball="$hpssdir/${tarpref}_gfs_prod_${CDUMP}.${CDATE}.anl.tar"
        fi
    else #GFSv15
        nfanal=2
        fanal[1]="./${CDUMP}.$yyyy$mm$dd/$cyc/${CDUMP}.t${cyc}z.atmanl.nemsio"
        fanal[2]="./${CDUMP}.$yyyy$mm$dd/$cyc/${CDUMP}.t${cyc}z.sfcanl.nemsio"
        flanal="${fanal[1]} ${fanal[2]}"
        if [ $CDATE -ge "2020022600" ]; then 
          tarpref="com"
        else 
          tarpref="gpfs_dell1_nco_ops_com"
        fi
        if [ $CDUMP = "gdas" ]; then
            tarball="$hpssdir/${tarpref}_gfs_prod_${CDUMP}.${yyyy}${mm}${dd}_${cyc}.${CDUMP}_nemsio.tar"
        elif [ $CDUMP = "gfs" ]; then
            tarball="$hpssdir/${tarpref}_gfs_prod_${CDUMP}.${yyyy}${mm}${dd}_${cyc}.${CDUMP}_nemsioa.tar"
        fi
    fi

    # First check the COMROOT for files, if present copy over
    if [ $machine = "WCOSS_C" ]; then

        # Need COMROOT
        module load prod_envir/1.1.0 >> /dev/null 2>&1

        comdir="$COMROOT/$CDUMP/prod/$CDUMP.$PDY"
        rc=0
        for i in `seq 1 $nfanal`; do
            if [ -f $comdir/${fanal[i]} ]; then
                $NCP $comdir/${fanal[i]} ${fanal[i]}
            else
                rb=1 ; ((rc+=rb))
            fi
        done

    fi

    # Get initial conditions from HPSS
    if [ $rc -ne 0 ]; then

        # check if the tarball exists
        hsi ls -l $tarball
        rc=$?
        if [ $rc -ne 0 ]; then
            echo "$tarball does not exist and should, ABORT!"
            exit $rc
        fi
        # get the tarball
        htar -xvf $tarball $flanal
        rc=$?
        if [ $rc -ne 0 ]; then
            echo "untarring $tarball failed, ABORT!"
            exit $rc
        fi

        # Move the files to legacy EMC filenames
        if [ $CDATE -le "2019061118" ]; then #GFSv14
           for i in `seq 1 $nfanal`; do
             $NMV ${fanal[i]} ${flanal[i]}
           done
        fi

    fi

    # If found, exit out
    if [ $rc -ne 0 ]; then
        echo "Unable to obtain operational GFS initial conditions, ABORT!"
        exit 1
    fi

elif [ $ics_from = "pargfs" ]; then

    # Add CDUMP.PDY/CYC to target_dir
    target_dir=$ICSDIR/$CDATE/$CDUMP/${CDUMP}.$yyyy$mm$dd/$cyc
    mkdir -p $target_dir
    cd $target_dir

    # Filenames in parallel
    nfanal=4
    fanal[1]="gfnanl.${CDUMP}.$CDATE"
    fanal[2]="sfnanl.${CDUMP}.$CDATE"
    fanal[3]="nsnanl.${CDUMP}.$CDATE"
    fanal[4]="pgbanl.${CDUMP}.$CDATE"
    flanal="${fanal[1]} ${fanal[2]} ${fanal[3]} ${fanal[4]}"

    # Get initial conditions from HPSS from retrospective parallel
    tarball="$HPSS_PAR_PATH/${CDATE}${CDUMP}.tar"

    # check if the tarball exists
    hsi ls -l $tarball
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "$tarball does not exist and should, ABORT!"
        exit $rc
    fi
    # get the tarball
    htar -xvf $tarball $flanal
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "untarring $tarball failed, ABORT!"
        exit $rc
    fi

    # If found, exit out
    if [ $rc -ne 0 ]; then
        echo "Unable to obtain parallel GFS initial conditions, ABORT!"
        exit 1
    fi

elif [ $ics_from = "cfsv2" ]; then

  rc=0
  # gfsanl.2016100300 -> siganl.gdas.2016100300.T574.nemsio
  # sfnanl.2016100300 -> sfcanl.gdas.2016100300.T574.nemsio

  # Create links just to satisify dependencies for fv3ic workflow job
  if [ -e $UGCSICSDIR/t574/gfsanl.$CDATE ]; then
    $NLN $UGCSICSDIR/t574/gfsanl.$CDATE siganl.${CDUMP}.$CDATE
  else
    $rc=1
  fi

  if [ -e $UGCSICSDIR/t574/sfnanl.$CDATE ]; then
    $NLN $UGCSICSDIR/t574/sfnanl.$CDATE sfcanl.${CDUMP}.$CDATE
  else
    $rc=2
  fi

  if [ $rc -ne 0 ] ; then
    echo "ics_from = $ics_from is not fully implemented yet"
    echo "Please use the EMC_ugcs workflow to generate T574 ICs"
    echo "These can then be used in the fv3ic.sh to generate ICs for this model"
    exit $rc
  fi
 
else

    echo "ics_from = $ics_from is not supported, ABORT!"
    exit 1

fi
###############################################################

#<<<<<<< HEAD
#BL2018
#exit 0 
# Copy pgbanl file to COMROT for verification
#COMROT=$ROTDIR/${CDUMP}.$PDY/$cyc
#[[ ! -d $COMROT ]] && mkdir -p $COMROT
#$NCP ${ftanal[1]} $COMROT/${CDUMP}.t${cyc}z.pgrbanl
#=======
# Copy pgbanl file to COMROT for verification - GFSv14 only
if [ $CDATE -le "2019061118" ]; then #GFSv14
  COMROT=$ROTDIR/${CDUMP}.$PDY/$cyc/$COMPONENT
  [[ ! -d $COMROT ]] && mkdir -p $COMROT
  $NCP ${fanal[4]} $COMROT/${CDUMP}.t${cyc}z.pgrbanl
fi
#>>>>>>> upstream/develop

###############################################################
# Exit out cleanly
exit 0
