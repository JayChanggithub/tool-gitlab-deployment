#!/usr/bin/python3

from os import system
from sys import version_info

exec_ver = version_info[0]

# check executing version is python3
if exec_ver < 3:
    system('printf "ERROR: must be using \033[1;31mpython3\033[0m' +
           ' to execute script.\n"')
    raise SystemExit(253)

from re import search
from json import dumps
from textwrap import dedent
from datetime import datetime
from requests import get, delete
from time import strftime, mktime
from argparse import ArgumentParser, RawTextHelpFormatter

def printf(text):
    if not suppress:
        print(text)
    return True

def timeConvertor(d):
    if not search(r'^\d{4}\-\d{2}\-\d{2}', d):
        return 0
    date = search(r'^\d{4}\-\d{2}\-\d{2}', d).group(0)
    ts = int(mktime(datetime.strptime(date, "%Y-%m-%d").timetuple()))
    days = int((current_ts - ts) / 60 / 60 / 24)
    return date, ts, days

def getRepoid(project_id):
    res = get('{0}/api/v4/projects/{1}/registry/repositories'.format(url, project_id),
               headers=headers,
               verify=False)
    repository_id = res.json()[0]['id']
    return int(repository_id)

def getTags(path):
    re_data = {}
    res = get('{0}/api/v4/projects/{1}{2}'.format(url, project_id, path),
              headers=headers,
              verify=False)
    data = res.json()
    for e in data:
        if e == 'error':
            printf(data["error"])
            raise SystemExit(-1)
        tag_name = e["name"]
        re_data[tag_name] = {}
        if 'commit' in e:
            if 'created_at' in e["commit"]:
                created_at = e["commit"]["created_at"]
                re_data[tag_name]["created_at"] = created_at
    return re_data

def getTagDetail(tag):
    res = get('{0}/api/v4/projects/{1}/registry/repositories/{2}/tags/{3}'. \
              format(url, project_id, repository_id, tag),
              headers=headers,
              verify=False)
    data = res.json()
    return data

def getProjectDetail(id):
    res = get('{0}/api/v4/projects/{1}'.format(url, project_id),
              headers=headers,
              verify=False)
    data = res.json()
    return data

def removeTag(tag):
    code = 0
    data = {}
    if not test_mode:
        res = delete('{0}/api/v4/projects/{1}/registry/repositories/{2}/tags/{3}'. \
                     format(url, project_id, repository_id, tag),
                     headers=headers,
                     verify=False)
        data = res.json()
        code = res.status_code
        if code < 210:
            result = '[ OK ]'
        else:
            result = '[FAIL]'
    else:
        result = '[ OK ]'
    printf('%-70s%10s' % (' --> remove repository tag ' + tag, result))
    return code, data

def listTags(expire):
    tmp = []
    tags_list = []
    re_data = {}
    project_info = getProjectDetail(project_id)
    for page in range(1, 11):
        tags = getTags(path='/registry/repositories/{0}/tags?format=json&page={1}'. \
                       format(repository_id, page))
        if len(tags.keys()) >= 1:
            tags_list.append([tag for tag in tags.keys() if tag])

    tags_tag = [ 
        tags_list[idx] 
        for idx in range(0, len(tags_list)) 
    ][0]
    project_tags = getTags(path='/repository/tags')
    for e in tags_tag:
        re_data[e] = getTagDetail(tag=e)
        created_at = re_data[e]["created_at"]
        date = {
            "datetime": {
                "date": timeConvertor(d=created_at)[0],
                "timestamp": timeConvertor(d=created_at)[1],
                "existing_day": timeConvertor(d=created_at)[2]
            }
        }
        re_data[e].update(date)

    if expire == 0:
        printf(
            '\nList all {0} registry tags, RepositoryID={1}, ProjectID={2}:'. \
            format(project_info["name"], repository_id, project_id) +
            '\n'
        )
        sort_tags = sorted([
            '{0}_{1}'.format(v["datetime"]["timestamp"], k)
            for k, v in re_data.items()
        ], reverse=True)
        for i, e in enumerate(sort_tags):
            tag_opt = 'keep'
            tag_ts = e.split('_')[0]
            tag_name = e.split('_')[1]
            if i > 6:
                tag_opt = 'remove'
                tmp.append(tag_name)
            printf(
                dedent("""\
                {6}
                {7}.Tag Name - {0}
                 - path:         {1}
                 - date:         {2}
                 - timestamp:    {3}
                 - existing day: {4}
                 - operation:    {5}
                """.format(
                        tag_name,
                        re_data[tag_name]["path"],
                        re_data[tag_name]["datetime"]["date"],
                        str(tag_ts),
                        str(re_data[tag_name]["datetime"]["existing_day"]),
                        tag_opt,
                        split_line,
                        str(i + 1).zfill(2)
                    )
                )
            )
    else:
        printf('\nList expired > {0} days registry repository'.format(expire) +
               ' tags except project tag:\n')
        for k, v in re_data.items():
            if k in project_tags.keys():
                created_at = project_tags[k]["created_at"]
                dates = timeConvertor(d=created_at)
                exists_day = dates[2]
                if exists_day < has_tag_expired_day:
                    printf('Tag - ' + k)
                    printf(' - date: ' + dates[0])
                    printf(' - timestamp: ' + str(dates[1]))
                    printf(' - existing day: ' + str(exists_day))
                    printf(' - operation: keep')
                    printf(split_line)
                    continue
            for k1, v1 in v.items():
                if k1 == 'created_at':
                    dates = timeConvertor(d=v1)
                    exists_day = dates[2]
                    if exists_day >= expire:
                        printf('Tag - ' + k)
                        printf(' - date: ' + dates[0])
                        printf(' - timestamp: ' + str(dates[1]))
                        printf(' - existing day: ' + str(exists_day))
                        printf(' - operation: remove')
                        printf(split_line)
                        tmp.append(k)
    return tmp

def callAPI():
    tags = []
    tags = listTags(expire=expire)

    # remove expired tags
    printf('\nStarting remove expired tag...')
    for e in tags:
        removeTag(tag=e)
    printf('\ndone!\n')

    return tags

if __name__ == '__main__':

    # define global variables
    script = __file__
    split_line = '=' * 80
    no_tag_expired_day = 4
    has_tag_expired_day = 14
    current_ts = int(strftime('%s'))

    # parse arguments
    parser = ArgumentParser(description='Using Restful API remove ' +
                                        'expired tags.',
                            formatter_class=RawTextHelpFormatter)
    parser.add_argument('-u', '--url',
                        dest='u', type=str,
                        default='http://ipt-gitlab.ies.inventec:8081',
                        help='Gitlab url\n    (default: %(default)s)')
    parser.add_argument('-t', '--token',
                        dest='t', type=str,
                        help='API access token')
    parser.add_argument('-p', '--projects',
                        dest='i',
                        help='set project id')
    parser.add_argument('-e', '--expire',
                        dest='e', type=int, default=no_tag_expired_day,
                        help='set threshold of expire day ' +
                             '(default: %(default)s days)')
    parser.add_argument('-n', '--name',
                        dest='n', type=str,
                        help='set repository tag name')
    parser.add_argument('-l', '--list',
                        action='store_true', default=False,
                        help='list all tags from specified repository')
    parser.add_argument('--test',
                        action='store_true', default=False,
                        help='run with test mode')
    parser.add_argument('--individual',
                        action='store_true', default=False,
                        help='individual removing repository tag')
    parser.add_argument('--suppress',
                        action='store_true', default=False,
                        help='suppress output')
    group1 = parser.add_argument_group('Display all repository tags',
                                       'python3 %(prog)s --list ' +
                                       '-t A_x7egs-pyp5QBRvycMW -p 65:35')
    group2 = parser.add_argument_group('Remove individual repository tags',
                                       'python3 %(prog)s ' +
                                       '-t A_x7egs-pyp5QBRvycMW ' +
                                       '-p 65:35,66:36 -n 56d8cc3 ' +
                                       '--individual')
    group3 = parser.add_argument_group('Remove all repository tags',
                                       'python3 %(prog)s ' +
                                       '-t A_x7egs-pyp5QBRvycMW ' +
                                       '-p 65:35,66:36')
    group4 = parser.add_argument_group('Remove repository tags except the ' +
                                       'latest 7 items',
                                       'python3 %(prog)s ' +
                                       '-t A_x7egs-pyp5QBRvycMW ' +
                                       '-p 65:35,66:36 -e 0')
    args = parser.parse_args()
    url = args.u
    token = args.t
    projects = args.i
    expire = args.e
    name = args.n
    list_tags = args.list
    test_mode = args.test
    individual = args.individual
    suppress = args.suppress
    headers = {
        'PRIVATE-TOKEN': token
    }

    try:
        for project in projects.split(','):
            project_id = int(project.split(':')[0].strip())
            repository_id = getRepoid(project_id)
            for e in [url, token, project_id, repository_id]:
                if not e:
                    raise ValueError
            if test_mode:
                printf('Running with test mode will not to do anything in ' +
                       'registry repository.')
            if list_tags:
                listTags(expire=0)
            elif individual:
                if not name:
                    raise ValueError
                printf('\nStarting remove specified repository tag...')
                removeTag(tag=name)
                printf('\ndone!\n')
            else:
                callAPI()
    except ValueError:
        print("Invalid arguments, try '-h/--help' for more information.")
        raise SystemExit(-1)
