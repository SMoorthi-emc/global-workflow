#! /usr/bin/env bash
set -eux

source ./machine-setup.sh > /dev/null 2>&1
cwd=`pwd`

USE_PREINST_LIBS=${USE_PREINST_LIBS:-"true"}
if [ $USE_PREINST_LIBS = true ]; then
  export MOD_PATH=/scratch3/NCEPDEV/nwprod/lib/modulefiles
else
  export MOD_PATH=${cwd}/lib/modulefiles
fi

# Check final exec folder exists
if [ ! -d "../exec" ]; then
  mkdir ../exec
fi

if [ $target = hera ]; then target=hera.intel ; fi
if [ $target = orion ]; then target=orion.intel ; fi

cd fv3gfs.fd/
<<<<<<< HEAD

# This builds the non-coupled model
#FV3=$( pwd -P )/FV3
#cd tests/
#./compile.sh "$FV3" "$target" "NCEP64LEV=Y HYDRO=N 32BIT=Y" 1
#mv -f fv3_1.exe ../NEMS/exe/fv3_gfs_nh.prod.32bit.x

# This builds the coupled model - app version
# Not a 32-bit build, may need to change later for bit-reproducibility checks
./NEMS/NEMSAppBuilder rebuild app=coupledFV3_MOM6_CICE
cd ./NEMS/exe
mv NEMS.x nems_fv3_mom6_cice5.x
=======
FV3=$( pwd -P )/FV3
cd tests/
if [ ! -d ../NEMS/exe ]; then mkdir ../NEMS/exe ; fi
if [ ${RUN_CCPP:-${1:-"YES"}} = "NO" ]; then
 ./compile.sh "$FV3" "$target" "WW3=Y 32BIT=Y" 1
 mv -f fv3_1.exe ../NEMS/exe/global_fv3gfs.x
else
 ./compile.sh "$target" "APP=ATM CCPP=Y 32BIT=Y SUITES=FV3_GFS_v16,FV3_GFS_v16_RRTMGP" 2 YES NO
 mv -f fv3_2.exe ../NEMS/exe/global_fv3gfs.x
fi
>>>>>>> upstream/develop
