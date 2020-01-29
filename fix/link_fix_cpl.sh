#!/bin/ksh
set -xa
export NOSCRUB=${NOSCRUB:-/gpfs/dell2/emc/modeling/noscrub}
ln -sf $NOSCRUB/emc.glopara/git/fv3gfs/fix/fix_am            fix_am
ln -sf $NOSCRUB/emc.glopara/git/fv3gfs/fix/fix_orog          fix_orog
ln -sf $NOSCRUB/emc.glopara/git/fv3gfs/fix/fix_verif         fix_verif
ln -sf $NOSCRUB/emc.glopara/git/fv3gfs/fix/fix_fv3           fix_fv3
ln -sf $NOSCRUB/emc.glopara/git/fv3gfs/fix/fix_fv3_gmted2010 fix_fv3_gmted2010

ln -sf $NOSCRUB/Shrinivas.Moorthi/coup_fix/fix_ocnice   fix_ocnice
ln -sf $NOSCRUB/Shrinivas.Moorthi/coup_fix/fix_cice5    fix_cice5
ln -sf $NOSCRUB/Shrinivas.Moorthi/coup_fix/fix_mom6     fix_mom6
ln -sf $NOSCRUB/Shrinivas.Moorthi/coup_fix/fix_fv3grid  fix_fv3grid


