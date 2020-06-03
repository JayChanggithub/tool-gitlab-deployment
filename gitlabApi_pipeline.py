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
from textwrap import dedent
from requests import get, post
from argparse import ArgumentParser, RawTextHelpFormatter

def runPipeline(id=1, ref='', token='', var={}):
    data = {
        "ref": ref,
        "token": token
    }
    data.update(eval(var))
    put_data = dumps(data, indent=4, sort_keys=False)
    res = post('http://ipt-gitlab.ies.inventec:8081/api/v4/projects/' + \
               '{0}/trigger/pipeline'.format(id),
               data=data,
               verify=False)
    res_code = res.status_code
    ret_data = res.json()
    res_data = dumps(ret_data, indent=4, sort_keys=False)

    # display result
    msg_temp = dedent("""
                      {0}
                      Configuration
                      {0}
                       - ID:     {6}
                       - Branch: {7}
                       - Token:  {8}
                      {0}
                      Post Data:
                      {9}
                      {0}
                       - Author: {1}
                       - ID:     {2}
                      {0}
                      Response Data:
                      {5}
                      {0}
                       - Status: {3}
                       - Result: {4}
                      {0}
                      """)
    if res_code < 210:
        result = 'O.K.'
        ret = True
    else:
        result = 'FAIL.'
        ret = False
    if withdraw:
        return ret
    print(msg_temp.format(split_line,
                          ret_data["user"]["name"],
                          ret_data["user"]["username"],
                          res_code,
                          result,
                          res_data,
                          id,
                          ref,
                          token,
                          put_data))

if __name__ == '__main__':

    # define global variables
    script = __file__
    split_line = '=' * 80

    # parse arguments
    parser = ArgumentParser(description='Using Restful API to trigger ' +
                                        'Gitlab-CI pipeline job.',
                            formatter_class=RawTextHelpFormatter)
    parser.add_argument('-i', '--id',
                        dest='i', type=int,
                        help='set project id')
    parser.add_argument('-b', '--branch',
                        dest='b', type=str, default='master',
                        help='set project branch (default: %(default)s)')
    parser.add_argument('-t', '--token',
                        dest='t', type=str,
                        help='pipeline trigger token')
    parser.add_argument('-v', '--variables',
                        dest='v', type=str,
                        help='pipeline pass job variables')
    parser.add_argument('-w', '--withdraw',
                        action='store_true', default=False,
                        help='withdraw trigger results output')
    group = parser.add_argument_group('Example',
                                      'python3 {0} '.format(script) +
                                      '-t 1a8c3b7b445331de405501ee23fc0e ' +
                                      '-i 39 -v "{\'variables[sut_ip]\': ' +
                                      '\'172.17.0.113\', ' +
                                      '\'variables[script_cmd]\': ' +
                                      '\'\\\'python StressMonitor.py ' +
                                      '--full -t 360\\\'\'}"')
    args = parser.parse_args()
    id = args.i
    branch = args.b
    token = args.t
    variables = args.v
    withdraw = args.withdraw

    try:
        runPipeline(id=id, ref=branch, token=token, var=variables)
    except TypeError:
        print("Invalid arguments, try '-h/--help' for more information.")

