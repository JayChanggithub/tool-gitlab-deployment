#!/usr/bin/python
# -*- coding: utf-8 -*-

from __future__ import print_function

from sys import argv
from json import dumps
from textwrap import dedent
from requests import get, post, delete

def getMissionData(script_name):
    data = {"script_name": script_name}
    if selector == 'update':
        data.update({"selector": selector})
    res = get(
       'http://ares-script-mgmt.cloudnative.ies.inventec/api/v1/script-management/missions/get',
        data=data,
        verify=False
    )
    res_code = res.status_code
    ret_data = res.json()
    return ret_data, res_code

def updateMissionData(get_data):
    data = get_data
    if selector == 'update':
        data.update({"selector": selector})
    data = {
        k:str(v)
        if isinstance(v, dict) and k == 'schedules'
        else v
        for k, v in data.items()
    }
    try:
        res = post(
            'http://ares-script-mgmt.cloudnative.ies.inventec/api/v1/script-management/missions/update',
            data=data,
            verify=False
        )
        res_code = res.status_code
        ret_data = res.json()
    except Exception as err:
        print('Please ensure the commit tag is right and requests data is valid.')
        print('Exception error message: ' + str(err))
        raise SystemExit(-1)

    return ret_data, res_code

if __name__ == '__main__':

    if len(argv) <= 2:
        raise SystemExit(-1)

    mail_msg = ''
    verify_list = ['validation', 'readme', 'pre-release']
    script_name = argv[1]
    stagestatus = argv[2].lower()
    summary = dedent("""
                     Summary:
                      - script name: {0}
                      - stage staus: {1}
                      - progress rate: {2}
                      - result: {3}
                     """)
    
    try:
        progress = argv[3]
    except:
        progress = int(50)
    try:
        selector = argv[4]
    except:
        selector = ''
    try:
        run_env = argv[5]
    except:
        run_env = 'prod'
    try:
        arg_flags = argv[6].lower().split(',')
    except:
        arg_flags = []

    # service environment selector
    if run_env == 'test':
        api_port = 55688
    else:
        api_port = 5566

    if stagestatus not in verify_list:
        raise SystemExit(-2)

    get_data = getMissionData(script_name)[0]
    get_status = getMissionData(script_name)[1]

    flags = {'pipeline_trigger': 'True'}
    try:
        if get_data['flags']:
            flags = eval(get_data['flags'])
            flags.update({'pipeline_trigger': 'True'})
    except:
        pass
    flags = str(flags)

    if stagestatus == 'validation':
        mail_msg = 'Please verify the script is satisfy in test requirement.'
        if 'reject' in arg_flags:
            mail_msg = ('Please re-verify the script ' +
                        'if any dissatisfied requirements.')
        get_data.update(
            {
                'author': get_data['developer'],
                'status': stagestatus,
                'phase': 'development',
                'progress': progress,
                'current': get_data['te_name'],
                'comment': mail_msg,
                'flags': flags
            }
        )
    elif stagestatus == 'readme':
        mail_msg = 'Please review the readme is satisfy in test requirement.'
        get_data.update(
            {
                'author': get_data['developer'],
                'status': stagestatus,
                'phase': 'readme-change',
                'progress': progress,
                'current': get_data['owner'],
                'comment': mail_msg,
                'flags': flags
            }
        )
    elif stagestatus == 'pre-release':
        mail_msg = 'Please review the project information.'
        get_data.update(
            {
                'author': get_data['developer'],
                'status': stagestatus,
                'phase': 'pre-release-change',
                'progress': progress,
                'current': get_data['ta_manager'],
                'comment': mail_msg,
                'flags': flags
            }
        )
        
    if get_status == 200:
        res_data, res_code = updateMissionData(get_data)
        if res_code > 400:
            ret = {
                "error": "Update Failed",
                "response": res_data,
                "code": res_code
            }
            print(dumps(ret, indent=4))
            raise SystemExit(-1)
        result = 'success'
    else:
        result = 'faild'

    print(summary.format(script_name, stagestatus, progress, result))

