#!/bin/bash

# define global variables
title=ipt
srv_path=/srv
gitlab_ver=12.4.3
image_ls="all|${title}-gitlab|${title}-registry|${title}-ldap|${title}-httpd"

if [ "`whoami`" != "root" ]; then
    gitlab_id=`docker ps -a | grep gitlab | awk '{print $1}'`
    registry_id=`docker ps -a | grep registry | awk '{print $1}'`
    ldap_id=`docker ps -a | grep ldap | awk '{print $1}'`
fi

# define functions
function usage
{
    more << EOF
Usage: $0 [Option] argv
    Run action in shell to replace complicated docker command
    operation.
      start=IMG   start the specified image to container
      stop=IMG    stop the specified container
      restart=IMG restart the specified container
                  IMG: {${image_ls}}
      status      show container list

    Docker Option:
      --cmd=ID    execute command in container,
      --env=ID    into specified container environ
      --log=ID    continuous output specified container log
      --ssh=ID    configure ssh setting to container
                  argv: \${container id/name} \${commands}

    Gitlab Option:
      --backup         run gitlab backup procedure
      --restore        run gitlab restore within timestamp
      --gitlab-srv     restart gitlab service in container
      --clear-garbage  clear gitlab container registry garbage

Example:
    $0 {start|stop|restart} ${title}-gitlab
    $0 --backup
    $0 --cmd ${title}-httpd service apache2 restart
EOF
    exit 0
}

function ssh_config
{
    if [ "$1" != "" ]; then
        local pass=$1
        echo -e "$pass\n$pass" | sudo docker exec -i $gitlab_id passwd
        docker exec -it $gitlab_id sed -i "s,PermitRootLogin\ prohibit-password,PermitRootLogin yes,g" /etc/ssh/sshd_config
        docker exec -it $gitlab_id grep '^PermitRootLogin ' /etc/ssh/sshd_config
        docker exec -it $gitlab_id service ssh restart
        echo "Docker ID: $gitlab_id sshd configured complete!"
    else
        echo "Root ssh password is required."
    fi
}

function service_start
{
    local containers="$1"

    # check action container
    if [ `echo $containers | grep -Pc $image_ls` -eq 0 ]; then
        echo "please specify a regular image name: $image_ls"
        return 1
    elif [ `echo $containers | grep -Pc all` -eq 1 ]; then
        local containers=`echo $image_ls | cut -d \| -f2-255`
    fi

    if [ `echo $containers | grep -Pc ${title}-gitlab` -eq 1 ]; then
        if [ `docker ps -a | awk '{print $NF}' | grep -c ${title}-gitlab` -eq 0 ]; then
            sudo docker run -tid \
                --hostname ${title}-gitlab \
                --restart always \
                --publish 443:443 --publish 8081:80 --publish 2022:22 \
                --name ${title}-gitlab \
                --volume ${srv_path}/gitlab/config:/etc/gitlab \
                --volume ${srv_path}/gitlab/logs:/var/log/gitlab \
                --volume ${srv_path}/gitlab/data:/var/opt/gitlab \
                --volume ${srv_path}/gitlab/logs/reconfigure:/var/log/gitlab/reconfigure \
                -e "TZ=Asia/Shanghai" \
                registry.ipt-gitlab:8081/sit-develop-tool/tool-gitlab-deployment/gitlab-ee:$gitlab_ver
        else
            echo "Container gitlab is exists."
        fi
    fi
    if [ `echo $containers | grep -Pc ${title}-registry` -eq 1 ]; then
        if [ `docker ps -a | grep -c ${title}-registry` -eq 0 ]; then
         #   sudo docker run -tid \
         #       --restart=always \
         #       -w /root -p 5000:5000 \
         #       --volume ${srv_path}/registry:/var/lib/registry \
         #       --hostname ${title}-registry \
         #       --name ${title}-registry \
         #       -e "TZ=Asia/Shanghai" \
         #       registry:2
            echo "Container registry is exists."
        fi
    fi
    if [ `echo $containers | grep -Pc ${title}-ldap` -eq 1 ]; then
        if [ `docker ps -a | awk '{print $NF}' | grep -c ${title}-ldap` -eq 0 ]; then
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
                registry.ipt-gitlab:8081/sit-develop-tool/tool-gitlab-deployment/openldap:1.0.0
            #sudo docker run -tid \
            #    --restart=always \
            #    -p 6443:443 \
            #    --env PHPLDAPADMIN_LDAP_HOSTS="ldap://localhost" \
            #    --hostname ${title}-phpldapadmin \
            #    --name ${title}-phpldapadmin \
            #    -e "TZ=Asia/Shanghai" \
            #    phpldapadmin:v1
        else
            echo "Container openldap is exists."
        fi
    fi
    if [ `echo $containers | grep -Pc ${title}-httpd` -eq 1 ]; then
        if [ `docker ps -a | awk '{print $NF}' | grep -c ${title}-httpd` -eq 0 ]; then
            sudo docker run -tid \
                --restart=always \
                -p 8000:80 \
                --volume ${srv_path}/httpd/htdocs:/usr/local/apache2/htdocs \
                --volume ${srv_path}/httpd/cgi-bin:/usr/local/apache2/cgi-bin \
                --hostname ${title}-httpd \
                --name ${title}-httpd \
                -e "TZ=Asia/Shanghai" \
                registry.ipt-gitlab:8081/sit-develop-tool/tool-gitlab-deployment/httpd:1.0.0
        else
            echo "Container httpd is exists."
        fi
    fi

    while :
    do
        boot_num=`docker ps -a | grep -c starting`
        docker ps -a
        if [ $boot_num -eq 0 ]; then
            break
        fi
        sleep 3
    done
}

function service_stop
{
    local containers="$1"

    # check action container
    if [ `echo $containers | grep -Pc $image_ls` -eq 0 ]; then
        echo "please specify a regular image name: $image_ls"
        return 1
    elif [ `echo $containers | grep -Pc all` -eq 1 ]; then
        local containers=`echo $image_ls | cut -d \| -f2-255`
    fi

    if [ `echo $containers | grep -Pc ${title}-gitlab` -eq 1 ]; then
        if [ `docker ps -a | grep -c ${title}-gitlab` -ne 0 ]; then
            docker container stop ${title}-gitlab && docker container rm -v ${title}-gitlab
	else
            echo "Container gitlab not found."
        fi
    fi
    if [ `echo $containers | grep -Pc ${title}-registry` -eq 1 ]; then
        if [ `docker ps -a | grep -c ${title}-registry` -ne 0 ]; then
            docker container stop ${title}-registry && docker container rm -v ${title}-registry
        else
            echo "Container registry not found."
        fi
    fi
    if [ `echo $containers | grep -Pc ${title}-ldap` -eq 1 ]; then
        if [ `docker ps -a | grep -c ${title}-ldap` -ne 0 ]; then
            docker container stop ${title}-ldap && docker container rm -v ${title}-ldap
            #docker container stop ${title}-phpldapadmin && docker container rm -v ${title}-phpldapadmin
        else
            echo "Container openldap not found."
        fi
    fi
    if [ `echo $containers | grep -Pc ${title}-httpd` -eq 1 ]; then
        if [ `docker ps -a | grep -c ${title}-httpd` -ne 0 ]; then
            docker container stop ${title}-httpd && docker container rm -v ${title}-httpd
        else
            echo "Container httpd not found."
        fi
    fi
    docker ps -a
}

function service_restart
{
    local containers="$1"

    # check action container
    if [ `echo $containers | grep -Pc $image_ls` -eq 0 ]; then
        echo "please specify a regular image name: $image_ls"
        return 1
    elif [ `echo $containers | grep -Pc all` -eq 1 ]; then
        local containers=`echo $image_ls | cut -d \| -f2-255`
    fi

    service_stop "$containers"
    sleep 1
    service_start "$containers"
    echo "Container: $containers restart completed."
}

function service_docker
{
    if [ "$1" != "" ]; then
        action=$1
        case $action in
            restart)
                docker exec -it $gitlab_id gitlab-ctl reconfigure && gitlab-rake gitlab:ldap:check;;
        esac
    else
        echo "Need to specify an action to do."
    fi
}

function service_backup
{
    docker exec ${title}-gitlab gitlab-ctl stop unicorn
    docker exec ${title}-gitlab gitlab-ctl stop sidekiq
    docker exec ${title}-gitlab gitlab-rake gitlab:backup:create
    docker exec ${title}-gitlab gitlab-ctl start
}

function service_restore
{
    if [ "`command -v docker 2> /dev/null`" != "" -a \
         "`command -v gitlab-ctl 2> /dev/null`" == "" ]; then
        echo "Please run restore in container."
        return 1
    fi
    if [ "$1" != "" ]; then
        local timestamp=$1
        local backup=$(ls /var/opt/gitlab/backups/ | grep ^$timestamp)
        echo "Restore from backup file:"
        echo " - '${backup}'"
        mv /var/opt/gitlab/backups/${backup} \
           /var/opt/gitlab/backups/${timestamp}_gitlab_backup.tar
        chmod 755 /var/opt/gitlab/backups/${timestamp}_gitlab_backup.tar
        gitlab-ctl stop unicorn
        gitlab-ctl stop sidekiq
        gitlab-rake gitlab:backup:restore BACKUP=$timestamp
        gitlab-ctl start unicorn
        gitlab-ctl start sidekiq
        gitlab-ctl start
        mv /var/opt/gitlab/backups/${timestamp}_gitlab_backup.tar \
           /var/opt/gitlab/backups/${backup}
    else
        echo "Need to specify the backup timestamp."
    fi
}

function docker_logger
{
    local name=$1
    if [ "$name" != "" ]; then
        if [ `docker container ls | grep -c $name` -ne 0 ]; then
            docker logs --tail 50 --follow --timestamps $name
        fi
    else
        echo "Need to specify the container name."
    fi
}

function clear_registry_garbage
{
    local times=$1
    for i in `seq 1 $times`
    do
        docker exec -i ${title}-gitlab gitlab-ctl registry-garbage-collect -m
    done
}

# main

# check env
if [ "`command -v docker`" == "" ]; then
    echo "ERROR: docker engine not found."
elif [ "$#" -eq 0 ]; then
    echo "ERROR: please specify an argument."
    exit 1
fi

# parse argv
case $1 in
    -h|--help)
        usage
        ;;
    start)
        service_start "$2"
        ;;
    stop)
        service_stop "$2"
        ;;
    restart)
        service_restart "$2"
        ;;
    status)
        docker container ls
        ;;
    --gitlab-srv)
        service_docker $2
        ;;
    --backup)
        service_backup
        ;;
    --restore)
        service_restore "$2"
        ;;
    --cmd)
        docker exec -it $2 `echo "$@"| cut -d ' ' -f3-255`
        ;;
    --ssh) 
        ssh_config $2
        ;;
    --log)
        docker_logger $2
        ;;
    --env)
        docker exec -u 0 -it $2 bash
        ;;
    --clear-garbage)
        clear_registry_garbage 2
        ;;
    * )
        echo "Invalid arguments, Try '-h/--help' for more information."
        exit 1;;
esac

