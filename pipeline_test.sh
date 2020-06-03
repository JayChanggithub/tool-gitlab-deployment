#!/bin/bash

RED="\033[1;31m"
BLUE="\033[1;34m"
YELLOW="\033[0;33m"
NC1="\033[0m"
collect_flag=True
report_name=$CI_PROJECT_NAME
__file__=$(basename $0)

function usage
{
    echo -en "${BLUE}"
    more << EOF
Usage: bash $__file__ [option] argv

Option to run
  -h, --help          display script uages
  -p, --project       specify the log name the same as project name
                      (default: ${report_name})
  --before            specify the CI pipeline run at before script
  --after             specify the CI pipeline run at after script
  --disable-collect   disable the collect the logfilter log
                      (default: $collect_flag)

EOF
    echo -en "${NC1}"
    return 0
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

function keycopy
{
    if [ -f ${PWD}/hosts ]; then
        local host_conf=hosts
    else
        local host_conf=inventory
    fi

    # configure hosts (replace ";" to "\n")
    sed -i "s,<SUT_USER>,${SUT_USER},g" ${PWD}/$host_conf
    sed -i "s,<SUT_PASS>,${SUT_PASS},g" ${PWD}/$host_conf
    sed -i "s,<SUT_IP>,${sut_ip},g" ${PWD}/$host_conf
    sed -i -E "s,\;,\n,g" ${PWD}/$host_conf

    # deploy key to each nodes
    for e in $(grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' $host_conf)
    do
        sshpass -p ${SUT_PASS} ssh-copy-id \
                -f \
                -i /root/.ssh/id_rsa.pub \
                ${SUT_USER}@${e} -o StrictHostKeychecking=no
        echo -e "${YELLOW}copy key to $e done.${NC1}"
    done
}

function before_script
{

    if [ -f ${PWD}/hosts ]; then
        local host_conf=hosts
    else
        local host_conf=inventory
    fi

    # print Group variables
    echo -e "${BLUE}Show Group variables:
===========================================================================${NC1}${YELLOW}
LOGFILTER_PATH: $LOGFILTER_PATH
LOGFILTER_PROJECT: $LOGFILTER_PROJECT
EXE_PATH: $EXE_PATH
WORK_PATH: $WORK_PATH
SUT_IP: $sut_ip
${NC1}${BLUE}===========================================================================${NC1}"

    # configure hosts (replace ";" to "\n")
    sed -i "s,<SUT_USER>,${SUT_USER},g" ${PWD}/$host_conf
    sed -i "s,<SUT_PASS>,${SUT_PASS},g" ${PWD}/$host_conf
    sed -i "s,<SUT_IP>,${sut_ip},g" ${PWD}/$host_conf
    sed -i -E "s,\;,\n,g" ${PWD}/$host_conf

    # clear SUT environment
    mkdir -p $LOGFILTER_PATH
    git clone $LOGFILTER_PROJECT ${LOGFILTER_PATH}/SIT-LogFilter
    ansible "*" -i ${PWD}/$host_conf -m copy \
                -a "src=${LOGFILTER_PATH}/SIT-LogFilter/LogFilterTool dest=$LOGFILTER_PATH owner=$SUT_USER group=$SUT_USER" \
                -b
    ansible "*" -i ${PWD}/$host_conf -m shell \
                -a "cd ${LOGFILTER_PATH}/LogFilterTool && python LogFilterTool.py --before --no-recommends" \
                -b
    echo "Test on SUT started."
}

function after_script
{
    if [ -f ${PWD}/hosts ]; then
        local host_conf=hosts
    else
        local host_conf=inventory
    fi

    # accept using API trigger job to ignore this condition
    if [ "$collect_flag" == "True" ] ||
       [ "$CI_PIPELINE_SOURCE" != "trigger" ]; then

        # collect logs and move it to report directory
        ansible "*" -i ${PWD}/$host_conf -m shell \
                    -a "cd $LOGFILTER_PATH/LogFilterTool && python LogFilterTool.py --after --no-recommends" \
                    -b
        ansible "*" -i ${PWD}/$host_conf -m shell \
                    -a "mv $LOGFILTER_PATH/LogFilterTool/reports/* ${EXE_PATH}/reports/" \
                    -b
    fi
    
    cp -rp ${PWD}/$(basename $TOOLS_PROJECT .git)/artifacts.yaml $PWD
   
    # execution ansible-playbook to generate artifacts in each host
    ansible-playbook -i ${PWD}/$host_conf --extra-vars "exe_path=${EXE_PATH} job_url=${CI_JOB_URL}" ${PWD}/artifacts.yaml
}

function main
{
    keycopy
    chkReqs curl ansible
    if [ "$run_mode" == "before" ]; then
        before_script
    elif [ "$run_mode" == "after" ]; then
        after_script
    else
        echo "Invalid arguments, only '--before/--after' option could be use."
        exit 1
    fi
}

if [ "$#" -eq 0 ]; then
    printf "%-40s [${RED} %s ${NC1}]\n" \
           " Invalid arguments,   " \
           "try '-h/--help' for more information"
    exit 1
fi

while [ "$1" != "" ]
do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --before)
            run_mode=before
            ;;
        --after)
            run_mode=after
            ;;
        -p|--project)
            shift
            report_name=$1
            ;;
        --disable-collect)
            collect_flag=False
            ;;
        *)
            printf "%-40s [${RED} %s ${NC1}]\n" \
                   " Invalid arguments,   " \
                   "try '-h/--help' for more information"
            exit 1
            ;;
    esac
    shift
done

# main
main
