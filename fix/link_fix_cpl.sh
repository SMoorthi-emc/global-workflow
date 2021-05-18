#!/bin/ksh
set -xa
pwd=$(pwd)
echo $pwd

if [ $(echo $pwd | cut -c1-8) = "/scratch" ] ; then
 NOSCRUB=/scratch1/NCEPDEV/global
 FV3_FIX=$NOSCRUB/glopara/fix
 CPL_FIX=$NOSCRUB/$LOGNAME/noscrub/coup_fix
 AER_FIX=$NOSCRUB/$LOGNAME/noscrub/coup_fix/FV3_input_data_INCCN_aeroclim
elif [ $(echo $pwd | cut -c1-11) = "/gpfs/dell2" ] ; then
 NOSCRUB=/gpfs/dell2/emc/modeling/noscrub
 FV3_FIX=$NOSCRUB/emc.glopara/git/fv3gfs/fix
 CPL_FIX=$NOSCRUB/$LOGNAME/coup_fix
 AER_FIX=$NOSCRUB/$LOGNAME/coup_fix/FV3_input_data_INCCN_aeroclim
elif [$(echo $pwd | cut -c1-9) = "/gpfs/hps" ] ; then
 NOSCRUB=/gpfs/hpsemc/global/noscrub
 FV3_FIX=$NOSCRUB/emc.glopara/git/fv3gfs/fix
 CPL_FIX=$NOSCRUB/$LOGNAME/coup_fix
 AER_FIX=$NOSCRUB/$LOGNAME/coup_fix/FV3_input_data_INCCN_aeroclim
fi

export FV3_FIX=${FV3_FIX:-/gpfs/dell2/emc/modeling/noscrub.emc.glopara/git/fv3gfs}
export CPL_FIX=${CPL_FIX:-/gpfs/dell2/emc/modeling/$LOGNAME/coup_fix}
export AER_FIX=${AER_FIX:-/gpfs/dell2/emc/modeling/$LOGNAME/coup_fix/FV3_input_data_INCCN_aeroclim}

ln -sf $FV3_FIX/fix_am            fix_am
ln -sf $FV3_FIX/fix_orog          fix_orog
ln -sf $FV3_FIX/fix_verif         fix_verif
ln -sf $FV3_FIX/fix_fv3           fix_fv3
ln -sf $FV3_FIX/fix_fv3_fracoro   fix_fv3_fracoro
ln -sf $FV3_FIX/fix_fv3_gmted2010 fix_fv3_gmted2010

ln -sf $CPL_FIX/fix_ocnice        fix_ocnice
ln -sf $CPL_FIX/fix_cice5         fix_cice5
ln -sf $CPL_FIX/fix_cice6         fix_cice6
ln -sf $CPL_FIX/fix_mom6          fix_mom6
ln -sf $CPL_FIX/fix_fv3grid       fix_fv3grid
ln -sf $CPL_FIX/ocean_ice_post    ocean_ice_post

ln -sf $AER_FIX/MERRA2            fix_aer
ln -sf $AER_FIX/mg2_IN_CCN        fix_ccn
ln -sf $AER_FIX/aer_data/LUTS     fix_lut



