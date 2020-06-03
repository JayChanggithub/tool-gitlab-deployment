#!/bin/bash
script=$(basename $0)
log_name=$(basename $script .sh).log
tm_stp=$(date '+%s')

function main
{
    local bak_pass=<BAK_PASS>
    local BAK_LATEST=$(ls /srv/gitlab/data/backups/*.tar | tail -1)

    if [ ! -d /srv/gitlab/data/backups/local_bak ]; then
        mkdir -p /srv/gitlab/data/backups/local_bak
    fi
    cp -rf $BAK_LATEST /srv/gitlab/data/backups/local_bak/gitlab_backup.tar

    # clear backup
    sshpass -p "$bak_pass" ssh root@10.99.104.243 rm -f /data/Gitlab_Backup/*

    while true
    do
        # remote backup
        sshpass -p "$bak_pass" rsync -avzh -e 'ssh -o StrictHostKeyChecking=no' \
                               $BAK_LATEST \
                               root@10.99.104.243:/data/Gitlab_Backup
        # wait time for 3 hours
        if [ $(( $(date '+%s') - $tm_stp )) -gt 10800 -a $? -ne 0 ]; then
            echo "$(date '+%F %T') --->, remote backup timeout."
            exit 1
        else
            echo "$(date '+%F %T') --->, remote backup success."
            break
        fi
    done
}

main | tee $PWD/reports/${log_name}
