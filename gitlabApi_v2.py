#!/usr/bin/python3
# -*- coding: utf-8 -*-

from sys import argv
from os import system
from time import sleep
from gitlab import Gitlab
from optparse import OptionParser

"""
The following constants define the supported access levels:
gitlab.GUEST_ACCESS = 10
gitlab.REPORTER_ACCESS = 20
gitlab.DEVELOPER_ACCESS = 30
gitlab.MASTER_ACCESS = 40
gitlab.OWNER_ACCESS = 50
"""

if __name__ in '__main__':

    if len(argv) > 1:
        # parse argv
        usage = 'Usage: %prog [Option] argv'
        parser = OptionParser(usage=usage)
        parser.add_option('--url',
                          dest='ul',
                          action='store',
                          help='set the gitlab API url ')
        parser.add_option('--token',
                          dest='tk',
                          action='store',
                          help='set the user access API token ')
        parser.add_option('--stop',
                          action='store_true',
                          help='to terminate current running service ')

        options, args = parser.parse_args()
        opt_dict = eval(str(options))

        url = options.ul
        token = options.tk
        duration = 60

        if opt_dict['stop']:
            system("for e in `ps -ef | grep gitlabApi_v2.py | awk '{print $2}'`; do sudo kill -9 $e; done")

        while(True):
            try:
                # create object of gitlab
                lab = Gitlab(url, token)

                # define specified group
                groups = lab.groups.list()
                group = lab.groups.get(10)

                # get group members
                members = group.members.list()
                group_members = [e.id for e in members]

                # get current user
                users = lab.users.list()
                current_users = [e.id for e in users]

                # add user to group that not exist
                for u in current_users:
                    if u not in group_members:
                        data = {
                            'user_id': u,
                            'access_level': 40
                        }
                        member = group.members.create(data)
            except:
                pass
            sleep(duration)
    else:
         print("Invalid argument, Try '-h/--help' for more information.")

