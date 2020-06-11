#!/bin/bash
cwd=$PWD
script=$(basename $0)
log_name=$(basename $script .sh).log
tm_stp=$(date '+%s')
datetime=$(date '+%Y%m%d_%H%M%S')

function dataBackup
{
    local bak_pass=<BAK_PASS>
    for e in "gitlab:config" "ldap:ldap"
    do
        local dir=$(echo $e | awk -F\: '{print $1}')
        local file=$(echo $e | awk -F\: '{print $2}')
        local name=${dir}_${file}_${datetime}.tar.gz

        if [ "$(echo $dir | sed -E s'/^ //'g)" == "gitlab" ]; then
            cd /srv/$dir
        elif [ "$(echo $dir | sed -E s'/^ //'g)" == "ldap" ]; then
            cd /srv
        fi
        tar zcvf $name $file
        cp $name /srv/gitlab/data/backups/local_bak/$name

        # define latest backup variables
        local BAK_LATEST=$(ls /srv/gitlab/data/backups/local_bak/*.gz | grep "${dir}_${file}" | tail -1)
        local backup_datas=($(ls /srv/gitlab/data/backups/local_bak/*.gz | grep "${dir}_${file}" | sort -Vr))

        # reserve the latest file
        if [ ${#backup_datas[@]} -gt 1 ]; then
            for e in $(ls /srv/gitlab/data/backups/local_bak/*.gz \
                       | grep "${dir}_${file}" \
                       | sort -Vr | sed -n 2,${#backup_datas[@]}p)
            do
                echo "move file to /tmp --->, $e."
                mv $e /tmp
            done
        fi

        # remote backup
        # sshpass -p "$bak_pass" rsync -avzh -e 'ssh -o StrictHostKeyChecking=no' \
        #                       $BAK_LATEST \
        #                       root@10.99.104.243:/data/Gitlab_Backup
        sshpass -p "$bak_pass" scp -o StrictHostKeyChecking=no \
                                   -rp $BAK_LATEST root@10.99.104.243:/data/Gitlab_Backup 2> /dev/null


        # remove duplicates files
        if [ $(ls -a /srv/$dir \
              | grep -v '^\.' \
              | grep -v '^\.$' \
              | grep -v '^\..$' \
              | egrep ".gz$" \
              | wc -l) -ne 0 ]; then
            mv /srv/$dir/*.gz /tmp
        elif [ $(ls -a /srv/ \
              | grep -v '^\.' \
              | grep -v '^\.$' \
              | grep -v '^\..$' \
              | egrep ".gz$" \
              | wc -l) -ne 0 ]; then
            mv /srv/*.gz /tmp
        fi
        cd $cwd
    done

    # delete /tmp .gz files
    if [ $(ls /tmp | egrep -c '.gz$') -ne 0 ]; then
        find /tmp -type f -name '*.gz' -delete
    fi
}

function main
{
    local bak_pass=<BAK_PASS>
    local BAK_LATEST=$(ls /srv/gitlab/data/backups/*.tar | tail -1)

    if [ ! -d /srv/gitlab/data/backups/local_bak ]; then
        mkdir -p /srv/gitlab/data/backups/local_bak
    fi
    cp -rf $BAK_LATEST /srv/gitlab/data/backups/local_bak/gitlab_backup.tar

    # clear remote backup
    sshpass -p "$bak_pass" ssh root@10.99.104.243 rm -f /data/Gitlab_Backup/*

    # backup gitlab, ldap data to local and remote
    dataBackup

    # remote backup gitlab
    while true
    do
        # remote backup
        # sshpass -p "$bak_pass" rsync -avzh -e 'ssh -o StrictHostKeyChecking=no' \
        #                       $BAK_LATEST \
        #                       root@10.99.104.243:/data/Gitlab_Backup
        sshpass -p "$bak_pass" scp -o StrictHostKeyChecking=no \
                                   -rp $BAK_LATEST root@10.99.104.243:/data/Gitlab_Backup 2> /dev/null

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
