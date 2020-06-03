#!/bin/bash

BLUE="\033[1;34m"
YELLOW="\033[0;33m"
NC1="\033[0m"

# define global functions
function usage
{
    more << EOF
Usage: $0 [Option] argv

Options:
  -p, --project     set project namespace
EOF
    exit 0
}

function chkReqs
{
    for p in $@
    do
        if [ "$(command -v $p 2> /dev/null)" == "" ]; then
            echo "'$p' command not found."
            exit 1
        fi
    done
}

function clone
{

    if [ -f ${PWD}/hosts ]; then
        local host_conf=hosts
    else
        local host_conf=inventory
    fi

    # print Group variables
    echo -e "${BLUE}Show Group variables:
===========================================================================${NC1}${YELLOW}
Old Project Name:  $CI_PROJECT_NAME
New Project Name:  $project_name
Namespace:         $project_namespace
SUT Host:          $sut_ip
Execute Path:      $EXE_PATH
Work Path:         $WORK_PATH
${NC1}${BLUE}===========================================================================${NC1}"

    # remove all files in current except root relatived path and tool project
    if [ $(echo $PWD | grep -cE '^(\/[a-zA-Z0-9]+|\/)$') -eq 0 ]; then
        for file in $(ls)
        do
            if [ "$file" == "tool-gitlab-deployment" ]; then
                continue
            fi
            rm -rf $file
        done
    fi

    # clone test project
    git clone http://ipt-gitlab.ies.inventec:8081/${project}.git $project_name
    mv ${project_name}/* .
    rm -rf $project_name

    # configure hosts (replace ";" to "\n")
    sed -i "s,<SUT_USER>,${SUT_USER},g" $host_conf
    sed -i "s,<SUT_PASS>,${SUT_PASS},g" $host_conf
    sed -i "s,<SUT_IP>,${sut_ip},g" $host_conf
    sed -i -E "s,\;,\n,g" $host_conf

    # deploy test scripts
    ansible "*" -i ${PWD}/hosts -m shell -a "mkdir -p $WORK_PATH" -b
    ansible "*" -i ${PWD}/hosts -m shell -a "rm -rf $EXE_PATH" -b
    ansible "*" -i ${PWD}/hosts -m copy  -a "src=$PWD dest=$WORK_PATH owner=$SUT_USER group=$SUT_USER" -b
    ansible "*" -i ${PWD}/hosts -m shell -a "cd $EXE_PATH && chmod 755 *.py lib/*.py tools/*" || true

    echo -e "\nConfigure test environment complete"'!\n'
}

function main
{
    chkReqs git curl ansible
    project_name=$(basename $project)
    project_namespace=$(dirname $project)
    clone
}

# parse arguments
if [ "$#" -eq 0 ]; then
    echo "Invalid arguments, try '-h/--help' for more information."
    exit 1
fi
while [ "$1" != "" ]
do
    case $1 in
        -h|--help)
            usage
            ;;
        -p|--project)
            shift
            project=$1
            ;;
        * ) echo "Invalid arguments, try '-h/--help' for more information."
            exit 1
            ;;
    esac
    shift
done

# main
main

