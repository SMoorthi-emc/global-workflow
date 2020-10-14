#!/usr/bin/env python

###############################################################
# < next few lines under version control, D O  N O T  E D I T >
# $Date$
# $Revision$
# $Author$
# $Id$
###############################################################

import os
import sys
import glob
import shutil
from datetime import datetime
from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter
import workflow_utils as wfu


global machines
global expdir, configdir, comrot, pslot, res, idate, edate, gfs_cyc, fhmin, warm_start, fhcyc, cdump


machines = ['HERA', 'WCOSS_C', 'WCOSS_DELL_P3', 'WCOSS']


def makedirs_if_missing(d):
    if not os.path.exists(d):
        os.makedirs(d)


def create_EXPDIR():

    makedirs_if_missing(expdir)
    configs = glob.glob('%s/config.*' % configdir)
    if len(configs) == 0:
        msg = 'no config files found in %s' % configdir
        raise IOError(msg)
    for config in configs:
        shutil.copy(config, expdir)

    return


def create_COMROT():

    makedirs_if_missing(comrot)

    return


def edit_baseconfig():

    base_config = '%s/config.base' % expdir

    here = os.path.dirname(__file__)
    top = os.path.abspath(os.path.join(os.path.abspath(here), '../..'))

    # make a copy of the default before editing
    shutil.copy(base_config, base_config + '.default')

    print '\nSDATE = %s\nEDATE = %s' % (idate, edate)
    with open(base_config + '.default', 'rt') as fi:
        with open(base_config + '.new', 'wt') as fo:
            for line in fi:
                line = line.replace('@MACHINE@', machine.upper())   \
                    .replace('@PSLOT@', pslot)                      \
                    .replace('@SDATE@', idate.strftime('%Y%m%d%H')) \
                    .replace('@EDATE@', edate.strftime('%Y%m%d%H')) \
                    .replace('@CASECTL@', 'C%d' % res)   \
                    .replace('@HOMEgfs@', top)           \
                    .replace('@BASE_GIT@', base_git)     \
                    .replace('@DMPDIR@', dmpdir)         \
                    .replace('@NWPROD@', nwprod)         \
                    .replace('@HOMEDIR@', homedir)       \
                    .replace('@STMP@', stmp)             \
                    .replace('@PTMP@', ptmp)             \
                    .replace('@NOSCRUB@', noscrub)       \
                    .replace('@EXECBASE@', execbase)     \
                    .replace('@ACCOUNT@', account)       \
                    .replace('@QUEUE@', queue)           \
                    .replace('@QUEUE_ARCH@', queue_arch) \
                    .replace('@gfs_cyc@', '%d' % gfs_cyc)
                if expdir is not None:
                    line = line.replace('@EXPDIR@', os.path.dirname(expdir))
                if cdump is not None:
                    line = line.replace('@CDUMP@', cdump)
                if fhmin is not None:
                    line = line.replace('@FHMIN@', fhmin)
                if warm_start is not None:
                    line = line.replace('@WARM_START@', warm_start)
                if fhcyc is not None:
                    line = line.replace('@FHCYC@', fhcyc)
                if comrot is not None:
                    line = line.replace('@ROTDIR@', os.path.dirname(comrot))
                line = line.replace('@ICSDIR@', os.path.join(os.path.dirname(comrot), 'FV3ICS'))
                fo.write(line)
    os.unlink(base_config)
    os.rename(base_config + '.new', base_config)

    print ''
    print 'EDITED:  %s/config.base as per user input.' % expdir
    print 'DEFAULT: %s/config.base.default is for reference only.' % expdir
    print 'Please verify and delete the default file before proceeding.'
    print ''

    return


if __name__ == '__main__':

    description = '''Setup files and directories to start a GFS parallel.
Create EXPDIR, copy config files
Create COMROT experiment directory structure'''

    parser = ArgumentParser(description=description, formatter_class=ArgumentDefaultsHelpFormatter)
    parser.add_argument('--pslot', help='parallel experiment name', type=str, required=False, default='test')
    parser.add_argument('--res', help='resolution of the model forecast', type=int, required=False, default=192)
    parser.add_argument('--comrot', help='full path to COMROT', type=str, required=False, default=None)
    parser.add_argument('--expdir', help='full path to EXPDIR', type=str, required=False, default=None)
    parser.add_argument('--idate', help='starting date of experiment, initial conditions must exist!', type=str, required=True)
    parser.add_argument('--edate', help='end date experiment', type=str, required=True)
    parser.add_argument('--configdir', help='full path to directory containing the config files', type=str, required=False, default=None)
    parser.add_argument('--gfs_cyc', help='GFS cycles to run', type=int, choices=[0, 1, 2, 4], default=1, required=False)
    parser.add_argument('--partition', help='partition on machine', type=str, required=False, default=None)
    parser.add_argument('--cdump',help='cycle to run forecasts', type=str, choices=['gdas', 'gfs'], default='gfs', required=False)
    parser.add_argument('--fhmin',help='starting forecast hour', type=str, default='0', required=False)
    parser.add_argument('--warm_start',help='warm start of forecasts', type=str, choices=['.false.', '.true.'], default='.false.', required=False)
    parser.add_argument('--fhcyc',help='urface cycling interval', type=str, default='24', required=False)

    args = parser.parse_args()

    machine = wfu.detectMachine()

    configdir = args.configdir
    if not configdir:
        configdir = os.path.abspath(os.path.dirname(__file__) + '/../parm/config')

    pslot = args.pslot
    idate = datetime.strptime(args.idate, '%Y%m%d%H')
    edate = datetime.strptime(args.edate, '%Y%m%d%H')
    res   = args.res
    comrot  = args.comrot if args.comrot is None else os.path.join(args.comrot, pslot)
    expdir  = args.expdir if args.expdir is None else os.path.join(args.expdir, pslot)
    gfs_cyc = args.gfs_cyc
    partition  = args.partition
    cdump      = args.cdump
    fhmin      = args.fhmin
    warm_start = args.warm_start
    fhcyc      = args.fhcyc

    # Set machine defaults
    if machine == 'WCOSS_DELL_P3':
      base_git = '/gpfs/dell2/emc/modeling/noscrub/emc.glopara/git'
      base_svn = '/gpfs/dell2/emc/modeling/noscrub/emc.glopara/git'
      dmpdir   = '/gpfs/dell3/emc/global/dump'
      nwprod   = '/gpfs/dell1/nco/ops/nwprod'
      homedir  = '/gpfs/dell2/emc/modeling/noscrub/$USER'
      stmp     = '/gpfs/dell2/stmp/$USER'
      ptmp     = '/gpfs/dell2/ptmp/$USER'
      noscrub  = '/gpfs/dell2/emc/modeling/noscrub/$USER'
      execbase = '/gpfs/dell2/emc/modeling/noscrub/$USER'
      account  = 'GFS-DEV'
      queue    = 'dev'
#     queue    = 'debug'
      queue_arch = 'dev_transfer'
      if partition in ['3p5']:
        queue = 'dev2'
        queue_arch = 'dev2_transfer'
    elif machine == 'WCOSS_C':
      base_git = '/gpfs/hps3/emc/global/noscrub/emc.glopara/git'
      base_svn = '/gpfs/hps3/emc/global/noscrub/emc.glopara/svn'
      dmpdir   = '/gpfs/dell3/emc/global/dump'
      nwprod   = '/gpfs/hps/nco/ops/nwprod'
      homedir  = '/gpfs/hps3/emc/global/noscrub/$USER'
      stmp     = '/gpfs/hps2/stmp/$USER'
      ptmp     = '/gpfs/hps2/ptmp/$USER'
      noscrub  = '/gpfs/hps3/emc/global/noscrub/$USER'
      execbase = '/gpfs/hps3/emc/global/noscrub/$USER'
      account  = 'GFS-DEV'
      queue    = 'dev'
#     queue    = 'debug'
      queue_arch = 'dev_transfer'
    elif machine == 'HERA':
      base_git = '/scratch1/NCEPDEV/global/save/glopara/git'
      base_svn = '/scratch1/NCEPDEV/global/save/glopara/svn'
      dmpdir   = '/scratch1/NCEPDEV/global/glopara/dump'
      nwprod   = '/scratch1/NCEPDEV/global/glopara/nwpara'
      homedir  = '/scratch1/NCEPDEV/global/$USER'
      stmp     = '/scratch1/NCEPDEV/stmp2/$USER'
      ptmp     = '/scratch1/NCEPDEV/stmp4/$USER'
      noscrub  = '/scratch1/NCEPDEV/global/$USER'
      execbase = '/scratch1/NCEPDEV/global/$USER/save'
      account  = 'fv3-cpu'
      queue    = 'batch'
      queue_arch = 'service'

    print (" comrot=",comrot)
    print (" fhmin=", fhmin)
    # COMROT directory
    create_comrot = True
    if os.path.exists(comrot):
        print
        print 'COMROT already exists in %s' % comrot
        print
        create_comrot = False
        if int(fhmin) == 0:
            overwrite_comrot = raw_input('Do you wish to over-write COMROT [y/N]: ')
            create_comrot = True if overwrite_comrot in ['y', 'yes', 'Y', 'YES'] else False
            if create_comrot:
                shutil.rmtree(comrot)

    if create_comrot:
        create_COMROT()

    # EXP directory
    create_expdir = True
    if os.path.exists(expdir):
        print
        print 'EXPDIR already exists in %s' % expdir
        print
        create_expdir = True
        if int(fhmin) == 0:
            overwrite_expdir = raw_input('Do you wish to over-write EXPDIR [y/N]: ')
            create_expdir = True if overwrite_expdir in ['y', 'yes', 'Y', 'YES'] else False
            if create_expdir:
                shutil.rmtree(expdir)
        else:
            create_expdir = True
            if create_expdir:
                shutil.rmtree(expdir)

    if create_expdir:
        create_EXPDIR()
        edit_baseconfig()

    sys.exit(0)
