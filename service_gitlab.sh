#!/bin/bash

# color codes
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC1='\033[0m'

# define default action flag
clear_registry=False
svc_restore=False
svc_backup=False
svc_restart=False
svc_stop=False
svc_start=False
container_exe=False

# define global variables
title=ipt
srv_path=/srv
gitlab_ver='13.1.1'
logdir=$PWD/reports
__file__=$(basename $0)
log_name=$(basename $__file__ .sh).log
image_ls="all|${title}-gitlab|${title}-ldap|${title}-httpd"

# redis variables
redis_opt=""
redis_container_name="ares-prod-redis"

if [ "`whoami`" != "root" ]; then
    gitlab_id=`docker ps -a | grep 'gitlab$' | awk '{print $1}' 2> /dev/null`
    ldap_id=`docker ps -a | grep ldap | awk '{print $1} 2> /dev/null'`
fi

# define functions
function usage
{
    echo -en $YELLOW
    more << EOF
Usage: $0 [Option] argv
    Normal Options:
        -h, --help             display how to use this script.

    Container Operating Options:
        start                  running the specified image as container.
        stop                   stop specified container.
        restart                restart the specified container.

    Gitlab Container Operating Options:
        -t, --times                specified clear gitlab garbage counts.
        -name, --container-name    specified container name.
        --tsmp, --timestemp        restore gitlab from timestemp of backups file.
        --backup                   run gitlab backup procedure
        --restore                  run gitlab restore within container from timestemp.
        --conexec-restore          within gitlab container restore from script use.
        --clear-garbage            clear gitlab container registry garbage.
        --restore-file             specified restore tar file.
        --gitlab-conf              specified gitlab config folder from backup diretory.

    Redis Container Operating Options:
        --redis                    specified an option to run: {start|stop|restart}

Example:
    $0 --backup
    $0 --clear-garbage -t 2
    $0 {start|stop|restart} -name ${title}-gitlab
    $0 -name ipt-gitlab --restore --restore-file /tmp/1591816571_2020_06_10_13.0.5-ee_gitlab_backup.tar --gitlab-conf /tmp/config
EOF
    echo -en $NC1
    exit 0
}

function run_gitlab
{
    if [ $(docker ps | awk '{print $NF}' | grep -ci "${title}-gitlab$") -eq 1 ]; then
        printf "%-40s [${RED} %s ${NC1}]\n" \
               " * container already exist " \
               " ${title}-gitlab "
        return 0
    fi
    sudo docker run -tid \
         --hostname ${title}-gitlab \
         --restart always \
         --publish 443:443 --publish 8081:80 --publish 2022:22 \
         --name ${title}-gitlab \
         --volume ${srv_path}/gitlab/config:/etc/gitlab \
         --volume ${srv_path}/gitlab/logs:/var/log/gitlab \
         --volume ${srv_path}/gitlab/data:/var/opt/gitlab \
         --volume ${srv_path}/gitlab/logs/reconfigure:/var/log/gitlab/reconfigure \
         --volume ${srv_path}/gitlab/tmpfs:/run/tmpfs \
         -e "TZ=Asia/Shanghai" \
         jaychangdockerimages/gitlab-server:13.1.1
}

function run_ldap
{
    if [ $(docker ps | awk '{print $NF}' | grep -ci "${title}-ldap$") -eq 1 ]; then
        printf "%-40s [${RED} %s ${NC1}]\n" \
               " * container already exist " \
               " ${title}-ldap "
        return 0
    fi
    sudo docker run -tid \
         --restart=always \
         -p 389:389 -p 636:636 \
         --env LDAP_BASE_DN="ou=People,dc=inventec,dc=com" \
         --env LDAP_ORGANISATION="inventec" \
         --env LDAP_DOMAIN="inventec.com" \
         --env LDAP_ADMIN_PASSWORD="admin" \
         --volume ${srv_path}/ldap/data/slapd/database:/var/lib/ldap \
         --volume ${srv_path}/ldap/data/slapd/config:/etc/ldap/slapd.d \
         --hostname ldap.inventec.com \
         --name ${title}-ldap \
         -e "TZ=Asia/Shanghai" \
         jaychangdockerimages/openldap-server:1.0.0
}


function run_httpd
{
    if [ $(docker ps | awk '{print $NF}' | grep -ci "${title}-httpd$") -eq 1 ]; then
        printf "%-40s [${RED} %s ${NC1}]\n" \
               " * container already exist " \
               " ${title}-httpd "
        return 0
    fi
    sudo docker run -tid \
         --restart=always \
         -p 8000:80 \
         --volume ${srv_path}/httpd/htdocs:/usr/local/apache2/htdocs \
         --volume ${srv_path}/httpd/cgi-bin:/usr/local/apache2/cgi-bin \
         --hostname ${title}-httpd \
         --name ${title}-httpd \
         -e "TZ=Asia/Shanghai" \
         jaychangdockerimages/httpd-server:1.0.0
}

function service_start
{
    # check action container
    if [ $(echo $containers | egrep -c "$image_ls") -eq 0 ]; then
        printf "%-40s [${RED} %s ${NC1}]\n" \
               " * specify a regular image name: " \
               " $image_ls "
        return 1
    elif [ $(echo $containers | egrep -ci 'all') -eq 1 ]; then
        local containers=`echo $image_ls | cut -d \| -f2-255 | tr -s '|' ' '`
    fi

    for c in ${containers[@]}
    do
        case "$c" in
            "${title}-gitlab")
                run_gitlab
                ;;
            "${title}-ldap")
                run_ldap
                ;;
            "${title}-httpd")
                run_httpd
                ;;
        esac
    done
}

function service_stop
{
    # match the all of images with container list
    if [ $(echo $containers | egrep -ci 'all') -ne 0 ]; then
        local containers=$(echo $image_ls | cut -d \| -f2-255 | tr -s '|' ' ')
        for c in ${containers[@]}
        do
            if [ $(docker ps -a | awk '{print $NF}' | grep -ci "$c$") -ne 0 ]; then
                docker stop $c
                docker rm $c --force
            fi
        done
        return 0
    fi

    # only match one of image in container list
    if [ $(docker ps -a | awk '{print $NF}' | grep -ci "$containers$") -ne 0 ]; then
        docker stop $containers
        docker rm $containers --force
    fi
}

function service_restart
{
    # check action container
    if [ $(echo $containers | egrep -c "$image_ls") -eq 0 ]; then
        printf "%-40s [${RED} %s ${NC1}]\n" \
               " * specify a regular image name: " \
               " $image_ls "
        return 1
    fi

    # restart all of containers which match whole image list
    if [ $(echo $containers | grep -ci 'all') -eq 1 ]; then
        local containers=$(echo $image_ls | cut -d \| -f2-255 | tr -s '|' ' ')
        for c in "${containers[@]}"
        do
            if [ "$c" == "${title}-gitlab" ]; then
                service_stop
                sleep 1
                service_start
                docker exec -it $containers gitlab-ctl reconfigure
                docker exec -it $containers gitlab-ctl restart
                printf "%-40s [${YELLOW} %s ${NC1}]\n" \
                       " * container restart completed: " \
                       " $c "
                continue
            fi
            service_stop
            sleep 1
            service_start
            printf "%-40s [${YELLOW} %s ${NC1}]\n" \
                   " * container restart completed: " \
                   " $c "
        done
        return 0
    fi

    # restart single container
    service_stop
    sleep 1
    service_start

    if [ "$containers" == "${title}-gitlab" ]; then
        docker exec -it $containers gitlab-ctl reconfigure
        docker exec -it $containers gitlab-ctl restart
    fi

    printf "%-40s [${YELLOW} %s ${NC1}]\n" \
           " * container restart completed: " \
           " $containers "
}

function service_backup
{
    docker exec ${title}-gitlab gitlab-ctl stop unicorn
    docker exec ${title}-gitlab gitlab-ctl stop sidekiq
    docker exec ${title}-gitlab gitlab-rake gitlab:backup:create
    docker exec ${title}-gitlab gitlab-ctl reconfigure
    docker exec ${title}-gitlab gitlab-ctl restart
}

function service_restore
{
    local gitbak_dir='/srv/gitlab/data/backups'
    local git_container=`docker ps | awk '/gitlab$/ {print $1}'`
    if [ ! -f "$gz" ] || [ ! -d "$git_conf" ]; then
        printf "%-40s [${RED} %s ${NC1}]\n" \
               " * $gz or gitlab configuration dir $git_conf  " \
               " not found "
        exit 1
    fi
    if [ "`command -v docker 2> /dev/null`" == "" ]; then
        printf "%-40s [${RED} %s ${NC1}]\n" \
               " * command not found: " \
               " docker "
        exit 2
    fi

    if [ $(ls $gitbak_dir | grep -ci $(basename $gz)) -ne 1 ] ||
       [ "$(du $gz | awk '{print $1}')" != "$(du $gitbak_dir/$(basename $gz) \
       | awk '{print $1}')" ]; then
       yes | cp -rf $gz /srv/gitlab/data/backups
    fi

    yes | cp -rf $git_conf /srv/gitlab/
    yes | cp -rf $PWD/$0 /srv/gitlab/config/

    printf "%-40s [${YELLOW} %s ${NC1}]\n" \
           " * restart docker daemon: " \
           " $git_container "
    docker exec -it $git_container gitlab-ctl reconfigure
    docker exec -it $git_container gitlab-ctl restart
    docker restart $git_container
    local gz_name=`basename $gz`
    local check_gz=`docker exec -it $git_container bash \
                                -c 'ls -al /var/opt/gitlab/backups/' \
                                | grep -c $gz_name`
    local backup=`echo $gz_name | awk -F '_' '{print $1}' \
                                | sed -E s',^ |  $,,'g`
    local check_shell=`docker exec -it $git_container bash \
                                   -c 'ls -al /etc/gitlab' \
                                   | grep -c $(basename $0)`
    if [ $check_gz -ne 1 ]; then
        printf "%-40s [${RED} %s ${NC1}]\n" \
               " * $gz_name not in container: " \
               " /var/opt/gitlab/backups/ "
        exit 3
    fi

    if [ $check_shell -ne 1 ]; then
        printf "%-40s [${RED} %s ${NC1}]\n" \
               " * $(basename $0) not in container: " \
               " /etc/gitlab "
        exit 4
    fi
    sleep 3m
    docker exec -it $git_container bash -c "echo yes | bash /etc/gitlab/`basename $0` --conexec-restore --tsmp $backup"
}

function container_exec
{
    if [ "`command -v gitlab-ctl 2> /dev/null`" == "" ]; then
        printf "%-40s [${RED} %s ${NC1}]\n" \
               " * command in container not found " \
               " gitlab-ctl "
        exit 7
    fi
    if [ "$timestamp" != "" ]; then
        local backup=$(ls /var/opt/gitlab/backups/ | grep ^$timestamp)
        local regx='([0-9]+_){4}([0-9]+\.){2}[0-9]+\-([a-zA-Z]+\_){2}[a-zA-Z]+\.[a-zA-Z]+'

        printf "%-40s [${YELLOW} %s ${NC1}]\n" \
               " * restore from backup file: " \
               " ${backup}, timestamp: $timestamp "

        mv /var/opt/gitlab/backups/${backup} \
           /var/opt/gitlab/backups/${timestamp}_gitlab_backup.tar
        chmod 755 /var/opt/gitlab/backups/${timestamp}_gitlab_backup.tar
        gitlab-ctl stop unicorn
        gitlab-ctl stop sidekiq
        gitlab-rake gitlab:backup:restore BACKUP=$timestamp
        gitlab-ctl start unicorn
        gitlab-ctl start sidekiq
        gitlab-ctl restart
        mv /var/opt/gitlab/backups/${timestamp}_gitlab_backup.tar \
           /var/opt/gitlab/backups/${backup}

        if [ $(ls -a /var/opt/gitlab/backups/ \
               | grep -v '^\.' | grep -v '^\.$' | grep -v '^\..$' \
               | egrep -v $regx | wc -l) -ne 0 ]; then
            cd /var/opt/gitlab/backups/
            local except_file=$(ls -al | awk '{print $NF}' | grep -Eo $regx)
            find . -type f ! -name $except_file -print0 | xargs -0  -I {} rm -v {}
            find . -type d ! -name $except_file -delete
            cd $PWD
        fi
    else
        printf "%-40s [${RED} %s ${NC1}]\n" \
               " * need to specify the backup timestamp " \
               " '$timestamp' "
        exit 226
    fi
    printf "%-40s [${YELLOW} %s ${NC1}]\n" \
           " * gitlab restore complete " \
           " '$except_file' "
    return 0
}

function redisHandler
{
    case $redis_opt in
        start)
            docker run -tid \
                       --restart=always  \
                       --privileged=true \
                       --cpus="2.0" \
                       --memory="15g" \
                       --memory-swap="20g" \
                       -p 6379:6379 \
                       -v /srv/redis/conf/redis.conf:/etc/redis/redis.conf \
                       -v /srv/redis/data:/data \
                       --name $redis_container_name registry.ipt-gitlab:8081/sit-develop-tool/tool-gitlab-deployment/redis:base redis-server /etc/redis/redis.conf \
                       --dbfilename dump.rdb \
                       --dir /data
            docker ps | grep $redis_container_name
            echo "Start Redis completed."
            ;;
        stop)
            docker stop $redis_container_name 2> /dev/null
            docker rm $redis_container_name 2> /dev/null
            echo "Stop Redis completed."
            ;;
        restart)
            docker stop $redis_container_name 2> /dev/null
            docker rm $redis_container_name 2> /dev/null
            docker run -tid \
                       --restart=always  \
                       --privileged=true \
                       --cpus="2.0" \
                       --memory="15g" \
                       --memory-swap="20g" \
                       -p 6379:6379 \
                       -v /srv/redis/conf/redis.conf:/etc/redis/redis.conf \
                       -v /srv/redis/data:/data \
                       --name $redis_container_name registry.ipt-gitlab:8081/sit-develop-tool/tool-gitlab-deployment/redis:base redis-server /etc/redis/redis.conf \
                       --dbfilename dump.rdb \
                       --dir /data
            docker ps | grep $redis_container_name
            echo "Restart Redis completed."
            ;;
    esac
    exit 0
}

function clear_registry_garbage
{
    for i in `seq 1 $times`
    do
        docker exec -i ${title}-gitlab gitlab-ctl registry-garbage-collect -m
    done
}

# main
function main
{
    if [ "$redis_opt" != "" ]; then
        redisHandler $redis_opt
    fi

    if [ "$svc_start" == "True" ]; then
        service_start
        return 0
    fi

    if [ "$svc_stop" == "True" ]; then
        service_stop
        return 0
    fi

    if [ "$svc_restart" == "True" ]; then
        service_restart
        return 0
    fi

    if [ "$svc_backup" == "True" ]; then
        service_backup
        return 0
    fi

    if [ "$svc_restore" == "True" ]; then
        service_restore
        return 0
    fi

    if [ "$container_exe" == "True" ]; then
        container_exec
        return 0
    fi

    if [ "$clear_registry" == "True" ]; then
        clear_registry_garbage
        return 0
    fi
}

if [ "$#" -eq 0 ]; then

    printf "%-40s [${RED} %s ${NC1}]\n" \
           " * Invalid arguments, " \
           " Try '-h/--help' for more information. "
    exit 1
fi

while [ "$1" != "" ]
do
    # parse argv
    case $1 in
        -h|--help)
            usage
            ;;
        start)
            svc_start=True
            ;;
        stop)
            svc_stop=True
            ;;
        restart)
            svc_restart=True
            ;;
        --backup)
            svc_backup=True
            ;;
        --restore)
            svc_restore=True
            ;;
        --conexec-restore)
            container_exe=True
            ;;
        --clear-garbage)
            clear_registry=True
            ;;
        --restore-file)
            shift
            gz=$1
            ;;
        --gitlab-conf)
            shift
            git_conf=$1
            ;;
        -t|--times)
            shift
            times=$1
            ;;
        -name|--container-name)
            shift
            containers=$1
            ;;
        --tsmp|--timestemp)
            shift
            timestamp=$1
            ;;
        --redis)
            shift
            redis_opt=$1
            ;;
        * )
            printf "%-40s [${RED} %s ${NC1}]\n" \
                   " * Invalid arguments, " \
                   " Try '-h/--help' for more information. "
            exit 1
            ;;
    esac
    shift
done

if [ ! -d $logdir ]; then
    mkdir -p $logdir
fi

main | tee $logdir/$log_name
