#!/usr/bin/python3

from os import system
from sys import version_info

exec_ver = version_info[0]

# check executing version is python3
if exec_ver < 3:
    system('printf "ERROR: must be using \033[1;31mpython3\033[0m' +
           ' to execute script.\n"')
    raise SystemExit(253)

from json import dumps
from requests import put
from gitlab import Gitlab
from argparse import ArgumentParser, RawTextHelpFormatter

def printf(text):
    if not suppress:
        print(text)
    return True

def transfer(id, name):
    data = {
        "namespace": destination
    }
    headers = {
        "PRIVATE-TOKEN": token
    }
    res = put('{0}/api/v4/projects/{1}/transfer'.format(url, id),
              data=data,
              headers=headers,
              verify=False)

    res_code = res.status_code
    ret_data = res.json()
    res_data = dumps(ret_data, indent=4, sort_keys=False)

    if res_code < 210:
        result = '[ OK ]'
        ret = True
    else:
        result = '[FAIL]'
        ret = False
    printf('%-70s%10s' % (' --> transfer project ' + name, result))
    return ret

def callAPI():
    namespaces = {}
    lab = Gitlab(url, token)
    all_projects = lab.projects.list(all=True)

    for e in all_projects:
        id = e.id
        name = e.name
        namespace = e.path_with_namespace.split('/')[0].strip()
        if individual and name == project:
            namespaces[name] = {
                "id": id,
                "name": name,
                "namespace": namespace
            }
            break
        elif not individual and namespace == group:
            namespaces['{0}_{1}'.format(str(id).zfill(3), name)] = {
                "id": id,
                "name": name,
                "namespace": namespace
            }

    # display projects
    printf('%-5s%-45s%-30s' % ('ID', 'Project', 'Group Namespace'))
    for k, v in sorted(namespaces.items()):
        printf('%-5s%-45s%-30s' % (v["id"], v["name"], v["namespace"]))

    # start transfer
    printf('\nStarting transfer specified projects...')
    for k, v in sorted(namespaces.items()):
        transfer(id=v["id"], name=v["name"])
    printf('\ndone!\n')

    return namespaces

if __name__ in '__main__':

    # define global variables
    script = __file__
    split_line = '=' * 80

    # parse arguments
    parser = ArgumentParser(description='Using Restful API to transfer ' +
                                        'specified project namespace.',
                            formatter_class=RawTextHelpFormatter)
    parser.add_argument('-u', '--url',
                        dest='u', type=str,
                        default='http://ipt-gitlab.ies.inventec:8081',
                        help='Gitlab url\n    (default: %(default)s)')
    parser.add_argument('-t', '--token',
                        dest='t', type=str,
                        help='API access token')
    parser.add_argument('-g', '--group',
                        dest='g', type=str,
                        help='set group namespace')
    parser.add_argument('-p', '--project',
                        dest='p', type=str,
                        help='set project name')
    parser.add_argument('-d', '--destination',
                        dest='d', type=str,
                        help='set destinate group namespace')
    parser.add_argument('--individual',
                        action='store_true', default=False,
                        help='transfer individual project')
    parser.add_argument('--suppress',
                        action='store_true', default=False,
                        help='suppress transfer output')
    group1 = parser.add_argument_group('Transfer All Projects',
                                      'python3 {0} '.format(script) +
                                      '-t A_x7egs-pyp5QBRvycMW ' +
                                      '-g TA-Team -d TA-Web')
    group2 = parser.add_argument_group('Transfer Individual Project',
                                      'python3 {0} '.format(script) +
                                      '-t A_x7egs-pyp5QBRvycMW --individual ' +
                                      '-p Ali-Drive-Test -d TA-Web')
    args = parser.parse_args()
    url = args.u
    token = args.t
    group = args.g
    project = args.p
    destination = args.d
    individual = args.individual
    suppress = args.suppress

    try:
        if individual and not project:
            raise ValueError
        elif not individual and not group:
            raise ValueError
        for e in [destination, token]:
            if not e:
                raise ValueError
        callAPI()
    except ValueError:
        print("Invalid arguments, try '-h/--help' for more information.")
        raise SystemExit(-1)

