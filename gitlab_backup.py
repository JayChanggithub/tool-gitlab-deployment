#!/usr/bin/python

from sys import argv
from re import search
from time import sleep, strftime
from os import system, listdir, remove
from os.path import isfile, isdir, join
from optparse import OptionParser, OptionGroup


def call_display(text):
    if display: 
        print text

def manageBackup(range):
    time_regex = r'\d+_\d{4}_\d{2}_\d{2}_\d+\.\d+\.\d+\-'
    backups = [e for e in listdir(bak_dir) if search(time_regex, e)]
    bak_times = sorted([int(e.split('_')[0]) for e in backups])
    call_display('List timestamps: ' + str(bak_times))
    today = bak_times[-1]
    for e in bak_times[:-1]:
        day = ( today - e ) / 24 / 60 / 60
        bak = ''.join([f for f in backups if str(e) in f])
        call_display('backup file: {0}, day life: {1}'.format(bak, str(day)))
        if day >= range:
            try:
                for e1 in backups:
                    if str(e) in e1:
                        file = join(bak_dir, e1)
                        call_display('remove file ' + file)
                        remove(file)
            except Exception as err:
                print str(err)

if __name__ == '__main__':

    cmd_ls = [
        'gitlab-ctl stop unicorn',
        'gitlab-ctl stop sidekiq',
        'gitlab-rake gitlab:backup:create',
        'gitlab-ctl start',
    ]

    if len(argv) < 2:
        print "Invalid argument, Try '-h/--help' for more information."
        raise SystemExit(-1)

    # parse arguments
    usage = 'Usage: %prog [Option]'
    parser = OptionParser(usage=usage)
    parser.add_option('--time',
                      dest='t',
                      action='store',
                      help='set the schedule datetime ')
    parser.add_option('--backup',
                      dest='bk',
                      action='store',
                      help='set the backup saved path ')
    parser.add_option('--display',
                      action='store_true',
                      help='display all process output ')
    group1 = OptionGroup(parser,
                         'Example',
                         'python {} --backup /srv2/gitlab/data/backups --time 01:00 --display'.format(__file__))
    group2 = OptionGroup(parser,
                         'Backup Management',
                         'To prevent system space be insufficient, '
                         'the service will clean backup in specified '
                         'day range automatically.')
    group2.add_option('--day',
                      dest='d',
                      action='store',
                      help='to keep the backup file time raange (days) ')
    group2.add_option('--manage-backup',
                      action='store_true',
                      help='enable the backup management service ')

    parser.add_option_group(group1)
    parser.add_option_group(group2)
    options, args = parser.parse_args()
    opt_dict = eval(str(options))

    display = opt_dict['display']
    manage_bak = opt_dict['manage_backup']
    day = options.d
    date = options.t
    bak_dir = options.bk

    # check backup path
    if not isdir(bak_dir):
        print "invalid backup path {}".format(bak_dir)
        raise SystemExit(-1)

    if manage_bak:
        # check day parameter
        if not day.isdigit():
            print "invalid day range."
            raise SystemExit(-1)

        # remove the backups out of day range
        manageBackup(range=int(day))
        raise SystemExit(0)

    # check datetime
    if not search(r'\d{2}\:\d{2}', date):
        print "invalid datetime."
        raise SystemExit(-1)

    if display:
        call_display('Gitlab Backup Schedule: A.M. [{}]'.format(date))
        call_display('Schedule Listening...')

    # loop thread to listen schedule
    while True:
        currentTime = strftime('%H:%M')
        if currentTime == date:
            call_display('Current Time: {}, Starting Backup Process...'.format(currentTime))
            for e in cmd_ls:
                call_display('Command: "docker exec ipt-gitlab {}"'.format(e))
                system('docker exec ipt-gitlab ' + e)
                sleep(2)

            # check backup
            bak = ''.join([e for e in listdir(bak_dir) if strftime('%m_%d') in e])
            bak = join(bak_dir, bak)
            if isfile(bak):
                call_display('ok: backup {} has been created.'.format(bak))
            else:
                call_display('fail: create backup failed.')

            sleep(30)
        sleep(5)

