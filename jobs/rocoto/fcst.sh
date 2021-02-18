#!/bin/ksh -x

###############################################################
# Source FV3GFS workflow modules
mod_ext=${mod_ext:-""}
. $HOMEgfs/ush/load_fv3gfs_modules.sh $mod_ext
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Execute the JJOB
$HOMEgfs/jobs/JGLOBAL_FORECAST
status=$?
exit $status
