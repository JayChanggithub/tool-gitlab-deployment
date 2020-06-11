tool-gitlab-deployment
=========================

This project is used to record automate deploy the **gitlab**, **ldap**, **httpd** server, backup all of project process.

## Version
`Rev: 1.2.7`

---

## Status

[![pipeline status](http://ipt-gitlab.ies.inventec:8081/TA-Team/tool-gitlab-deployment/badges/master/pipeline.svg)](http://ipt-gitlab.ies.inventec:8081/TA-Team/tool-gitlab-deployment/commits/master)

---

## Usage

  - How to get {+ Container Registry ID +} from `Project ID=106`:

    ```bash
    $ curl -s -H "PRIVATE-TOKEN: <GITLAB_ADMIN_TOKEN>" \
           http://ipt-gitlab.ies.inventec:8081/api/v4/projects/106/registry/repositories \
           | python -m json.tool
    ```

    Output as following JSON format, `id=54` number means `Project ID=106`:

    ```bash
    [
        {
            "created_at": "2019-11-11T02:29:05.797Z",
            "id": 54,
            "location": "registry.ipt-gitlab:8081/ta-web/sit-web-rmsback",
            "name": "",
            "path": "ta-web/sit-web-rmsback",
            "project_id": 106
        }
    ]
    ```

## Crontab

```bash
# /etc/crontab: system-wide crontab
# Unlike any other crontab you don't have to run the `crontab'
# command to install the new version when you edit this file
# and files in /etc/cron.d. These files also have username fields,
# that none of the other crontabs do.

SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# m h dom mon dow user  command
17 *    * * *   root    cd / && run-parts --report /etc/cron.hourly
25 6    * * *   root    test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.daily )
47 6    * * 7   root    test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.weekly )
52 6    1 * *   root    test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.monthly )

# Gitlab Backup Local
#5  0    * * *   root    bash /root/tool-gitlab-deployment/service_gitlab.sh --backup
#30 0    * * *   root    python /root/tool-gitlab-deployment/gitlab_backup.py --day 7 --backup /srv/gitlab/data/backups/ --manage-backup

# Gitlab Backup Remote
#0  2    * * *   root    bash /root/tool-gitlab-deployment/gitlab_backup_remote.sh

# Gitlab Clear Registry Garbage
#0  0    * * *   root    bash /root/tool-gitlab-deployment/service_gitlab.sh --clear-garbage

# Clamav scan process
#0  5    * * *   root    cd /root/tool-antivirus-clamav/ && python clamav_scan.py --run
```

> All cron job have been moved to gitlab schedule pipeline.

> Click **[tool-gitlab-deployment](http://ipt-gitlab.ies.inventec:8081/TA-Team/tool-gitlab-deployment/pipeline_schedules)** for more information.


---


## /etc/rc.local

```bash
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

python3 /root/tool-gitlab-deployment/gitlabApi_v2.py --url http://10.99.104.242:8081 --token L2JxyBQbD7e3n5csTcuf &
#python /root/tool-gitlab-deployment/gitlab_backup.py --backup /srv2/gitlab/data/backups --time 03:34 --display &

exit 0
```

